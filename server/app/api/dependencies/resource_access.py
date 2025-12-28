"""统一的资源访问验证依赖.

消除所有API端点中重复的资源所有权检查代码。

使用方式:
```python
@router.get("/{account_id}")
async def get_account(
    account: Account = Depends(get_user_account),
):
    return account
```
"""

from typing import TypeVar, Type, Generic, Optional, Callable
from uuid import UUID

from fastapi import Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import DeclarativeBase

from app.core.database import get_db
from app.models.user import User
from app.api.deps import get_current_user


ModelT = TypeVar("ModelT", bound=DeclarativeBase)


class ResourceAccessChecker(Generic[ModelT]):
    """通用资源访问检查器.

    用于验证用户对特定资源的访问权限。

    Args:
        model_class: SQLAlchemy模型类
        user_field: 用户ID字段名，默认为 "user_id"
        id_param_name: 路径参数名，默认为 "{model_name}_id"
        not_found_message: 资源未找到时的错误消息
    """

    def __init__(
        self,
        model_class: Type[ModelT],
        user_field: str = "user_id",
        id_param_name: Optional[str] = None,
        not_found_message: Optional[str] = None,
    ):
        self.model_class = model_class
        self.user_field = user_field
        self.id_param_name = id_param_name or f"{model_class.__name__.lower()}_id"
        self.not_found_message = not_found_message or f"{model_class.__name__} not found"

    async def __call__(
        self,
        resource_id: UUID,
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ) -> ModelT:
        """验证并返回用户拥有的资源."""
        query = select(self.model_class).where(
            and_(
                self.model_class.id == resource_id,
                getattr(self.model_class, self.user_field) == current_user.id,
            )
        )

        result = await db.execute(query)
        resource = result.scalar_one_or_none()

        if not resource:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=self.not_found_message,
            )

        return resource


async def get_user_resource(
    model_class: Type[ModelT],
    resource_id: UUID,
    user_id: UUID,
    db: AsyncSession,
    user_field: str = "user_id",
    not_found_message: Optional[str] = None,
) -> ModelT:
    """通用资源获取函数.

    验证资源存在且属于指定用户。

    Args:
        model_class: SQLAlchemy模型类
        resource_id: 资源ID
        user_id: 用户ID
        db: 数据库会话
        user_field: 用户ID字段名
        not_found_message: 资源未找到时的错误消息

    Returns:
        资源对象

    Raises:
        HTTPException: 资源不存在或不属于用户
    """
    query = select(model_class).where(
        and_(
            model_class.id == resource_id,
            getattr(model_class, user_field) == user_id,
        )
    )

    result = await db.execute(query)
    resource = result.scalar_one_or_none()

    if not resource:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=not_found_message or f"{model_class.__name__} not found",
        )

    return resource


# ==================== 预定义的资源验证器 ====================


def get_user_book(book_id: UUID):
    """验证账本归属."""
    from app.models.book import Book

    return ResourceAccessChecker(Book, not_found_message="Book not found")(book_id)


def get_user_account(account_id: UUID):
    """验证账户归属."""
    from app.models.account import Account

    return ResourceAccessChecker(Account, not_found_message="Account not found")(account_id)


def get_user_budget(budget_id: UUID):
    """验证预算归属."""
    from app.models.budget import Budget

    return ResourceAccessChecker(Budget, not_found_message="Budget not found")(budget_id)


def get_user_category(category_id: UUID):
    """验证分类归属."""
    from app.models.category import Category

    return ResourceAccessChecker(Category, not_found_message="Category not found")(category_id)


async def verify_book_member_access(
    book_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    require_admin: bool = False,
) -> None:
    """验证用户对账本的访问权限.

    检查用户是账本所有者或成员。

    Args:
        book_id: 账本ID
        current_user: 当前用户
        db: 数据库会话
        require_admin: 是否需要管理员权限

    Raises:
        HTTPException: 无访问权限
    """
    from app.models.book import Book
    from app.models.book_member import BookMember

    # 检查是否是账本所有者
    result = await db.execute(
        select(Book).where(
            and_(Book.id == book_id, Book.user_id == current_user.id)
        )
    )
    if result.scalar_one_or_none():
        return  # 所有者有完全权限

    # 检查是否是成员
    result = await db.execute(
        select(BookMember).where(
            and_(
                BookMember.book_id == book_id,
                BookMember.user_id == current_user.id,
            )
        )
    )
    member = result.scalar_one_or_none()

    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Book not found or access denied",
        )

    if require_admin and member.role < 1:  # 0 = viewer, 1 = admin
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin permission required",
        )


# ==================== 工厂函数 ====================


def create_resource_checker(
    model_class: Type[ModelT],
    user_field: str = "user_id",
    not_found_message: Optional[str] = None,
) -> Callable:
    """创建资源检查器的工厂函数.

    Args:
        model_class: SQLAlchemy模型类
        user_field: 用户ID字段名
        not_found_message: 资源未找到时的错误消息

    Returns:
        资源检查器依赖
    """
    checker = ResourceAccessChecker(
        model_class,
        user_field=user_field,
        not_found_message=not_found_message,
    )

    async def dependency(
        resource_id: UUID,
        current_user: User = Depends(get_current_user),
        db: AsyncSession = Depends(get_db),
    ) -> ModelT:
        return await checker(resource_id, current_user, db)

    return dependency
