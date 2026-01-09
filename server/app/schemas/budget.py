"""Budget schemas."""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class BudgetCreate(BaseModel):
    """Schema for creating a budget."""
    book_id: UUID
    category_id: Optional[UUID] = None  # NULL for total budget
    name: str = Field("Budget", min_length=1, max_length=100)  # Budget name
    budget_type: int = Field(..., ge=1, le=2)  # 1: monthly, 2: yearly
    amount: Decimal = Field(..., gt=0)
    year: int = Field(..., ge=2000, le=2100)
    month: Optional[int] = Field(None, ge=1, le=12)  # Required for monthly
    is_active: bool = True  # Budget active status


class BudgetUpdate(BaseModel):
    """Schema for updating a budget."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    amount: Optional[Decimal] = Field(None, gt=0)
    is_active: Optional[bool] = None


class BudgetResponse(BaseModel):
    """Schema for budget response."""
    id: UUID
    user_id: UUID
    book_id: UUID
    category_id: Optional[UUID] = None
    name: str
    budget_type: int
    amount: Decimal
    year: int
    month: Optional[int] = None
    is_active: bool = True
    created_at: datetime
    updated_at: datetime
    # Computed fields
    spent: Optional[Decimal] = None
    remaining: Optional[Decimal] = None
    percentage: Optional[float] = None

    class Config:
        from_attributes = True


class BudgetList(BaseModel):
    """Schema for budget list."""
    items: List[BudgetResponse]
    total: int
