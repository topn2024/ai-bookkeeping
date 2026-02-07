"""Admin management endpoints (managing admin users)."""
import pyotp
import secrets
from datetime import datetime
from typing import Optional, List, Dict, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
from pydantic import BaseModel, EmailStr

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.models.admin_role import AdminRole, AdminPermission, PREDEFINED_PERMISSIONS, PREDEFINED_ROLES
from admin.api.deps import get_current_admin, require_superadmin
from admin.core.security import get_password_hash, verify_password
from admin.core.audit import create_audit_log
from admin.schemas.admin_user import (
    AdminUserCreate,
    AdminUserUpdate,
    AdminUserResponse,
    AdminUserListResponse,
    AdminRoleResponse,
    AdminRoleListResponse,
    AdminPermissionListResponse,
)


router = APIRouter(prefix="/admins", tags=["Admin Management"])


@router.get("", response_model=AdminUserListResponse)
async def list_admins(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """获取管理员列表（仅超级管理员可用）"""
    # 获取总数
    count_result = await db.execute(select(func.count(AdminUser.id)))
    total = count_result.scalar() or 0

    # 获取列表
    offset = (page - 1) * page_size
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role))
        .order_by(AdminUser.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    admins = result.scalars().all()

    return AdminUserListResponse(
        items=admins,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=AdminUserResponse)
async def create_admin(
    request: Request,
    admin_data: AdminUserCreate,
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """创建管理员（仅超级管理员可用）"""
    # 检查用户名是否已存在
    existing = await db.execute(
        select(AdminUser).where(AdminUser.username == admin_data.username)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户名已存在",
        )

    # 检查邮箱是否已存在
    existing_email = await db.execute(
        select(AdminUser).where(AdminUser.email == admin_data.email)
    )
    if existing_email.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="邮箱已存在",
        )

    # 验证角色存在
    role_result = await db.execute(
        select(AdminRole).where(AdminRole.id == admin_data.role_id)
    )
    role = role_result.scalar_one_or_none()
    if not role:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="角色不存在",
        )

    # 创建管理员
    new_admin = AdminUser(
        username=admin_data.username,
        email=admin_data.email,
        password_hash=get_password_hash(admin_data.password),
        display_name=admin_data.display_name,
        phone=admin_data.phone,
        role_id=admin_data.role_id,
        created_by=current_admin.id,
    )

    db.add(new_admin)

    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.create",
        module="admin",
        target_type="admin",
        target_id=str(new_admin.id),
        target_name=new_admin.username,
        description=f"创建管理员: {new_admin.username}",
        request=request,
    )

    await db.commit()
    await db.refresh(new_admin)

    # 加载角色关系
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role))
        .where(AdminUser.id == new_admin.id)
    )
    new_admin = result.scalar_one()

    return new_admin


# ============ Request/Response Models ============

class ProfileUpdateRequest(BaseModel):
    """个人信息更新请求"""
    display_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    avatar_url: Optional[str] = None


class PasswordChangeRequest(BaseModel):
    """密码修改请求"""
    current_password: str
    new_password: str


class MFASetupResponse(BaseModel):
    """MFA设置响应"""
    secret: str
    qr_code_url: str
    backup_codes: List[str]


class MFAVerifyRequest(BaseModel):
    """MFA验证请求"""
    code: str


class NotificationPreferences(BaseModel):
    """通知偏好设置"""
    email_enabled: bool = True
    email_on_login: bool = True
    email_on_security_alert: bool = True
    browser_notifications: bool = False
    digest_frequency: str = "daily"  # never, daily, weekly


# In-memory storage for notification preferences (should be in database in production)
_notification_preferences: Dict[str, NotificationPreferences] = {}


# ============ Profile Management (GF-008) ============
# NOTE: /me endpoints MUST be defined BEFORE /{admin_id} routes to avoid path conflicts

