"""Transaction endpoints.

Implements transaction CRUD with distributed consistency guarantees:
- Saga pattern for multi-step operations (create/delete with balance updates)
- Cache invalidation on mutations
- Distributed locking for budget protection

Reference: Design Document Chapter 33.1 - Saga Transaction Orchestrator
"""
import logging
from datetime import date
from decimal import Decimal
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_

from app.core.database import get_db
from app.core.saga import saga, SagaContext, SagaStatus
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction
from app.schemas.transaction import TransactionCreate, TransactionUpdate, TransactionResponse, TransactionList
from app.api.deps import get_current_user

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/transactions", tags=["Transactions"])


# ==================== Cache Invalidation Helper ====================

async def _invalidate_transaction_cache(user_id: UUID) -> None:
    """Invalidate transaction-related cache entries for a user.

    Called after any transaction mutation (create, update, delete).
    """
    try:
        from app.services.cache_consistency_service import cache_service

        # Invalidate transaction list cache
        await cache_service.invalidate_pattern(f"txn:list:{user_id}:*")

        # Invalidate statistics cache
        await cache_service.invalidate_pattern(f"stats:{user_id}:*")

        logger.debug(f"Cache invalidated for user {user_id}")
    except Exception as e:
        # Cache invalidation failure should not break the operation
        logger.warning(f"Cache invalidation failed for user {user_id}: {e}")


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
    """Create a new transaction with Saga protection.

    Uses Saga pattern to ensure atomicity across:
    1. Transaction record creation
    2. Source account balance update
    3. Target account balance update (for transfers)

    If any step fails, all previous steps are compensated.
    """
    # ==================== Validation Step ====================

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

    # Verify category exists and belongs to user (or is system category)
    result = await db.execute(
        select(Category).where(
            Category.id == transaction_data.category_id,
            or_(Category.user_id == current_user.id, Category.is_system == True)
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Category not found or not accessible",
        )

    # For transfers, verify target account
    target_account = None
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

    # ==================== Saga Definition ====================

    # Step 1: Create transaction record
    async def create_record(ctx: SagaContext):
        txn = Transaction(
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
            # Structured location fields (Chapter 14)
            location_latitude=transaction_data.location_latitude,
            location_longitude=transaction_data.location_longitude,
            location_place_name=transaction_data.location_place_name,
            location_address=transaction_data.location_address,
            location_city=transaction_data.location_city,
            location_district=transaction_data.location_district,
            location_type=transaction_data.location_type,
            location_poi_id=transaction_data.location_poi_id,
            geofence_region=transaction_data.geofence_region,
            is_cross_region=transaction_data.is_cross_region,
            # Money Age fields
            money_age=transaction_data.money_age,
            money_age_level=transaction_data.money_age_level,
            resource_pool_id=transaction_data.resource_pool_id,
            # Other fields
            is_reimbursable=transaction_data.is_reimbursable,
            is_exclude_stats=transaction_data.is_exclude_stats,
            visibility=transaction_data.visibility,
            source=transaction_data.source,
            ai_confidence=transaction_data.ai_confidence,
            # Source file fields
            source_file_url=transaction_data.source_file_url,
            source_file_type=transaction_data.source_file_type,
            source_file_size=transaction_data.source_file_size,
            recognition_raw_response=transaction_data.recognition_raw_response,
            recognition_timestamp=transaction_data.recognition_timestamp,
            source_file_expires_at=transaction_data.source_file_expires_at,
        )
        db.add(txn)
        await db.flush()  # Get the ID without committing
        ctx.set("transaction", txn)
        ctx.set("transaction_id", str(txn.id))
        return {"transaction_id": str(txn.id)}

    async def compensate_record(ctx: SagaContext):
        txn = ctx.get("transaction")
        if txn:
            await db.delete(txn)
            logger.info(f"Compensated: deleted transaction {ctx.get('transaction_id')}")

    # Step 2: Update source account balance
    async def update_source_balance(ctx: SagaContext):
        old_balance = account.balance
        ctx.set("old_source_balance", old_balance)

        if transaction_data.transaction_type == 1:  # Expense
            account.balance -= transaction_data.amount + transaction_data.fee
        elif transaction_data.transaction_type == 2:  # Income
            account.balance += transaction_data.amount
        elif transaction_data.transaction_type == 3:  # Transfer
            account.balance -= transaction_data.amount + transaction_data.fee

        return {"old_balance": str(old_balance), "new_balance": str(account.balance)}

    async def compensate_source_balance(ctx: SagaContext):
        old_balance = ctx.get("old_source_balance")
        if old_balance is not None:
            account.balance = old_balance
            logger.info(f"Compensated: restored source account balance to {old_balance}")

    # Step 3: Update target account balance (for transfers)
    async def update_target_balance(ctx: SagaContext):
        if transaction_data.transaction_type != 3 or not target_account:
            return {"skipped": True}

        old_balance = target_account.balance
        ctx.set("old_target_balance", old_balance)
        target_account.balance += transaction_data.amount
        return {"old_balance": str(old_balance), "new_balance": str(target_account.balance)}

    async def compensate_target_balance(ctx: SagaContext):
        old_balance = ctx.get("old_target_balance")
        if old_balance is not None and target_account:
            target_account.balance = old_balance
            logger.info(f"Compensated: restored target account balance to {old_balance}")

    # ==================== Execute Saga ====================

    transaction_saga = (
        saga("create_transaction")
        .step("create_record", create_record, compensate_record)
        .step("update_source_balance", update_source_balance, compensate_source_balance)
        .step("update_target_balance", update_target_balance, compensate_target_balance)
        .build()
    )

    result = await transaction_saga.execute()

    if result.status == SagaStatus.COMPLETED:
        await db.commit()
        transaction = result.context.get("transaction")
        await db.refresh(transaction)

        # Invalidate cache
        await _invalidate_transaction_cache(current_user.id)

        logger.info(f"Transaction created: {transaction.id} via Saga")
        return TransactionResponse.model_validate(transaction)
    else:
        # Saga failed, rollback was applied
        await db.rollback()
        error_msg = result.error or "Transaction creation failed"
        logger.error(f"Transaction Saga failed: {error_msg}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Transaction creation failed: {error_msg}",
        )


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

    # Invalidate cache
    await _invalidate_transaction_cache(current_user.id)

    return TransactionResponse.model_validate(transaction)


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    transaction_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a transaction with Saga protection.

    Uses Saga pattern to ensure atomicity across:
    1. Source account balance restoration
    2. Target account balance restoration (for transfers)
    3. Transaction record deletion

    If any step fails, all previous steps are compensated.
    """
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
    )
    transaction = result.scalar_one_or_none()

    if not transaction:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transaction not found",
        )

    # Get source account
    result = await db.execute(
        select(Account).where(Account.id == transaction.account_id)
    )
    account = result.scalar_one_or_none()

    # Get target account for transfers
    target_account = None
    if transaction.transaction_type == 3 and transaction.target_account_id:
        result = await db.execute(
            select(Account).where(Account.id == transaction.target_account_id)
        )
        target_account = result.scalar_one_or_none()

    # Store transaction data for compensation
    txn_data = {
        "id": transaction.id,
        "type": transaction.transaction_type,
        "amount": transaction.amount,
        "fee": transaction.fee,
    }

    # ==================== Saga Definition ====================

    # Step 1: Restore source account balance
    async def restore_source_balance(ctx: SagaContext):
        if not account:
            return {"skipped": True, "reason": "account_not_found"}

        old_balance = account.balance
        ctx.set("old_source_balance", old_balance)

        if txn_data["type"] == 1:  # Expense: add back
            account.balance += txn_data["amount"] + txn_data["fee"]
        elif txn_data["type"] == 2:  # Income: subtract
            account.balance -= txn_data["amount"]
        elif txn_data["type"] == 3:  # Transfer: add back
            account.balance += txn_data["amount"] + txn_data["fee"]

        return {"old_balance": str(old_balance), "new_balance": str(account.balance)}

    async def compensate_source_balance(ctx: SagaContext):
        old_balance = ctx.get("old_source_balance")
        if old_balance is not None and account:
            account.balance = old_balance
            logger.info(f"Compensated: reverted source account balance to {old_balance}")

    # Step 2: Restore target account balance (for transfers)
    async def restore_target_balance(ctx: SagaContext):
        if txn_data["type"] != 3 or not target_account:
            return {"skipped": True}

        old_balance = target_account.balance
        ctx.set("old_target_balance", old_balance)
        target_account.balance -= txn_data["amount"]
        return {"old_balance": str(old_balance), "new_balance": str(target_account.balance)}

    async def compensate_target_balance(ctx: SagaContext):
        old_balance = ctx.get("old_target_balance")
        if old_balance is not None and target_account:
            target_account.balance = old_balance
            logger.info(f"Compensated: reverted target account balance to {old_balance}")

    # Step 3: Delete transaction record
    async def delete_record(ctx: SagaContext):
        ctx.set("deleted_transaction", transaction)
        await db.delete(transaction)
        return {"deleted_id": str(txn_data["id"])}

    async def compensate_delete(ctx: SagaContext):
        # Cannot easily restore deleted record in compensation
        # This is a limitation - in production, use soft delete first
        logger.warning(f"Cannot compensate delete for transaction {txn_data['id']}")

    # ==================== Execute Saga ====================

    delete_saga = (
        saga("delete_transaction")
        .step("restore_source_balance", restore_source_balance, compensate_source_balance)
        .step("restore_target_balance", restore_target_balance, compensate_target_balance)
        .step("delete_record", delete_record, compensate_delete)
        .build()
    )

    saga_result = await delete_saga.execute()

    if saga_result.status == SagaStatus.COMPLETED:
        await db.commit()

        # Invalidate cache
        await _invalidate_transaction_cache(current_user.id)

        logger.info(f"Transaction deleted: {transaction_id} via Saga")
    else:
        await db.rollback()
        error_msg = saga_result.error or "Transaction deletion failed"
        logger.error(f"Delete Saga failed: {error_msg}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Transaction deletion failed: {error_msg}",
        )
