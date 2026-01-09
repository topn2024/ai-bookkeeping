"""Sync endpoints for data synchronization between client and server."""
from datetime import datetime, date, time
from decimal import Decimal
from typing import List, Dict, Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.budget import Budget
from app.schemas.sync import (
    SyncPushRequest, SyncPushResponse, EntitySyncResult, ConflictInfo,
    SyncPullRequest, SyncPullResponse, EntityData,
    SyncStatusResponse, EntityChange,
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/sync", tags=["Sync"])


# Entity type to model mapping
ENTITY_MODELS = {
    "transaction": Transaction,
    "account": Account,
    "category": Category,
    "book": Book,
    "budget": Budget,
}


@router.post("/push", response_model=SyncPushResponse)
async def push_changes(
    request: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Receive changes from client and apply to server.

    Strategy: Local-first (client wins on conflict)
    """
    accepted: List[EntitySyncResult] = []
    conflicts: List[ConflictInfo] = []

    # Process changes in dependency order
    ordered_types = ["book", "account", "category", "budget", "transaction"]
    changes_by_type: Dict[str, List[EntityChange]] = {}

    for change in request.changes:
        if change.entity_type not in changes_by_type:
            changes_by_type[change.entity_type] = []
        changes_by_type[change.entity_type].append(change)

    for entity_type in ordered_types:
        if entity_type not in changes_by_type:
            continue

        for change in changes_by_type[entity_type]:
            try:
                result = await _process_change(
                    db, current_user, change, entity_type
                )
                if result.success:
                    accepted.append(result)
                else:
                    # Handle as conflict if there's an error
                    pass
            except Exception as e:
                accepted.append(EntitySyncResult(
                    local_id=change.local_id,
                    server_id=change.server_id or UUID(int=0),
                    entity_type=entity_type,
                    operation=change.operation,
                    success=False,
                    error=str(e),
                ))

    await db.commit()

    return SyncPushResponse(
        accepted=accepted,
        conflicts=conflicts,
        server_time=datetime.utcnow(),
    )


async def _process_change(
    db: AsyncSession,
    user: User,
    change: EntityChange,
    entity_type: str,
) -> EntitySyncResult:
    """Process a single entity change."""

    if change.operation == "create":
        return await _handle_create(db, user, change, entity_type)
    elif change.operation == "update":
        return await _handle_update(db, user, change, entity_type)
    elif change.operation == "delete":
        return await _handle_delete(db, user, change, entity_type)
    else:
        raise ValueError(f"Unknown operation: {change.operation}")


async def _handle_create(
    db: AsyncSession,
    user: User,
    change: EntityChange,
    entity_type: str,
) -> EntitySyncResult:
    """Handle entity creation."""
    data = change.data

    if entity_type == "transaction":
        # Parse date and time
        tx_date = date.fromisoformat(data["transaction_date"]) if isinstance(data.get("transaction_date"), str) else data.get("transaction_date", date.today())
        tx_time = time.fromisoformat(data["transaction_time"]) if data.get("transaction_time") else None

        # Get book_id - use provided or get user's default book
        book_id = None
        if data.get("book_id"):
            try:
                book_id = UUID(data["book_id"]) if isinstance(data["book_id"], str) else data["book_id"]
            except ValueError:
                pass
        if not book_id:
            # Get or create default book for user
            default_book = await db.execute(
                select(Book).where(Book.user_id == user.id, Book.is_default == True)
            )
            book = default_book.scalar_one_or_none()
            if not book:
                # Get any book or create one
                any_book = await db.execute(
                    select(Book).where(Book.user_id == user.id).limit(1)
                )
                book = any_book.scalar_one_or_none()
                if not book:
                    book = Book(user_id=user.id, name="默认账本", is_default=True)
                    db.add(book)
                    await db.flush()
            book_id = book.id

        # Get account_id - use provided or get user's default account
        account_id = None
        if data.get("account_id"):
            try:
                account_id = UUID(data["account_id"]) if isinstance(data["account_id"], str) else data["account_id"]
            except ValueError:
                pass
        if not account_id:
            default_account = await db.execute(
                select(Account).where(Account.user_id == user.id, Account.is_default == True)
            )
            account = default_account.scalar_one_or_none()
            if not account:
                any_account = await db.execute(
                    select(Account).where(Account.user_id == user.id).limit(1)
                )
                account = any_account.scalar_one_or_none()
                if not account:
                    account = Account(user_id=user.id, name="现金", account_type=1, is_default=True)
                    db.add(account)
                    await db.flush()
            account_id = account.id

        # Get category_id - use provided or get default category
        category_id = None
        if data.get("category_id"):
            try:
                category_id = UUID(data["category_id"]) if isinstance(data["category_id"], str) else data["category_id"]
            except ValueError:
                pass
        if not category_id:
            tx_type = data.get("transaction_type", 1)
            default_category = await db.execute(
                select(Category).where(
                    Category.category_type == tx_type,
                    or_(Category.user_id == user.id, Category.is_system == True)
                ).limit(1)
            )
            category = default_category.scalar_one_or_none()
            if not category:
                category = Category(name="其他", category_type=tx_type, is_system=True)
                db.add(category)
                await db.flush()
            category_id = category.id

        entity = Transaction(
            user_id=user.id,
            book_id=book_id,
            account_id=account_id,
            target_account_id=UUID(data["target_account_id"]) if data.get("target_account_id") else None,
            category_id=category_id,
            transaction_type=data.get("transaction_type", 1),
            amount=Decimal(str(data.get("amount", 0))),
            fee=Decimal(str(data.get("fee", 0))),
            transaction_date=tx_date,
            transaction_time=tx_time,
            note=data.get("note"),
            tags=data.get("tags"),
            images=data.get("images"),
            location=data.get("location"),
            # Structured location fields (Chapter 14)
            location_latitude=Decimal(str(data["location_latitude"])) if data.get("location_latitude") else None,
            location_longitude=Decimal(str(data["location_longitude"])) if data.get("location_longitude") else None,
            location_place_name=data.get("location_place_name"),
            location_address=data.get("location_address"),
            location_city=data.get("location_city"),
            location_district=data.get("location_district"),
            location_type=data.get("location_type"),
            location_poi_id=data.get("location_poi_id"),
            is_reimbursable=data.get("is_reimbursable", False),
            is_reimbursed=data.get("is_reimbursed", False),
            is_exclude_stats=data.get("is_exclude_stats", False),
            source=data.get("source", 0),
            ai_confidence=Decimal(str(data["ai_confidence"])) if data.get("ai_confidence") else None,
        )
        db.add(entity)
        await db.flush()

        # Update account balance
        await _update_account_balance_on_create(db, user, entity)

    elif entity_type == "account":
        entity = Account(
            user_id=user.id,
            name=data["name"],
            account_type=data.get("account_type", 1),
            icon=data.get("icon"),
            balance=Decimal(str(data.get("balance", 0))),
            currency=data.get("currency", "CNY"),
            credit_limit=Decimal(str(data["credit_limit"])) if data.get("credit_limit") else None,
            bill_day=data.get("bill_day"),
            repay_day=data.get("repay_day"),
            is_default=data.get("is_default", False),
            is_active=data.get("is_active", True),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "category":
        entity = Category(
            user_id=user.id if not data.get("is_system") else None,
            parent_id=UUID(data["parent_id"]) if data.get("parent_id") else None,
            name=data["name"],
            icon=data.get("icon"),
            category_type=data.get("category_type", 1),
            sort_order=data.get("sort_order", 0),
            is_system=data.get("is_system", False),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "book":
        entity = Book(
            user_id=user.id,
            name=data["name"],
            description=data.get("description"),
            book_type=data.get("book_type", 0),
            icon=data.get("icon"),
            is_default=data.get("is_default", False),
            is_archived=data.get("is_archived", False),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "budget":
        entity = Budget(
            user_id=user.id,
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data.get("book_id"),
            category_id=UUID(data["category_id"]) if data.get("category_id") else None,
            name=data["name"],
            amount=Decimal(str(data.get("amount", 0))),
            budget_type=data.get("budget_type", 1),
            year=data.get("year", datetime.now().year),
            month=data.get("month"),
            is_active=data.get("is_active", True),
        )
        db.add(entity)
        await db.flush()
    else:
        raise ValueError(f"Unknown entity type: {entity_type}")

    return EntitySyncResult(
        local_id=change.local_id,
        server_id=entity.id,
        entity_type=entity_type,
        operation="create",
        success=True,
    )


async def _handle_update(
    db: AsyncSession,
    user: User,
    change: EntityChange,
    entity_type: str,
) -> EntitySyncResult:
    """Handle entity update. Local-first: always apply client changes."""
    if not change.server_id:
        raise ValueError("server_id is required for update")

    model = ENTITY_MODELS.get(entity_type)
    if not model:
        raise ValueError(f"Unknown entity type: {entity_type}")

    # Get existing entity
    query = select(model).where(model.id == change.server_id)
    if hasattr(model, 'user_id'):
        query = query.where(model.user_id == user.id)

    result = await db.execute(query)
    entity = result.scalar_one_or_none()

    if not entity:
        raise ValueError(f"{entity_type} not found: {change.server_id}")

    # Handle balance update for transactions
    if entity_type == "transaction":
        await _revert_account_balance(db, user, entity)

    # Apply updates (Local-first: always use client data)
    data = change.data
    for key, value in data.items():
        if hasattr(entity, key) and key not in ['id', 'user_id', 'created_at']:
            # Handle special types
            if key in ['book_id', 'account_id', 'target_account_id', 'category_id', 'parent_id'] and value:
                value = UUID(value) if isinstance(value, str) else value
            elif key in ['amount', 'fee', 'balance', 'credit_limit', 'location_latitude', 'location_longitude'] and value is not None:
                value = Decimal(str(value))
            elif key == 'transaction_date' and value:
                value = date.fromisoformat(value) if isinstance(value, str) else value
            elif key == 'transaction_time' and value:
                value = time.fromisoformat(value) if isinstance(value, str) else value
            setattr(entity, key, value)

    # Re-apply balance for transactions
    if entity_type == "transaction":
        await _update_account_balance_on_create(db, user, entity)

    return EntitySyncResult(
        local_id=change.local_id,
        server_id=change.server_id,
        entity_type=entity_type,
        operation="update",
        success=True,
    )


async def _handle_delete(
    db: AsyncSession,
    user: User,
    change: EntityChange,
    entity_type: str,
) -> EntitySyncResult:
    """Handle entity deletion."""
    if not change.server_id:
        raise ValueError("server_id is required for delete")

    model = ENTITY_MODELS.get(entity_type)
    if not model:
        raise ValueError(f"Unknown entity type: {entity_type}")

    query = select(model).where(model.id == change.server_id)
    if hasattr(model, 'user_id'):
        query = query.where(model.user_id == user.id)

    result = await db.execute(query)
    entity = result.scalar_one_or_none()

    if entity:
        # Revert balance for transactions
        if entity_type == "transaction":
            await _revert_account_balance(db, user, entity)

        await db.delete(entity)

    return EntitySyncResult(
        local_id=change.local_id,
        server_id=change.server_id,
        entity_type=entity_type,
        operation="delete",
        success=True,
    )


async def _update_account_balance_on_create(
    db: AsyncSession,
    user: User,
    transaction: Transaction,
):
    """Update account balance when creating a transaction."""
    result = await db.execute(
        select(Account).where(Account.id == transaction.account_id)
    )
    account = result.scalar_one_or_none()

    if account:
        if transaction.transaction_type == 1:  # Expense
            account.balance -= transaction.amount + transaction.fee
        elif transaction.transaction_type == 2:  # Income
            account.balance += transaction.amount
        elif transaction.transaction_type == 3:  # Transfer
            account.balance -= transaction.amount + transaction.fee
            if transaction.target_account_id:
                result = await db.execute(
                    select(Account).where(Account.id == transaction.target_account_id)
                )
                target_account = result.scalar_one_or_none()
                if target_account:
                    target_account.balance += transaction.amount


async def _revert_account_balance(
    db: AsyncSession,
    user: User,
    transaction: Transaction,
):
    """Revert account balance when updating/deleting a transaction."""
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


@router.post("/pull", response_model=SyncPullResponse)
async def pull_changes(
    request: SyncPullRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return all changes since last_sync_time for each entity type.
    """
    changes: Dict[str, List[EntityData]] = {}

    for entity_type, last_sync_time in request.last_sync_times.items():
        model = ENTITY_MODELS.get(entity_type)
        if not model:
            continue

        query = select(model)
        if hasattr(model, 'user_id'):
            query = query.where(model.user_id == current_user.id)

        if last_sync_time:
            query = query.where(model.updated_at > last_sync_time)

        result = await db.execute(query)
        entities = result.scalars().all()

        changes[entity_type] = [
            EntityData(
                id=entity.id,
                entity_type=entity_type,
                operation="update" if last_sync_time else "create",
                data=_entity_to_dict(entity, entity_type),
                updated_at=entity.updated_at,
                is_deleted=False,
            )
            for entity in entities
        ]

    return SyncPullResponse(
        changes=changes,
        server_time=datetime.utcnow(),
        has_more=False,
    )


def _entity_to_dict(entity, entity_type: str) -> Dict[str, Any]:
    """Convert entity to dictionary for sync response."""
    data = {}

    if entity_type == "transaction":
        data = {
            "book_id": str(entity.book_id),
            "account_id": str(entity.account_id),
            "target_account_id": str(entity.target_account_id) if entity.target_account_id else None,
            "category_id": str(entity.category_id),
            "transaction_type": entity.transaction_type,
            "amount": str(entity.amount),
            "fee": str(entity.fee),
            "transaction_date": entity.transaction_date.isoformat() if entity.transaction_date else None,
            "transaction_time": entity.transaction_time.isoformat() if entity.transaction_time else None,
            "note": entity.note,
            "tags": entity.tags,
            "images": entity.images,
            "location": entity.location,
            # Structured location fields (Chapter 14)
            "location_latitude": str(entity.location_latitude) if entity.location_latitude else None,
            "location_longitude": str(entity.location_longitude) if entity.location_longitude else None,
            "location_place_name": entity.location_place_name if hasattr(entity, 'location_place_name') else None,
            "location_address": entity.location_address if hasattr(entity, 'location_address') else None,
            "location_city": entity.location_city if hasattr(entity, 'location_city') else None,
            "location_district": entity.location_district if hasattr(entity, 'location_district') else None,
            "location_type": entity.location_type if hasattr(entity, 'location_type') else None,
            "location_poi_id": entity.location_poi_id if hasattr(entity, 'location_poi_id') else None,
            "is_reimbursable": entity.is_reimbursable,
            "is_reimbursed": entity.is_reimbursed,
            "is_exclude_stats": entity.is_exclude_stats,
            "source": entity.source,
            "ai_confidence": str(entity.ai_confidence) if entity.ai_confidence else None,
        }
    elif entity_type == "account":
        data = {
            "name": entity.name,
            "account_type": entity.account_type,
            "icon": entity.icon,
            "balance": str(entity.balance),
            "currency": entity.currency if hasattr(entity, 'currency') else "CNY",
            "credit_limit": str(entity.credit_limit) if entity.credit_limit else None,
            "bill_day": entity.bill_day,
            "repay_day": entity.repay_day,
            "is_default": entity.is_default,
            "is_active": entity.is_active,
        }
    elif entity_type == "category":
        data = {
            "parent_id": str(entity.parent_id) if entity.parent_id else None,
            "name": entity.name,
            "icon": entity.icon,
            "category_type": entity.category_type,
            "sort_order": entity.sort_order if hasattr(entity, 'sort_order') else 0,
            "is_system": entity.is_system if hasattr(entity, 'is_system') else False,
        }
    elif entity_type == "book":
        data = {
            "name": entity.name,
            "description": entity.description if hasattr(entity, 'description') else None,
            "book_type": entity.book_type,
            "icon": entity.icon if hasattr(entity, 'icon') else None,
            "is_default": entity.is_default,
            "is_archived": entity.is_archived if hasattr(entity, 'is_archived') else False,
        }
    elif entity_type == "budget":
        data = {
            "book_id": str(entity.book_id),
            "category_id": str(entity.category_id) if entity.category_id else None,
            "name": entity.name,
            "amount": str(entity.amount),
            "budget_type": entity.budget_type if hasattr(entity, 'budget_type') else 1,
            "year": entity.year if hasattr(entity, 'year') else datetime.now().year,
            "month": entity.month if hasattr(entity, 'month') else None,
            "is_active": entity.is_active if hasattr(entity, 'is_active') else True,
        }

    return data


@router.get("/status", response_model=SyncStatusResponse)
async def get_sync_status(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get current sync status for the user."""
    entity_counts: Dict[str, int] = {}

    for entity_type, model in ENTITY_MODELS.items():
        query = select(func.count()).select_from(model)
        if hasattr(model, 'user_id'):
            query = query.where(model.user_id == current_user.id)

        result = await db.execute(query)
        entity_counts[entity_type] = result.scalar() or 0

    return SyncStatusResponse(
        server_time=datetime.utcnow(),
        entity_counts=entity_counts,
        last_sync_times={},  # TODO: Track per-device sync times
        pending_conflicts=0,
    )
