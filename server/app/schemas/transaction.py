"""Transaction schemas."""
from datetime import datetime, date, time
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class TransactionCreate(BaseModel):
    """Schema for creating a transaction."""
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
    location: Optional[str] = Field(None, max_length=200)
    is_reimbursable: bool = False
    is_exclude_stats: bool = False
    source: int = Field(default=0, ge=0, le=3)  # 0: manual, 1: image, 2: voice, 3: email
    ai_confidence: Optional[Decimal] = Field(None, ge=0, le=1)
    # Source file fields for AI recognition
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
    is_reimbursable: Optional[bool] = None
    is_reimbursed: Optional[bool] = None
    is_exclude_stats: Optional[bool] = None


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
    location: Optional[str] = None
    is_reimbursable: bool
    is_reimbursed: bool
    is_exclude_stats: bool
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
