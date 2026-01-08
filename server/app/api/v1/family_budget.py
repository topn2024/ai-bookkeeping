"""Family budget endpoints."""
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.core.timezone import beijing_now_naive
from app.models.user import User
from app.models.book import Book, BookMember, FamilyBudget, MemberBudget
from app.models.transaction import Transaction
from app.schemas.family import (
    FamilyBudgetCreate, FamilyBudgetUpdate, FamilyBudgetResponse,
    MemberBudgetResponse, MemberBudgetCreate
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/books/{book_id}/family-budgets", tags=["Family Budgets"])


async def verify_book_member_access(
    db: AsyncSession,
    book_id: UUID,
    user_id: UUID,
    require_admin: bool = False,
) -> tuple[Book, Optional[BookMember]]:
    """Verify user has access to the book."""
    # Check if user is owner
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == user_id)
    )
    book = result.scalar_one_or_none()
    if book:
        return book, None  # Owner, no member record needed

    # Check if user is a member
    result = await db.execute(
        select(BookMember, Book)
        .join(Book, BookMember.book_id == Book.id)
        .where(
            BookMember.book_id == book_id,
            BookMember.user_id == user_id,
        )
    )
    row = result.first()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Book not found or access denied",
        )

    member, book = row
    if require_admin and member.role < 2:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )

    return book, member


async def calculate_member_spent(
    db: AsyncSession,
    book_id: UUID,
    user_id: UUID,
    period: str,
) -> tuple[float, dict]:
    """Calculate member's spending for a period."""
    year, month = period.split('-')

    result = await db.execute(
        select(
            func.coalesce(func.sum(Transaction.amount), 0).label('total'),
            Transaction.category_id,
        )
        .where(
            Transaction.book_id == book_id,
            Transaction.user_id == user_id,
            Transaction.transaction_type == 1,  # expense
            func.extract('year', Transaction.transaction_date) == int(year),
            func.extract('month', Transaction.transaction_date) == int(month),
        )
        .group_by(Transaction.category_id)
    )
    rows = result.all()

    total_spent = 0.0
    category_spent = {}
    for row in rows:
        amount = float(row.total)
        total_spent += amount
        if row.category_id:
            category_spent[str(row.category_id)] = amount

    return total_spent, category_spent


