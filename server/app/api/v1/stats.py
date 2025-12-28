"""Statistics endpoints."""
from datetime import date, timedelta
from decimal import Decimal
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, case

from app.core.database import get_db
from app.models.user import User
from app.models.transaction import Transaction
from app.models.category import Category
from app.schemas.stats import StatsOverview, StatsTrend, DailyStats, StatsCategory, CategoryStats
from app.api.deps import get_current_user


router = APIRouter(prefix="/stats", tags=["Statistics"])


@router.get("/overview", response_model=StatsOverview)
async def get_overview(
    book_id: Optional[UUID] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get income/expense overview."""
    # Default to current month
    if not start_date:
        today = date.today()
        start_date = date(today.year, today.month, 1)
    if not end_date:
        end_date = date.today()

    # Base query
    query = select(
        func.coalesce(func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=Decimal(0))), Decimal(0)).label("income"),
        func.coalesce(func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=Decimal(0))), Decimal(0)).label("expense"),
        func.count(Transaction.id).label("count"),
    ).where(
        and_(
            Transaction.user_id == current_user.id,
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date <= end_date,
            Transaction.is_exclude_stats == False,
            Transaction.transaction_type.in_([1, 2]),
        )
    )

    if book_id:
        query = query.where(Transaction.book_id == book_id)

    result = await db.execute(query)
    row = result.one()

    income = row.income or Decimal(0)
    expense = row.expense or Decimal(0)

    return StatsOverview(
        total_income=income,
        total_expense=expense,
        net_amount=income - expense,
        transaction_count=row.count or 0,
        start_date=start_date,
        end_date=end_date,
    )


@router.get("/trend", response_model=StatsTrend)
async def get_trend(
    book_id: Optional[UUID] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get daily trend data."""
    # Default to last 30 days
    if not end_date:
        end_date = date.today()
    if not start_date:
        start_date = end_date - timedelta(days=29)

    # Query daily stats
    query = select(
        Transaction.transaction_date,
        func.coalesce(func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=Decimal(0))), Decimal(0)).label("income"),
        func.coalesce(func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=Decimal(0))), Decimal(0)).label("expense"),
    ).where(
        and_(
            Transaction.user_id == current_user.id,
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date <= end_date,
            Transaction.is_exclude_stats == False,
            Transaction.transaction_type.in_([1, 2]),
        )
    ).group_by(Transaction.transaction_date).order_by(Transaction.transaction_date)

    if book_id:
        query = query.where(Transaction.book_id == book_id)

    result = await db.execute(query)
    rows = result.all()

    # Build daily stats with all days (fill gaps with zero)
    daily_map = {row.transaction_date: row for row in rows}
    daily_stats = []
    current_date = start_date
    while current_date <= end_date:
        if current_date in daily_map:
            row = daily_map[current_date]
            daily_stats.append(DailyStats(
                date=current_date,
                income=row.income or Decimal(0),
                expense=row.expense or Decimal(0),
            ))
        else:
            daily_stats.append(DailyStats(
                date=current_date,
                income=Decimal(0),
                expense=Decimal(0),
            ))
        current_date += timedelta(days=1)

    return StatsTrend(
        daily_stats=daily_stats,
        period="daily",
    )


@router.get("/category", response_model=StatsCategory)
async def get_category_stats(
    transaction_type: int = Query(..., ge=1, le=2, description="1: expense, 2: income"),
    book_id: Optional[UUID] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get category breakdown statistics."""
    # Default to current month
    if not start_date:
        today = date.today()
        start_date = date(today.year, today.month, 1)
    if not end_date:
        end_date = date.today()

    # Query category stats
    query = select(
        Transaction.category_id,
        Category.name,
        Category.icon,
        func.sum(Transaction.amount).label("amount"),
        func.count(Transaction.id).label("count"),
    ).join(
        Category, Transaction.category_id == Category.id
    ).where(
        and_(
            Transaction.user_id == current_user.id,
            Transaction.transaction_type == transaction_type,
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date <= end_date,
            Transaction.is_exclude_stats == False,
        )
    ).group_by(
        Transaction.category_id, Category.name, Category.icon
    ).order_by(func.sum(Transaction.amount).desc())

    if book_id:
        query = query.where(Transaction.book_id == book_id)

    result = await db.execute(query)
    rows = result.all()

    # Calculate total and percentages
    total_amount = sum(row.amount for row in rows) if rows else Decimal(0)

    categories = []
    for row in rows:
        percentage = float(row.amount / total_amount * 100) if total_amount > 0 else 0
        categories.append(CategoryStats(
            category_id=row.category_id,
            category_name=row.name,
            category_icon=row.icon,
            amount=row.amount,
            percentage=round(percentage, 2),
            count=row.count,
        ))

    return StatsCategory(
        categories=categories,
        total_amount=total_amount,
        transaction_type=transaction_type,
    )
