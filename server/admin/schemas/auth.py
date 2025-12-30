"""Authentication schemas."""
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, EmailStr


class AdminLoginRequest(BaseModel):
    """管理员登录请求"""
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6, max_length=100)
    mfa_code: Optional[str] = Field(None, min_length=6, max_length=6)


class AdminLoginResponse(BaseModel):
    """管理员登录响应"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # 秒
    admin: "AdminInfo"


class AdminInfo(BaseModel):
    """管理员基本信息"""
    id: UUID
    username: str
    email: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    role_name: str
    role_display_name: str
    permissions: List[str]
    is_superadmin: bool
    mfa_enabled: bool

    class Config:
        from_attributes = True


class AdminTokenRefreshRequest(BaseModel):
    """Token刷新请求"""
    refresh_token: str


class AdminTokenRefreshResponse(BaseModel):
    """Token刷新响应"""
    access_token: str
    token_type: str = "bearer"
    expires_in: int


class PasswordChangeRequest(BaseModel):
    """修改密码请求"""
    old_password: str = Field(..., min_length=6, max_length=100)
    new_password: str = Field(..., min_length=6, max_length=100)


class MFASetupResponse(BaseModel):
    """MFA设置响应"""
    secret: str
    qr_code_url: str


class MFAVerifyRequest(BaseModel):
    """MFA验证请求"""
    code: str = Field(..., min_length=6, max_length=6)


# Update forward references
AdminLoginResponse.model_rebuild()
