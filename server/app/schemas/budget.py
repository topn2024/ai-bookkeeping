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
    budget_type: int = Field(..., ge=1, le=2)  # 1: monthly, 2: yearly
    amount: Decimal = Field(..., gt=0)
    year: int = Field(..., ge=2000, le=2100)
    month: Optional[int] = Field(None, ge=1, le=12)  # Required for monthly


class BudgetUpdate(BaseModel):
    """Schema for updating a budget."""
    amount: Optional[Decimal] = Field(None, gt=0)


class BudgetResponse(BaseModel):
    """Schema for budget response."""
    id: UUID
    user_id: UUID
    book_id: UUID
    category_id: Optional[UUID] = None
    budget_type: int
    amount: Decimal
    year: int
    month: Optional[int] = None
    created_at: datetime
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
