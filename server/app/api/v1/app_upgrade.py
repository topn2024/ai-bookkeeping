"""App upgrade/update check API for client applications."""
import logging
import hashlib
import json
from fastapi import APIRouter, Depends, Query, Request, Header
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func

from app.api.deps import get_db
from app.models.app_version import AppVersion
from app.models.upgrade_analytics import UpgradeAnalytics
from app.services.signed_url_service import create_download_url

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/app-upgrade", tags=["App Upgrade"])


# ============== Response Models ==============

class PatchInfo(BaseModel):
    """Patch (incremental update) information."""
    from_version: str
    from_code: int
    download_url: str
    file_size: int
    file_md5: str


class VersionInfo(BaseModel):
    """Version information."""
    version_name: str
    version_code: int
    release_notes: str
    release_notes_en: Optional[str] = None
    is_force_update: bool
    download_url: Optional[str] = None
    file_size: Optional[int] = None
    file_md5: Optional[str] = None
    published_at: Optional[datetime] = None
    # Patch info (incremental update)
    patch: Optional[PatchInfo] = None


class CheckUpdateResponse(BaseModel):
    """Update check response."""
    has_update: bool
    is_force_update: bool
    current_version: str
    latest_version: Optional[VersionInfo] = None
    message: Optional[str] = None
    # Whether patch update is available
    has_patch: bool = False


# ============== Helper Functions ==============

def is_in_rollout(device_id: str, rollout_percentage: int) -> bool:
    """Determine if a device is in the rollout group.

    Uses consistent hashing to ensure the same device always gets
    the same result for a given rollout percentage.

    Args:
        device_id: Unique device identifier
        rollout_percentage: 0-100 percentage of devices to include

    Returns:
        True if device should receive the update
    """
    if rollout_percentage >= 100:
        return True
    if rollout_percentage <= 0:
        return False

    # Create a hash of the device ID
    hash_bytes = hashlib.md5(device_id.encode()).digest()
    # Use first 4 bytes to get a number 0-255
    hash_value = int.from_bytes(hash_bytes[:4], 'big')
    # Normalize to 0-100
    device_bucket = hash_value % 100

    return device_bucket < rollout_percentage


def compare_versions(v1: str, v2: str) -> int:
    """Compare two version strings.

    Args:
        v1: First version string (e.g., "1.2.0")
        v2: Second version string (e.g., "1.3.0")

    Returns:
        -1 if v1 < v2
        0 if v1 == v2
        1 if v1 > v2
    """
    try:
        parts1 = [int(x) for x in v1.split('.')]
        parts2 = [int(x) for x in v2.split('.')]

        # Pad with zeros to make equal length
        while len(parts1) < len(parts2):
            parts1.append(0)
        while len(parts2) < len(parts1):
            parts2.append(0)

        for p1, p2 in zip(parts1, parts2):
            if p1 < p2:
                return -1
            elif p1 > p2:
                return 1
        return 0
    except (ValueError, AttributeError):
        return 0


# ============== API Endpoints ==============