@router.get("", response_model=List[FamilyBudgetResponse])
async def get_family_budgets(
    book_id: UUID,
    period: Optional[str] = Query(None, pattern=r"^\d{4}-\d{2}$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get family budgets for a book."""
    book, _ = await verify_book_member_access(db, book_id, current_user.id)

    query = select(FamilyBudget).where(FamilyBudget.book_id == book_id)
    if period:
        query = query.where(FamilyBudget.period == period)
    query = query.order_by(FamilyBudget.period.desc())

    result = await db.execute(query)
    budgets = result.scalars().all()

    responses = []
    for budget in budgets:
        # Get member budgets
        result = await db.execute(
            select(MemberBudget, User)
            .join(User, MemberBudget.user_id == User.id)
            .where(MemberBudget.family_budget_id == budget.id)
        )
        member_budget_rows = result.all()

        member_responses = []
        total_spent = 0.0
        for mb, user in member_budget_rows:
            # Calculate actual spent
            spent, category_spent = await calculate_member_spent(
                db, book_id, mb.user_id, budget.period
            )
            # Update member budget spent
            mb.spent = spent
            mb.category_spent = category_spent
            await db.commit()

            remaining = float(mb.allocated) - spent
            percentage = (spent / float(mb.allocated) * 100) if mb.allocated > 0 else 0
            total_spent += spent

            member_responses.append(MemberBudgetResponse(
                id=mb.id,
                user_id=mb.user_id,
                user_name=user.nickname,
                allocated=float(mb.allocated),
                spent=spent,
                remaining=remaining,
                percentage=round(percentage, 2),
                category_spent=category_spent,
            ))

        total_remaining = float(budget.total_budget) - total_spent
        usage_percentage = (total_spent / float(budget.total_budget) * 100) if budget.total_budget > 0 else 0

        responses.append(FamilyBudgetResponse(
            id=budget.id,
            book_id=budget.book_id,
            period=budget.period,
            strategy=budget.strategy,
            total_budget=float(budget.total_budget),
            total_spent=total_spent,
            total_remaining=total_remaining,
            usage_percentage=round(usage_percentage, 2),
            member_budgets=member_responses,
            rules=budget.rules,
            created_at=budget.created_at,
            updated_at=budget.updated_at,
        ))

    return responses


@router.post("", response_model=FamilyBudgetResponse, status_code=status.HTTP_201_CREATED)
async def create_family_budget(
    book_id: UUID,
    budget_data: FamilyBudgetCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new family budget."""
    book, _ = await verify_book_member_access(db, book_id, current_user.id, require_admin=True)

    # Check if budget already exists for this period
    result = await db.execute(
        select(FamilyBudget).where(
            FamilyBudget.book_id == book_id,
            FamilyBudget.period == budget_data.period,
        )
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Budget already exists for this period",
        )

    # Create family budget
    family_budget = FamilyBudget(
        book_id=book_id,
        period=budget_data.period,
        strategy=budget_data.strategy,
        total_budget=budget_data.total_budget,
        rules=budget_data.rules or {},
    )
    db.add(family_budget)
    await db.flush()

    # Get all members
    result = await db.execute(
        select(BookMember, User)
        .join(User, BookMember.user_id == User.id)
        .where(BookMember.book_id == book_id)
    )
    members = result.all()

    # Also include owner
    result = await db.execute(select(User).where(User.id == book.user_id))
    owner = result.scalar_one()
    all_users = [(owner, None)] + [(user, member) for member, user in members]

    # Create member budgets
    member_budgets_data = budget_data.member_allocations or []
    allocation_map = {str(mb.user_id): mb.allocated for mb in member_budgets_data}

    member_responses = []
    for user, member in all_users:
        if budget_data.strategy == 0:  # unified - share total
            allocated = budget_data.total_budget
        elif str(user.id) in allocation_map:
            allocated = allocation_map[str(user.id)]
        else:
            # Equal split
            allocated = budget_data.total_budget / len(all_users)

        member_budget = MemberBudget(
            family_budget_id=family_budget.id,
            user_id=user.id,
            allocated=allocated,
            spent=0,
            category_spent={},
        )
        db.add(member_budget)
        await db.flush()

        member_responses.append(MemberBudgetResponse(
            id=member_budget.id,
            user_id=user.id,
            user_name=user.nickname,
            allocated=allocated,
            spent=0,
            remaining=allocated,
            percentage=0,
            category_spent={},
        ))

    await db.commit()
    await db.refresh(family_budget)

    return FamilyBudgetResponse(
        id=family_budget.id,
        book_id=family_budget.book_id,
        period=family_budget.period,
        strategy=family_budget.strategy,
        total_budget=float(family_budget.total_budget),
        total_spent=0,
        total_remaining=float(family_budget.total_budget),
        usage_percentage=0,
        member_budgets=member_responses,
        rules=family_budget.rules,
        created_at=family_budget.created_at,
        updated_at=family_budget.updated_at,
    )


@router.get("/{budget_id}", response_model=FamilyBudgetResponse)
async def get_family_budget(
    book_id: UUID,
    budget_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific family budget."""
    await verify_book_member_access(db, book_id, current_user.id)

    result = await db.execute(
        select(FamilyBudget).where(
            FamilyBudget.id == budget_id,
            FamilyBudget.book_id == book_id,
        )
    )
    budget = result.scalar_one_or_none()

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    # Get member budgets with calculated spent
    result = await db.execute(
        select(MemberBudget, User)
        .join(User, MemberBudget.user_id == User.id)
        .where(MemberBudget.family_budget_id == budget.id)
    )
    member_budget_rows = result.all()

    member_responses = []
    total_spent = 0.0
    for mb, user in member_budget_rows:
        spent, category_spent = await calculate_member_spent(
            db, book_id, mb.user_id, budget.period
        )
        remaining = float(mb.allocated) - spent
        percentage = (spent / float(mb.allocated) * 100) if mb.allocated > 0 else 0
        total_spent += spent

        member_responses.append(MemberBudgetResponse(
            id=mb.id,
            user_id=mb.user_id,
            user_name=user.nickname,
            allocated=float(mb.allocated),
            spent=spent,
            remaining=remaining,
            percentage=round(percentage, 2),
            category_spent=category_spent,
        ))

    total_remaining = float(budget.total_budget) - total_spent
    usage_percentage = (total_spent / float(budget.total_budget) * 100) if budget.total_budget > 0 else 0

    return FamilyBudgetResponse(
        id=budget.id,
        book_id=budget.book_id,
        period=budget.period,
        strategy=budget.strategy,
        total_budget=float(budget.total_budget),
        total_spent=total_spent,
        total_remaining=total_remaining,
        usage_percentage=round(usage_percentage, 2),
        member_budgets=member_responses,
        rules=budget.rules,
        created_at=budget.created_at,
        updated_at=budget.updated_at,
    )


@router.put("/{budget_id}", response_model=FamilyBudgetResponse)
async def update_family_budget(
    book_id: UUID,
    budget_id: UUID,
    budget_data: FamilyBudgetUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a family budget."""
    await verify_book_member_access(db, book_id, current_user.id, require_admin=True)

    result = await db.execute(
        select(FamilyBudget).where(
            FamilyBudget.id == budget_id,
            FamilyBudget.book_id == book_id,
        )
    )
    budget = result.scalar_one_or_none()

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    # Update fields
    if budget_data.total_budget is not None:
        budget.total_budget = budget_data.total_budget
    if budget_data.strategy is not None:
        budget.strategy = budget_data.strategy
    if budget_data.rules is not None:
        budget.rules = budget_data.rules

    # Update member allocations if provided
    if budget_data.member_allocations:
        for allocation in budget_data.member_allocations:
            result = await db.execute(
                select(MemberBudget).where(
                    MemberBudget.family_budget_id == budget.id,
                    MemberBudget.user_id == allocation.user_id,
                )
            )
            mb = result.scalar_one_or_none()
            if mb:
                mb.allocated = allocation.allocated

    await db.commit()

    # Return updated budget
    return await get_family_budget(book_id, budget_id, current_user, db)


@router.delete("/{budget_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_family_budget(
    book_id: UUID,
    budget_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a family budget."""
    await verify_book_member_access(db, book_id, current_user.id, require_admin=True)

    result = await db.execute(
        select(FamilyBudget).where(
            FamilyBudget.id == budget_id,
            FamilyBudget.book_id == book_id,
        )
    )
    budget = result.scalar_one_or_none()

    if not budget:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Budget not found",
        )

    await db.delete(budget)
    await db.commit()
