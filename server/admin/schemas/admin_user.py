"""Admin user schemas."""
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, EmailStr


class AdminUserCreate(BaseModel):
    """创建管理员请求"""
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=6, max_length=100)
    display_name: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    role_id: UUID


class AdminUserUpdate(BaseModel):
    """更新管理员请求"""
    email: Optional[EmailStr] = None
    display_name: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    role_id: Optional[UUID] = None
    is_active: Optional[bool] = None


class AdminRoleInfo(BaseModel):
    """角色信息"""
    id: UUID
    name: str
    display_name: str

    class Config:
        from_attributes = True


class AdminUserResponse(BaseModel):
    """管理员响应"""
    id: UUID
    username: str
    email: str
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    phone: Optional[str] = None
    role: Optional[AdminRoleInfo] = None  # 允许 role 为空
    is_active: bool
    is_superadmin: bool
    mfa_enabled: bool
    last_login_at: Optional[datetime] = None
    last_login_ip: Optional[str] = None
    login_count: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AdminUserListResponse(BaseModel):
    """管理员列表响应"""
    items: List[AdminUserResponse]
    total: int
    page: int
    page_size: int


class AdminRoleResponse(BaseModel):
    """角色详情响应"""
    id: UUID
    name: str
    display_name: str
    description: Optional[str] = None
    is_system: bool
    is_active: bool
    permissions: List[str]
    user_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class AdminRoleListResponse(BaseModel):
    """角色列表响应"""
    items: List[AdminRoleResponse]
    total: int


class AdminPermissionResponse(BaseModel):
    """权限响应"""
    id: UUID
    code: str
    name: str
    module: str
    description: Optional[str] = None

    class Config:
        from_attributes = True


class AdminPermissionListResponse(BaseModel):
    """权限列表响应（按模块分组）"""
    modules: dict  # {module_name: [permissions]}
