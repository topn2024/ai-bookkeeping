"""Account endpoints."""
import logging
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func
from sqlalchemy.exc import SQLAlchemyError

from app.core.database import get_db
from app.models.user import User
from app.models.account import Account
from app.models.transaction import Transaction
from app.schemas.account import AccountCreate, AccountUpdate, AccountResponse
from app.api.deps import get_current_user


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/accounts", tags=["Accounts"])


@router.get("", response_model=List[AccountResponse])
async def get_accounts(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get all accounts for current user."""
    try:
        result = await db.execute(
            select(Account)
            .where(Account.user_id == current_user.id, Account.is_active == True)
            .order_by(Account.is_default.desc(), Account.created_at.desc())
        )
        accounts = result.scalars().all()
        return [AccountResponse.model_validate(acc) for acc in accounts]
    except SQLAlchemyError as e:
        logger.error(f"Database error fetching accounts: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch accounts",
        )


@router.post("", response_model=AccountResponse, status_code=status.HTTP_201_CREATED)
async def create_account(
    account_data: AccountCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new account."""
    try:
        # If setting as default, unset other defaults
        if account_data.is_default:
            await db.execute(
                update(Account).where(Account.user_id == current_user.id).values(is_default=False)
            )

        account = Account(
            user_id=current_user.id,
            name=account_data.name,
            account_type=account_data.account_type,
            icon=account_data.icon,
            balance=account_data.balance,
            currency=account_data.currency,
            credit_limit=account_data.credit_limit,
            bill_day=account_data.bill_day,
            repay_day=account_data.repay_day,
            is_default=account_data.is_default,
        )
        db.add(account)
        await db.commit()
        await db.refresh(account)

        return AccountResponse.model_validate(account)
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"Database error creating account: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create account",
        )


@router.get("/{account_id}", response_model=AccountResponse)
async def get_account(
    account_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific account."""
    try:
        result = await db.execute(
            select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
        )
        account = result.scalar_one_or_none()

        if not account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Account not found",
            )

        return AccountResponse.model_validate(account)
    except HTTPException:
        raise
    except SQLAlchemyError as e:
        logger.error(f"Database error fetching account: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch account",
        )


@router.put("/{account_id}", response_model=AccountResponse)
async def update_account(
    account_id: UUID,
    account_data: AccountUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update an account."""
    try:
        result = await db.execute(
            select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
        )
        account = result.scalar_one_or_none()

        if not account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Account not found",
            )

        # If setting as default, unset other defaults
        if account_data.is_default:
            await db.execute(
                update(Account).where(Account.user_id == current_user.id, Account.id != account_id).values(is_default=False)
            )

        # Update fields
        update_data = account_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(account, field, value)

        await db.commit()
        await db.refresh(account)

        return AccountResponse.model_validate(account)
    except HTTPException:
        raise
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"Database error updating account: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update account",
        )


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    account_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete (deactivate) an account."""
    try:
        result = await db.execute(
            select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
        )
        account = result.scalar_one_or_none()

        if not account:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Account not found",
            )

        # Check if account has transactions
        tx_count_result = await db.execute(
            select(func.count(Transaction.id)).where(Transaction.account_id == account_id)
        )
        tx_count = tx_count_result.scalar() or 0

        if tx_count > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot delete account with {tx_count} transactions. Please transfer or delete transactions first.",
            )

        # Soft delete
        account.is_active = False
        await db.commit()
    except HTTPException:
        raise
    except SQLAlchemyError as e:
        await db.rollback()
        logger.error(f"Database error deleting account: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete account",
        )
