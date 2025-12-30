"""App upgrade/update check API for client applications."""
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from app.api.deps import get_db
from app.models.app_version import AppVersion


router = APIRouter(prefix="/app-upgrade", tags=["App Upgrade"])


# ============== Response Models ==============

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


class CheckUpdateResponse(BaseModel):
    """Update check response."""
    has_update: bool
    is_force_update: bool
    current_version: str
    latest_version: Optional[VersionInfo] = None
    message: Optional[str] = None


# ============== Helper Functions ==============

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
    version_name: str = Query(..., description="Current app version (e.g., '1.2.0')"),
    version_code: int = Query(..., description="Current build number (e.g., 18)"),
    platform: str = Query("android", description="Platform (android/ios)"),
    db: AsyncSession = Depends(get_db),
):
    """Check for app updates.

    This endpoint does not require authentication and is called by the app
    on startup to check for available updates.

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

    # Determine if force update is required
    is_force = latest.is_force_update

    # Also force if current version is below minimum supported version
    if latest.min_supported_version:
        if compare_versions(version_name, latest.min_supported_version) < 0:
            is_force = True

    return CheckUpdateResponse(
        has_update=True,
        is_force_update=is_force,
        current_version=version_name,
        latest_version=VersionInfo(
            version_name=latest.version_name,
            version_code=latest.version_code,
            release_notes=latest.release_notes,
            release_notes_en=latest.release_notes_en,
            is_force_update=is_force,
            download_url=latest.file_url,
            file_size=latest.file_size,
            file_md5=latest.file_md5,
            published_at=latest.published_at,
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

    return VersionInfo(
        version_name=latest.version_name,
        version_code=latest.version_code,
        release_notes=latest.release_notes,
        release_notes_en=latest.release_notes_en,
        is_force_update=latest.is_force_update,
        download_url=latest.file_url,
        file_size=latest.file_size,
        file_md5=latest.file_md5,
        published_at=latest.published_at,
    )
