"""Transaction endpoints."""
from datetime import date
from decimal import Decimal
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction
from app.schemas.transaction import TransactionCreate, TransactionUpdate, TransactionResponse, TransactionList
from app.api.deps import get_current_user


router = APIRouter(prefix="/transactions", tags=["Transactions"])


@router.get("", response_model=TransactionList)
async def get_transactions(
    book_id: Optional[UUID] = None,
    category_id: Optional[UUID] = None,
    transaction_type: Optional[int] = Query(None, ge=1, le=3),
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get transactions with filters and pagination."""
    query = select(Transaction).where(Transaction.user_id == current_user.id)

    if book_id:
        query = query.where(Transaction.book_id == book_id)
    if category_id:
        query = query.where(Transaction.category_id == category_id)
    if transaction_type:
        query = query.where(Transaction.transaction_type == transaction_type)
    if start_date:
        query = query.where(Transaction.transaction_date >= start_date)
    if end_date:
        query = query.where(Transaction.transaction_date <= end_date)

    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()

    # Get paginated results
    query = query.order_by(Transaction.transaction_date.desc(), Transaction.created_at.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)

    result = await db.execute(query)
    transactions = result.scalars().all()

    return TransactionList(
        items=[TransactionResponse.model_validate(t) for t in transactions],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post("", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    transaction_data: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new transaction."""
    # Verify book exists and belongs to user
    result = await db.execute(
        select(Book).where(Book.id == transaction_data.book_id, Book.user_id == current_user.id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Book not found",
        )

    # Verify account exists and belongs to user
    result = await db.execute(
        select(Account).where(Account.id == transaction_data.account_id, Account.user_id == current_user.id)
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Account not found",
        )

    # Verify category exists
    result = await db.execute(
        select(Category).where(Category.id == transaction_data.category_id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Category not found",
        )

    # For transfers, verify target account
    if transaction_data.transaction_type == 3:
        if not transaction_data.target_account_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target account is required for transfers",
            )
        result = await db.execute(
            select(Account).where(Account.id == transaction_data.target_account_id, Account.user_id == current_user.id)
        )
        target_account = result.scalar_one_or_none()
        if not target_account:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target account not found",
            )

    # Create transaction
    transaction = Transaction(
        user_id=current_user.id,
        book_id=transaction_data.book_id,
        account_id=transaction_data.account_id,
        target_account_id=transaction_data.target_account_id,
        category_id=transaction_data.category_id,
        transaction_type=transaction_data.transaction_type,
        amount=transaction_data.amount,
        fee=transaction_data.fee,
        transaction_date=transaction_data.transaction_date,
        transaction_time=transaction_data.transaction_time,
        note=transaction_data.note,
        tags=transaction_data.tags,
        images=transaction_data.images,
        location=transaction_data.location,
        is_reimbursable=transaction_data.is_reimbursable,
        is_exclude_stats=transaction_data.is_exclude_stats,
        source=transaction_data.source,
        ai_confidence=transaction_data.ai_confidence,
    )
    db.add(transaction)

    # Update account balance
    if transaction_data.transaction_type == 1:  # Expense
        account.balance -= transaction_data.amount + transaction_data.fee
    elif transaction_data.transaction_type == 2:  # Income
        account.balance += transaction_data.amount
    elif transaction_data.transaction_type == 3:  # Transfer
        account.balance -= transaction_data.amount + transaction_data.fee
        target_account.balance += transaction_data.amount

    await db.commit()
    await db.refresh(transaction)

    return TransactionResponse.model_validate(transaction)


@router.get("/{transaction_id}", response_model=TransactionResponse)
async def get_transaction(
    transaction_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific transaction."""
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
    )
    transaction = result.scalar_one_or_none()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    return TransactionResponse.model_validate(transaction)


@router.put("/{transaction_id}", response_model=TransactionResponse)
async def update_transaction(
    transaction_id: UUID,
    transaction_data: TransactionUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update a transaction."""
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
    )
    transaction = result.scalar_one_or_none()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    update_data = transaction_data.model_dump(exclude_unset=True)

    # Check if we need to recalculate balances
    balance_affecting_fields = {'amount', 'fee', 'transaction_type', 'account_id', 'target_account_id'}
    needs_balance_update = bool(balance_affecting_fields & set(update_data.keys()))

    if needs_balance_update:
        # Store old values
        old_amount = transaction.amount
        old_fee = transaction.fee
        old_type = transaction.transaction_type
        old_account_id = transaction.account_id
        old_target_account_id = transaction.target_account_id

        # Get new values (use old if not provided)
        new_amount = update_data.get('amount', old_amount)
        new_fee = update_data.get('fee', old_fee)
        new_type = update_data.get('transaction_type', old_type)
        new_account_id = update_data.get('account_id', old_account_id)
        new_target_account_id = update_data.get('target_account_id', old_target_account_id)

        # Validate transfer type requires target_account_id
        if new_type == 3 and not new_target_account_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Target account is required for transfers",
            )

        # Validate new account exists
        if new_account_id != old_account_id:
            result = await db.execute(
                select(Account).where(Account.id == new_account_id, Account.user_id == current_user.id)
            )
            if not result.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Account not found",
                )

        # Validate new target account exists for transfers
        if new_type == 3 and new_target_account_id and new_target_account_id != old_target_account_id:
            result = await db.execute(
                select(Account).where(Account.id == new_target_account_id, Account.user_id == current_user.id)
            )
            if not result.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Target account not found",
                )

        # Step 1: Revert old balance changes on old accounts
        result = await db.execute(select(Account).where(Account.id == old_account_id))
        old_account = result.scalar_one_or_none()
        if old_account:
            if old_type == 1:  # Was expense
                old_account.balance += old_amount + old_fee
            elif old_type == 2:  # Was income
                old_account.balance -= old_amount
            elif old_type == 3:  # Was transfer
                old_account.balance += old_amount + old_fee

        if old_type == 3 and old_target_account_id:
            result = await db.execute(select(Account).where(Account.id == old_target_account_id))
            old_target_account = result.scalar_one_or_none()
            if old_target_account:
                old_target_account.balance -= old_amount

        # Step 2: Apply new balance changes on new accounts
        result = await db.execute(select(Account).where(Account.id == new_account_id))
        new_account = result.scalar_one_or_none()
        if new_account:
            if new_type == 1:  # Expense
                new_account.balance -= new_amount + new_fee
            elif new_type == 2:  # Income
                new_account.balance += new_amount
            elif new_type == 3:  # Transfer
                new_account.balance -= new_amount + new_fee

        if new_type == 3 and new_target_account_id:
            result = await db.execute(select(Account).where(Account.id == new_target_account_id))
            new_target_account = result.scalar_one_or_none()
            if new_target_account:
                new_target_account.balance += new_amount

    # Update transaction fields
    for field, value in update_data.items():
        setattr(transaction, field, value)

    await db.commit()
    await db.refresh(transaction)

    return TransactionResponse.model_validate(transaction)


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    transaction_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a transaction."""
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
    )
    transaction = result.scalar_one_or_none()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    # Revert account balance
    result = await db.execute(
        select(Account).where(Account.id == transaction.account_id)
    )
    account = result.scalar_one_or_none()

    if account:
        if transaction.transaction_type == 1:  # Expense
            account.balance += transaction.amount + transaction.fee
        elif transaction.transaction_type == 2:  # Income
            account.balance -= transaction.amount
        elif transaction.transaction_type == 3:  # Transfer
            account.balance += transaction.amount + transaction.fee
            if transaction.target_account_id:
                result = await db.execute(
                    select(Account).where(Account.id == transaction.target_account_id)
                )
                target_account = result.scalar_one_or_none()
                if target_account:
                    target_account.balance -= transaction.amount

    await db.delete(transaction)
    await db.commit()
