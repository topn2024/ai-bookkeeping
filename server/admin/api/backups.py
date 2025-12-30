"""Admin backup management endpoints."""
from datetime import datetime, date, timedelta
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, delete

from app.core.database import get_db
from app.models.backup import Backup
from app.models.user import User
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.core.audit import create_audit_log, mask_email
from admin.schemas.data_management import (
    BackupItem,
    BackupListResponse,
    BackupStorageStats,
    BackupPolicyConfig,
)


router = APIRouter(prefix="/backups", tags=["Backup Management"])


BACKUP_TYPES = {0: "手动备份", 1: "自动备份"}


def format_size(size_bytes: int) -> str:
    """Format bytes to human readable string."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


@router.get("", response_model=BackupListResponse)
async def list_backups(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: Optional[UUID] = None,
    backup_type: Optional[int] = Query(None, ge=0, le=1),
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:backup:view")),
):
    """获取备份列表 (DM-015)"""
    query = select(Backup)

    conditions = []

    if user_id:
        conditions.append(Backup.user_id == user_id)

    if backup_type is not None:
        conditions.append(Backup.backup_type == backup_type)

    if start_date:
        conditions.append(func.date(Backup.created_at) >= start_date)

    if end_date:
        conditions.append(func.date(Backup.created_at) <= end_date)

    if conditions:
        query = query.where(and_(*conditions))

    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Pagination
    offset = (page - 1) * page_size
    query = query.order_by(Backup.created_at.desc()).offset(offset).limit(page_size)

    result = await db.execute(query)
    backups = result.scalars().all()

    # Build response
    items = []
    for backup in backups:
        # Get user email
        user_result = await db.execute(select(User.email).where(User.id == backup.user_id))
        user_email = user_result.scalar()

        items.append(BackupItem(
            id=backup.id,
            user_id=backup.user_id,
            user_email=mask_email(user_email) if user_email else None,
            name=backup.name,
            description=backup.description,
            backup_type=backup.backup_type,
            transaction_count=backup.transaction_count,
            account_count=backup.account_count,
            category_count=backup.category_count,
            book_count=backup.book_count,
            budget_count=backup.budget_count,
            size=backup.size,
            device_name=backup.device_name,
            app_version=backup.app_version,
            created_at=backup.created_at,
        ))

    return BackupListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/storage-stats", response_model=BackupStorageStats)
async def get_backup_storage_stats(
    days: int = Query(30, ge=1, le=90),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:backup:view")),
):
    """获取备份存储统计 (DM-016)"""
    # Total stats
    total_result = await db.execute(
        select(
            func.count(Backup.id).label("count"),
            func.coalesce(func.sum(Backup.size), 0).label("size"),
        )
    )
    totals = total_result.one()
    total_count = totals.count or 0
    total_size = totals.size or 0

    # By type
    type_result = await db.execute(
        select(
            Backup.backup_type,
            func.count(Backup.id).label("count"),
            func.coalesce(func.sum(Backup.size), 0).label("size"),
        ).group_by(Backup.backup_type)
    )
    by_type = {
        BACKUP_TYPES.get(row.backup_type, "unknown"): {
            "count": row.count,
            "size": row.size,
            "size_formatted": format_size(row.size),
        }
        for row in type_result.all()
    }

    # By date (last N days)
    start_date = date.today() - timedelta(days=days - 1)
    daily_result = await db.execute(
        select(
            func.date(Backup.created_at).label("day"),
            func.count(Backup.id).label("count"),
            func.coalesce(func.sum(Backup.size), 0).label("size"),
        ).where(
            func.date(Backup.created_at) >= start_date
        ).group_by(
            func.date(Backup.created_at)
        ).order_by(
            func.date(Backup.created_at)
        )
    )
    by_date = [
        {
            "date": row.day.isoformat(),
            "count": row.count,
            "size": row.size,
            "size_formatted": format_size(row.size),
        }
        for row in daily_result.all()
    ]

    # Top users by backup size
    top_users_result = await db.execute(
        select(
            Backup.user_id,
            func.count(Backup.id).label("backup_count"),
            func.coalesce(func.sum(Backup.size), 0).label("total_size"),
        ).group_by(
            Backup.user_id
        ).order_by(
            func.sum(Backup.size).desc()
        ).limit(10)
    )

    top_users = []
    for row in top_users_result.all():
        user_result = await db.execute(select(User.email).where(User.id == row.user_id))
        user_email = user_result.scalar()

        top_users.append({
            "user_id": str(row.user_id),
            "user_email": mask_email(user_email) if user_email else None,
            "backup_count": row.backup_count,
            "total_size": row.total_size,
            "total_size_formatted": format_size(row.total_size),
        })

    return BackupStorageStats(
        total_backups=total_count,
        total_size=total_size,
        total_size_formatted=format_size(total_size),
        by_type=by_type,
        by_date=by_date,
        top_users=top_users,
    )


@router.post("/cleanup")
async def cleanup_expired_backups(
    request: Request,
    retention_days: int = Query(90, ge=7, le=365),
    dry_run: bool = Query(True),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:backup:delete")),
):
    """清理过期备份 (DM-017)"""
    cutoff_date = datetime.utcnow() - timedelta(days=retention_days)

    # Find expired backups
    expired_query = select(Backup).where(Backup.created_at < cutoff_date)
    expired_result = await db.execute(expired_query)
    expired_backups = expired_result.scalars().all()

    total_count = len(expired_backups)
    total_size = sum(b.size for b in expired_backups)

    if dry_run:
        return {
            "dry_run": True,
            "would_delete": total_count,
            "would_free_size": total_size,
            "would_free_size_formatted": format_size(total_size),
            "cutoff_date": cutoff_date.isoformat(),
        }

    # Actually delete
    if total_count > 0:
        await db.execute(
            delete(Backup).where(Backup.created_at < cutoff_date)
        )

        # Audit log
        await create_audit_log(
            db=db,
            admin_id=current_admin.id,
            admin_username=current_admin.username,
            action="backup.cleanup",
            module="backup",
            description=f"清理过期备份: {total_count} 个, 释放空间: {format_size(total_size)}",
            request=request,
        )

        await db.commit()

    return {
        "dry_run": False,
        "deleted": total_count,
        "freed_size": total_size,
        "freed_size_formatted": format_size(total_size),
        "cutoff_date": cutoff_date.isoformat(),
    }


@router.delete("/{backup_id}")
async def delete_backup(
    request: Request,
    backup_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:backup:delete")),
):
    """删除单个备份"""
    result = await db.execute(select(Backup).where(Backup.id == backup_id))
    backup = result.scalar_one_or_none()

    if not backup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="备份不存在",
        )

    backup_name = backup.name
    backup_size = backup.size

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="backup.delete",
        module="backup",
        target_type="backup",
        target_id=str(backup_id),
        target_name=backup_name,
        description=f"删除备份: {backup_name}, 大小: {format_size(backup_size)}",
        request=request,
    )

    await db.delete(backup)
    await db.commit()

    return {
        "message": "备份已删除",
        "freed_size": backup_size,
        "freed_size_formatted": format_size(backup_size),
    }


@router.get("/policy")
async def get_backup_policy(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("data:backup:view")),
):
    """获取备份策略配置 (DM-018)"""
    # In a real implementation, this would be stored in database or config
    # For now, return default values
    return BackupPolicyConfig(
        retention_days=90,
        max_backups_per_user=10,
        max_backup_size_mb=50,
        auto_cleanup_enabled=True,
    )


@router.put("/policy")
async def update_backup_policy(
    request: Request,
    policy: BackupPolicyConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:backup:edit")),
):
    """更新备份策略配置 (DM-018)"""
    # In a real implementation, this would save to database or config
    # For now, just log the change

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="backup.policy_update",
        module="backup",
        description=f"更新备份策略: 保留天数={policy.retention_days}, 每用户最大备份数={policy.max_backups_per_user}",
        changes={
            "retention_days": policy.retention_days,
            "max_backups_per_user": policy.max_backups_per_user,
            "max_backup_size_mb": policy.max_backup_size_mb,
            "auto_cleanup_enabled": policy.auto_cleanup_enabled,
        },
        request=request,
    )

    await db.commit()

    return {
        "message": "备份策略已更新",
        "policy": policy,
    }
