"""Transaction schemas."""
from datetime import datetime, date, time
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class TransactionCreate(BaseModel):
    """Schema for creating a transaction.

    Visibility levels (for family/shared books):
        0: private - 仅本人可见
        1: all_members - 所有成员可见 (默认)
        2: admins_only - 仅管理员可见
    """
    book_id: UUID
    account_id: UUID
    target_account_id: Optional[UUID] = None
    category_id: UUID
    transaction_type: int = Field(..., ge=1, le=3)  # 1: expense, 2: income, 3: transfer
    amount: Decimal = Field(..., gt=0)
    fee: Decimal = Field(default=Decimal("0"), ge=0)
    transaction_date: date = Field(default_factory=date.today)
    transaction_time: Optional[time] = None
    note: Optional[str] = Field(None, max_length=500)
    tags: Optional[List[str]] = None
    images: Optional[List[str]] = None
    location: Optional[str] = Field(None, max_length=200)  # Legacy: simple location string

    # Structured location fields (Chapter 14: Location Intelligence)
    location_latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    location_longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    location_place_name: Optional[str] = Field(None, max_length=200)
    location_address: Optional[str] = Field(None, max_length=500)
    location_city: Optional[str] = Field(None, max_length=100)
    location_district: Optional[str] = Field(None, max_length=100)
    location_type: Optional[int] = Field(None, ge=0, le=10)  # LocationType enum
    location_poi_id: Optional[str] = Field(None, max_length=100)
    geofence_region: Optional[str] = Field(None, max_length=100)  # home/work/shopping etc
    is_cross_region: bool = False  # Cross-region transaction flag

    # Money Age fields
    money_age: Optional[int] = None  # Age in days
    money_age_level: Optional[str] = Field(None, max_length=20)  # health/warning/danger
    resource_pool_id: Optional[UUID] = None  # For income tracking

    is_reimbursable: bool = False
    is_exclude_stats: bool = False
    visibility: int = Field(default=1, ge=0, le=2)  # 0: private, 1: all_members, 2: admins_only
    source: int = Field(default=0, ge=0, le=3)  # 0: manual, 1: image, 2: voice, 3: email
    ai_confidence: Optional[Decimal] = Field(None, ge=0, le=1)

    # Source file fields for AI recognition
    source_file_url: Optional[str] = Field(None, max_length=500)  # MinIO file URL
    source_file_type: Optional[str] = Field(None, max_length=50)  # MIME type
    source_file_size: Optional[int] = Field(None, ge=0)  # File size in bytes
    recognition_raw_response: Optional[str] = Field(None, max_length=5000)  # AI raw response
    recognition_timestamp: Optional[datetime] = None
    source_file_expires_at: Optional[datetime] = None


class TransactionUpdate(BaseModel):
    """Schema for updating a transaction."""
    account_id: Optional[UUID] = None
    target_account_id: Optional[UUID] = None
    category_id: Optional[UUID] = None
    transaction_type: Optional[int] = Field(None, ge=1, le=3)
    amount: Optional[Decimal] = Field(None, gt=0)
    fee: Optional[Decimal] = Field(None, ge=0)
    transaction_date: Optional[date] = None
    transaction_time: Optional[time] = None
    note: Optional[str] = Field(None, max_length=500)
    tags: Optional[List[str]] = None
    images: Optional[List[str]] = None
    location: Optional[str] = Field(None, max_length=200)

    # Structured location fields (Chapter 14: Location Intelligence)
    location_latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    location_longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    location_place_name: Optional[str] = Field(None, max_length=200)
    location_address: Optional[str] = Field(None, max_length=500)
    location_city: Optional[str] = Field(None, max_length=100)
    location_district: Optional[str] = Field(None, max_length=100)
    location_type: Optional[int] = Field(None, ge=0, le=10)
    location_poi_id: Optional[str] = Field(None, max_length=100)
    geofence_region: Optional[str] = Field(None, max_length=100)
    is_cross_region: Optional[bool] = None

    # Money Age fields
    money_age: Optional[int] = None
    money_age_level: Optional[str] = Field(None, max_length=20)
    resource_pool_id: Optional[UUID] = None

    is_reimbursable: Optional[bool] = None
    is_reimbursed: Optional[bool] = None
    is_exclude_stats: Optional[bool] = None
    visibility: Optional[int] = Field(None, ge=0, le=2)


class TransactionResponse(BaseModel):
    """Schema for transaction response."""
    id: UUID
    user_id: UUID
    book_id: UUID
    account_id: UUID
    target_account_id: Optional[UUID] = None
    category_id: UUID
    transaction_type: int
    amount: Decimal
    fee: Decimal
    transaction_date: date
    transaction_time: Optional[time] = None
    note: Optional[str] = None
    tags: Optional[List[str]] = None
    images: Optional[List[str]] = None
    location: Optional[str] = None  # Legacy: simple location string

    # Structured location fields (Chapter 14: Location Intelligence)
    location_latitude: Optional[Decimal] = None
    location_longitude: Optional[Decimal] = None
    location_place_name: Optional[str] = None
    location_address: Optional[str] = None
    location_city: Optional[str] = None
    location_district: Optional[str] = None
    location_type: Optional[int] = None
    location_poi_id: Optional[str] = None
    geofence_region: Optional[str] = None
    is_cross_region: bool = False

    # Money Age fields
    money_age: Optional[int] = None
    money_age_level: Optional[str] = None
    resource_pool_id: Optional[UUID] = None

    is_reimbursable: bool
    is_reimbursed: bool
    is_exclude_stats: bool
    visibility: int = 1
    source: int
    ai_confidence: Optional[Decimal] = None

    # Source file fields
    source_file_url: Optional[str] = None
    source_file_type: Optional[str] = None
    source_file_size: Optional[int] = None
    recognition_raw_response: Optional[str] = None
    recognition_timestamp: Optional[datetime] = None
    source_file_expires_at: Optional[datetime] = None

    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class TransactionList(BaseModel):
    """Schema for transaction list with pagination."""
    items: List[TransactionResponse]
    total: int
    page: int
    page_size: int
