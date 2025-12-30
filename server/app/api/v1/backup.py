"""Backup endpoints for user data backup and restore."""
import json
from datetime import datetime, date, time
from decimal import Decimal
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, delete

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.budget import Budget
from app.models.backup import Backup
from app.schemas.backup import (
    BackupCreate,
    BackupResponse,
    BackupListResponse,
    BackupDetailResponse,
    BackupData,
    RestoreRequest,
    RestoreResponse,
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/backup", tags=["Backup"])


def _serialize_value(value):
    """Serialize a value for JSON storage."""
    if isinstance(value, UUID):
        return str(value)
    elif isinstance(value, (datetime, date)):
        return value.isoformat()
    elif isinstance(value, time):
        return value.isoformat()
    elif isinstance(value, Decimal):
        return str(value)
    return value


def _entity_to_dict(entity, exclude_fields=None) -> dict:
    """Convert SQLAlchemy entity to dictionary."""
    exclude = exclude_fields or set()
    exclude.update({'_sa_instance_state'})

    result = {}
    for key in entity.__dict__:
        if key not in exclude:
            result[key] = _serialize_value(getattr(entity, key))
    return result


@router.post("", response_model=BackupResponse)
async def create_backup(
    request: BackupCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new backup of user's data."""

    # Fetch all user data
    transactions_result = await db.execute(
        select(Transaction).where(Transaction.user_id == current_user.id)
    )
    transactions = transactions_result.scalars().all()

    accounts_result = await db.execute(
        select(Account).where(Account.user_id == current_user.id)
    )
    accounts = accounts_result.scalars().all()

    categories_result = await db.execute(
        select(Category).where(Category.user_id == current_user.id)
    )
    categories = categories_result.scalars().all()

    books_result = await db.execute(
        select(Book).where(Book.user_id == current_user.id)
    )
    books = books_result.scalars().all()

    budgets_result = await db.execute(
        select(Budget).where(Budget.user_id == current_user.id)
    )
    budgets = budgets_result.scalars().all()

    # Prepare backup data
    backup_data = {
        "transactions": [_entity_to_dict(t) for t in transactions],
        "accounts": [_entity_to_dict(a) for a in accounts],
        "categories": [_entity_to_dict(c) for c in categories],
        "books": [_entity_to_dict(b) for b in books],
        "budgets": [_entity_to_dict(b) for b in budgets],
        "backup_version": "1.0",
        "created_at": datetime.utcnow().isoformat(),
    }

    # Serialize to JSON
    data_json = json.dumps(backup_data, ensure_ascii=False)

    # Create backup record
    backup = Backup(
        user_id=current_user.id,
        name=request.name,
        description=request.description,
        backup_type=request.backup_type,
        data=data_json,
        transaction_count=len(transactions),
        account_count=len(accounts),
        category_count=len(categories),
        book_count=len(books),
        budget_count=len(budgets),
        size=len(data_json.encode('utf-8')),
        device_name=request.device_name,
        device_id=request.device_id,
        app_version=request.app_version,
    )

    db.add(backup)
    await db.commit()
    await db.refresh(backup)

    return backup


@router.get("", response_model=BackupListResponse)
async def list_backups(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all backups for the current user."""

    result = await db.execute(
        select(Backup)
        .where(Backup.user_id == current_user.id)
        .order_by(Backup.created_at.desc())
    )
    backups = result.scalars().all()

    return BackupListResponse(
        backups=backups,
        total=len(backups),
    )


@router.get("/{backup_id}", response_model=BackupDetailResponse)
async def get_backup(
    backup_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a specific backup with its data."""

    result = await db.execute(
        select(Backup)
        .where(Backup.id == backup_id)
        .where(Backup.user_id == current_user.id)
    )
    backup = result.scalar_one_or_none()

    if not backup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="备份不存在",
        )

    # Parse backup data
    data = json.loads(backup.data)
    backup_data = BackupData(
        transactions=data.get("transactions", []),
        accounts=data.get("accounts", []),
        categories=data.get("categories", []),
        books=data.get("books", []),
        budgets=data.get("budgets", []),
    )

    return BackupDetailResponse(
        id=backup.id,
        user_id=backup.user_id,
        name=backup.name,
        description=backup.description,
        backup_type=backup.backup_type,
        data=backup_data,
        transaction_count=backup.transaction_count,
        account_count=backup.account_count,
        category_count=backup.category_count,
        book_count=backup.book_count,
        budget_count=backup.budget_count,
        size=backup.size,
        device_name=backup.device_name,
        device_id=backup.device_id,
        app_version=backup.app_version,
        created_at=backup.created_at,
    )


@router.post("/{backup_id}/restore", response_model=RestoreResponse)
async def restore_backup(
    backup_id: UUID,
    request: RestoreRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Restore data from a backup."""

    # Get the backup
    result = await db.execute(
        select(Backup)
        .where(Backup.id == backup_id)
        .where(Backup.user_id == current_user.id)
    )
    backup = result.scalar_one_or_none()

    if not backup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="备份不存在",
        )

    # Parse backup data
    data = json.loads(backup.data)
    restored_counts = {}

    try:
        # Clear existing data if requested
        if request.clear_existing:
            await db.execute(delete(Transaction).where(Transaction.user_id == current_user.id))
            await db.execute(delete(Budget).where(Budget.user_id == current_user.id))
            await db.execute(delete(Category).where(Category.user_id == current_user.id))
            await db.execute(delete(Account).where(Account.user_id == current_user.id))
            await db.execute(delete(Book).where(Book.user_id == current_user.id))
            await db.flush()

        # Restore in dependency order: books -> accounts -> categories -> budgets -> transactions

        # Restore books
        books_data = data.get("books", [])
        for book_data in books_data:
            book = Book(
                id=UUID(book_data["id"]),
                user_id=current_user.id,
                name=book_data["name"],
                description=book_data.get("description"),
                book_type=book_data.get("book_type", 0),
                icon=book_data.get("icon"),
                is_default=book_data.get("is_default", False),
                is_archived=book_data.get("is_archived", False),
            )
            db.add(book)
        restored_counts["books"] = len(books_data)
        await db.flush()

        # Restore accounts
        accounts_data = data.get("accounts", [])
        for acc_data in accounts_data:
            account = Account(
                id=UUID(acc_data["id"]),
                user_id=current_user.id,
                name=acc_data["name"],
                account_type=acc_data.get("account_type", 1),
                icon=acc_data.get("icon"),
                balance=Decimal(str(acc_data.get("balance", 0))),
                currency=acc_data.get("currency", "CNY"),
                credit_limit=Decimal(str(acc_data["credit_limit"])) if acc_data.get("credit_limit") else None,
                bill_day=acc_data.get("bill_day"),
                repay_day=acc_data.get("repay_day"),
                is_default=acc_data.get("is_default", False),
                is_active=acc_data.get("is_active", True),
            )
            db.add(account)
        restored_counts["accounts"] = len(accounts_data)
        await db.flush()

        # Restore categories
        categories_data = data.get("categories", [])
        # First pass: categories without parent
        for cat_data in categories_data:
            if not cat_data.get("parent_id"):
                category = Category(
                    id=UUID(cat_data["id"]),
                    user_id=current_user.id,
                    parent_id=None,
                    name=cat_data["name"],
                    icon=cat_data.get("icon"),
                    category_type=cat_data.get("category_type", 1),
                    sort_order=cat_data.get("sort_order", 0),
                    is_system=cat_data.get("is_system", False),
                )
                db.add(category)
        await db.flush()

        # Second pass: categories with parent
        for cat_data in categories_data:
            if cat_data.get("parent_id"):
                category = Category(
                    id=UUID(cat_data["id"]),
                    user_id=current_user.id,
                    parent_id=UUID(cat_data["parent_id"]),
                    name=cat_data["name"],
                    icon=cat_data.get("icon"),
                    category_type=cat_data.get("category_type", 1),
                    sort_order=cat_data.get("sort_order", 0),
                    is_system=cat_data.get("is_system", False),
                )
                db.add(category)
        restored_counts["categories"] = len(categories_data)
        await db.flush()

        # Restore budgets
        budgets_data = data.get("budgets", [])
        for budget_data in budgets_data:
            budget = Budget(
                id=UUID(budget_data["id"]),
                user_id=current_user.id,
                book_id=UUID(budget_data["book_id"]) if budget_data.get("book_id") else None,
                category_id=UUID(budget_data["category_id"]) if budget_data.get("category_id") else None,
                name=budget_data["name"],
                amount=Decimal(str(budget_data.get("amount", 0))),
                budget_type=budget_data.get("budget_type", 1),
                year=budget_data.get("year", datetime.now().year),
                month=budget_data.get("month"),
                is_active=budget_data.get("is_active", True),
            )
            db.add(budget)
        restored_counts["budgets"] = len(budgets_data)
        await db.flush()

        # Restore transactions
        transactions_data = data.get("transactions", [])
        for tx_data in transactions_data:
            tx_date = date.fromisoformat(tx_data["transaction_date"]) if tx_data.get("transaction_date") else date.today()
            tx_time = time.fromisoformat(tx_data["transaction_time"]) if tx_data.get("transaction_time") else None

            transaction = Transaction(
                id=UUID(tx_data["id"]),
                user_id=current_user.id,
                book_id=UUID(tx_data["book_id"]) if tx_data.get("book_id") else None,
                account_id=UUID(tx_data["account_id"]) if tx_data.get("account_id") else None,
                target_account_id=UUID(tx_data["target_account_id"]) if tx_data.get("target_account_id") else None,
                category_id=UUID(tx_data["category_id"]) if tx_data.get("category_id") else None,
                transaction_type=tx_data.get("transaction_type", 1),
                amount=Decimal(str(tx_data.get("amount", 0))),
                fee=Decimal(str(tx_data.get("fee", 0))),
                transaction_date=tx_date,
                transaction_time=tx_time,
                note=tx_data.get("note"),
                tags=tx_data.get("tags"),
                images=tx_data.get("images"),
                location=tx_data.get("location"),
                is_reimbursable=tx_data.get("is_reimbursable", False),
                is_reimbursed=tx_data.get("is_reimbursed", False),
                is_exclude_stats=tx_data.get("is_exclude_stats", False),
                source=tx_data.get("source", 0),
                ai_confidence=Decimal(str(tx_data["ai_confidence"])) if tx_data.get("ai_confidence") else None,
            )
            db.add(transaction)
        restored_counts["transactions"] = len(transactions_data)

        await db.commit()

        return RestoreResponse(
            success=True,
            message="数据恢复成功",
            restored_counts=restored_counts,
        )

    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"恢复失败: {str(e)}",
        )


@router.delete("/{backup_id}")
async def delete_backup(
    backup_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a backup."""

    result = await db.execute(
        select(Backup)
        .where(Backup.id == backup_id)
        .where(Backup.user_id == current_user.id)
    )
    backup = result.scalar_one_or_none()

    if not backup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="备份不存在",
        )

    await db.delete(backup)
    await db.commit()

    return {"message": "备份已删除"}
