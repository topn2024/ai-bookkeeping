"""Money Age schemas for API request/response."""
from datetime import date, datetime
from decimal import Decimal
from typing import Optional, List, Dict
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


# ==================== Resource Pool Schemas ====================

class ResourcePoolBase(BaseModel):
    """Base schema for Resource Pool."""
    original_amount: Decimal = Field(..., description="Original income amount")
    income_date: date = Field(..., description="When income was received")
    account_id: UUID = Field(..., description="Account holding this resource")
    income_category_id: UUID = Field(..., description="Income category")


class ResourcePoolCreate(ResourcePoolBase):
    """Schema for creating a Resource Pool."""
    income_transaction_id: UUID = Field(..., description="Income transaction ID")
    book_id: UUID = Field(..., description="Book ID")


class ResourcePoolUpdate(BaseModel):
    """Schema for updating a Resource Pool."""
    remaining_amount: Optional[Decimal] = None
    is_fully_consumed: Optional[bool] = None


class ResourcePoolResponse(ResourcePoolBase):
    """Schema for Resource Pool response."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    book_id: UUID
    income_transaction_id: UUID
    remaining_amount: Decimal
    consumed_amount: Decimal
    first_consumed_date: Optional[date] = None
    last_consumed_date: Optional[date] = None
    fully_consumed_date: Optional[date] = None
    is_fully_consumed: bool
    consumption_count: int
    created_at: datetime
    updated_at: datetime


# ==================== Consumption Record Schemas ====================

class ConsumptionRecordBase(BaseModel):
    """Base schema for Consumption Record."""
    resource_pool_id: UUID
    expense_transaction_id: UUID
    consumed_amount: Decimal
    consumption_date: date
    money_age_days: int


class ConsumptionRecordCreate(ConsumptionRecordBase):
    """Schema for creating a Consumption Record."""
    book_id: UUID


class ConsumptionRecordResponse(ConsumptionRecordBase):
    """Schema for Consumption Record response."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    book_id: UUID
    created_at: datetime


# ==================== Money Age Calculation Schemas ====================

class MoneyAgeCalculateRequest(BaseModel):
    """Request schema for calculating money age."""
    transaction_id: UUID = Field(..., description="Transaction ID to calculate money age for")
    book_id: UUID = Field(..., description="Book ID")
    force_recalculate: bool = Field(default=False, description="Force recalculation even if exists")


class MoneyAgeCalculateResponse(BaseModel):
    """Response schema for money age calculation."""
    transaction_id: UUID
    money_age: int = Field(..., description="Calculated money age in days")
    money_age_level: str = Field(..., description="Health level: health/warning/danger")
    consumption_breakdown: List[Dict] = Field(default_factory=list, description="List of consumption records")
    resource_pools_used: int = Field(..., description="Number of resource pools consumed")
    calculation_timestamp: datetime


class MoneyAgeBatchCalculateRequest(BaseModel):
    """Request schema for batch calculating money age."""
    transaction_ids: List[UUID] = Field(..., description="List of transaction IDs")
    book_id: UUID
    force_recalculate: bool = Field(default=False)


class MoneyAgeBatchCalculateResponse(BaseModel):
    """Response schema for batch money age calculation."""
    results: List[MoneyAgeCalculateResponse]
    total_count: int
    success_count: int
    failed_count: int
    failed_ids: List[UUID] = Field(default_factory=list)


# ==================== Money Age Dashboard Schemas ====================

class MoneyAgeDashboardResponse(BaseModel):
    """Response schema for money age dashboard."""
    user_id: UUID
    book_id: UUID

    # Overall statistics
    avg_money_age: Decimal = Field(..., description="Average money age in days")
    median_money_age: int = Field(..., description="Median money age")
    current_health_level: str = Field(..., description="Current overall health level")

    # Health distribution
    health_count: int = Field(default=0, description="Transactions in health range")
    warning_count: int = Field(default=0, description="Transactions in warning range")
    danger_count: int = Field(default=0, description="Transactions in danger range")

    # Resource pool summary
    total_resource_pools: int = Field(default=0)
    active_resource_pools: int = Field(default=0)
    total_remaining_amount: Decimal = Field(default=0)

    # Recent transactions with money age
    recent_transactions: List[Dict] = Field(default_factory=list)

    # Trend data
    trend_data: List[Dict] = Field(default_factory=list, description="Historical trend data")