@router.get("/me")
async def get_my_profile(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """获取当前管理员个人信息"""
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role))
        .where(AdminUser.id == current_admin.id)
    )
    admin = result.scalar_one()

    return {
        "id": str(admin.id),
        "username": admin.username,
        "email": admin.email,
        "display_name": admin.display_name,
        "phone": admin.phone,
        "avatar_url": getattr(admin, 'avatar_url', None),
        "role": admin.role.display_name if admin.role else None,
        "is_superadmin": admin.is_superadmin,
        "mfa_enabled": getattr(admin, 'mfa_enabled', False),
        "last_login_at": admin.last_login_at.isoformat() if admin.last_login_at else None,
        "created_at": admin.created_at.isoformat() if admin.created_at else None,
    }


@router.put("/me")
async def update_my_profile(
    request: Request,
    profile_data: ProfileUpdateRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """更新个人信息 (GF-008)"""
    changes = {}

    if profile_data.display_name is not None:
        changes["display_name"] = {"before": current_admin.display_name, "after": profile_data.display_name}
        current_admin.display_name = profile_data.display_name

    if profile_data.email is not None and profile_data.email != current_admin.email:
        # Check if email already used
        existing = await db.execute(
            select(AdminUser).where(AdminUser.email == profile_data.email)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="邮箱已被使用",
            )
        changes["email"] = {"before": current_admin.email, "after": profile_data.email}
        current_admin.email = profile_data.email

    if profile_data.phone is not None:
        changes["phone"] = {"before": current_admin.phone, "after": profile_data.phone}
        current_admin.phone = profile_data.phone

    if profile_data.avatar_url is not None and hasattr(current_admin, 'avatar_url'):
        changes["avatar_url"] = {"before": getattr(current_admin, 'avatar_url', None), "after": profile_data.avatar_url}
        current_admin.avatar_url = profile_data.avatar_url

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.profile_update",
        module="admin",
        target_type="admin",
        target_id=str(current_admin.id),
        target_name=current_admin.username,
        description="更新个人信息",
        changes=changes,
        request=request,
    )

    await db.commit()
    await db.refresh(current_admin)

    return {"message": "个人信息已更新"}


@router.post("/me/change-password")
async def change_my_password(
    request: Request,
    password_data: PasswordChangeRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """修改密码"""
    # Verify current password
    if not verify_password(password_data.current_password, current_admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="当前密码错误",
        )

    # Validate new password
    from admin.core.security import validate_password_complexity
    complexity_errors = validate_password_complexity(password_data.new_password)
    if complexity_errors:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="密码不符合要求: " + "; ".join(complexity_errors),
        )

    # Update password
    current_admin.password_hash = get_password_hash(password_data.new_password)

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.password_change",
        module="admin",
        target_type="admin",
        target_id=str(current_admin.id),
        target_name=current_admin.username,
        description="修改密码",
        request=request,
    )

    await db.commit()

    return {"message": "密码已修改"}


class MFADisableRequest(BaseModel):
    """MFA禁用请求"""
    password: str


# ============ MFA Management (GF-002) ============

@router.post("/me/mfa/setup", response_model=MFASetupResponse)
async def setup_mfa(
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """设置MFA双因素认证 (GF-002)"""
    # Generate TOTP secret
    secret = pyotp.random_base32()

    # Generate QR code URL
    totp = pyotp.TOTP(secret)
    qr_code_url = totp.provisioning_uri(
        name=current_admin.email or current_admin.username,
        issuer_name="AI Bookkeeping Admin",
    )

    # Generate backup codes
    backup_codes = [secrets.token_hex(4).upper() for _ in range(8)]

    # Store temporarily (in production, store encrypted in session or temp storage)
    # We'll store in admin user model once verified
    if hasattr(current_admin, 'mfa_secret_temp'):
        current_admin.mfa_secret_temp = secret
        current_admin.mfa_backup_codes_temp = ",".join(backup_codes)
        await db.commit()

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.mfa_setup_start",
        module="admin",
        description="开始设置MFA双因素认证",
        request=request,
    )
    await db.commit()

    return MFASetupResponse(
        secret=secret,
        qr_code_url=qr_code_url,
        backup_codes=backup_codes,
    )


