"""Backup schemas."""
from datetime import datetime
from typing import Optional, Dict, Any, List
from uuid import UUID

from pydantic import BaseModel, Field


class BackupCreate(BaseModel):
    """Schema for creating a backup."""
    name: str = Field(..., max_length=100, description="备份名称")
    description: Optional[str] = Field(None, max_length=500, description="备份描述")
    backup_type: int = Field(default=0, ge=0, le=1, description="0=手动备份, 1=自动备份")
    device_name: Optional[str] = Field(None, max_length=100, description="设备名称")
    device_id: Optional[str] = Field(None, max_length=100, description="设备ID")
    app_version: Optional[str] = Field(None, max_length=20, description="应用版本")


class BackupData(BaseModel):
    """Schema for backup data content."""
    transactions: List[Dict[str, Any]] = Field(default_factory=list)
    accounts: List[Dict[str, Any]] = Field(default_factory=list)
    categories: List[Dict[str, Any]] = Field(default_factory=list)
    books: List[Dict[str, Any]] = Field(default_factory=list)
    budgets: List[Dict[str, Any]] = Field(default_factory=list)


class BackupResponse(BaseModel):
    """Schema for backup response."""
    id: UUID
    user_id: UUID
    name: str
    description: Optional[str] = None
    backup_type: int
    transaction_count: int
    account_count: int
    category_count: int
    book_count: int
    budget_count: int
    size: int
    device_name: Optional[str] = None
    device_id: Optional[str] = None
    app_version: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class BackupListResponse(BaseModel):
    """Schema for backup list response."""
    backups: List[BackupResponse]
    total: int


class BackupDetailResponse(BaseModel):
    """Schema for backup detail with data."""
    id: UUID
    user_id: UUID
    name: str
    description: Optional[str] = None
    backup_type: int
    data: BackupData
    transaction_count: int
    account_count: int
    category_count: int
    book_count: int
    budget_count: int
    size: int
    device_name: Optional[str] = None
    device_id: Optional[str] = None
    app_version: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class RestoreRequest(BaseModel):
    """Schema for restore request."""
    clear_existing: bool = Field(default=False, description="是否清除现有数据")


class RestoreResponse(BaseModel):
    """Schema for restore response."""
    success: bool
    message: str
    restored_counts: Dict[str, int] = Field(default_factory=dict)
