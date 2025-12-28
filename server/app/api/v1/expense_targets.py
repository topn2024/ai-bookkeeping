"""Expense target endpoints for monthly spending limits."""
from datetime import date
from decimal import Decimal
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book
from app.models.category import Category
from app.models.expense_target import ExpenseTarget
from app.models.transaction import Transaction
from app.schemas.expense_target import (
    ExpenseTargetCreate,
    ExpenseTargetUpdate,
    ExpenseTargetResponse,
    ExpenseTargetList,
    ExpenseTargetSummary,
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/expense-targets", tags=["Expense Targets"])


async def calculate_monthly_spent(
    db: AsyncSession,
    user_id: UUID,
    book_id: UUID,
    category_id: Optional[UUID],
    year: int,
    month: int,
) -> Decimal:
    """Calculate spent amount for a specific month."""
    start_date = date(year, month, 1)
    if month == 12:
        end_date = date(year + 1, 1, 1)
    else:
        end_date = date(year, month + 1, 1)

    query = select(func.coalesce(func.sum(Transaction.amount), Decimal(0))).where(
        and_(
            Transaction.user_id == user_id,
            Transaction.book_id == book_id,
            Transaction.transaction_type == 1,  # Expense only
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date < end_date,
            Transaction.is_exclude_stats == False,
        )
    )

    if category_id:
        query = query.where(Transaction.category_id == category_id)

    result = await db.execute(query)
    return result.scalar() or Decimal(0)


async def build_response(
    target: ExpenseTarget,
    db: AsyncSession,
    user_id: UUID,
) -> ExpenseTargetResponse:
    """Build expense target response with computed fields."""
    # Get category name if exists
    category_name = None
    if target.category_id:
        result = await db.execute(
            select(Category.name).where(Category.id == target.category_id)
        )
        category_name = result.scalar()

    # Calculate spent amount
    current_spent = await calculate_monthly_spent(
        db, user_id, target.book_id, target.category_id, target.year, target.month
    )
    remaining = target.max_amount - current_spent
    percentage = float(current_spent / target.max_amount * 100) if target.max_amount > 0 else 0
    is_exceeded = current_spent > target.max_amount
    is_near_limit = percentage >= target.alert_threshold and not is_exceeded

    return ExpenseTargetResponse(
        id=target.id,
        user_id=target.user_id,
        book_id=target.book_id,
        name=target.name,
        description=target.description,
        max_amount=target.max_amount,
        category_id=target.category_id,
        category_name=category_name,
        year=target.year,
        month=target.month,
        icon_code=target.icon_code,
        color_value=target.color_value,
        alert_threshold=target.alert_threshold,
        enable_notifications=target.enable_notifications,
        is_active=target.is_active,
        created_at=target.created_at,
        updated_at=target.updated_at,
        current_spent=current_spent,
        remaining=remaining,
        percentage=round(percentage, 2),
        is_exceeded=is_exceeded,
        is_near_limit=is_near_limit,
    )


@router.get("", response_model=ExpenseTargetList)
async def get_expense_targets(
    book_id: Optional[UUID] = None,
    year: Optional[int] = None,
    month: Optional[int] = None,
    is_active: Optional[bool] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get user's expense targets with spent calculation."""
    query = select(ExpenseTarget).where(ExpenseTarget.user_id == current_user.id)

    if book_id:
        query = query.where(ExpenseTarget.book_id == book_id)
    if year:
        query = query.where(ExpenseTarget.year == year)
    if month:
        query = query.where(ExpenseTarget.month == month)
    if is_active is not None:
        query = query.where(ExpenseTarget.is_active == is_active)

    query = query.order_by(ExpenseTarget.year.desc(), ExpenseTarget.month.desc(), ExpenseTarget.created_at.desc())

    result = await db.execute(query)
    targets = result.scalars().all()

    items = []
    for target in targets:
        response = await build_response(target, db, current_user.id)
        items.append(response)

    return ExpenseTargetList(items=items, total=len(items))


@router.get("/summary", response_model=ExpenseTargetSummary)
async def get_expense_targets_summary(
    book_id: Optional[UUID] = None,
    year: Optional[int] = None,
    month: Optional[int] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get summary of expense targets."""
    query = select(ExpenseTarget).where(
        ExpenseTarget.user_id == current_user.id,
        ExpenseTarget.is_active == True,
    )

    if book_id:
        query = query.where(ExpenseTarget.book_id == book_id)
    if year:
        query = query.where(ExpenseTarget.year == year)
    if month:
        query = query.where(ExpenseTarget.month == month)

    result = await db.execute(query)
    targets = result.scalars().all()

    total_limit = Decimal(0)
    total_spent = Decimal(0)
    exceeded_count = 0
    near_limit_count = 0

    for target in targets:
        total_limit += target.max_amount
        spent = await calculate_monthly_spent(
            db, current_user.id, target.book_id, target.category_id, target.year, target.month
        )
        total_spent += spent

        percentage = float(spent / target.max_amount * 100) if target.max_amount > 0 else 0
        if spent > target.max_amount:
            exceeded_count += 1
        elif percentage >= target.alert_threshold:
            near_limit_count += 1

    total_remaining = total_limit - total_spent
    overall_percentage = float(total_spent / total_limit * 100) if total_limit > 0 else 0

    return ExpenseTargetSummary(
        total_limit=total_limit,
        total_spent=total_spent,
        total_remaining=total_remaining,
        overall_percentage=round(overall_percentage, 2),
        active_count=len(targets),
        exceeded_count=exceeded_count,
        near_limit_count=near_limit_count,
    )


@router.post("", response_model=ExpenseTargetResponse, status_code=status.HTTP_201_CREATED)
async def create_expense_target(
    data: ExpenseTargetCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new expense target."""
    # Verify book exists and belongs to user
    result = await db.execute(
        select(Book).where(Book.id == data.book_id, Book.user_id == current_user.id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Book not found",
        )

    # Verify category exists if provided
    if data.category_id:
        result = await db.execute(
            select(Category).where(Category.id == data.category_id)
        )
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Category not found",
            )

    # Check for duplicate target (same book, category, year, month)
    query = select(ExpenseTarget).where(
        and_(
            ExpenseTarget.user_id == current_user.id,
            ExpenseTarget.book_id == data.book_id,
            ExpenseTarget.year == data.year,
            ExpenseTarget.month == data.month,
        )
    )
    if data.category_id:
        query = query.where(ExpenseTarget.category_id == data.category_id)
    else:
        query = query.where(ExpenseTarget.category_id.is_(None))

    result = await db.execute(query)
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Expense target already exists for this period and category",
        )

    # Create target
    target = ExpenseTarget(
        user_id=current_user.id,
        book_id=data.book_id,
        name=data.name,
        description=data.description,
        max_amount=data.max_amount,
        category_id=data.category_id,
        year=data.year,
        month=data.month,
        icon_code=data.icon_code or 0xe8d4,
        color_value=data.color_value or 0xFF4CAF50,
        alert_threshold=data.alert_threshold,
        enable_notifications=data.enable_notifications,
    )
    db.add(target)
    await db.commit()
    await db.refresh(target)

    return await build_response(target, db, current_user.id)


@router.get("/{target_id}", response_model=ExpenseTargetResponse)
async def get_expense_target(
    target_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific expense target."""
    result = await db.execute(
        select(ExpenseTarget).where(
            ExpenseTarget.id == target_id,
            ExpenseTarget.user_id == current_user.id,
        )
    )
    target = result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Expense target not found",
        )

    return await build_response(target, db, current_user.id)


@router.patch("/{target_id}", response_model=ExpenseTargetResponse)
async def update_expense_target(
    target_id: UUID,
    data: ExpenseTargetUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update an expense target."""
    result = await db.execute(
        select(ExpenseTarget).where(
            ExpenseTarget.id == target_id,
            ExpenseTarget.user_id == current_user.id,
        )
    )
    target = result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Expense target not found",
        )

    # Update fields
    if data.name is not None:
        target.name = data.name
    if data.description is not None:
        target.description = data.description
    if data.max_amount is not None:
        target.max_amount = data.max_amount
    if data.icon_code is not None:
        target.icon_code = data.icon_code
    if data.color_value is not None:
        target.color_value = data.color_value
    if data.alert_threshold is not None:
        target.alert_threshold = data.alert_threshold
    if data.enable_notifications is not None:
        target.enable_notifications = data.enable_notifications
    if data.is_active is not None:
        target.is_active = data.is_active

    await db.commit()
    await db.refresh(target)

    return await build_response(target, db, current_user.id)


@router.delete("/{target_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_expense_target(
    target_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete an expense target."""
    result = await db.execute(
        select(ExpenseTarget).where(
            ExpenseTarget.id == target_id,
            ExpenseTarget.user_id == current_user.id,
        )
    )
    target = result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Expense target not found",
        )

    await db.delete(target)
    await db.commit()


@router.post("/{target_id}/copy-to-next-month", response_model=ExpenseTargetResponse)
async def copy_to_next_month(
    target_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Copy an expense target to the next month."""
    result = await db.execute(
        select(ExpenseTarget).where(
            ExpenseTarget.id == target_id,
            ExpenseTarget.user_id == current_user.id,
        )
    )
    target = result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Expense target not found",
        )

    # Calculate next month
    next_year = target.year
    next_month = target.month + 1
    if next_month > 12:
        next_month = 1
        next_year += 1

    # Check if target already exists for next month
    query = select(ExpenseTarget).where(
        and_(
            ExpenseTarget.user_id == current_user.id,
            ExpenseTarget.book_id == target.book_id,
            ExpenseTarget.year == next_year,
            ExpenseTarget.month == next_month,
        )
    )
    if target.category_id:
        query = query.where(ExpenseTarget.category_id == target.category_id)
    else:
        query = query.where(ExpenseTarget.category_id.is_(None))

    result = await db.execute(query)
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Expense target already exists for next month",
        )

    # Create new target
    new_target = ExpenseTarget(
        user_id=current_user.id,
        book_id=target.book_id,
        name=target.name,
        description=target.description,
        max_amount=target.max_amount,
        category_id=target.category_id,
        year=next_year,
        month=next_month,
        icon_code=target.icon_code,
        color_value=target.color_value,
        alert_threshold=target.alert_threshold,
        enable_notifications=target.enable_notifications,
    )
    db.add(new_target)
    await db.commit()
    await db.refresh(new_target)

    return await build_response(new_target, db, current_user.id)