@router.post("/me/mfa/verify")
async def verify_mfa_setup(
    request: Request,
    verify_data: MFAVerifyRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """验证并启用MFA (GF-002)"""
    # Get temp secret
    secret = getattr(current_admin, 'mfa_secret_temp', None)
    if not secret:
        # If no temp secret, this is a fresh setup - need to call setup first
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="请先调用 /me/mfa/setup 获取设置信息",
        )

    # Verify code
    totp = pyotp.TOTP(secret)
    if not totp.verify(verify_data.code, valid_window=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码错误",
        )

    # Enable MFA
    if hasattr(current_admin, 'mfa_enabled'):
        current_admin.mfa_enabled = True
    if hasattr(current_admin, 'mfa_secret'):
        current_admin.mfa_secret = secret
    if hasattr(current_admin, 'mfa_backup_codes'):
        backup_codes = getattr(current_admin, 'mfa_backup_codes_temp', "")
        current_admin.mfa_backup_codes = backup_codes

    # Clear temp values
    if hasattr(current_admin, 'mfa_secret_temp'):
        current_admin.mfa_secret_temp = None
    if hasattr(current_admin, 'mfa_backup_codes_temp'):
        current_admin.mfa_backup_codes_temp = None

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.mfa_enabled",
        module="admin",
        description="启用MFA双因素认证",
        request=request,
    )
    await db.commit()

    return {"message": "MFA已启用", "mfa_enabled": True}


@router.delete("/me/mfa")
async def disable_mfa(
    request: Request,
    body: MFADisableRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """禁用MFA (GF-002)"""
    # Verify password (from request body, not query parameter)
    if not verify_password(body.password, current_admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="密码错误",
        )

    # Disable MFA
    if hasattr(current_admin, 'mfa_enabled'):
        current_admin.mfa_enabled = False
    if hasattr(current_admin, 'mfa_secret'):
        current_admin.mfa_secret = None
    if hasattr(current_admin, 'mfa_backup_codes'):
        current_admin.mfa_backup_codes = None

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.mfa_disabled",
        module="admin",
        description="禁用MFA双因素认证",
        request=request,
    )
    await db.commit()

    return {"message": "MFA已禁用", "mfa_enabled": False}


@router.get("/me/mfa/status")
async def get_mfa_status(
    current_admin: AdminUser = Depends(get_current_admin),
):
    """获取MFA状态"""
    mfa_enabled = getattr(current_admin, 'mfa_enabled', False)
    backup_codes_count = 0

    if mfa_enabled and hasattr(current_admin, 'mfa_backup_codes'):
        codes = getattr(current_admin, 'mfa_backup_codes', "") or ""
        backup_codes_count = len([c for c in codes.split(",") if c])

    return {
        "mfa_enabled": mfa_enabled,
        "backup_codes_remaining": backup_codes_count,
    }


# ============ Notification Preferences (GF-009) ============

@router.get("/me/notifications")
async def get_notification_preferences(
    current_admin: AdminUser = Depends(get_current_admin),
):
    """获取通知偏好设置 (GF-009)"""
    admin_id = str(current_admin.id)

    if admin_id in _notification_preferences:
        prefs = _notification_preferences[admin_id]
    else:
        # Default preferences
        prefs = NotificationPreferences()

    return {
        "email_enabled": prefs.email_enabled,
        "email_on_login": prefs.email_on_login,
        "email_on_security_alert": prefs.email_on_security_alert,
        "browser_notifications": prefs.browser_notifications,
        "digest_frequency": prefs.digest_frequency,
    }


@router.put("/me/notifications")
async def update_notification_preferences(
    request: Request,
    prefs: NotificationPreferences,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """更新通知偏好设置 (GF-009)"""
    admin_id = str(current_admin.id)

    old_prefs = _notification_preferences.get(admin_id, NotificationPreferences())

    # Store new preferences
    _notification_preferences[admin_id] = prefs

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.notification_prefs_update",
        module="admin",
        description="更新通知偏好设置",
        changes={
            "email_enabled": {"before": old_prefs.email_enabled, "after": prefs.email_enabled},
            "digest_frequency": {"before": old_prefs.digest_frequency, "after": prefs.digest_frequency},
        },
        request=request,
    )
    await db.commit()

    return {"message": "通知偏好已更新"}


# ============ Admin CRUD (must be after /me routes) ============

@router.get("/{admin_id}", response_model=AdminUserResponse)
async def get_admin(
    admin_id: UUID,
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """获取管理员详情"""
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role))
        .where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="管理员不存在",
        )

    return admin


