"""Permission checking utilities."""
from functools import wraps
from typing import List, Set, Callable, Optional
from uuid import UUID

from fastapi import HTTPException, status, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.models.admin_role import AdminRole, AdminPermission


async def get_admin_permissions(
    admin_id: UUID,
    db: AsyncSession
) -> Set[str]:
    """获取管理员的所有权限代码"""
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role).selectinload(AdminRole.permissions))
        .where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        return set()

    # 超级管理员拥有所有权限
    if admin.is_superadmin:
        return {"*"}

    # 获取角色的所有权限
    permissions = set()
    if admin.role:
        for perm in admin.role.permissions:
            permissions.add(perm.code)

    return permissions


def check_permission(
    user_permissions: Set[str],
    required_permission: str
) -> bool:
    """检查是否拥有指定权限"""
    # 超级管理员通配符
    if "*" in user_permissions:
        return True

    # 精确匹配
    if required_permission in user_permissions:
        return True

    # 模块级通配符 (如 user:* 匹配 user:list)
    module = required_permission.split(":")[0]
    if f"{module}:*" in user_permissions:
        return True

    return False


def require_permission(permission: str):
    """权限检查装饰器 - 用于路由"""
    def decorator(func: Callable):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # 从kwargs中获取current_admin
            current_admin = kwargs.get("current_admin")
            db = kwargs.get("db")

            if not current_admin or not db:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="未认证",
                )

            # 获取权限
            permissions = await get_admin_permissions(current_admin.id, db)

            # 检查权限
            if not check_permission(permissions, permission):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"权限不足: {permission}",
                )

            return await func(*args, **kwargs)

        return wrapper
    return decorator


class PermissionChecker:
    """权限检查器 - 用作依赖注入"""

    def __init__(self, required_permission: str):
        self.required_permission = required_permission

    async def __call__(
        self,
        request: Request,
        db: AsyncSession = Depends(get_db),
    ) -> bool:
        # 从request.state获取当前管理员
        current_admin = getattr(request.state, "admin", None)

        if not current_admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="未认证",
            )

        # 获取权限
        permissions = await get_admin_permissions(current_admin.id, db)

        # 检查权限
        if not check_permission(permissions, self.required_permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"权限不足: {self.required_permission}",
            )

        return True


def has_permission(permission: str) -> PermissionChecker:
    """创建权限检查依赖"""
    return PermissionChecker(permission)
