"""Statistics schemas."""
from datetime import date
from decimal import Decimal
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel


class StatsOverview(BaseModel):
    """Schema for overview statistics."""
    total_income: Decimal
    total_expense: Decimal
    net_amount: Decimal
    transaction_count: int
    start_date: date
    end_date: date


class DailyStats(BaseModel):
    """Schema for daily statistics."""
    date: date
    income: Decimal
    expense: Decimal


class StatsTrend(BaseModel):
    """Schema for trend statistics."""
    daily_stats: List[DailyStats]
    period: str  # daily, weekly, monthly, yearly


class CategoryStats(BaseModel):
    """Schema for category statistics."""
    category_id: UUID
    category_name: str
    category_icon: Optional[str] = None
    amount: Decimal
    percentage: float
    count: int


class StatsCategory(BaseModel):
    """Schema for category breakdown statistics."""
    categories: List[CategoryStats]
    total_amount: Decimal
    transaction_type: int  # 1: expense, 2: income


class BudgetStats(BaseModel):
    """Schema for budget execution statistics."""
    budget_amount: Decimal
    spent_amount: Decimal
    remaining_amount: Decimal
    percentage: float
    category_id: Optional[UUID] = None
    category_name: Optional[str] = None