@router.get("/check", response_model=CheckUpdateResponse)
async def check_update(
    request: Request,
    version_name: str = Query(..., description="Current app version (e.g., '1.2.0')"),
    version_code: int = Query(..., description="Current build number (e.g., 18)"),
    platform: str = Query("android", description="Platform (android/ios)"),
    device_id: Optional[str] = Query(None, description="Device ID for gradual rollout"),
    db: AsyncSession = Depends(get_db),
):
    """Check for app updates.

    This endpoint does not require authentication and is called by the app
    on startup to check for available updates.

    The device_id parameter is used for gradual rollout. If provided, the
    server will use consistent hashing to determine if this device should
    receive the update based on the rollout percentage.

    Returns information about whether an update is available and if it's
    a forced update.
    """
    # Query the latest published version for this platform
    result = await db.execute(
        select(AppVersion)
        .where(
            AppVersion.platform == platform,
            AppVersion.status == 1,  # Published only
        )
        .order_by(desc(AppVersion.version_code))
        .limit(1)
    )
    latest = result.scalar_one_or_none()

    # No published versions found
    if not latest:
        return CheckUpdateResponse(
            has_update=False,
            is_force_update=False,
            current_version=version_name,
            message="Already up to date"
        )

    # Check if update is available (compare version codes)
    has_update = latest.version_code > version_code

    if not has_update:
        return CheckUpdateResponse(
            has_update=False,
            is_force_update=False,
            current_version=version_name,
            message="Already up to date"
        )

    # Check gradual rollout (if device_id provided and rollout < 100%)
    rollout_percentage = getattr(latest, 'rollout_percentage', 100) or 100
    if device_id and rollout_percentage < 100:
        if not is_in_rollout(device_id, rollout_percentage):
            logger.info(
                f"Device {device_id[:8]}... excluded from rollout "
                f"({rollout_percentage}%) for version {latest.version_name}"
            )
            return CheckUpdateResponse(
                has_update=False,
                is_force_update=False,
                current_version=version_name,
                message="Already up to date"  # Don't reveal rollout status
            )

    # Determine if force update is required
    is_force = latest.is_force_update

    # Also force if current version is below minimum supported version
    if latest.min_supported_version:
        if compare_versions(version_name, latest.min_supported_version) < 0:
            is_force = True

    # Generate signed download URL (valid for 2 hours)
    download_url = None
    if latest.file_url:
        try:
            download_url = create_download_url(
                latest.file_url,
                expire_seconds=7200,  # 2 hours
            )
            logger.info(f"Generated signed URL for version {latest.version_name}")
        except Exception as e:
            logger.warning(f"Failed to sign URL, using original: {e}")
            download_url = latest.file_url

    # Check if patch (incremental update) is available
    patch_info = None
    has_patch = False

    # Patch is available if:
    # 1. The latest version has a patch file
    # 2. The patch is from the user's current version
    if (latest.patch_file_url and
        latest.patch_from_code and
        latest.patch_from_code == version_code):
        try:
            patch_download_url = create_download_url(
                latest.patch_file_url,
                expire_seconds=7200,
            )
            patch_info = PatchInfo(
                from_version=latest.patch_from_version or version_name,
                from_code=latest.patch_from_code,
                download_url=patch_download_url,
                file_size=latest.patch_file_size or 0,
                file_md5=latest.patch_file_md5 or "",
            )
            has_patch = True
            logger.info(
                f"Patch available from v{version_code} to v{latest.version_code}"
            )
        except Exception as e:
            logger.warning(f"Failed to generate patch URL: {e}")

    return CheckUpdateResponse(
        has_update=True,
        is_force_update=is_force,
        current_version=version_name,
        has_patch=has_patch,
        latest_version=VersionInfo(
            version_name=latest.version_name,
            version_code=latest.version_code,
            release_notes=latest.release_notes,
            release_notes_en=latest.release_notes_en,
            is_force_update=is_force,
            download_url=download_url,
            file_size=latest.file_size,
            file_md5=latest.file_md5,
            published_at=latest.published_at,
            patch=patch_info,
        ),
        message="New version available"
    )


@router.get("/latest", response_model=Optional[VersionInfo])
async def get_latest_version(
    platform: str = Query("android", description="Platform (android/ios)"),
    db: AsyncSession = Depends(get_db),
):
    """Get the latest published version info.

    Returns None if no published version exists.
    """
    result = await db.execute(
        select(AppVersion)
        .where(
            AppVersion.platform == platform,
            AppVersion.status == 1,  # Published only
        )
        .order_by(desc(AppVersion.version_code))
        .limit(1)
    )
    latest = result.scalar_one_or_none()

    if not latest:
        return None

    # Generate signed download URL
    download_url = None
    if latest.file_url:
        try:
            download_url = create_download_url(
                latest.file_url,
                expire_seconds=7200,  # 2 hours
            )
        except Exception as e:
            logger.warning(f"Failed to sign URL: {e}")
            download_url = latest.file_url

    return VersionInfo(
        version_name=latest.version_name,
        version_code=latest.version_code,
        release_notes=latest.release_notes,
        release_notes_en=latest.release_notes_en,
        is_force_update=latest.is_force_update,
        download_url=download_url,
        file_size=latest.file_size,
        file_md5=latest.file_md5,
        published_at=latest.published_at,
    )


# ============== Analytics Models ==============

class AnalyticsEventRequest(BaseModel):
    """Analytics event from client."""
    event_type: str = Field(..., description="Event type name")
    from_version: str = Field(..., description="Current app version")
    to_version: Optional[str] = Field(None, description="Target version")
    download_progress: Optional[int] = Field(None, description="Download progress 0-100")
    download_size: Optional[int] = Field(None, description="Download size in bytes")
    download_duration_ms: Optional[int] = Field(None, description="Download duration in ms")
    error_message: Optional[str] = Field(None, description="Error message")
    error_code: Optional[str] = Field(None, description="Error code")
    timestamp: Optional[datetime] = Field(None, description="Event timestamp")
    platform: str = Field("android", description="Platform")
    device_model: Optional[str] = Field(None, description="Device model")
    device_id: Optional[str] = Field(None, description="Device ID")
    app_version: Optional[str] = Field(None, description="App version")
    app_build: Optional[str] = Field(None, description="App build number")
    extra: Optional[Dict[str, Any]] = Field(None, description="Extra data")


