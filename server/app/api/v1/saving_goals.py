"""Family saving goal endpoints."""
from datetime import datetime
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.timezone import beijing_now_naive
from app.models.user import User
from app.models.book import Book, BookMember, FamilySavingGoal, GoalContribution
from app.schemas.family import (
    FamilySavingGoalCreate, FamilySavingGoalUpdate, FamilySavingGoalResponse,
    GoalContributionCreate, GoalContributionResponse
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/books/{book_id}/saving-goals", tags=["Family Saving Goals"])


async def verify_book_member_access(
    db: AsyncSession,
    book_id: UUID,
    user_id: UUID,
) -> Book:
    """Verify user has access to the book."""
    # Check if user is owner
    result = await db.execute(
        select(Book).where(Book.id == book_id, Book.user_id == user_id)
    )
    book = result.scalar_one_or_none()
    if book:
        return book

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

    _, book = row
    return book


async def get_goal_response(
    db: AsyncSession,
    goal: FamilySavingGoal,
    include_contributions: bool = True,
) -> FamilySavingGoalResponse:
    """Build goal response with computed fields."""
    # Get creator name
    result = await db.execute(select(User).where(User.id == goal.created_by))
    creator = result.scalar_one_or_none()

    progress = (float(goal.current_amount) / float(goal.target_amount) * 100) if goal.target_amount > 0 else 0

    contributions = None
    if include_contributions:
        result = await db.execute(
            select(GoalContribution, User)
            .join(User, GoalContribution.user_id == User.id)
            .where(GoalContribution.goal_id == goal.id)
            .order_by(GoalContribution.created_at.desc())
            .limit(10)
        )
        contribution_rows = result.all()
        contributions = [
            GoalContributionResponse(
                id=c.id,
                goal_id=c.goal_id,
                user_id=c.user_id,
                user_name=user.nickname,
                amount=float(c.amount),
                note=c.note,
                created_at=c.created_at,
            )
            for c, user in contribution_rows
        ]

    return FamilySavingGoalResponse(
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
        creator_name=creator.nickname if creator else None,
        created_at=goal.created_at,
        completed_at=goal.completed_at,
        recent_contributions=contributions,
    )


@router.get("", response_model=List[FamilySavingGoalResponse])
async def get_saving_goals(
    book_id: UUID,
    status_filter: Optional[int] = Query(None, ge=0, le=2, alias="status"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all saving goals for a book."""
    await verify_book_member_access(db, book_id, current_user.id)

    query = select(FamilySavingGoal).where(FamilySavingGoal.book_id == book_id)
    if status_filter is not None:
        query = query.where(FamilySavingGoal.status == status_filter)
    query = query.order_by(FamilySavingGoal.created_at.desc())

    result = await db.execute(query)
    goals = result.scalars().all()

    return [await get_goal_response(db, goal) for goal in goals]


@router.post("", response_model=FamilySavingGoalResponse, status_code=status.HTTP_201_CREATED)
async def create_saving_goal(
    book_id: UUID,
    goal_data: FamilySavingGoalCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new saving goal."""
    await verify_book_member_access(db, book_id, current_user.id)

    goal = FamilySavingGoal(
        book_id=book_id,
        name=goal_data.name,
        description=goal_data.description,
        icon=goal_data.icon,
        target_amount=goal_data.target_amount,
        current_amount=0,
        deadline=goal_data.deadline,
        status=0,  # active
        created_by=current_user.id,
    )
    db.add(goal)
    await db.commit()
    await db.refresh(goal)

    return await get_goal_response(db, goal)


@router.get("/{goal_id}", response_model=FamilySavingGoalResponse)
async def get_saving_goal(
    book_id: UUID,
    goal_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific saving goal."""
    await verify_book_member_access(db, book_id, current_user.id)

    result = await db.execute(
        select(FamilySavingGoal).where(
            FamilySavingGoal.id == goal_id,
            FamilySavingGoal.book_id == book_id,
        )
    )
    goal = result.scalar_one_or_none()

    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Saving goal not found",
        )

    return await get_goal_response(db, goal)


@router.put("/{goal_id}", response_model=FamilySavingGoalResponse)
async def update_saving_goal(
    book_id: UUID,
    goal_id: UUID,
    goal_data: FamilySavingGoalUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a saving goal."""
    await verify_book_member_access(db, book_id, current_user.id)

    result = await db.execute(
        select(FamilySavingGoal).where(
            FamilySavingGoal.id == goal_id,
            FamilySavingGoal.book_id == book_id,
        )
    )
    goal = result.scalar_one_or_none()

    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Saving goal not found",
        )

    # Update fields
    if goal_data.name is not None:
        goal.name = goal_data.name
    if goal_data.description is not None:
        goal.description = goal_data.description
    if goal_data.icon is not None:
        goal.icon = goal_data.icon
    if goal_data.target_amount is not None:
        goal.target_amount = goal_data.target_amount
    if goal_data.deadline is not None:
        goal.deadline = goal_data.deadline
    if goal_data.status is not None:
        old_status = goal.status
        goal.status = goal_data.status
        if goal_data.status == 1 and old_status != 1:  # completed
            goal.completed_at = beijing_now_naive()

    await db.commit()
    await db.refresh(goal)

    return await get_goal_response(db, goal)


@router.delete("/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_saving_goal(
    book_id: UUID,
    goal_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a saving goal."""
    await verify_book_member_access(db, book_id, current_user.id)

    result = await db.execute(
        select(FamilySavingGoal).where(
            FamilySavingGoal.id == goal_id,
            FamilySavingGoal.book_id == book_id,
        )
    )
    goal = result.scalar_one_or_none()

    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Saving goal not found",
        )

    # Only creator can delete
    if goal.created_by != current_user.id:
        # Check if owner
        result = await db.execute(
            select(Book).where(Book.id == book_id, Book.user_id == current_user.id)
        )
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only goal creator or book owner can delete",
            )

    await db.delete(goal)
    await db.commit()


# =============================================================================
# Goal Contributions
# =============================================================================

@router.post("/{goal_id}/contributions", response_model=GoalContributionResponse, status_code=status.HTTP_201_CREATED)
async def add_contribution(
    book_id: UUID,
    goal_id: UUID,
    contribution_data: GoalContributionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a contribution to a saving goal."""
    await verify_book_member_access(db, book_id, current_user.id)

    result = await db.execute(
        select(FamilySavingGoal).where(
            FamilySavingGoal.id == goal_id,
            FamilySavingGoal.book_id == book_id,
        )
    )
    goal = result.scalar_one_or_none()

    if not goal:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Saving goal not found",
        )

    if goal.status != 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot add contribution to non-active goal",
        )

    # Create contribution
    contribution = GoalContribution(
        goal_id=goal_id,
        user_id=current_user.id,
        amount=contribution_data.amount,
        note=contribution_data.note,
    )
    db.add(contribution)

    # Update goal current amount
    goal.current_amount = float(goal.current_amount) + contribution_data.amount

    # Check if goal is reached
    if float(goal.current_amount) >= float(goal.target_amount):
        goal.status = 1  # completed
        goal.completed_at = beijing_now_naive()

    await db.commit()
    await db.refresh(contribution)

    return GoalContributionResponse(
        id=contribution.id,
        goal_id=contribution.goal_id,
        user_id=contribution.user_id,
        user_name=current_user.nickname,
        amount=float(contribution.amount),
        note=contribution.note,
        created_at=contribution.created_at,
    )


@router.get("/{goal_id}/contributions", response_model=List[GoalContributionResponse])
async def get_contributions(
    book_id: UUID,
    goal_id: UUID,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get contributions for a saving goal."""
    await verify_book_member_access(db, book_id, current_user.id)

    result = await db.execute(
        select(FamilySavingGoal).where(
            FamilySavingGoal.id == goal_id,
            FamilySavingGoal.book_id == book_id,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Saving goal not found",
        )

    result = await db.execute(
        select(GoalContribution, User)
        .join(User, GoalContribution.user_id == User.id)
        .where(GoalContribution.goal_id == goal_id)
        .order_by(GoalContribution.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    contribution_rows = result.all()

    return [
        GoalContributionResponse(
            id=c.id,
            goal_id=c.goal_id,
            user_id=c.user_id,
            user_name=user.nickname,
            amount=float(c.amount),
            note=c.note,
            created_at=c.created_at,
        )
        for c, user in contribution_rows
    ]


@router.delete("/{goal_id}/contributions/{contribution_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contribution(
    book_id: UUID,
    goal_id: UUID,
    contribution_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a contribution (only by contributor)."""
    await verify_book_member_access(db, book_id, current_user.id)

    result = await db.execute(
        select(GoalContribution, FamilySavingGoal)
        .join(FamilySavingGoal, GoalContribution.goal_id == FamilySavingGoal.id)
        .where(
            GoalContribution.id == contribution_id,
            GoalContribution.goal_id == goal_id,
            FamilySavingGoal.book_id == book_id,
        )
    )
    row = result.first()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Contribution not found",
        )

    contribution, goal = row

    # Only contributor can delete
    if contribution.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only contributor can delete this contribution",
        )

    # Update goal current amount
    goal.current_amount = float(goal.current_amount) - float(contribution.amount)
    if goal.current_amount < 0:
        goal.current_amount = 0

    # Reset completed status if necessary
    if goal.status == 1 and float(goal.current_amount) < float(goal.target_amount):
        goal.status = 0
        goal.completed_at = None

    await db.delete(contribution)
    await db.commit()
