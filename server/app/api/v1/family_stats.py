"""Family statistics and dashboard endpoints."""
from datetime import datetime
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book, BookMember, FamilyBudget, FamilySavingGoal, TransactionSplit, SplitParticipant
from app.models.transaction import Transaction
from app.models.category import Category
from app.schemas.family import (
    FamilyDashboardResponse, FamilySummary, MemberContribution, CategoryBreakdown,
    PendingSplit, FamilySavingGoalResponse, FamilyBudgetResponse,
    FamilyLeaderboardResponse, FamilyLeaderboardEntry,
    GoalContributionResponse
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/books/{book_id}/family-stats", tags=["Family Statistics"])


async def verify_book_member_access(
    db: AsyncSession,
    book_id: UUID,
    user_id: UUID,
) -> Book:
    """Verify user has access to the book."""
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == user_id)
    )
    book = result.scalar_one_or_none()
    if book:
        return book

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

    _, book = row
    return book


async def get_all_members(db: AsyncSession, book: Book) -> List[tuple[UUID, str, Optional[str]]]:
    """Get all members including owner."""
    members = []

    # Get owner
    result = await db.execute(select(User).where(User.id == book.user_id))
    owner = result.scalar_one()
    members.append((owner.id, owner.nickname or "Owner", owner.avatar))

    # Get other members
    result = await db.execute(
        select(BookMember, User)
        .join(User, BookMember.user_id == User.id)
        .where(BookMember.book_id == book.id)
    )
    for member, user in result.all():
        members.append((user.id, member.nickname or user.nickname or "Member", user.avatar))

    return members


