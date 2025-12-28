"""Book schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class BookCreate(BaseModel):
    """Schema for creating a book."""
    name: str = Field(..., max_length=100)
    icon: Optional[str] = Field(None, max_length=50)
    cover_image: Optional[str] = None
    book_type: int = Field(default=0, ge=0, le=2)
    is_default: bool = False


class BookUpdate(BaseModel):
    """Schema for updating a book."""
    name: Optional[str] = Field(None, max_length=100)
    icon: Optional[str] = Field(None, max_length=50)
    cover_image: Optional[str] = None
    book_type: Optional[int] = Field(None, ge=0, le=2)
    is_default: Optional[bool] = None


class BookResponse(BaseModel):
    """Schema for book response."""
    id: UUID
    user_id: UUID
    name: str
    icon: Optional[str] = None
    cover_image: Optional[str] = None
    book_type: int
    is_default: bool
    created_at: datetime

    class Config:
        from_attributes = True
