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


class CheckEmailRequest(BaseModel):
    """Schema for checking if email exists."""
    email: EmailStr


class CheckEmailResponse(BaseModel):
    """Schema for check email response."""
    exists: bool
    message: str


class ResetPasswordRequest(BaseModel):
    """Schema for password reset request."""
    email: EmailStr


class ResetPasswordConfirm(BaseModel):
    """Schema for confirming password reset with code."""
    email: EmailStr
    code: str = Field(..., min_length=6, max_length=6)
    new_password: str = Field(..., min_length=6, max_length=50)


class ResetPasswordResponse(BaseModel):
    """Schema for reset password response."""
    success: bool
    message: str


class SendSmsCodeRequest(BaseModel):
    """Schema for sending SMS verification code."""
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="手机号（11位）")
    scene: str = Field(
        default="login",
        pattern=r"^(login|register|reset_password)$",
        description="使用场景：login（登录）| register（注册）| reset_password（重置密码）"
    )


class SendSmsCodeResponse(BaseModel):
    """Schema for send SMS code response."""
    success: bool
    message: str
    expires_in: int = Field(default=600, description="验证码有效期（秒）")


class SmsLoginRequest(BaseModel):
    """Schema for SMS verification code login."""
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$", description="手机号（11位）")
    code: str = Field(..., min_length=6, max_length=6, description="6位数字验证码")
    auto_register: bool = Field(
        default=True,
        description="如果用户不存在，是否自动注册"
    )