class AnalyticsResponse(BaseModel):
    """Response for analytics submission."""
    success: bool
    message: str


class UpgradeStatsResponse(BaseModel):
    """Upgrade statistics response."""
    version: str
    total_checks: int
    total_downloads: int
    download_success_rate: float
    install_success_rate: float
    avg_download_duration_ms: Optional[int]
    events_by_type: Dict[str, int]


# ============== Analytics Endpoints ==============

@router.post("/analytics", response_model=AnalyticsResponse)
async def submit_analytics(
    event: AnalyticsEventRequest,
    db: AsyncSession = Depends(get_db),
):
    """Submit an upgrade analytics event.

    This endpoint receives analytics events from client apps
    to track upgrade behavior and diagnose issues.

    No authentication required.
    """
    try:
        # Create analytics record
        analytics = UpgradeAnalytics(
            event_type=event.event_type,
            platform=event.platform,
            from_version=event.from_version,
            to_version=event.to_version,
            download_progress=event.download_progress,
            download_size=event.download_size,
            download_duration_ms=event.download_duration_ms,
            error_message=event.error_message,
            error_code=event.error_code,
            device_id=event.device_id,
            device_model=event.device_model,
            extra_data=json.dumps(event.extra) if event.extra else None,
            event_time=event.timestamp or datetime.utcnow(),
        )

        # Parse build number
        if event.app_build:
            try:
                analytics.from_build = int(event.app_build)
            except ValueError:
                pass

        db.add(analytics)
        await db.commit()

        logger.debug(f"Recorded analytics event: {event.event_type} from {event.from_version}")

        return AnalyticsResponse(
            success=True,
            message="Event recorded"
        )
    except Exception as e:
        logger.error(f"Failed to record analytics: {e}")
        return AnalyticsResponse(
            success=False,
            message="Failed to record event"
        )


@router.get("/stats/{version}", response_model=UpgradeStatsResponse)
async def get_upgrade_stats(
    version: str,
    platform: str = Query("android", description="Platform"),
    db: AsyncSession = Depends(get_db),
):
    """Get upgrade statistics for a specific version.

    Returns metrics about how many users have checked for,
    downloaded, and installed this version.
    """
    # Count events by type
    result = await db.execute(
        select(
            UpgradeAnalytics.event_type,
            func.count(UpgradeAnalytics.id).label('count')
        )
        .where(
            UpgradeAnalytics.to_version == version,
            UpgradeAnalytics.platform == platform,
        )
        .group_by(UpgradeAnalytics.event_type)
    )
    events_by_type = {row.event_type: row.count for row in result.all()}

    # Calculate metrics
    total_checks = events_by_type.get('updateFound', 0) + events_by_type.get('check_update', 0)
    download_starts = events_by_type.get('downloadStart', 0) + events_by_type.get('download_start', 0)
    download_complete = events_by_type.get('downloadComplete', 0) + events_by_type.get('download_complete', 0)
    install_success = events_by_type.get('installSuccess', 0) + events_by_type.get('install_success', 0)

    download_success_rate = (download_complete / download_starts * 100) if download_starts > 0 else 0
    install_success_rate = (install_success / download_complete * 100) if download_complete > 0 else 0

    # Average download duration
    avg_result = await db.execute(
        select(func.avg(UpgradeAnalytics.download_duration_ms))
        .where(
            UpgradeAnalytics.to_version == version,
            UpgradeAnalytics.platform == platform,
            UpgradeAnalytics.event_type.in_(['downloadComplete', 'download_complete']),
            UpgradeAnalytics.download_duration_ms.isnot(None),
        )
    )
    avg_duration = avg_result.scalar()

    return UpgradeStatsResponse(
        version=version,
        total_checks=total_checks,
        total_downloads=download_starts,
        download_success_rate=round(download_success_rate, 1),
        install_success_rate=round(install_success_rate, 1),
        avg_download_duration_ms=int(avg_duration) if avg_duration else None,
        events_by_type=events_by_type,
    )