class MoneyAgeTrendRequest(BaseModel):
    """Request schema for money age trend."""
    book_id: UUID
    start_date: date
    end_date: date
    granularity: str = Field(default='daily', description="daily/weekly/monthly")


class MoneyAgeTrendResponse(BaseModel):
    """Response schema for money age trend."""
    book_id: UUID
    start_date: date
    end_date: date
    granularity: str
    data_points: List[Dict] = Field(..., description="Time series data points")
    avg_money_age: Decimal
    trend: str = Field(..., description="improving/stable/declining")


# ==================== Money Age Health Level Schemas ====================

class HealthLevelDistribution(BaseModel):
    """Health level distribution schema."""
    level: str = Field(..., description="health/warning/danger")
    count: int
    percentage: Decimal
    total_amount: Decimal
    avg_money_age: Decimal


class MoneyAgeHealthResponse(BaseModel):
    """Response schema for money age health analysis."""
    book_id: UUID
    overall_level: str
    distributions: List[HealthLevelDistribution]
    recommendations: List[str] = Field(default_factory=list)


# ==================== Money Age Snapshot Schemas ====================

class MoneyAgeSnapshotResponse(BaseModel):
    """Response schema for money age snapshot."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    book_id: UUID
    snapshot_date: date
    snapshot_type: str
    avg_money_age: Decimal
    median_money_age: Optional[int]
    health_level: str
    health_count: int
    warning_count: int
    danger_count: int
    total_resource_pools: int
    active_resource_pools: int
    total_remaining_amount: Decimal
    category_breakdown: Optional[Dict]
    monthly_trend: Optional[Dict]
    created_at: datetime


# ==================== Money Age Configuration Schemas ====================

class MoneyAgeConfigBase(BaseModel):
    """Base schema for Money Age Configuration."""
    consumption_strategy: str = Field(default='fifo', description="fifo/lifo/weighted_average")
    health_threshold: int = Field(default=30, description="Healthy threshold in days")
    warning_threshold: int = Field(default=60, description="Warning threshold in days")
    enable_daily_snapshot: bool = Field(default=True)
    enable_weekly_snapshot: bool = Field(default=True)
    enable_monthly_snapshot: bool = Field(default=True)
    enable_notifications: bool = Field(default=True)
    notify_on_warning: bool = Field(default=True)
    notify_on_danger: bool = Field(default=True)


class MoneyAgeConfigCreate(MoneyAgeConfigBase):
    """Schema for creating Money Age Configuration."""
    book_id: UUID


class MoneyAgeConfigUpdate(BaseModel):
    """Schema for updating Money Age Configuration."""
    consumption_strategy: Optional[str] = None
    health_threshold: Optional[int] = None
    warning_threshold: Optional[int] = None
    enable_daily_snapshot: Optional[bool] = None
    enable_weekly_snapshot: Optional[bool] = None
    enable_monthly_snapshot: Optional[bool] = None
    enable_notifications: Optional[bool] = None
    notify_on_warning: Optional[bool] = None
    notify_on_danger: Optional[bool] = None


class MoneyAgeConfigResponse(MoneyAgeConfigBase):
    """Schema for Money Age Configuration response."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    book_id: UUID
    created_at: datetime
    updated_at: datetime


# ==================== Money Age Rebuild Schemas ====================

class MoneyAgeRebuildRequest(BaseModel):
    """Request schema for rebuilding money age data."""
    book_id: UUID
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    clear_existing: bool = Field(default=False, description="Clear existing data before rebuild")


class MoneyAgeRebuildResponse(BaseModel):
    """Response schema for money age rebuild."""
    book_id: UUID
    status: str = Field(..., description="success/failed/partial")
    processed_transactions: int
    created_resource_pools: int
    created_consumption_records: int
    errors: List[str] = Field(default_factory=list)
    started_at: datetime
    completed_at: datetime
    duration_seconds: float