@router.put("/{admin_id}", response_model=AdminUserResponse)
async def update_admin(
    request: Request,
    admin_id: UUID,
    admin_data: AdminUserUpdate,
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """更新管理员"""
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role))
        .where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="管理员不存在",
        )

    # 不能修改超级管理员
    if admin.is_superadmin and admin.id != current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="不能修改其他超级管理员",
        )

    changes = {}

    if admin_data.email is not None and admin_data.email != admin.email:
        # 检查邮箱是否已被使用
        existing = await db.execute(
            select(AdminUser).where(AdminUser.email == admin_data.email)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="邮箱已被使用",
            )
        changes["email"] = {"before": admin.email, "after": admin_data.email}
        admin.email = admin_data.email

    if admin_data.display_name is not None:
        changes["display_name"] = {"before": admin.display_name, "after": admin_data.display_name}
        admin.display_name = admin_data.display_name

    if admin_data.phone is not None:
        changes["phone"] = {"before": admin.phone, "after": admin_data.phone}
        admin.phone = admin_data.phone

    if admin_data.role_id is not None:
        # 验证角色
        role_result = await db.execute(
            select(AdminRole).where(AdminRole.id == admin_data.role_id)
        )
        role = role_result.scalar_one_or_none()
        if not role:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="角色不存在",
            )
        changes["role_id"] = {"before": str(admin.role_id), "after": str(admin_data.role_id)}
        admin.role_id = admin_data.role_id

    if admin_data.is_active is not None:
        changes["is_active"] = {"before": admin.is_active, "after": admin_data.is_active}
        admin.is_active = admin_data.is_active

    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.edit",
        module="admin",
        target_type="admin",
        target_id=str(admin_id),
        target_name=admin.username,
        description=f"编辑管理员: {admin.username}",
        changes=changes,
        request=request,
    )

    await db.commit()
    await db.refresh(admin)

    return admin


@router.delete("/{admin_id}")
async def delete_admin(
    request: Request,
    admin_id: UUID,
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """删除管理员"""
    if admin_id == current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="不能删除自己",
        )

    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="管理员不存在",
        )

    if admin.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="不能删除超级管理员",
        )

    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.delete",
        module="admin",
        target_type="admin",
        target_id=str(admin_id),
        target_name=admin.username,
        description=f"删除管理员: {admin.username}",
        request=request,
    )

    await db.delete(admin)
    await db.commit()

    return {"message": "管理员已删除"}


# 角色管理

@router.get("/roles/list", response_model=AdminRoleListResponse)
async def list_roles(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """获取角色列表"""
    result = await db.execute(
        select(AdminRole)
        .options(selectinload(AdminRole.permissions))
        .order_by(AdminRole.sort_order)
    )
    roles = result.scalars().all()

    items = []
    for role in roles:
        # 获取使用该角色的用户数
        user_count_result = await db.execute(
            select(func.count(AdminUser.id))
            .where(AdminUser.role_id == role.id)
        )
        user_count = user_count_result.scalar() or 0

        items.append(AdminRoleResponse(
            id=role.id,
            name=role.name,
            display_name=role.display_name,
            description=role.description,
            is_system=role.is_system,
            is_active=role.is_active,
            permissions=[p.code for p in role.permissions],
            user_count=user_count,
            created_at=role.created_at,
        ))

    return AdminRoleListResponse(
        items=items,
        total=len(items),
    )


@router.get("/permissions/list", response_model=AdminPermissionListResponse)
async def list_permissions(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """获取权限列表（按模块分组）"""
    result = await db.execute(
        select(AdminPermission).order_by(AdminPermission.module, AdminPermission.code)
    )
    permissions = result.scalars().all()

    # 按模块分组
    modules = {}
    for perm in permissions:
        if perm.module not in modules:
            modules[perm.module] = []
        modules[perm.module].append({
            "id": str(perm.id),
            "code": perm.code,
            "name": perm.name,
            "description": perm.description,
        })

    return AdminPermissionListResponse(modules=modules)


@router.post("/{admin_id}/reset-password")
async def reset_admin_password(
    request: Request,
    admin_id: UUID,
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """重置管理员密码"""
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="管理员不存在",
        )

    if admin.is_superadmin and admin.id != current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="不能重置其他超级管理员的密码",
        )

    # Generate temporary password
    import secrets
    temp_password = secrets.token_urlsafe(12)
    admin.password_hash = get_password_hash(temp_password)

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.reset_password",
        module="admin",
        target_type="admin",
        target_id=str(admin_id),
        target_name=admin.username,
        description=f"重置管理员密码: {admin.username}",
        request=request,
    )
    await db.commit()

    return {"message": "密码已重置", "temp_password": temp_password}


