"""Category schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class CategoryCreate(BaseModel):
    """Schema for creating a category."""
    parent_id: Optional[UUID] = None
    name: str = Field(..., max_length=50)
    icon: Optional[str] = Field(None, max_length=50)
    category_type: int = Field(..., ge=1, le=2)  # 1: expense, 2: income
    sort_order: int = Field(default=0)


class CategoryUpdate(BaseModel):
    """Schema for updating a category."""
    name: Optional[str] = Field(None, max_length=50)
    icon: Optional[str] = Field(None, max_length=50)
    sort_order: Optional[int] = None


class CategoryResponse(BaseModel):
    """Schema for category response."""
    id: UUID
    user_id: Optional[UUID] = None
    parent_id: Optional[UUID] = None
    name: str
    icon: Optional[str] = None
    category_type: int
    sort_order: int
    is_system: bool
    created_at: datetime

    class Config:
        from_attributes = True
