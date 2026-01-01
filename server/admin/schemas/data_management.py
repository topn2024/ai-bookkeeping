"""Schemas for data management module."""
from datetime import datetime, date, time
from decimal import Decimal
from typing import Optional, List, Literal
from uuid import UUID

from pydantic import BaseModel, Field, computed_field


# ============ Transaction Schemas ============

class TransactionItem(BaseModel):
    """Transaction list item."""
    id: UUID
    user_id: UUID
    user_email: Optional[str] = None  # Masked
    book_id: UUID
    book_name: Optional[str] = None
    account_id: UUID
    account_name: Optional[str] = None
    category_id: UUID
    category_name: Optional[str] = None
    transaction_type: int  # 1: expense, 2: income, 3: transfer
    amount: Decimal
    fee: Decimal = Decimal("0")
    transaction_date: date
    transaction_time: Optional[time] = None  # Time part for display
    note: Optional[str] = None
    tags: Optional[List[str]] = None
    source: int = 0  # 0: manual, 1: image, 2: voice, 3: email
    is_reimbursable: bool = False
    is_reimbursed: bool = False
    created_at: datetime

    @computed_field
    @property
    def type(self) -> Literal["expense", "income", "transfer"]:
        """Computed type string from transaction_type."""
        type_map = {1: "expense", 2: "income", 3: "transfer"}
        return type_map.get(self.transaction_type, "expense")

    class Config:
        from_attributes = True


class TransactionSummary(BaseModel):
    """Transaction summary statistics."""
    total_count: int = 0
    total_income: Decimal = Decimal("0")
    total_expense: Decimal = Decimal("0")
    net_income: Decimal = Decimal("0")


class TransactionListResponse(BaseModel):
    """Transaction list response."""
    items: List[TransactionItem]
    total: int
    page: int
    page_size: int
    summary: Optional[TransactionSummary] = None


class TransactionDetail(TransactionItem):
    """Transaction detail with more info."""
    target_account_id: Optional[UUID] = None
    target_account_name: Optional[str] = None
    images: Optional[List[str]] = None
    location: Optional[str] = None
    is_exclude_stats: bool = False
    ai_confidence: Optional[Decimal] = None
    source_file_url: Optional[str] = None
    source_file_type: Optional[str] = None
    updated_at: datetime


class TransactionStatsResponse(BaseModel):
    """Transaction statistics response."""
    total_count: int
    total_expense: Decimal
    total_income: Decimal
    total_transfer: Decimal
    avg_expense: Decimal
    avg_income: Decimal
    by_date: List[dict]  # [{date, expense, income, count}]
    by_category: List[dict]  # [{category_id, category_name, amount, count}]
    by_source: dict  # {manual: count, image: count, voice: count, email: count}


class AbnormalTransactionItem(BaseModel):
    """Abnormal transaction item."""
    id: UUID
    user_id: UUID
    user_email: Optional[str] = None
    amount: Decimal
    transaction_type: int
    transaction_date: date
    abnormal_type: str  # "high_amount", "high_frequency", "unusual_time"
    abnormal_reason: str
    created_at: datetime


class AbnormalTransactionListResponse(BaseModel):
    """Abnormal transaction list response."""
    items: List[AbnormalTransactionItem]
    total: int


# ============ Book/Ledger Schemas ============

class BookItem(BaseModel):
    """Book list item."""
    id: UUID
    user_id: UUID
    user_email: Optional[str] = None  # Masked
    name: str
    icon: Optional[str] = None
    book_type: int  # 0: normal, 1: family, 2: business
    is_default: bool
    transaction_count: int = 0
    member_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


class BookListResponse(BaseModel):
    """Book list response."""
    items: List[BookItem]
    total: int
    page: int
    page_size: int


# ============ Account Schemas ============

class AccountItem(BaseModel):
    """Account list item."""
    id: UUID
    user_id: UUID
    user_email: Optional[str] = None  # Masked
    name: str
    account_type: int  # 1: cash, 2: debit, 3: credit, 4: alipay, 5: wechat
    icon: Optional[str] = None
    balance: Decimal
    credit_limit: Optional[Decimal] = None
    is_default: bool
    is_active: bool
    transaction_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


class AccountListResponse(BaseModel):
    """Account list response."""
    items: List[AccountItem]
    total: int
    page: int
    page_size: int


class AccountTypeStatsResponse(BaseModel):
    """Account type statistics."""
    by_type: List[dict]  # [{type: int, type_name: str, count: int, total_balance: Decimal}]
    total_accounts: int
    total_balance: Decimal


# ============ Category Schemas ============

class CategoryItem(BaseModel):
    """Category list item."""
    id: UUID
    user_id: Optional[UUID] = None
    parent_id: Optional[UUID] = None
    name: str
    icon: Optional[str] = None
    category_type: int  # 1: expense, 2: income
    sort_order: int
    is_system: bool
    usage_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


class CategoryStats(BaseModel):
    """Category statistics."""
    total_count: int = 0
    income_count: int = 0
    expense_count: int = 0
    custom_count: int = 0


class CategoryListResponse(BaseModel):
    """Category list response."""
    items: List[CategoryItem]
    total: int
    stats: Optional[CategoryStats] = None


class CategoryCreate(BaseModel):
    """Create system category."""
    name: str = Field(..., min_length=1, max_length=50)
    icon: Optional[str] = Field(None, max_length=50)
    category_type: int = Field(..., ge=1, le=2)  # 1: expense, 2: income
    parent_id: Optional[UUID] = None
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    """Update system category."""
    name: Optional[str] = Field(None, min_length=1, max_length=50)
    icon: Optional[str] = Field(None, max_length=50)
    sort_order: Optional[int] = None


class CategoryUsageStats(BaseModel):
    """Category usage statistics."""
    category_id: UUID
    category_name: str
    category_type: int
    is_system: bool
    transaction_count: int
    total_amount: Decimal
    user_count: int  # Number of users using this category


class CategoryUsageStatsResponse(BaseModel):
    """Category usage statistics response."""
    items: List[CategoryUsageStats]
    total_categories: int


# ============ Backup Schemas ============

class BackupItem(BaseModel):
    """Backup list item."""
    id: UUID
    user_id: UUID
    user_email: Optional[str] = None  # Masked
    name: str
    description: Optional[str] = None
    backup_type: int  # 0: manual, 1: auto
    transaction_count: int
    account_count: int
    category_count: int
    book_count: int
    budget_count: int
    size: int  # bytes
    device_name: Optional[str] = None
    app_version: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class BackupListResponse(BaseModel):
    """Backup list response."""
    items: List[BackupItem]
    total: int
    page: int
    page_size: int


class BackupStorageStats(BaseModel):
    """Backup storage statistics."""
    total_backups: int
    total_size: int  # bytes
    total_size_formatted: str  # e.g., "1.5 GB"
    by_type: dict  # {manual: {count, size}, auto: {count, size}}
    by_date: List[dict]  # [{date, count, size}]
    top_users: List[dict]  # [{user_id, user_email, backup_count, total_size}]


class BackupPolicyConfig(BaseModel):
    """Backup policy configuration."""
    retention_days: int = Field(90, ge=7, le=365)  # Days to keep backups
    max_backups_per_user: int = Field(10, ge=1, le=100)
    max_backup_size_mb: int = Field(50, ge=1, le=500)
    auto_cleanup_enabled: bool = True
