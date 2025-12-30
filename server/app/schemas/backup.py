"""Backup schemas."""
from datetime import datetime
from typing import Optional, Dict, Any, List
from uuid import UUID

from pydantic import BaseModel, Field


class BackupData(BaseModel):
    """Schema for backup data content.

    支持所有前端模块的完整备份：
    - 基础数据：交易、账户、分类、账本、预算
    - 扩展数据：信用卡、债务、储蓄目标、账单提醒、周期交易
    - 关联数据：债务还款记录、储蓄存款记录、预算结转记录
    """
    # 基础数据（原有）
    transactions: List[Dict[str, Any]] = Field(default_factory=list)
    accounts: List[Dict[str, Any]] = Field(default_factory=list)
    categories: List[Dict[str, Any]] = Field(default_factory=list)
    books: List[Dict[str, Any]] = Field(default_factory=list)
    budgets: List[Dict[str, Any]] = Field(default_factory=list)

    # 扩展数据（新增）
    credit_cards: List[Dict[str, Any]] = Field(default_factory=list)
    debts: List[Dict[str, Any]] = Field(default_factory=list)
    debt_payments: List[Dict[str, Any]] = Field(default_factory=list)
    savings_goals: List[Dict[str, Any]] = Field(default_factory=list)
    savings_deposits: List[Dict[str, Any]] = Field(default_factory=list)
    bill_reminders: List[Dict[str, Any]] = Field(default_factory=list)
    recurring_transactions: List[Dict[str, Any]] = Field(default_factory=list)
    budget_carryovers: List[Dict[str, Any]] = Field(default_factory=list)
    zero_based_allocations: List[Dict[str, Any]] = Field(default_factory=list)


class BackupCreate(BaseModel):
    """Schema for creating a backup.

    支持两种模式：
    1. 服务器模式（data为空）：从服务器数据库获取数据
    2. 客户端模式（data有值）：直接保存客户端上传的数据
    """
    name: str = Field(..., max_length=100, description="备份名称")
    description: Optional[str] = Field(None, max_length=500, description="备份描述")
    backup_type: int = Field(default=0, ge=0, le=1, description="0=手动备份, 1=自动备份")
    device_name: Optional[str] = Field(None, max_length=100, description="设备名称")
    device_id: Optional[str] = Field(None, max_length=100, description="设备ID")
    app_version: Optional[str] = Field(None, max_length=20, description="应用版本")
    # 新增：客户端上传的备份数据
    data: Optional[BackupData] = Field(None, description="客户端上传的备份数据")


class BackupResponse(BaseModel):
    """Schema for backup response."""
    id: UUID
    user_id: UUID
    name: str
    description: Optional[str] = None
    backup_type: int
    # 基础数据统计
    transaction_count: int
    account_count: int
    category_count: int
    book_count: int
    budget_count: int
    # 扩展数据统计（新增）
    credit_card_count: int = 0
    debt_count: int = 0
    savings_goal_count: int = 0
    bill_reminder_count: int = 0
    recurring_count: int = 0
    # 文件大小
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
    # 基础数据统计
    transaction_count: int
    account_count: int
    category_count: int
    book_count: int
    budget_count: int
    # 扩展数据统计（新增）
    credit_card_count: int = 0
    debt_count: int = 0
    savings_goal_count: int = 0
    bill_reminder_count: int = 0
    recurring_count: int = 0
    # 文件大小
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
