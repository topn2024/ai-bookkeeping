"""Transaction split (AA) endpoints."""
from datetime import datetime
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.timezone import beijing_now_naive
from app.models.user import User
from app.models.book import Book, BookMember, TransactionSplit, SplitParticipant
from app.models.transaction import Transaction
from app.schemas.family import (
    TransactionSplitCreate, TransactionSplitResponse, SplitParticipantResponse,
    SplitSettleRequest
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/splits", tags=["Transaction Splits"])


async def verify_transaction_access(
    db: AsyncSession,
    transaction_id: UUID,
    user_id: UUID,
) -> Transaction:
    """Verify user has access to the transaction."""
    result = await db.execute(
        select(Transaction, Book)
        .join(Book, Transaction.book_id == Book.id)
        .where(Transaction.id == transaction_id)
    )
    row = result.first()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    transaction, book = row

    # Check if user is owner or member
    if book.user_id != user_id:
        result = await db.execute(
            select(BookMember).where(
                BookMember.book_id == book.id,
                BookMember.user_id == user_id,
            )
        )
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied",
            )

    return transaction


@router.post("", response_model=TransactionSplitResponse, status_code=status.HTTP_201_CREATED)
async def create_split(
    split_data: TransactionSplitCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new transaction split."""
    transaction = await verify_transaction_access(db, split_data.transaction_id, current_user.id)

    # Check if split already exists
    result = await db.execute(
        select(TransactionSplit).where(TransactionSplit.transaction_id == transaction.id)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Split already exists for this transaction",
        )

    # Validate participants
    total_amount = float(transaction.amount)
    participant_ids = [p.user_id for p in split_data.participants]

    if len(participant_ids) != len(set(participant_ids)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Duplicate participants not allowed",
        )

    # Create split
    split = TransactionSplit(
        transaction_id=transaction.id,
        split_type=split_data.split_type,
        status=0,  # pending
    )
    db.add(split)
    await db.flush()

    # Create participants based on split type
    participant_responses = []

    if split_data.split_type == 0:  # equal
        per_person = total_amount / len(split_data.participants)
        for p in split_data.participants:
            participant = SplitParticipant(
                split_id=split.id,
                user_id=p.user_id,
                amount=per_person,
                percentage=100 / len(split_data.participants),
                is_payer=p.is_payer,
                is_settled=p.is_payer,  # Payer is auto-settled
                settled_at=beijing_now_naive() if p.is_payer else None,
            )
            db.add(participant)
            await db.flush()

            # Get user name
            result = await db.execute(select(User).where(User.id == p.user_id))
            user = result.scalar_one_or_none()

            participant_responses.append(SplitParticipantResponse(
                id=participant.id,
                user_id=participant.user_id,
                user_name=user.nickname if user else None,
                amount=per_person,
                percentage=100 / len(split_data.participants),
                shares=None,
                is_payer=participant.is_payer,
                is_settled=participant.is_settled,
                settled_at=participant.settled_at,
            ))

    elif split_data.split_type == 1:  # percentage
        for p in split_data.participants:
            if p.percentage is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Percentage required for percentage split",
                )
            amount = total_amount * p.percentage / 100
            participant = SplitParticipant(
                split_id=split.id,
                user_id=p.user_id,
                amount=amount,
                percentage=p.percentage,
                is_payer=p.is_payer,
                is_settled=p.is_payer,
                settled_at=beijing_now_naive() if p.is_payer else None,
            )
            db.add(participant)
            await db.flush()

            result = await db.execute(select(User).where(User.id == p.user_id))
            user = result.scalar_one_or_none()

            participant_responses.append(SplitParticipantResponse(
                id=participant.id,
                user_id=participant.user_id,
                user_name=user.nickname if user else None,
                amount=amount,
                percentage=p.percentage,
                shares=None,
                is_payer=participant.is_payer,
                is_settled=participant.is_settled,
                settled_at=participant.settled_at,
            ))

    elif split_data.split_type == 2:  # exact
        for p in split_data.participants:
            if p.amount is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Amount required for exact split",
                )
            participant = SplitParticipant(
                split_id=split.id,
                user_id=p.user_id,
                amount=p.amount,
                is_payer=p.is_payer,
                is_settled=p.is_payer,
                settled_at=beijing_now_naive() if p.is_payer else None,
            )
            db.add(participant)
            await db.flush()

            result = await db.execute(select(User).where(User.id == p.user_id))
            user = result.scalar_one_or_none()

            participant_responses.append(SplitParticipantResponse(
                id=participant.id,
                user_id=participant.user_id,
                user_name=user.nickname if user else None,
                amount=p.amount,
                percentage=None,
                shares=None,
                is_payer=participant.is_payer,
                is_settled=participant.is_settled,
                settled_at=participant.settled_at,
            ))

    elif split_data.split_type == 3:  # shares
        total_shares = sum(p.shares or 1 for p in split_data.participants)
        for p in split_data.participants:
            shares = p.shares or 1
            amount = total_amount * shares / total_shares
            participant = SplitParticipant(
                split_id=split.id,
                user_id=p.user_id,
                amount=amount,
                shares=shares,
                is_payer=p.is_payer,
                is_settled=p.is_payer,
                settled_at=beijing_now_naive() if p.is_payer else None,
            )
            db.add(participant)
            await db.flush()

            result = await db.execute(select(User).where(User.id == p.user_id))
            user = result.scalar_one_or_none()

            participant_responses.append(SplitParticipantResponse(
                id=participant.id,
                user_id=participant.user_id,
                user_name=user.nickname if user else None,
                amount=amount,
                percentage=None,
                shares=shares,
                is_payer=participant.is_payer,
                is_settled=participant.is_settled,
                settled_at=participant.settled_at,
            ))

    await db.commit()
    await db.refresh(split)

    settled_amount = sum(p.amount for p in participant_responses if p.is_settled)

    return TransactionSplitResponse(
        id=split.id,
        transaction_id=split.transaction_id,
        split_type=split.split_type,
        status=split.status,
        total_amount=total_amount,
        settled_amount=settled_amount,
        participants=participant_responses,
        created_at=split.created_at,
        settled_at=split.settled_at,
    )


@router.get("/{split_id}", response_model=TransactionSplitResponse)
async def get_split(
    split_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific split."""
    result = await db.execute(
        select(TransactionSplit, Transaction)
        .join(Transaction, TransactionSplit.transaction_id == Transaction.id)
        .where(TransactionSplit.id == split_id)
    )
    row = result.first()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Split not found",
        )

    split, transaction = row
    await verify_transaction_access(db, transaction.id, current_user.id)

    # Get participants
    result = await db.execute(
        select(SplitParticipant, User)
        .join(User, SplitParticipant.user_id == User.id)
        .where(SplitParticipant.split_id == split.id)
    )
    participant_rows = result.all()

    participant_responses = []
    settled_amount = 0.0
    for p, user in participant_rows:
        if p.is_settled:
            settled_amount += float(p.amount)
        participant_responses.append(SplitParticipantResponse(
            id=p.id,
            user_id=p.user_id,
            user_name=user.nickname,
            amount=float(p.amount),
            percentage=float(p.percentage) if p.percentage else None,
            shares=p.shares,
            is_payer=p.is_payer,
            is_settled=p.is_settled,
            settled_at=p.settled_at,
        ))

    return TransactionSplitResponse(
        id=split.id,
        transaction_id=split.transaction_id,
        split_type=split.split_type,
        status=split.status,
        total_amount=float(transaction.amount),
        settled_amount=settled_amount,
        participants=participant_responses,
        created_at=split.created_at,
        settled_at=split.settled_at,
    )


