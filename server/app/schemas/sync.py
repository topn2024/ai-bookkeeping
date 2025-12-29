"""Sync schemas for data synchronization between client and server."""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List, Dict, Any
from uuid import UUID

from pydantic import BaseModel, Field


class EntityChange(BaseModel):
    """Represents a single entity change from client."""
    entity_type: str = Field(..., description="Entity type: transaction, account, category, book, budget")
    operation: str = Field(..., description="Operation: create, update, delete")
    local_id: str = Field(..., description="Client-side local ID")
    server_id: Optional[UUID] = Field(None, description="Server-side ID if known")
    data: Dict[str, Any] = Field(default_factory=dict, description="Entity data for create/update")
    local_updated_at: datetime = Field(..., description="Client-side last update time")


class SyncPushRequest(BaseModel):
    """Request schema for pushing local changes to server."""
    changes: List[EntityChange] = Field(..., description="List of entity changes")
    client_version: str = Field(default="1.0.0", description="Client app version")
    device_id: str = Field(..., description="Unique device identifier")


class EntitySyncResult(BaseModel):
    """Result for a single entity sync operation."""
    local_id: str
    server_id: UUID
    entity_type: str
    operation: str
    success: bool
    error: Optional[str] = None


class ConflictInfo(BaseModel):
    """Information about a sync conflict."""
    entity_type: str
    local_id: str
    server_id: UUID
    local_data: Dict[str, Any]
    server_data: Dict[str, Any]
    local_updated_at: datetime
    server_updated_at: datetime
    conflict_type: str = Field(..., description="Conflict type: both_modified, deleted_on_server, deleted_locally")


class SyncPushResponse(BaseModel):
    """Response schema for push operation."""
    accepted: List[EntitySyncResult] = Field(default_factory=list)
    conflicts: List[ConflictInfo] = Field(default_factory=list)
    server_time: datetime


class SyncPullRequest(BaseModel):
    """Request schema for pulling server changes."""
    last_sync_times: Dict[str, datetime] = Field(
        default_factory=dict,
        description="Last sync time per entity type"
    )
    device_id: str = Field(..., description="Unique device identifier")
    include_deleted: bool = Field(default=True, description="Include deleted entities")


class EntityData(BaseModel):
    """Entity data from server."""
    id: UUID
    entity_type: str
    operation: str = Field(..., description="create, update, delete")
    data: Dict[str, Any]
    updated_at: datetime
    is_deleted: bool = False


class SyncPullResponse(BaseModel):
    """Response schema for pull operation."""
    changes: Dict[str, List[EntityData]] = Field(
        default_factory=dict,
        description="Changes grouped by entity type"
    )
    server_time: datetime
    has_more: bool = Field(default=False, description="More changes available")


class SyncStatusResponse(BaseModel):
    """Response schema for sync status check."""
    server_time: datetime
    entity_counts: Dict[str, int] = Field(
        default_factory=dict,
        description="Total count per entity type"
    )
    last_sync_times: Dict[str, Optional[datetime]] = Field(
        default_factory=dict,
        description="Last sync time per entity type for this device"
    )
    pending_conflicts: int = Field(default=0)


# Transaction-specific sync schemas
class TransactionSyncData(BaseModel):
    """Transaction data for sync."""
    book_id: UUID
    account_id: UUID
    target_account_id: Optional[UUID] = None
    category_id: UUID
    transaction_type: int = Field(..., ge=1, le=3)
    amount: Decimal = Field(..., gt=0)
    fee: Decimal = Field(default=Decimal("0"), ge=0)
    transaction_date: str  # ISO date string
    transaction_time: Optional[str] = None  # ISO time string
    note: Optional[str] = Field(None, max_length=500)
    tags: Optional[List[str]] = None
    images: Optional[List[str]] = None
    location: Optional[str] = Field(None, max_length=200)
    is_reimbursable: bool = False
    is_reimbursed: bool = False
    is_exclude_stats: bool = False
    source: int = Field(default=0, ge=0, le=3)
    ai_confidence: Optional[Decimal] = Field(None, ge=0, le=1)


class AccountSyncData(BaseModel):
    """Account data for sync."""
    name: str = Field(..., max_length=100)
    account_type: int = Field(..., ge=1, le=5)
    icon: Optional[str] = Field(None, max_length=50)
    balance: Decimal = Field(default=Decimal("0"))
    currency: str = Field(default="CNY", max_length=3)
    credit_limit: Optional[Decimal] = None
    bill_day: Optional[int] = Field(None, ge=1, le=31)
    repay_day: Optional[int] = Field(None, ge=1, le=31)
    is_default: bool = False
    is_active: bool = True


class CategorySyncData(BaseModel):
    """Category data for sync."""
    parent_id: Optional[UUID] = None
    name: str = Field(..., max_length=50)
    icon: Optional[str] = Field(None, max_length=50)
    category_type: int = Field(..., ge=1, le=2)  # 1: expense, 2: income
    sort_order: int = Field(default=0)
    is_system: bool = False


class BookSyncData(BaseModel):
    """Book (ledger) data for sync."""
    name: str = Field(..., max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    book_type: int = Field(default=0, ge=0, le=2)  # 0: personal, 1: family, 2: business
    icon: Optional[str] = Field(None, max_length=50)
    is_default: bool = False
    is_archived: bool = False


class BudgetSyncData(BaseModel):
    """Budget data for sync."""
    book_id: UUID
    category_id: Optional[UUID] = None
    name: str = Field(..., max_length=100)
    amount: Decimal = Field(..., gt=0)
    budget_type: int = Field(default=1, ge=1, le=2)  # 1: monthly, 2: yearly
    year: int
    month: Optional[int] = Field(None, ge=1, le=12)
    is_active: bool = True