@router.put("/{admin_id}/status")
async def toggle_admin_status(
    request: Request,
    admin_id: UUID,
    status_data: dict,
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """切换管理员状态"""
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="管理员不存在",
        )

    if admin.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="不能禁用超级管理员",
        )

    is_active = status_data.get("is_active", True)
    old_status = admin.is_active
    admin.is_active = is_active

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.toggle_status",
        module="admin",
        target_type="admin",
        target_id=str(admin_id),
        target_name=admin.username,
        description=f"{'启用' if is_active else '禁用'}管理员: {admin.username}",
        changes={"is_active": {"before": old_status, "after": is_active}},
        request=request,
    )
    await db.commit()

    return {"message": f"管理员已{'启用' if is_active else '禁用'}", "is_active": is_active}


@router.get("/me/login-history")
async def get_login_history(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """获取登录历史"""
    from admin.models.admin_log import AdminLog

    offset = (page - 1) * page_size

    # Query login logs
    result = await db.execute(
        select(AdminLog)
        .where(
            AdminLog.admin_id == current_admin.id,
            AdminLog.action.like("auth.login%"),
        )
        .order_by(AdminLog.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    logs = result.scalars().all()

    count_result = await db.execute(
        select(func.count(AdminLog.id)).where(
            AdminLog.admin_id == current_admin.id,
            AdminLog.action.like("auth.login%"),
        )
    )
    total = count_result.scalar() or 0

    return {
        "items": [
            {
                "id": str(log.id),
                "login_time": log.created_at.isoformat() if log.created_at else None,
                "ip_address": log.ip_address,
                "user_agent": log.user_agent,
                "status": "success" if log.status == 1 else "failed",
            }
            for log in logs
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.post("/me/avatar")
async def upload_avatar(
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """上传头像"""
    # In production, this would save to MinIO/S3
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.upload_avatar",
        module="admin",
        description="上传头像",
        request=request,
    )
    await db.commit()

    return {"avatar_url": "/static/avatar.png", "message": "Avatar upload not yet implemented"}


@router.post("/init-data")
async def init_admin_data(
    request: Request,
    current_admin: AdminUser = Depends(require_superadmin),
    db: AsyncSession = Depends(get_db),
):
    """初始化权限和角色数据（仅超级管理员可用）"""
    # 初始化权限
    for perm_data in PREDEFINED_PERMISSIONS:
        existing = await db.execute(
            select(AdminPermission).where(AdminPermission.code == perm_data["code"])
        )
        if not existing.scalar_one_or_none():
            perm = AdminPermission(**perm_data)
            db.add(perm)

    await db.flush()

    # 初始化角色
    for role_name, role_data in PREDEFINED_ROLES.items():
        existing = await db.execute(
            select(AdminRole).where(AdminRole.name == role_name)
        )
        if not existing.scalar_one_or_none():
            role = AdminRole(
                name=role_name,
                display_name=role_data["display_name"],
                description=role_data["description"],
                is_system=role_data["is_system"],
            )
            db.add(role)
            await db.flush()

            # 分配权限
            if role_data["permissions"] != ["*"]:
                for perm_code in role_data["permissions"]:
                    perm_result = await db.execute(
                        select(AdminPermission).where(AdminPermission.code == perm_code)
                    )
                    perm = perm_result.scalar_one_or_none()
                    if perm:
                        role.permissions.append(perm)

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="admin.init_data",
        module="admin",
        description="初始化权限和角色数据",
        request=request,
    )

    await db.commit()

    return {"message": "初始化完成"}
