"""User schemas."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    """Schema for user registration."""
    phone: Optional[str] = Field(None, pattern=r"^1[3-9]\d{9}$")
    email: Optional[EmailStr] = None
    password: str = Field(..., min_length=6, max_length=50)
    nickname: Optional[str] = Field(None, max_length=50)


class UserLogin(BaseModel):
    """Schema for user login."""
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    password: str


class UserUpdate(BaseModel):
    """Schema for updating user profile."""
    nickname: Optional[str] = Field(None, max_length=50)
    avatar_url: Optional[str] = None


class UserResponse(BaseModel):
    """Schema for user response."""
    id: UUID
    phone: Optional[str] = None
    email: Optional[str] = None
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    member_level: int
    member_expire_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    """Schema for JWT token response."""
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    user: UserResponse


class RefreshTokenRequest(BaseModel):
    """Schema for token refresh request."""
    refresh_token: str
