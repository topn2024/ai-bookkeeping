"""Common utility functions."""
from typing import TypeVar, Type, Optional, Any
from uuid import UUID

from fastapi import HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import Base


T = TypeVar("T", bound=Base)


def update_model_fields(model: T, update_data: BaseModel, exclude_unset: bool = True) -> T:
    """
    Update model fields from Pydantic schema.

    Args:
        model: SQLAlchemy model instance to update
        update_data: Pydantic schema with update data
        exclude_unset: If True, only update fields that were explicitly set

    Returns:
        Updated model instance
    """
    data = update_data.model_dump(exclude_unset=exclude_unset)
    for field, value in data.items():
        setattr(model, field, value)
    return model


async def get_user_resource(
    db: AsyncSession,
    model: Type[T],
    resource_id: UUID,
    user_id: UUID,
    user_field: str = "user_id",
    not_found_msg: str = "Resource not found",
) -> T:
    """
    Get a resource that belongs to a user.

    Args:
        db: Database session
        model: SQLAlchemy model class
        resource_id: ID of the resource
        user_id: ID of the current user
        user_field: Name of the user_id field on the model
        not_found_msg: Error message if not found

    Returns:
        The resource if found and belongs to user

    Raises:
        HTTPException: 404 if not found or doesn't belong to user
    """
    query = select(model).where(
        model.id == resource_id,
        getattr(model, user_field) == user_id,
    )
    result = await db.execute(query)
    resource = result.scalar_one_or_none()

    if not resource:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=not_found_msg,
        )

    return resource


async def set_default_item(
    db: AsyncSession,
    model: Type[T],
    user_id: UUID,
    new_default_id: UUID,
    default_field: str = "is_default",
    user_field: str = "user_id",
) -> None:
    """
    Set a new default item, unsetting all others.

    Args:
        db: Database session
        model: SQLAlchemy model class
        user_id: ID of the current user
        new_default_id: ID of the item to set as default
        default_field: Name of the boolean default field
        user_field: Name of the user_id field
    """
    # Unset all defaults for this user
    query = select(model).where(
        getattr(model, user_field) == user_id,
        getattr(model, default_field) == True,
    )
    result = await db.execute(query)
    current_defaults = result.scalars().all()

    for item in current_defaults:
        if item.id != new_default_id:
            setattr(item, default_field, False)
