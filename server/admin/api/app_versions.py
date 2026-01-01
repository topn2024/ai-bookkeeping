"""Admin app version management endpoints."""
import hashlib
import io
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, Query, HTTPException, status, Request, UploadFile, File, Form
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from app.core.database import get_db
from app.core.config import get_settings
from app.models.app_version import AppVersion
from app.services.file_storage_service import file_storage_service
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.audit import create_audit_log


router = APIRouter(prefix="/app-versions", tags=["App Version Management"])


# ============== Helper Functions ==============

def format_size(size_bytes: int) -> str:
    """Format bytes to human readable string."""
    if size_bytes is None:
        return "-"
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


# ============== Request/Response Models ==============

class AppVersionCreate(BaseModel):
    """Create app version request."""
    version_name: str
    version_code: int
    platform: str = "android"
    release_notes: str
    release_notes_en: Optional[str] = None
    is_force_update: bool = False
    min_supported_version: Optional[str] = None


class AppVersionUpdate(BaseModel):
    """Update app version request."""
    release_notes: Optional[str] = None
    release_notes_en: Optional[str] = None
    is_force_update: Optional[bool] = None
    min_supported_version: Optional[str] = None


class DeleteVersionRequest(BaseModel):
    """Delete version request with password verification."""
    password: str


class AppVersionResponse(BaseModel):
    """App version response."""
    id: UUID
    version_name: str
    version_code: int
    platform: str
    file_url: Optional[str]
    file_size: Optional[int]
    file_size_formatted: str
    file_md5: Optional[str]
    release_notes: str
    release_notes_en: Optional[str]
    is_force_update: bool
    min_supported_version: Optional[str]
    status: int
    status_text: str
    published_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime
    created_by: Optional[str]

    @classmethod
    def from_model(cls, model: AppVersion) -> "AppVersionResponse":
        status_map = {0: "草稿", 1: "已发布", 2: "已废弃"}
        return cls(
            id=model.id,
            version_name=model.version_name,
            version_code=model.version_code,
            platform=model.platform,
            file_url=model.file_url,
            file_size=model.file_size,
            file_size_formatted=format_size(model.file_size) if model.file_size else "-",
            file_md5=model.file_md5,
            release_notes=model.release_notes,
            release_notes_en=model.release_notes_en,
            is_force_update=model.is_force_update,
            min_supported_version=model.min_supported_version,
            status=model.status,
            status_text=status_map.get(model.status, "未知"),
            published_at=model.published_at,
            created_at=model.created_at,
            updated_at=model.updated_at,
            created_by=model.created_by,
        )


class AppVersionListResponse(BaseModel):
    """App version list response."""
    items: List[AppVersionResponse]
    total: int


# ============== API Endpoints ==============

