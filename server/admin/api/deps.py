"""Admin API dependencies."""
from typing import Optional
from uuid import UUID

from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.models.admin_role import AdminRole
from admin.core.security import decode_access_token


security = HTTPBearer()


async def _check_token_blacklist_async(token: str) -> bool:
    """异步检查token是否在黑名单中"""
    from admin.api.auth import is_token_blacklisted
    return await is_token_blacklisted(token)


async def get_current_admin(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db),
) -> AdminUser:
    """获取当前登录的管理员"""
    token = credentials.credentials

    # 检查Token是否在黑名单中（使用异步Redis检查）
    if await _check_token_blacklist_async(token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="令牌已失效，请重新登录",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 解码Token
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证令牌",
            headers={"WWW-Authenticate": "Bearer"},
        )

    admin_id = payload.get("sub")
    if not admin_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证令牌",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 查询管理员
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role).selectinload(AdminRole.permissions))
        .where(AdminUser.id == UUID(admin_id))
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被禁用",
        )

    if admin.is_locked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被锁定",
        )

    return admin


async def get_current_admin_optional(
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> Optional[AdminUser]:
    """可选的管理员认证（用于某些允许匿名访问的接口）"""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        return None

    token = auth_header[7:]  # Remove "Bearer " prefix

    payload = decode_access_token(token)
    if not payload:
        return None

    admin_id = payload.get("sub")
    if not admin_id:
        return None

    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role))
        .where(AdminUser.id == UUID(admin_id))
    )
    admin = result.scalar_one_or_none()

    if admin and admin.is_active and not admin.is_locked:
        return admin

    return None


def require_superadmin(
    current_admin: AdminUser = Depends(get_current_admin),
) -> AdminUser:
    """要求超级管理员权限"""
    if not current_admin.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="需要超级管理员权限",
        )
    return current_admin


def require_permission(permission_code: str):
    """
    创建一个权限检查依赖项

    Args:
        permission_code: 权限代码，如 "monitor:data_quality:view"

    Returns:
        依赖函数，返回当前管理员（如果有权限）
    """
    async def check_permission(
        current_admin: AdminUser = Depends(get_current_admin),
    ) -> AdminUser:
        # 超级管理员拥有所有权限
        if current_admin.is_superadmin:
            return current_admin

        # 检查角色权限
        if current_admin.role and current_admin.role.permissions:
            for perm in current_admin.role.permissions:
                # 支持通配符权限，如 "*" 或 "monitor:*"
                if perm.code == "*":
                    return current_admin
                if perm.code == permission_code:
                    return current_admin
                # 检查前缀匹配，如 "monitor:*" 匹配 "monitor:data_quality:view"
                if perm.code.endswith(":*"):
                    prefix = perm.code[:-1]  # 去掉 "*"
                    if permission_code.startswith(prefix):
                        return current_admin

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"需要权限: {permission_code}",
        )

    return check_permission
