"""Sync endpoints for data synchronization between client and server."""
import logging
from datetime import datetime, date, time
from decimal import Decimal
from typing import List, Dict, Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_

from app.core.database import get_db
from app.models.user import User
from app.models.book import Book, BookMember, FamilyBudget, MemberBudget, FamilySavingGoal, GoalContribution, TransactionSplit, SplitParticipant
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.budget import Budget
from app.models.money_age import ResourcePool, ConsumptionRecord, MoneyAgeSnapshot, MoneyAgeConfig
from app.models.location import GeoFence, FrequentLocation, UserHomeLocation
from app.schemas.sync import (
    SyncPushRequest, SyncPushResponse, EntitySyncResult, ConflictInfo,
    SyncPullRequest, SyncPullResponse, EntityData,
    SyncStatusResponse, EntityChange,
)
from app.api.deps import get_current_user


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/sync", tags=["Sync"])


# Entity type to model mapping
ENTITY_MODELS = {
    # Core entities
    "transaction": Transaction,
    "account": Account,
    "category": Category,
    "book": Book,
    "budget": Budget,
    # Family book entities
    "book_member": BookMember,
    "family_budget": FamilyBudget,
    "member_budget": MemberBudget,
    "family_saving_goal": FamilySavingGoal,
    "goal_contribution": GoalContribution,
    "transaction_split": TransactionSplit,
    "split_participant": SplitParticipant,
    # Money age entities
    "resource_pool": ResourcePool,
    "consumption_record": ConsumptionRecord,
    "money_age_snapshot": MoneyAgeSnapshot,
    "money_age_config": MoneyAgeConfig,
    # Location entities
    "geo_fence": GeoFence,
    "frequent_location": FrequentLocation,
    "user_home_location": UserHomeLocation,
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
    ordered_types = [
        # Core entities (in dependency order)
        "book", "account", "category", "budget", "transaction",
        # Family book entities
        "book_member", "family_budget", "member_budget",
        "family_saving_goal", "goal_contribution",
        "transaction_split", "split_participant",
        # Money age entities
        "resource_pool", "consumption_record", "money_age_snapshot", "money_age_config",
        # Location entities
        "geo_fence", "frequent_location", "user_home_location",
    ]
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
                # Check for conflicts before processing
                conflict = await _check_conflict(db, current_user, change, entity_type)
                if conflict:
                    conflicts.append(conflict)
                    continue

                # Use savepoint to isolate each entity's changes
                # Failed entities rollback to savepoint, successful ones are preserved
                async with db.begin_nested():  # savepoint
                    result = await _process_change(
                        db, current_user, change, entity_type
                    )
                    if result.success:
                        accepted.append(result)
                    else:
                        # Failed but not a conflict - add to accepted with error
                        accepted.append(result)
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


async def _check_conflict(
    db: AsyncSession,
    user: User,
    change: EntityChange,
    entity_type: str,
) -> Optional[ConflictInfo]:
    """Check if there's a conflict between client and server data.

    Returns ConflictInfo if conflict detected, None otherwise.
    Currently using local-first strategy, so conflicts are only reported
    when server data was modified after client's last sync.
    """
    # Create operations don't have conflicts (new entity)
    if change.operation == "create":
        return None

    # Need server_id for update/delete operations
    if not change.server_id:
        return None

    model = ENTITY_MODELS.get(entity_type)
    if not model:
        return None

    # Get server entity
    query = select(model).where(model.id == change.server_id)
    if hasattr(model, 'user_id'):
        query = query.where(model.user_id == user.id)

    result = await db.execute(query)
    entity = result.scalar_one_or_none()

    if not entity:
        if change.operation == "update":
            # Entity was deleted on server but client wants to update
            return ConflictInfo(
                entity_type=entity_type,
                local_id=change.local_id,
                server_id=change.server_id,
                local_data=change.data,
                server_data={},
                local_updated_at=change.local_updated_at,
                server_updated_at=datetime.utcnow(),
                conflict_type="deleted_on_server",
            )
        return None

    # Check if server was modified after client's local_updated_at
    if hasattr(entity, 'updated_at') and entity.updated_at:
        server_updated = entity.updated_at
        # If server was updated after client's version, it's a potential conflict
        # But with local-first strategy, we still apply client changes
        # We only report conflict for informational purposes
        if server_updated > change.local_updated_at:
            # Convert entity to dict for server_data
            server_data = {}
            for column in entity.__table__.columns:
                value = getattr(entity, column.name)
                if value is not None:
                    if hasattr(value, 'isoformat'):
                        value = value.isoformat()
                    elif isinstance(value, UUID):
                        value = str(value)
                    elif isinstance(value, Decimal):
                        value = str(value)
                server_data[column.name] = value

            # With local-first, we don't block - just report
            # Return None to allow processing, but log the conflict
            # For strict conflict handling, uncomment the return below:
            # return ConflictInfo(
            #     entity_type=entity_type,
            #     local_id=change.local_id,
            #     server_id=change.server_id,
            #     local_data=change.data,
            #     server_data=server_data,
            #     local_updated_at=change.local_updated_at,
            #     server_updated_at=server_updated,
            #     conflict_type="both_modified",
            # )

    return None


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
            except ValueError as e:
                logger.debug(f"Invalid book_id UUID format: {e}")
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
            except ValueError as e:
                logger.debug(f"Invalid account_id UUID format: {e}")
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
            except ValueError as e:
                logger.debug(f"Invalid category_id UUID format: {e}")
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
            geofence_region=data.get("geofence_region"),
            is_cross_region=data.get("is_cross_region", False),
            # Money Age fields
            money_age=data.get("money_age"),
            money_age_level=data.get("money_age_level"),
            resource_pool_id=UUID(data["resource_pool_id"]) if data.get("resource_pool_id") else None,
            # Reimbursement and stats
            is_reimbursable=data.get("is_reimbursable", False),
            is_reimbursed=data.get("is_reimbursed", False),
            is_exclude_stats=data.get("is_exclude_stats", False),
            source=data.get("source", 0),
            ai_confidence=Decimal(str(data["ai_confidence"])) if data.get("ai_confidence") else None,
            # Source file fields
            source_file_url=data.get("source_file_url"),
            source_file_type=data.get("source_file_type"),
            source_file_size=data.get("source_file_size"),
            recognition_raw_response=data.get("recognition_raw_response"),
            recognition_timestamp=datetime.fromisoformat(data["recognition_timestamp"]) if data.get("recognition_timestamp") else None,
            source_file_expires_at=datetime.fromisoformat(data["source_file_expires_at"]) if data.get("source_file_expires_at") else None,
            # Visibility
            visibility=data.get("visibility", 1),
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
            cover_image=data.get("cover_image"),
            currency=data.get("currency", "CNY"),
            is_default=data.get("is_default", False),
            is_archived=data.get("is_archived", False),
            settings=data.get("settings"),
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

    # ============== Family Book Entities ==============
    elif entity_type == "book_member":
        entity = BookMember(
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data["book_id"],
            user_id=user.id,
            role=data.get("role", 1),
            nickname=data.get("nickname"),
            invited_by=UUID(data["invited_by"]) if data.get("invited_by") else None,
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "family_budget":
        entity = FamilyBudget(
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data["book_id"],
            period=data["period"],
            strategy=data.get("strategy", 0),
            total_budget=Decimal(str(data.get("total_budget", 0))),
            rules=data.get("rules"),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "member_budget":
        entity = MemberBudget(
            family_budget_id=UUID(data["family_budget_id"]) if isinstance(data.get("family_budget_id"), str) else data["family_budget_id"],
            user_id=user.id,
            allocated=Decimal(str(data.get("allocated", 0))),
            spent=Decimal(str(data.get("spent", 0))),
            category_spent=data.get("category_spent"),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "family_saving_goal":
        entity = FamilySavingGoal(
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data["book_id"],
            name=data["name"],
            description=data.get("description"),
            icon=data.get("icon"),
            target_amount=Decimal(str(data.get("target_amount", 0))),
            current_amount=Decimal(str(data.get("current_amount", 0))),
            deadline=datetime.fromisoformat(data["deadline"]) if data.get("deadline") else None,
            status=data.get("status", 0),
            created_by=user.id,
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "goal_contribution":
        entity = GoalContribution(
            goal_id=UUID(data["goal_id"]) if isinstance(data.get("goal_id"), str) else data["goal_id"],
            user_id=user.id,
            amount=Decimal(str(data.get("amount", 0))),
            note=data.get("note"),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "transaction_split":
        entity = TransactionSplit(
            transaction_id=UUID(data["transaction_id"]) if isinstance(data.get("transaction_id"), str) else data["transaction_id"],
            split_type=data.get("split_type", 0),
            status=data.get("status", 0),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "split_participant":
        entity = SplitParticipant(
            split_id=UUID(data["split_id"]) if isinstance(data.get("split_id"), str) else data["split_id"],
            user_id=user.id,
            amount=Decimal(str(data.get("amount", 0))),
            percentage=Decimal(str(data["percentage"])) if data.get("percentage") else None,
            shares=data.get("shares"),
            is_payer=data.get("is_payer", False),
            is_settled=data.get("is_settled", False),
        )
        db.add(entity)
        await db.flush()

    # ============== Money Age Entities ==============
    elif entity_type == "resource_pool":
        entity = ResourcePool(
            user_id=user.id,
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data["book_id"],
            income_transaction_id=UUID(data["income_transaction_id"]) if isinstance(data.get("income_transaction_id"), str) else data["income_transaction_id"],
            original_amount=Decimal(str(data.get("original_amount", 0))),
            remaining_amount=Decimal(str(data.get("remaining_amount", 0))),
            consumed_amount=Decimal(str(data.get("consumed_amount", 0))),
            income_date=date.fromisoformat(data["income_date"]) if isinstance(data.get("income_date"), str) else data.get("income_date", date.today()),
            first_consumed_date=date.fromisoformat(data["first_consumed_date"]) if data.get("first_consumed_date") else None,
            last_consumed_date=date.fromisoformat(data["last_consumed_date"]) if data.get("last_consumed_date") else None,
            fully_consumed_date=date.fromisoformat(data["fully_consumed_date"]) if data.get("fully_consumed_date") else None,
            is_fully_consumed=data.get("is_fully_consumed", False),
            consumption_count=data.get("consumption_count", 0),
            account_id=UUID(data["account_id"]) if isinstance(data.get("account_id"), str) else data["account_id"],
            income_category_id=UUID(data["income_category_id"]) if isinstance(data.get("income_category_id"), str) else data["income_category_id"],
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "consumption_record":
        entity = ConsumptionRecord(
            resource_pool_id=UUID(data["resource_pool_id"]) if isinstance(data.get("resource_pool_id"), str) else data["resource_pool_id"],
            expense_transaction_id=UUID(data["expense_transaction_id"]) if isinstance(data.get("expense_transaction_id"), str) else data["expense_transaction_id"],
            consumed_amount=Decimal(str(data.get("consumed_amount", 0))),
            consumption_date=date.fromisoformat(data["consumption_date"]) if isinstance(data.get("consumption_date"), str) else data.get("consumption_date", date.today()),
            money_age_days=data.get("money_age_days", 0),
            user_id=user.id,
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data["book_id"],
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "money_age_snapshot":
        entity = MoneyAgeSnapshot(
            user_id=user.id,
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data["book_id"],
            snapshot_date=date.fromisoformat(data["snapshot_date"]) if isinstance(data.get("snapshot_date"), str) else data.get("snapshot_date", date.today()),
            snapshot_type=data.get("snapshot_type", "daily"),
            avg_money_age=Decimal(str(data.get("avg_money_age", 0))),
            median_money_age=data.get("median_money_age"),
            min_money_age=data.get("min_money_age"),
            max_money_age=data.get("max_money_age"),
            health_level=data.get("health_level", "health"),
            health_count=data.get("health_count", 0),
            warning_count=data.get("warning_count", 0),
            danger_count=data.get("danger_count", 0),
            total_resource_pools=data.get("total_resource_pools", 0),
            active_resource_pools=data.get("active_resource_pools", 0),
            total_remaining_amount=Decimal(str(data.get("total_remaining_amount", 0))),
            total_transactions=data.get("total_transactions", 0),
            expense_transactions=data.get("expense_transactions", 0),
            income_transactions=data.get("income_transactions", 0),
            category_breakdown=data.get("category_breakdown"),
            monthly_trend=data.get("monthly_trend"),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "money_age_config":
        entity = MoneyAgeConfig(
            user_id=user.id,
            book_id=UUID(data["book_id"]) if isinstance(data.get("book_id"), str) else data["book_id"],
            consumption_strategy=data.get("consumption_strategy", "fifo"),
            health_threshold=data.get("health_threshold", 30),
            warning_threshold=data.get("warning_threshold", 60),
            enable_daily_snapshot=data.get("enable_daily_snapshot", True),
            enable_weekly_snapshot=data.get("enable_weekly_snapshot", True),
            enable_monthly_snapshot=data.get("enable_monthly_snapshot", True),
            enable_notifications=data.get("enable_notifications", True),
            notify_on_warning=data.get("notify_on_warning", True),
            notify_on_danger=data.get("notify_on_danger", True),
        )
        db.add(entity)
        await db.flush()

    # ============== Location Entities ==============
    elif entity_type == "geo_fence":
        entity = GeoFence(
            user_id=user.id,
            name=data["name"],
            center_latitude=Decimal(str(data["center_latitude"])),
            center_longitude=Decimal(str(data["center_longitude"])),
            radius_meters=data.get("radius_meters", 100.0),
            place_name=data.get("place_name"),
            action=data.get("action", 4),
            linked_category_id=UUID(data["linked_category_id"]) if data.get("linked_category_id") else None,
            linked_vault_id=data.get("linked_vault_id"),
            budget_limit=Decimal(str(data["budget_limit"])) if data.get("budget_limit") else None,
            is_enabled=data.get("is_enabled", True),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "frequent_location":
        entity = FrequentLocation(
            user_id=user.id,
            latitude=Decimal(str(data["latitude"])),
            longitude=Decimal(str(data["longitude"])),
            place_name=data.get("place_name"),
            address=data.get("address"),
            city=data.get("city"),
            district=data.get("district"),
            location_type=data.get("location_type"),
            poi_id=data.get("poi_id"),
            visit_count=data.get("visit_count", 1),
            total_spent=Decimal(str(data.get("total_spent", 0))),
            default_category_id=UUID(data["default_category_id"]) if data.get("default_category_id") else None,
            default_vault_id=data.get("default_vault_id"),
        )
        db.add(entity)
        await db.flush()

    elif entity_type == "user_home_location":
        entity = UserHomeLocation(
            user_id=user.id,
            location_role=data.get("location_role", 0),
            name=data["name"],
            latitude=Decimal(str(data["latitude"])),
            longitude=Decimal(str(data["longitude"])),
            city=data.get("city"),
            radius_meters=data.get("radius_meters", 5000.0),
            is_primary=data.get("is_primary", False),
            is_enabled=data.get("is_enabled", True),
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
            # UUID fields
            if key in ['book_id', 'account_id', 'target_account_id', 'category_id', 'parent_id',
                       'resource_pool_id', 'income_transaction_id', 'expense_transaction_id',
                       'family_budget_id', 'goal_id', 'transaction_id', 'split_id',
                       'linked_category_id', 'default_category_id', 'income_category_id',
                       'invited_by', 'created_by'] and value:
                value = UUID(value) if isinstance(value, str) else value
            # Decimal fields
            elif key in ['amount', 'fee', 'balance', 'credit_limit', 'location_latitude', 'location_longitude',
                         'ai_confidence', 'original_amount', 'remaining_amount', 'consumed_amount',
                         'target_amount', 'current_amount', 'total_budget', 'allocated', 'spent',
                         'percentage', 'avg_money_age', 'total_remaining_amount', 'total_spent',
                         'center_latitude', 'center_longitude', 'latitude', 'longitude',
                         'budget_limit'] and value is not None:
                value = Decimal(str(value))
            # Date fields
            elif key in ['transaction_date', 'income_date', 'first_consumed_date', 'last_consumed_date',
                         'fully_consumed_date', 'consumption_date', 'snapshot_date'] and value:
                value = date.fromisoformat(value) if isinstance(value, str) else value
            # Time fields
            elif key == 'transaction_time' and value:
                value = time.fromisoformat(value) if isinstance(value, str) else value
            # Datetime fields
            elif key in ['recognition_timestamp', 'source_file_expires_at', 'deadline', 'completed_at',
                         'settled_at', 'joined_at', 'last_visit_at', 'updated_at'] and value:
                value = datetime.fromisoformat(value) if isinstance(value, str) else value
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
        select(Account).where(Account.id == transaction.account_id).with_for_update()
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
                    select(Account).where(Account.id == transaction.target_account_id).with_for_update()
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
        select(Account).where(Account.id == transaction.account_id).with_for_update()
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
                    select(Account).where(Account.id == transaction.target_account_id).with_for_update()
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

    Supports pagination via limit parameter. When has_more is True,
    the client should request again with updated last_sync_times.
    """
    limit = getattr(request, 'limit', None) or 500
    changes: Dict[str, List[EntityData]] = {}
    has_more = False

    for entity_type, last_sync_time in request.last_sync_times.items():
        model = ENTITY_MODELS.get(entity_type)
        if not model:
            continue

        query = select(model)
        if hasattr(model, 'user_id'):
            query = query.where(model.user_id == current_user.id)

        if last_sync_time:
            query = query.where(model.updated_at > last_sync_time)

        query = query.order_by(model.updated_at).limit(limit + 1)

        result = await db.execute(query)
        entities = list(result.scalars().all())

        if len(entities) > limit:
            has_more = True
            entities = entities[:limit]

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
        has_more=has_more,
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
            "geofence_region": entity.geofence_region if hasattr(entity, 'geofence_region') else None,
            "is_cross_region": entity.is_cross_region if hasattr(entity, 'is_cross_region') else False,
            # Money Age fields
            "money_age": entity.money_age if hasattr(entity, 'money_age') else None,
            "money_age_level": entity.money_age_level if hasattr(entity, 'money_age_level') else None,
            "resource_pool_id": str(entity.resource_pool_id) if hasattr(entity, 'resource_pool_id') and entity.resource_pool_id else None,
            # Reimbursement and stats
            "is_reimbursable": entity.is_reimbursable,
            "is_reimbursed": entity.is_reimbursed,
            "is_exclude_stats": entity.is_exclude_stats,
            "source": entity.source,
            "ai_confidence": str(entity.ai_confidence) if entity.ai_confidence else None,
            # Source file fields
            "source_file_url": entity.source_file_url if hasattr(entity, 'source_file_url') else None,
            "source_file_type": entity.source_file_type if hasattr(entity, 'source_file_type') else None,
            "source_file_size": entity.source_file_size if hasattr(entity, 'source_file_size') else None,
            "recognition_raw_response": entity.recognition_raw_response if hasattr(entity, 'recognition_raw_response') else None,
            "recognition_timestamp": entity.recognition_timestamp.isoformat() if hasattr(entity, 'recognition_timestamp') and entity.recognition_timestamp else None,
            "source_file_expires_at": entity.source_file_expires_at.isoformat() if hasattr(entity, 'source_file_expires_at') and entity.source_file_expires_at else None,
            # Visibility
            "visibility": entity.visibility if hasattr(entity, 'visibility') else 1,
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
            "cover_image": entity.cover_image if hasattr(entity, 'cover_image') else None,
            "currency": entity.currency if hasattr(entity, 'currency') else "CNY",
            "is_default": entity.is_default,
            "is_archived": entity.is_archived if hasattr(entity, 'is_archived') else False,
            "settings": entity.settings if hasattr(entity, 'settings') else None,
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

    # ============== Family Book Entities ==============
    elif entity_type == "book_member":
        data = {
            "book_id": str(entity.book_id),
            "role": entity.role,
            "nickname": entity.nickname,
            "invited_by": str(entity.invited_by) if entity.invited_by else None,
            "joined_at": entity.joined_at.isoformat() if entity.joined_at else None,
            "settings": entity.settings,
        }
    elif entity_type == "family_budget":
        data = {
            "book_id": str(entity.book_id),
            "period": entity.period,
            "strategy": entity.strategy,
            "total_budget": str(entity.total_budget),
            "rules": entity.rules,
        }
    elif entity_type == "member_budget":
        data = {
            "family_budget_id": str(entity.family_budget_id),
            "allocated": str(entity.allocated),
            "spent": str(entity.spent),
            "category_spent": entity.category_spent,
        }
    elif entity_type == "family_saving_goal":
        data = {
            "book_id": str(entity.book_id),
            "name": entity.name,
            "description": entity.description,
            "icon": entity.icon,
            "target_amount": str(entity.target_amount),
            "current_amount": str(entity.current_amount),
            "deadline": entity.deadline.isoformat() if entity.deadline else None,
            "status": entity.status,
            "created_by": str(entity.created_by),
            "completed_at": entity.completed_at.isoformat() if entity.completed_at else None,
        }
    elif entity_type == "goal_contribution":
        data = {
            "goal_id": str(entity.goal_id),
            "amount": str(entity.amount),
            "note": entity.note,
        }
    elif entity_type == "transaction_split":
        data = {
            "transaction_id": str(entity.transaction_id),
            "split_type": entity.split_type,
            "status": entity.status,
            "settled_at": entity.settled_at.isoformat() if entity.settled_at else None,
        }
    elif entity_type == "split_participant":
        data = {
            "split_id": str(entity.split_id),
            "amount": str(entity.amount),
            "percentage": str(entity.percentage) if entity.percentage else None,
            "shares": entity.shares,
            "is_payer": entity.is_payer,
            "is_settled": entity.is_settled,
            "settled_at": entity.settled_at.isoformat() if entity.settled_at else None,
        }

    # ============== Money Age Entities ==============
    elif entity_type == "resource_pool":
        data = {
            "book_id": str(entity.book_id),
            "income_transaction_id": str(entity.income_transaction_id),
            "original_amount": str(entity.original_amount),
            "remaining_amount": str(entity.remaining_amount),
            "consumed_amount": str(entity.consumed_amount),
            "income_date": entity.income_date.isoformat() if entity.income_date else None,
            "first_consumed_date": entity.first_consumed_date.isoformat() if entity.first_consumed_date else None,
            "last_consumed_date": entity.last_consumed_date.isoformat() if entity.last_consumed_date else None,
            "fully_consumed_date": entity.fully_consumed_date.isoformat() if entity.fully_consumed_date else None,
            "is_fully_consumed": entity.is_fully_consumed,
            "consumption_count": entity.consumption_count,
            "account_id": str(entity.account_id),
            "income_category_id": str(entity.income_category_id),
        }
    elif entity_type == "consumption_record":
        data = {
            "resource_pool_id": str(entity.resource_pool_id),
            "expense_transaction_id": str(entity.expense_transaction_id),
            "consumed_amount": str(entity.consumed_amount),
            "consumption_date": entity.consumption_date.isoformat() if entity.consumption_date else None,
            "money_age_days": entity.money_age_days,
            "book_id": str(entity.book_id),
        }
    elif entity_type == "money_age_snapshot":
        data = {
            "book_id": str(entity.book_id),
            "snapshot_date": entity.snapshot_date.isoformat() if entity.snapshot_date else None,
            "snapshot_type": entity.snapshot_type,
            "avg_money_age": str(entity.avg_money_age),
            "median_money_age": entity.median_money_age,
            "min_money_age": entity.min_money_age,
            "max_money_age": entity.max_money_age,
            "health_level": entity.health_level,
            "health_count": entity.health_count,
            "warning_count": entity.warning_count,
            "danger_count": entity.danger_count,
            "total_resource_pools": entity.total_resource_pools,
            "active_resource_pools": entity.active_resource_pools,
            "total_remaining_amount": str(entity.total_remaining_amount),
            "total_transactions": entity.total_transactions,
            "expense_transactions": entity.expense_transactions,
            "income_transactions": entity.income_transactions,
            "category_breakdown": entity.category_breakdown,
            "monthly_trend": entity.monthly_trend,
        }
    elif entity_type == "money_age_config":
        data = {
            "book_id": str(entity.book_id),
            "consumption_strategy": entity.consumption_strategy,
            "health_threshold": entity.health_threshold,
            "warning_threshold": entity.warning_threshold,
            "enable_daily_snapshot": entity.enable_daily_snapshot,
            "enable_weekly_snapshot": entity.enable_weekly_snapshot,
            "enable_monthly_snapshot": entity.enable_monthly_snapshot,
            "enable_notifications": entity.enable_notifications,
            "notify_on_warning": entity.notify_on_warning,
            "notify_on_danger": entity.notify_on_danger,
        }

    # ============== Location Entities ==============
    elif entity_type == "geo_fence":
        data = {
            "name": entity.name,
            "center_latitude": str(entity.center_latitude),
            "center_longitude": str(entity.center_longitude),
            "radius_meters": entity.radius_meters,
            "place_name": entity.place_name,
            "action": entity.action,
            "linked_category_id": str(entity.linked_category_id) if entity.linked_category_id else None,
            "linked_vault_id": entity.linked_vault_id,
            "budget_limit": str(entity.budget_limit) if entity.budget_limit else None,
            "is_enabled": entity.is_enabled,
        }
    elif entity_type == "frequent_location":
        data = {
            "latitude": str(entity.latitude),
            "longitude": str(entity.longitude),
            "place_name": entity.place_name,
            "address": entity.address,
            "city": entity.city,
            "district": entity.district,
            "location_type": entity.location_type,
            "poi_id": entity.poi_id,
            "visit_count": entity.visit_count,
            "total_spent": str(entity.total_spent),
            "default_category_id": str(entity.default_category_id) if entity.default_category_id else None,
            "default_vault_id": entity.default_vault_id,
            "last_visit_at": entity.last_visit_at.isoformat() if entity.last_visit_at else None,
        }
    elif entity_type == "user_home_location":
        data = {
            "location_role": entity.location_role,
            "name": entity.name,
            "latitude": str(entity.latitude),
            "longitude": str(entity.longitude),
            "city": entity.city,
            "radius_meters": entity.radius_meters,
            "is_primary": entity.is_primary,
            "is_enabled": entity.is_enabled,
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