@router.get("/dashboard", response_model=FamilyDashboardResponse)
async def get_family_dashboard(
    book_id: UUID,
    period: str = Query(..., pattern=r"^\d{4}-\d{2}$", description="Period in YYYY-MM format"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get family dashboard with comprehensive statistics."""
    book = await verify_book_member_access(db, book_id, current_user.id)

    year, month = period.split('-')
    members = await get_all_members(db, book)

    # Calculate summary
    result = await db.execute(
        select(
            func.coalesce(func.sum(
                func.case((Transaction.transaction_type == 2, Transaction.amount), else_=0)
            ), 0).label('total_income'),
            func.coalesce(func.sum(
                func.case((Transaction.transaction_type == 1, Transaction.amount), else_=0)
            ), 0).label('total_expense'),
            func.count(Transaction.id).label('transaction_count'),
        )
        .where(
            Transaction.book_id == book_id,
            func.extract('year', Transaction.transaction_date) == int(year),
            func.extract('month', Transaction.transaction_date) == int(month),
        )
    )
    row = result.first()
    total_income = float(row.total_income)
    total_expense = float(row.total_expense)
    net_savings = total_income - total_expense
    savings_rate = (net_savings / total_income * 100) if total_income > 0 else 0
    avg_daily_expense = total_expense / 30

    summary = FamilySummary(
        total_income=total_income,
        total_expense=total_expense,
        net_savings=net_savings,
        savings_rate=round(savings_rate, 2),
        transaction_count=row.transaction_count,
        avg_daily_expense=round(avg_daily_expense, 2),
    )

    # Calculate member contributions
    member_contributions = []
    for member_id, member_name, avatar_url in members:
        result = await db.execute(
            select(
                func.coalesce(func.sum(
                    func.case((Transaction.transaction_type == 2, Transaction.amount), else_=0)
                ), 0).label('income'),
                func.coalesce(func.sum(
                    func.case((Transaction.transaction_type == 1, Transaction.amount), else_=0)
                ), 0).label('expense'),
                func.count(Transaction.id).label('count'),
            )
            .where(
                Transaction.book_id == book_id,
                Transaction.user_id == member_id,
                func.extract('year', Transaction.transaction_date) == int(year),
                func.extract('month', Transaction.transaction_date) == int(month),
            )
        )
        r = result.first()

        # Get top categories
        result = await db.execute(
            select(Category.name)
            .join(Transaction, Transaction.category_id == Category.id)
            .where(
                Transaction.book_id == book_id,
                Transaction.user_id == member_id,
                Transaction.transaction_type == 1,
                func.extract('year', Transaction.transaction_date) == int(year),
                func.extract('month', Transaction.transaction_date) == int(month),
            )
            .group_by(Category.id, Category.name)
            .order_by(func.sum(Transaction.amount).desc())
            .limit(3)
        )
        top_categories = [cat for (cat,) in result.all()]

        contribution_pct = (float(r.expense) / total_expense * 100) if total_expense > 0 else 0

        member_contributions.append(MemberContribution(
            member_id=member_id,
            member_name=member_name,
            avatar_url=avatar_url,
            income=float(r.income),
            expense=float(r.expense),
            transaction_count=r.count,
            contribution_percentage=round(contribution_pct, 2),
            top_categories=top_categories,
        ))

    # Calculate category breakdown
    result = await db.execute(
        select(
            Category.id,
            Category.name,
            Category.icon,
            func.sum(Transaction.amount).label('amount'),
        )
        .join(Transaction, Transaction.category_id == Category.id)
        .where(
            Transaction.book_id == book_id,
            Transaction.transaction_type == 1,
            func.extract('year', Transaction.transaction_date) == int(year),
            func.extract('month', Transaction.transaction_date) == int(month),
        )
        .group_by(Category.id, Category.name, Category.icon)
        .order_by(func.sum(Transaction.amount).desc())
        .limit(10)
    )

    category_breakdown = []
    for cat_id, cat_name, cat_icon, amount in result.all():
        pct = (float(amount) / total_expense * 100) if total_expense > 0 else 0
        category_breakdown.append(CategoryBreakdown(
            category_id=cat_id,
            category_name=cat_name,
            category_icon=cat_icon,
            amount=float(amount),
            percentage=round(pct, 2),
        ))

    # Get budget status
    result = await db.execute(
        select(FamilyBudget).where(
            FamilyBudget.book_id == book_id,
            FamilyBudget.period == period,
        )
    )
    family_budget = result.scalar_one_or_none()
    budget_status = None
    if family_budget:
        # Import the function to avoid circular imports
        from app.api.v1.family_budget import get_family_budget
        budget_status = await get_family_budget(book_id, family_budget.id, current_user, db)

    # Get pending splits for current user
    result = await db.execute(
        select(TransactionSplit, Transaction)
        .join(Transaction, TransactionSplit.transaction_id == Transaction.id)
        .join(SplitParticipant, TransactionSplit.id == SplitParticipant.split_id)
        .where(
            Transaction.book_id == book_id,
            SplitParticipant.user_id == current_user.id,
            SplitParticipant.is_payer == False,
            SplitParticipant.is_settled == False,
        )
        .limit(10)
    )

    pending_splits = []
    for split, transaction in result.all():
        # Get payer name
        result2 = await db.execute(
            select(SplitParticipant, User)
            .join(User, SplitParticipant.user_id == User.id)
            .where(
                SplitParticipant.split_id == split.id,
                SplitParticipant.is_payer == True,
            )
        )
        payer_row = result2.first()
        payer_name = payer_row[1].nickname if payer_row else "Unknown"

        # Get current user's amount
        result2 = await db.execute(
            select(SplitParticipant).where(
                SplitParticipant.split_id == split.id,
                SplitParticipant.user_id == current_user.id,
            )
        )
        participant = result2.scalar_one_or_none()

        pending_splits.append(PendingSplit(
            split_id=split.id,
            transaction_id=transaction.id,
            description=transaction.note or "Transaction",
            total_amount=float(transaction.amount),
            your_amount=float(participant.amount) if participant else 0,
            payer_name=payer_name,
            created_at=split.created_at,
        ))

    # Get active saving goals
    result = await db.execute(
        select(FamilySavingGoal, User)
        .join(User, FamilySavingGoal.created_by == User.id)
        .where(
            FamilySavingGoal.book_id == book_id,
            FamilySavingGoal.status == 0,  # active
        )
        .order_by(FamilySavingGoal.created_at.desc())
        .limit(5)
    )

    saving_goals = []
    for goal, creator in result.all():
        progress = (float(goal.current_amount) / float(goal.target_amount) * 100) if goal.target_amount > 0 else 0
        saving_goals.append(FamilySavingGoalResponse(
            id=goal.id,
            book_id=goal.book_id,
            name=goal.name,
            description=goal.description,
            icon=goal.icon,
            target_amount=float(goal.target_amount),
            current_amount=float(goal.current_amount),
            progress_percentage=round(progress, 2),
            deadline=goal.deadline,
            status=goal.status,
            created_by=goal.created_by,
            creator_name=creator.nickname,
            created_at=goal.created_at,
            completed_at=goal.completed_at,
            recent_contributions=None,
        ))

    return FamilyDashboardResponse(
        book_id=book_id,
        book_name=book.name,
        period=period,
        summary=summary,
        member_contributions=member_contributions,
        category_breakdown=category_breakdown,
        budget_status=budget_status,
        pending_splits=pending_splits,
        saving_goals=saving_goals,
    )


@router.get("/leaderboard", response_model=FamilyLeaderboardResponse)
async def get_family_leaderboard(
    book_id: UUID,
    period: str = Query(..., pattern=r"^\d{4}-\d{2}$"),
    leaderboard_type: str = Query("expense_control", enum=["savings", "expense_control", "contribution"]),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get family leaderboard for gamification."""
    book = await verify_book_member_access(db, book_id, current_user.id)

    year, month = period.split('-')
    members = await get_all_members(db, book)

    entries = []
    metric_name = ""

    for member_id, member_name, avatar_url in members:
        if leaderboard_type == "savings":
            # Highest savings rate
            result = await db.execute(
                select(
                    func.coalesce(func.sum(
                        func.case((Transaction.transaction_type == 2, Transaction.amount), else_=0)
                    ), 0).label('income'),
                    func.coalesce(func.sum(
                        func.case((Transaction.transaction_type == 1, Transaction.amount), else_=0)
                    ), 0).label('expense'),
                )
                .where(
                    Transaction.book_id == book_id,
                    Transaction.user_id == member_id,
                    func.extract('year', Transaction.transaction_date) == int(year),
                    func.extract('month', Transaction.transaction_date) == int(month),
                )
            )
            r = result.first()
            income = float(r.income)
            expense = float(r.expense)
            savings_rate = ((income - expense) / income * 100) if income > 0 else 0
            entries.append((member_id, member_name, avatar_url, savings_rate))
            metric_name = "储蓄率 %"

        elif leaderboard_type == "expense_control":
            # Best budget adherence (lowest overspend)
            result = await db.execute(
                select(func.coalesce(func.sum(Transaction.amount), 0))
                .where(
                    Transaction.book_id == book_id,
                    Transaction.user_id == member_id,
                    Transaction.transaction_type == 1,
                    func.extract('year', Transaction.transaction_date) == int(year),
                    func.extract('month', Transaction.transaction_date) == int(month),
                )
            )
            total_expense = float(result.scalar() or 0)
            # Lower expense = better score (inverse)
            score = 10000 - total_expense  # Simple scoring
            entries.append((member_id, member_name, avatar_url, score))
            metric_name = "节约指数"

        elif leaderboard_type == "contribution":
            # Most transactions recorded
            result = await db.execute(
                select(func.count(Transaction.id))
                .where(
                    Transaction.book_id == book_id,
                    Transaction.user_id == member_id,
                    func.extract('year', Transaction.transaction_date) == int(year),
                    func.extract('month', Transaction.transaction_date) == int(month),
                )
            )
            count = result.scalar() or 0
            entries.append((member_id, member_name, avatar_url, count))
            metric_name = "记账次数"

    # Sort by metric value (descending)
    entries.sort(key=lambda x: x[3], reverse=True)

    leaderboard_entries = [
        FamilyLeaderboardEntry(
            rank=i + 1,
            member_id=member_id,
            member_name=member_name,
            avatar_url=avatar_url,
            metric_value=round(metric_value, 2),
            metric_name=metric_name,
        )
        for i, (member_id, member_name, avatar_url, metric_value) in enumerate(entries)
    ]

    return FamilyLeaderboardResponse(
        book_id=book_id,
        period=period,
        leaderboard_type=leaderboard_type,
        entries=leaderboard_entries,
    )


@router.get("/member-comparison")
async def get_member_comparison(
    book_id: UUID,
    period: str = Query(..., pattern=r"^\d{4}-\d{2}$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get detailed member spending comparison."""
    book = await verify_book_member_access(db, book_id, current_user.id)

    year, month = period.split('-')
    members = await get_all_members(db, book)

    comparison = []
    for member_id, member_name, avatar_url in members:
        # Get category breakdown for this member
        result = await db.execute(
            select(
                Category.name,
                func.sum(Transaction.amount).label('amount'),
            )
            .join(Transaction, Transaction.category_id == Category.id)
            .where(
                Transaction.book_id == book_id,
                Transaction.user_id == member_id,
                Transaction.transaction_type == 1,
                func.extract('year', Transaction.transaction_date) == int(year),
                func.extract('month', Transaction.transaction_date) == int(month),
            )
            .group_by(Category.name)
            .order_by(func.sum(Transaction.amount).desc())
        )

        categories = {row.name: float(row.amount) for row in result.all()}

        comparison.append({
            "member_id": str(member_id),
            "member_name": member_name,
            "avatar_url": avatar_url,
            "categories": categories,
            "total": sum(categories.values()),
        })

    return {"period": period, "comparison": comparison}
