"""Book schemas."""
from datetime import datetime
from typing import Optional, Dict, Any
from uuid import UUID

from pydantic import BaseModel, Field


class BookCreate(BaseModel):
    """Schema for creating a book.

    Book types:
        0: personal - 个人账本
        1: family - 家庭账本
        2: business - 商业账本
        3: couple - 情侣账本
        4: group - 群组账本/AA制
        5: project - 专项账本
    """
    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    icon: Optional[str] = Field(None, max_length=50)
    cover_image: Optional[str] = None
    book_type: int = Field(default=0, ge=0, le=5)
    currency: str = Field(default="CNY", max_length=10)
    is_default: bool = False
    settings: Optional[Dict[str, Any]] = None


class BookUpdate(BaseModel):
    """Schema for updating a book."""
    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    icon: Optional[str] = Field(None, max_length=50)
    cover_image: Optional[str] = None
    book_type: Optional[int] = Field(None, ge=0, le=5)
    currency: Optional[str] = Field(None, max_length=10)
    is_default: Optional[bool] = None
    is_archived: Optional[bool] = None  # Archive status for soft delete
    settings: Optional[Dict[str, Any]] = None


class BookResponse(BaseModel):
    """Schema for book response."""
    id: UUID
    user_id: UUID
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    cover_image: Optional[str] = None
    book_type: int
    currency: str = "CNY"
    is_default: bool
    is_archived: bool = False  # Archive status for soft delete
    settings: Optional[Dict[str, Any]] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
