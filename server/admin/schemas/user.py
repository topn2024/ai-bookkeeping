"""User management schemas (for managing app users)."""
from datetime import datetime
from typing import List, Optional
from uuid import UUID
from decimal import Decimal

from pydantic import BaseModel, Field


class AppUserListItem(BaseModel):
    """APP用户列表项"""
    id: UUID
    email_masked: Optional[str] = None  # 脱敏后的邮箱（可能为空，如手机号登录用户）
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    is_active: bool
    is_premium: bool = False  # 是否会员
    transaction_count: int
    total_amount: str  # 总交易金额
    book_count: int
    account_count: int
    last_login_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class AppUserListResponse(BaseModel):
    """APP用户列表响应"""
    items: List[AppUserListItem]
    total: int
    page: int
    page_size: int


class AppUserDetail(BaseModel):
    """APP用户详情"""
    id: UUID
    email_masked: Optional[str] = None
    display_name: Optional[str] = None
    avatar_url: Optional[str] = None
    is_active: bool
    is_premium: bool = False
    premium_until: Optional[datetime] = None

    # 统计数据
    book_count: int
    account_count: int
    category_count: int
    transaction_count: int
    budget_count: int
    total_income: str
    total_expense: str
    total_balance: str

    # 时间信息
    created_at: datetime
    last_login_at: Optional[datetime] = None
    last_transaction_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AppUserBook(BaseModel):
    """用户账本"""
    id: UUID
    name: str
    book_type: int
    is_default: bool
    transaction_count: int
    created_at: datetime


class AppUserAccount(BaseModel):
    """用户账户"""
    id: UUID
    name: str
    account_type: int
    balance_masked: str  # 脱敏后的余额
    currency: str
    is_default: bool
    is_active: bool


class AppUserTransaction(BaseModel):
    """用户交易记录"""
    id: UUID
    transaction_type: int
    type_name: str
    amount_masked: str  # 脱敏后的金额
    category_name: str
    account_name: str
    note_masked: Optional[str] = None  # 脱敏后的备注
    transaction_date: str
    created_at: datetime


class AppUserTransactionsResponse(BaseModel):
    """用户交易列表响应"""
    items: List[AppUserTransaction]
    total: int
    page: int
    page_size: int


class AppUserLoginHistory(BaseModel):
    """用户登录历史"""
    login_at: datetime
    ip_address: str
    device: Optional[str] = None
    location: Optional[str] = None


class AppUserLoginHistoryResponse(BaseModel):
    """登录历史响应"""
    items: List[AppUserLoginHistory]
    total: int


class UserStatusUpdateRequest(BaseModel):
    """更新用户状态请求"""
    is_active: bool
    reason: Optional[str] = Field(None, max_length=500)


class UserBatchOperationRequest(BaseModel):
    """批量操作请求"""
    user_ids: List[UUID]
    operation: str  # disable, enable
    reason: Optional[str] = Field(None, max_length=500)


class UserBatchOperationResponse(BaseModel):
    """批量操作响应"""
    success_count: int
    failed_count: int
    failed_ids: List[UUID]


class UserExportRequest(BaseModel):
    """用户导出请求"""
    user_ids: Optional[List[UUID]] = None  # 为空则导出全部
    fields: List[str] = ["id", "email", "display_name", "created_at", "transaction_count"]
    format: str = "xlsx"  # xlsx, csv


class UserExportResponse(BaseModel):
    """用户导出响应"""
    task_id: str
    status: str  # pending, processing, completed, failed
    download_url: Optional[str] = None
    expires_at: Optional[datetime] = None