@router.get("", response_model=AppVersionListResponse)
async def list_versions(
    platform: str = Query("android", description="Platform filter"),
    status_filter: Optional[int] = Query(None, alias="status", description="Status filter: 0=draft, 1=published, 2=deprecated"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """List all app versions.

    Supports filtering by platform and status.
    Results are ordered by version_code descending.
    """
    query = select(AppVersion).where(AppVersion.platform == platform)

    if status_filter is not None:
        query = query.where(AppVersion.status == status_filter)

    # Get total count
    from sqlalchemy import func
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Get paginated results
    query = query.order_by(desc(AppVersion.version_code)).offset(skip).limit(limit)
    result = await db.execute(query)
    versions = result.scalars().all()

    return AppVersionListResponse(
        items=[AppVersionResponse.from_model(v) for v in versions],
        total=total,
    )


@router.get("/latest", response_model=Optional[AppVersionResponse])
async def get_latest_version(
    platform: str = Query("android"),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get the latest published version."""
    result = await db.execute(
        select(AppVersion)
        .where(
            AppVersion.platform == platform,
            AppVersion.status == 1,  # Published only
        )
        .order_by(desc(AppVersion.version_code))
        .limit(1)
    )
    version = result.scalar_one_or_none()

    if not version:
        return None

    return AppVersionResponse.from_model(version)


@router.get("/{version_id}", response_model=AppVersionResponse)
async def get_version(
    version_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Get version details by ID."""
    result = await db.execute(
        select(AppVersion).where(AppVersion.id == version_id)
    )
    version = result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="版本不存在",
        )

    return AppVersionResponse.from_model(version)


@router.post("", response_model=AppVersionResponse)
async def create_version(
    request: Request,
    data: AppVersionCreate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Create a new app version.

    The version is created in draft status. Upload APK and publish separately.
    """
    # Check if version already exists
    existing = await db.execute(
        select(AppVersion).where(
            AppVersion.version_name == data.version_name,
            AppVersion.version_code == data.version_code,
            AppVersion.platform == data.platform,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该版本号已存在",
        )

    version = AppVersion(
        version_name=data.version_name,
        version_code=data.version_code,
        platform=data.platform,
        release_notes=data.release_notes,
        release_notes_en=data.release_notes_en,
        is_force_update=data.is_force_update,
        min_supported_version=data.min_supported_version,
        status=0,  # Draft
        created_by=current_admin.username,
    )

    db.add(version)

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="app_version.create",
        module="app_version",
        target_type="app_version",
        target_name=f"{data.version_name}+{data.version_code}",
        description=f"创建APP版本: {data.version_name}+{data.version_code} ({data.platform})",
        request=request,
    )

    await db.commit()
    await db.refresh(version)

    return AppVersionResponse.from_model(version)


@router.put("/{version_id}", response_model=AppVersionResponse)
async def update_version(
    request: Request,
    version_id: UUID,
    data: AppVersionUpdate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update app version info.

    For draft versions: all fields can be updated.
    For published versions: only release_notes and release_notes_en can be updated.
    """
    result = await db.execute(
        select(AppVersion).where(AppVersion.id == version_id)
    )
    version = result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="版本不存在",
        )

    # For published versions, only allow updating release notes
    if version.status == 1:
        if data.is_force_update is not None or data.min_supported_version is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="已发布版本只能修改 release notes",
            )

    # Update fields
    if data.release_notes is not None:
        version.release_notes = data.release_notes
    if data.release_notes_en is not None:
        version.release_notes_en = data.release_notes_en
    if data.is_force_update is not None:
        version.is_force_update = data.is_force_update
    if data.min_supported_version is not None:
        version.min_supported_version = data.min_supported_version

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="app_version.update",
        module="app_version",
        target_type="app_version",
        target_id=str(version_id),
        target_name=version.full_version,
        description=f"更新APP版本: {version.full_version}",
        request=request,
    )

    await db.commit()
    await db.refresh(version)

    return AppVersionResponse.from_model(version)


@router.post("/{version_id}/upload-apk")
async def upload_apk(
    request: Request,
    version_id: UUID,
    file: UploadFile = File(...),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Upload APK file for a version.

    Only draft versions can have APK uploaded. If APK already exists, it will be replaced.
    """
    result = await db.execute(
        select(AppVersion).where(AppVersion.id == version_id)
    )
    version = result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="版本不存在",
        )

    if version.status == 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="已发布版本不能修改APK",
        )

    # Validate file type
    if not file.filename or not file.filename.lower().endswith('.apk'):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="只支持APK文件",
        )

    # Read file content
    content = await file.read()
    file_size = len(content)

    # Calculate MD5
    file_md5 = hashlib.md5(content).hexdigest()

    # Upload to MinIO
    settings = get_settings()
    object_name = f"app-releases/{version.platform}/{version.version_name}/app-release-{version.version_code}.apk"

    # Ensure bucket exists
    await file_storage_service.ensure_bucket()

    # Upload file
    file_storage_service.client.put_object(
        settings.MINIO_BUCKET,
        object_name,
        io.BytesIO(content),
        length=file_size,
        content_type="application/vnd.android.package-archive",
    )

    # Build URL
    protocol = "https" if settings.MINIO_SECURE else "http"
    file_url = f"{protocol}://{settings.MINIO_ENDPOINT}/{settings.MINIO_BUCKET}/{object_name}"

    # Update version record
    version.file_url = file_url
    version.file_size = file_size
    version.file_md5 = file_md5

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="app_version.upload_apk",
        module="app_version",
        target_type="app_version",
        target_id=str(version_id),
        target_name=version.full_version,
        description=f"上传APK: {version.full_version}, 大小: {format_size(file_size)}",
        request=request,
    )

    await db.commit()

    return {
        "message": "APK上传成功",
        "url": file_url,
        "size": file_size,
        "size_formatted": format_size(file_size),
        "md5": file_md5,
    }


@router.post("/{version_id}/publish")
async def publish_version(
    request: Request,
    version_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Publish a version.

    Requires APK to be uploaded first. Once published, the version becomes available for updates.
    """
    result = await db.execute(
        select(AppVersion).where(AppVersion.id == version_id)
    )
    version = result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="版本不存在",
        )

    if version.status == 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="版本已发布",
        )

    if not version.file_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="请先上传APK文件",
        )

    version.status = 1
    version.published_at = datetime.utcnow()

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="app_version.publish",
        module="app_version",
        target_type="app_version",
        target_id=str(version_id),
        target_name=version.full_version,
        description=f"发布APP版本: {version.full_version}",
        request=request,
    )

    await db.commit()

    return {
        "message": "版本已发布",
        "version": version.full_version,
        "published_at": version.published_at.isoformat(),
    }


