"""Expense target schemas."""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class ExpenseTargetCreate(BaseModel):
    """Schema for creating an expense target."""
    book_id: UUID
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    max_amount: Decimal = Field(..., gt=0)
    category_id: Optional[UUID] = None  # None for total spending
    year: int = Field(..., ge=2000, le=2100)
    month: int = Field(..., ge=1, le=12)
    icon_code: Optional[int] = None
    color_value: Optional[int] = None
    alert_threshold: int = Field(default=80, ge=0, le=100)
    enable_notifications: bool = True


class ExpenseTargetUpdate(BaseModel):
    """Schema for updating an expense target."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    max_amount: Optional[Decimal] = Field(None, gt=0)
    icon_code: Optional[int] = None
    color_value: Optional[int] = None
    alert_threshold: Optional[int] = Field(None, ge=0, le=100)
    enable_notifications: Optional[bool] = None
    is_active: Optional[bool] = None


class ExpenseTargetResponse(BaseModel):
    """Schema for expense target response."""
    id: UUID
    user_id: UUID
    book_id: UUID
    name: str
    description: Optional[str] = None
    max_amount: Decimal
    category_id: Optional[UUID] = None
    category_name: Optional[str] = None  # Populated from category
    year: int
    month: int
    icon_code: int
    color_value: int
    alert_threshold: int
    enable_notifications: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime

    # Computed fields
    current_spent: Decimal = Decimal(0)
    remaining: Decimal = Decimal(0)
    percentage: float = 0.0
    is_exceeded: bool = False
    is_near_limit: bool = False  # True when >= alert_threshold

    class Config:
        from_attributes = True


class ExpenseTargetList(BaseModel):
    """Schema for expense target list."""
    items: List[ExpenseTargetResponse]
    total: int


class ExpenseTargetSummary(BaseModel):
    """Schema for expense targets summary."""
    total_limit: Decimal
    total_spent: Decimal
    total_remaining: Decimal
    overall_percentage: float
    active_count: int
    exceeded_count: int
    near_limit_count: int
