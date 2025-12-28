"""Book member schemas."""
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class BookMemberCreate(BaseModel):
    """Schema for adding a book member."""
    user_id: UUID
    role: int = Field(default=0, ge=0, le=1)  # 0: member, 1: admin


class BookMemberUpdate(BaseModel):
    """Schema for updating a book member."""
    role: int = Field(..., ge=0, le=1)  # 0: member, 1: admin


class BookMemberResponse(BaseModel):
    """Schema for book member response."""
    id: UUID
    book_id: UUID
    user_id: UUID
    role: int  # 0: member, 1: admin, 2: owner
    nickname: Optional[str] = None
    joined_at: datetime

    class Config:
        from_attributes = True


class BookMemberList(BaseModel):
    """Schema for book member list."""
    items: List[BookMemberResponse]
    total: int
