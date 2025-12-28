"""Budget endpoints."""
from datetime import date
from decimal import Decimal
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book
from app.models.category import Category
from app.models.budget import Budget
from app.models.transaction import Transaction
from app.schemas.budget import BudgetCreate, BudgetUpdate, BudgetResponse, BudgetList
from app.api.deps import get_current_user


router = APIRouter(prefix="/budgets", tags=["Budgets"])


async def calculate_budget_spent(
    db: AsyncSession,
    user_id: UUID,
    book_id: UUID,
    category_id: Optional[UUID],
    year: int,
    month: Optional[int],
) -> Decimal:
    """Calculate spent amount for a budget period."""
    if month:
        # Monthly budget
        start_date = date(year, month, 1)
        if month == 12:
            end_date = date(year + 1, 1, 1)
        else:
            end_date = date(year, month + 1, 1)
    else:
        # Yearly budget
        start_date = date(year, 1, 1)
        end_date = date(year + 1, 1, 1)

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


@router.get("", response_model=BudgetList)
async def get_budgets(
    book_id: Optional[UUID] = None,
    year: Optional[int] = None,
    month: Optional[int] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get user's budgets with spent calculation."""
    query = select(Budget).where(Budget.user_id == current_user.id)

    if book_id:
        query = query.where(Budget.book_id == book_id)
    if year:
        query = query.where(Budget.year == year)
    if month:
        query = query.where(Budget.month == month)

    query = query.order_by(Budget.year.desc(), Budget.month.desc())

    result = await db.execute(query)
    budgets = result.scalars().all()

    # Calculate spent for each budget
    items = []
    for budget in budgets:
        spent = await calculate_budget_spent(
            db, current_user.id, budget.book_id, budget.category_id, budget.year, budget.month
        )
        remaining = budget.amount - spent
        percentage = float(spent / budget.amount * 100) if budget.amount > 0 else 0

        budget_dict = {
            "id": budget.id,
            "user_id": budget.user_id,
            "book_id": budget.book_id,
            "category_id": budget.category_id,
            "budget_type": budget.budget_type,
            "amount": budget.amount,
            "year": budget.year,
            "month": budget.month,
            "created_at": budget.created_at,
            "spent": spent,
            "remaining": remaining,
            "percentage": round(percentage, 2),
        }
        items.append(BudgetResponse(**budget_dict))

    return BudgetList(items=items, total=len(items))


@router.post("", response_model=BudgetResponse, status_code=status.HTTP_201_CREATED)
async def create_budget(
    budget_data: BudgetCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new budget."""
    # Validate monthly budget has month
    if budget_data.budget_type == 1 and not budget_data.month:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Month is required for monthly budgets",
        )

    # Verify book exists and belongs to user
    result = await db.execute(
        select(Book).where(Book.id == budget_data.book_id, Book.user_id == current_user.id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Book not found",
        )

    # Verify category exists if provided
    if budget_data.category_id:
        result = await db.execute(
            select(Category).where(Category.id == budget_data.category_id)
        )
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Category not found",
            )

    # Check for duplicate budget
    query = select(Budget).where(
        and_(
            Budget.user_id == current_user.id,
            Budget.book_id == budget_data.book_id,
            Budget.year == budget_data.year,
            Budget.budget_type == budget_data.budget_type,
        )
    )
    if budget_data.category_id:
        query = query.where(Budget.category_id == budget_data.category_id)
    else:
        query = query.where(Budget.category_id.is_(None))

    if budget_data.month:
        query = query.where(Budget.month == budget_data.month)

    result = await db.execute(query)
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Budget already exists for this period",
        )

    # Create budget
    budget = Budget(
        user_id=current_user.id,
        book_id=budget_data.book_id,
        category_id=budget_data.category_id,
        budget_type=budget_data.budget_type,
        amount=budget_data.amount,
        year=budget_data.year,
        month=budget_data.month,
    )
    db.add(budget)
    await db.commit()
    await db.refresh(budget)

    # Calculate spent
    spent = await calculate_budget_spent(
        db, current_user.id, budget.book_id, budget.category_id, budget.year, budget.month
    )
    remaining = budget.amount - spent
    percentage = float(spent / budget.amount * 100) if budget.amount > 0 else 0

    return BudgetResponse(
        id=budget.id,
        user_id=budget.user_id,
        book_id=budget.book_id,
        category_id=budget.category_id,
        budget_type=budget.budget_type,
        amount=budget.amount,
        year=budget.year,
        month=budget.month,
        created_at=budget.created_at,
        spent=spent,
        remaining=remaining,
        percentage=round(percentage, 2),
    )


@router.get("/{budget_id}", response_model=BudgetResponse)
async def get_budget(
    budget_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific budget."""
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.user_id == current_user.id)
    )
    budget = result.scalar_one_or_none()

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    # Calculate spent
    spent = await calculate_budget_spent(
        db, current_user.id, budget.book_id, budget.category_id, budget.year, budget.month
    )
    remaining = budget.amount - spent
    percentage = float(spent / budget.amount * 100) if budget.amount > 0 else 0

    return BudgetResponse(
        id=budget.id,
        user_id=budget.user_id,
        book_id=budget.book_id,
        category_id=budget.category_id,
        budget_type=budget.budget_type,
        amount=budget.amount,
        year=budget.year,
        month=budget.month,
        created_at=budget.created_at,
        spent=spent,
        remaining=remaining,
        percentage=round(percentage, 2),
    )


@router.put("/{budget_id}", response_model=BudgetResponse)
async def update_budget(
    budget_id: UUID,
    budget_data: BudgetUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a budget amount."""
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.user_id == current_user.id)
    )
    budget = result.scalar_one_or_none()

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    # Update amount
    if budget_data.amount is not None:
        budget.amount = budget_data.amount

    await db.commit()
    await db.refresh(budget)

    # Calculate spent
    spent = await calculate_budget_spent(
        db, current_user.id, budget.book_id, budget.category_id, budget.year, budget.month
    )
    remaining = budget.amount - spent
    percentage = float(spent / budget.amount * 100) if budget.amount > 0 else 0

    return BudgetResponse(
        id=budget.id,
        user_id=budget.user_id,
        book_id=budget.book_id,
        category_id=budget.category_id,
        budget_type=budget.budget_type,
        amount=budget.amount,
        year=budget.year,
        month=budget.month,
        created_at=budget.created_at,
        spent=spent,
        remaining=remaining,
        percentage=round(percentage, 2),
    )


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_budget(
    budget_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a budget."""
    result = await db.execute(
        select(Budget).where(Budget.id == budget_id, Budget.user_id == current_user.id)
    )
    budget = result.scalar_one_or_none()

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    await db.delete(budget)
    await db.commit()