@router.post("/{version_id}/deprecate")
async def deprecate_version(
    request: Request,
    version_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Deprecate a version.

    Deprecated versions are no longer available for updates but remain in the system.
    """
    result = await db.execute(
        select(AppVersion).where(AppVersion.id == version_id)
    )
    version = result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="版本不存在",
        )

    if version.status == 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="版本已废弃",
        )

    version.status = 2

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="app_version.deprecate",
        module="app_version",
        target_type="app_version",
        target_id=str(version_id),
        target_name=version.full_version,
        description=f"废弃APP版本: {version.full_version}",
        request=request,
    )

    await db.commit()

    return {
        "message": "版本已废弃",
        "version": version.full_version,
    }


@router.delete("/{version_id}")
async def delete_version(
    request: Request,
    version_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Delete a draft version (no password required).

    Only draft versions can be deleted with this endpoint.
    For deprecated versions, use the POST /{version_id}/delete endpoint with password.
    """
    result = await db.execute(
        select(AppVersion).where(AppVersion.id == version_id)
    )
    version = result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="版本不存在",
        )

    if version.status != 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="只能删除草稿版本，已发布版本请使用废弃功能，废弃版本请使用密码删除功能",
        )

    version_name = version.full_version

    # Delete APK file from MinIO if exists
    if version.file_url:
        try:
            settings = get_settings()
            # Extract object name from URL
            object_name = f"app-releases/{version.platform}/{version.version_name}/app-release-{version.version_code}.apk"
            file_storage_service.client.remove_object(settings.MINIO_BUCKET, object_name)
        except Exception:
            pass  # Ignore errors when deleting file

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="app_version.delete",
        module="app_version",
        target_type="app_version",
        target_id=str(version_id),
        target_name=version_name,
        description=f"删除APP版本: {version_name}",
        request=request,
    )

    await db.delete(version)
    await db.commit()

    return {
        "message": "版本已删除",
        "version": version_name,
    }


@router.post("/{version_id}/delete")
async def delete_deprecated_version(
    request: Request,
    version_id: UUID,
    data: DeleteVersionRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """Delete a deprecated version with password verification.

    Only deprecated versions (status=2) can be deleted with this endpoint.
    Requires admin password for verification.
    """
    from admin.core.security import verify_password

    result = await db.execute(
        select(AppVersion).where(AppVersion.id == version_id)
    )
    version = result.scalar_one_or_none()

    if not version:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="版本不存在",
        )

    if version.status == 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="已发布版本不能删除，请先将其废弃",
        )

    if version.status == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="草稿版本请直接使用删除功能，无需密码验证",
        )

    # Verify admin password
    if not verify_password(data.password, current_admin.hashed_password):
        # Audit log for failed attempt
        await create_audit_log(
            db=db,
            admin_id=current_admin.id,
            admin_username=current_admin.username,
            action="app_version.delete_failed",
            module="app_version",
            target_type="app_version",
            target_id=str(version_id),
            target_name=version.full_version,
            description=f"删除废弃版本失败(密码错误): {version.full_version}",
            request=request,
        )
        await db.commit()

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="密码错误",
        )

    version_name = version.full_version

    # Delete APK file from MinIO if exists
    if version.file_url:
        try:
            settings = get_settings()
            object_name = f"app-releases/{version.platform}/{version.version_name}/app-release-{version.version_code}.apk"
            file_storage_service.client.remove_object(settings.MINIO_BUCKET, object_name)
        except Exception:
            pass  # Ignore errors when deleting file

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="app_version.delete_deprecated",
        module="app_version",
        target_type="app_version",
        target_id=str(version_id),
        target_name=version_name,
        description=f"删除废弃版本: {version_name} (需密码验证)",
        request=request,
    )

    await db.delete(version)
    await db.commit()

    return {
        "message": "废弃版本已删除",
        "version": version_name,
    }