@router.post("/{split_id}/settle", response_model=TransactionSplitResponse)
async def settle_participant(
    split_id: UUID,
    settle_data: SplitSettleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Mark a participant as settled."""
    result = await db.execute(
        select(TransactionSplit, Transaction)
        .join(Transaction, TransactionSplit.transaction_id == Transaction.id)
        .where(TransactionSplit.id == split_id)
    )
    row = result.first()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Split not found",
        )

    split, transaction = row
    await verify_transaction_access(db, transaction.id, current_user.id)

    # Get participant
    result = await db.execute(
        select(SplitParticipant).where(
            SplitParticipant.id == settle_data.participant_id,
            SplitParticipant.split_id == split.id,
        )
    )
    participant = result.scalar_one_or_none()

    if not participant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Participant not found",
        )

    # Only the participant or admin can settle
    if participant.user_id != current_user.id:
        # Check if current user is the payer (can settle for others)
        result = await db.execute(
            select(SplitParticipant).where(
                SplitParticipant.split_id == split.id,
                SplitParticipant.user_id == current_user.id,
                SplitParticipant.is_payer == True,
            )
        )
        if not result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only participant or payer can settle",
            )

    # Mark as settled
    participant.is_settled = True
    participant.settled_at = beijing_now_naive()

    # Check if all participants are settled
    result = await db.execute(
        select(SplitParticipant).where(
            SplitParticipant.split_id == split.id,
            SplitParticipant.is_settled == False,
        )
    )
    if not result.scalars().all():
        split.status = 3  # settled
        split.settled_at = beijing_now_naive()

    await db.commit()

    return await get_split(split_id, current_user, db)


@router.get("/pending/me", response_model=List[TransactionSplitResponse])
async def get_my_pending_splits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all pending splits where current user owes money."""
    result = await db.execute(
        select(TransactionSplit, Transaction)
        .join(Transaction, TransactionSplit.transaction_id == Transaction.id)
        .join(SplitParticipant, TransactionSplit.id == SplitParticipant.split_id)
        .where(
            SplitParticipant.user_id == current_user.id,
            SplitParticipant.is_payer == False,
            SplitParticipant.is_settled == False,
        )
    )
    rows = result.all()

    splits = []
    for split, transaction in rows:
        split_response = await get_split(split.id, current_user, db)
        splits.append(split_response)

    return splits


@router.delete("/{split_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_split(
    split_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a split (only by transaction creator)."""
    result = await db.execute(
        select(TransactionSplit, Transaction)
        .join(Transaction, TransactionSplit.transaction_id == Transaction.id)
        .where(TransactionSplit.id == split_id)
    )
    row = result.first()

    if not row:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Split not found",
        )

    split, transaction = row

    # Only transaction creator can delete split
    if transaction.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only transaction creator can delete split",
        )

    await db.delete(split)
    await db.commit()
