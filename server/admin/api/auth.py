"""Admin authentication endpoints."""
from datetime import datetime, timedelta
from typing import List, Set
import time

import pyotp
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.models.admin_role import AdminRole
from admin.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    ACCESS_TOKEN_EXPIRE_MINUTES,
)
from admin.core.audit import create_audit_log
from admin.api.deps import get_current_admin
from admin.schemas.auth import (
    AdminLoginRequest,
    AdminLoginResponse,
    AdminInfo,
    AdminTokenRefreshRequest,
    AdminTokenRefreshResponse,
    PasswordChangeRequest,
)

# Token blacklist for logout invalidation
# In production, use Redis with TTL for better scalability
# Format: {token_jti: expire_timestamp}
_token_blacklist: dict[str, float] = {}
_BLACKLIST_CLEANUP_INTERVAL = 300  # Clean up every 5 minutes
_last_cleanup_time = time.time()


router = APIRouter(prefix="/auth", tags=["Admin Auth"])


# 登录失败锁定配置
MAX_FAILED_ATTEMPTS = 5
LOCKOUT_MINUTES = 15


@router.post("/login", response_model=AdminLoginResponse)
async def login(
    request: Request,
    login_data: AdminLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """管理员登录"""
    # 查询管理员
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role).selectinload(AdminRole.permissions))
        .where(AdminUser.username == login_data.username)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
        )

    # 检查账户是否被锁定
    if admin.is_locked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"账户已锁定，请{LOCKOUT_MINUTES}分钟后重试",
        )

    # 检查账户是否被禁用
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被禁用",
        )

    # 验证密码
    if not verify_password(login_data.password, admin.password_hash):
        # 记录失败次数
        admin.failed_login_count += 1

        # 超过最大失败次数，锁定账户
        if admin.failed_login_count >= MAX_FAILED_ATTEMPTS:
            admin.locked_until = datetime.utcnow() + timedelta(minutes=LOCKOUT_MINUTES)

        await db.commit()

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
        )

    # 检查MFA
    if admin.mfa_enabled:
        if not login_data.mfa_code:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="需要MFA验证码",
            )
        # 验证MFA码
        if not admin.mfa_secret:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="MFA配置错误，请联系管理员",
            )
        totp = pyotp.TOTP(admin.mfa_secret)
        if not totp.verify(login_data.mfa_code, valid_window=1):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="MFA验证码错误或已过期",
            )

    # 登录成功，重置失败计数
    admin.failed_login_count = 0
    admin.locked_until = None
    admin.last_login_at = datetime.utcnow()
    admin.last_login_ip = _get_client_ip(request)
    admin.login_count += 1

    # 获取权限列表
    permissions = _get_permission_codes(admin)

    # 生成Token
    access_token = create_access_token(
        data={"sub": str(admin.id), "username": admin.username}
    )
    refresh_token = create_refresh_token(admin.id)

    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=admin.id,
        admin_username=admin.username,
        action="auth.login",
        module="auth",
        description=f"管理员 {admin.username} 登录成功",
        request=request,
    )

    await db.commit()

    return AdminLoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        admin=AdminInfo(
            id=admin.id,
            username=admin.username,
            email=admin.email,
            display_name=admin.display_name,
            avatar_url=admin.avatar_url,
            role_name=admin.role.name if admin.role else "",
            role_display_name=admin.role.display_name if admin.role else "",
            permissions=permissions,
            is_superadmin=admin.is_superadmin,
            mfa_enabled=admin.mfa_enabled,
        ),
    )


@router.post("/refresh", response_model=AdminTokenRefreshResponse)
async def refresh_token(
    request_data: AdminTokenRefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    """刷新Token"""
    admin_id = decode_refresh_token(request_data.refresh_token)

    if not admin_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的刷新令牌",
        )

    # 验证管理员存在且有效
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin or not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在或已禁用",
        )

    # 生成新Token
    access_token = create_access_token(
        data={"sub": str(admin.id), "username": admin.username}
    )

    return AdminTokenRefreshResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/logout")
async def logout(
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """管理员登出"""
    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="auth.logout",
        module="auth",
        description=f"管理员 {current_admin.username} 登出",
        request=request,
    )

    await db.commit()

    # 将当前Token加入黑名单
    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        add_token_to_blacklist(token)

    return {"message": "登出成功"}


@router.post("/password/change")
async def change_password(
    request: Request,
    password_data: PasswordChangeRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """修改密码"""
    # 验证旧密码
    if not verify_password(password_data.old_password, current_admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="旧密码错误",
        )

    # 更新密码
    current_admin.password_hash = get_password_hash(password_data.new_password)

    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="auth.password_change",
        module="auth",
        description=f"管理员 {current_admin.username} 修改密码",
        request=request,
    )

    await db.commit()

    return {"message": "密码修改成功"}


@router.get("/me", response_model=AdminInfo)
async def get_current_admin_info(
    current_admin: AdminUser = Depends(get_current_admin),
):
    """获取当前管理员信息"""
    permissions = _get_permission_codes(current_admin)

    return AdminInfo(
        id=current_admin.id,
        username=current_admin.username,
        email=current_admin.email,
        display_name=current_admin.display_name,
        avatar_url=current_admin.avatar_url,
        role_name=current_admin.role.name if current_admin.role else "",
        role_display_name=current_admin.role.display_name if current_admin.role else "",
        permissions=permissions,
        is_superadmin=current_admin.is_superadmin,
        mfa_enabled=current_admin.mfa_enabled,
    )


def _get_permission_codes(admin: AdminUser) -> List[str]:
    """获取管理员的权限代码列表"""
    if admin.is_superadmin:
        return ["*"]

    if admin.role and admin.role.permissions:
        return [p.code for p in admin.role.permissions]

    return []


def _get_client_ip(request: Request) -> str:
    """获取客户端IP"""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()

    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip

    if request.client:
        return request.client.host

    return "unknown"


def _cleanup_blacklist():
    """清理已过期的黑名单token"""
    global _last_cleanup_time
    current_time = time.time()

    if current_time - _last_cleanup_time < _BLACKLIST_CLEANUP_INTERVAL:
        return

    _last_cleanup_time = current_time
    expired_tokens = [
        token for token, expire_time in _token_blacklist.items()
        if current_time > expire_time
    ]
    for token in expired_tokens:
        del _token_blacklist[token]


def add_token_to_blacklist(token: str):
    """将token加入黑名单"""
    _cleanup_blacklist()
    # Token有效期为ACCESS_TOKEN_EXPIRE_MINUTES分钟
    expire_time = time.time() + ACCESS_TOKEN_EXPIRE_MINUTES * 60
    _token_blacklist[token] = expire_time


def is_token_blacklisted(token: str) -> bool:
    """检查token是否在黑名单中"""
    _cleanup_blacklist()
    if token not in _token_blacklist:
        return False

    expire_time = _token_blacklist[token]
    if time.time() > expire_time:
        del _token_blacklist[token]
        return False

    return True
