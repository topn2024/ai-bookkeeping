"""Money Age API endpoints."""
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.money_age import ResourcePool, ConsumptionRecord, MoneyAgeSnapshot, MoneyAgeConfig
from app.models.transaction import Transaction
from app.schemas.money_age import (
    ResourcePoolCreate, ResourcePoolUpdate, ResourcePoolResponse,
    ConsumptionRecordResponse,
    MoneyAgeCalculateRequest, MoneyAgeCalculateResponse,
    MoneyAgeDashboardResponse,
    MoneyAgeTrendRequest, MoneyAgeTrendResponse,
    MoneyAgeHealthResponse, HealthLevelDistribution,
    MoneyAgeSnapshotResponse,
    MoneyAgeConfigCreate, MoneyAgeConfigUpdate, MoneyAgeConfigResponse,
    MoneyAgeRebuildRequest, MoneyAgeRebuildResponse,
)

router = APIRouter(prefix="/money-age", tags=["Money Age"])


# ============== Resource Pool Endpoints ==============

@router.get("/resource-pools", response_model=List[ResourcePoolResponse])
async def list_resource_pools(
    book_id: UUID,
    is_fully_consumed: Optional[bool] = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List resource pools for a book."""
    query = select(ResourcePool).where(
        and_(ResourcePool.user_id == current_user.id, ResourcePool.book_id == book_id)
    )
    if is_fully_consumed is not None:
        query = query.where(ResourcePool.is_fully_consumed == is_fully_consumed)
    query = query.order_by(ResourcePool.income_date.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


@router.get("/resource-pools/{pool_id}", response_model=ResourcePoolResponse)
async def get_resource_pool(
    pool_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a specific resource pool."""
    result = await db.execute(
        select(ResourcePool).where(
            and_(ResourcePool.id == pool_id, ResourcePool.user_id == current_user.id)
        )
    )
    pool = result.scalar_one_or_none()
    if not pool:
        raise HTTPException(status_code=404, detail="Resource pool not found")
    return pool


# ============== Consumption Record Endpoints ==============

@router.get("/consumption-records", response_model=List[ConsumptionRecordResponse])
async def list_consumption_records(
    book_id: UUID,
    resource_pool_id: Optional[UUID] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List consumption records."""
    query = select(ConsumptionRecord).where(
        and_(ConsumptionRecord.user_id == current_user.id, ConsumptionRecord.book_id == book_id)
    )
    if resource_pool_id:
        query = query.where(ConsumptionRecord.resource_pool_id == resource_pool_id)
    if start_date:
        query = query.where(ConsumptionRecord.consumption_date >= start_date)
    if end_date:
        query = query.where(ConsumptionRecord.consumption_date <= end_date)
    query = query.order_by(ConsumptionRecord.consumption_date.desc()).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


# ============== Money Age Calculation ==============

@router.post("/calculate", response_model=MoneyAgeCalculateResponse)
async def calculate_money_age(
    data: MoneyAgeCalculateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Calculate money age for a transaction using FIFO strategy."""
    # Get the transaction
    tx_result = await db.execute(
        select(Transaction).where(
            and_(Transaction.id == data.transaction_id, Transaction.user_id == current_user.id)
        )
    )
    transaction = tx_result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")

    if transaction.transaction_type != 1:  # Only for expenses
        raise HTTPException(status_code=400, detail="Money age only applies to expenses")

    # Skip if already calculated and not forcing recalculation
    if transaction.money_age is not None and not data.force_recalculate:
        return MoneyAgeCalculateResponse(
            transaction_id=transaction.id,
            money_age=transaction.money_age,
            money_age_level=transaction.money_age_level or "health",
            consumption_breakdown=[],
            resource_pools_used=0,
            calculation_timestamp=datetime.now(),
        )

    # Get available resource pools (FIFO - oldest first)
    pools_result = await db.execute(
        select(ResourcePool).where(
            and_(
                ResourcePool.user_id == current_user.id,
                ResourcePool.book_id == data.book_id,
                ResourcePool.is_fully_consumed == False,
                ResourcePool.remaining_amount > 0,
            )
        ).order_by(ResourcePool.income_date.asc())
    )
    pools = pools_result.scalars().all()

    remaining_amount = float(transaction.amount)
    if remaining_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transaction amount must be positive",
        )
    total_weighted_age = 0.0
    consumption_breakdown = []
    pools_used = 0
    tx_date = transaction.transaction_date

    for pool in pools:
        if remaining_amount <= 0:
            break

        consume_amount = min(float(pool.remaining_amount), remaining_amount)
        age_days = (tx_date - pool.income_date).days
        if age_days < 0:
            age_days = 0  # Treat future-dated income as 0 age

        # Create consumption record
        record = ConsumptionRecord(
            resource_pool_id=pool.id,
            expense_transaction_id=transaction.id,
            consumed_amount=Decimal(str(consume_amount)),
            consumption_date=tx_date,
            money_age_days=age_days,
            user_id=current_user.id,
            book_id=data.book_id,
        )
        db.add(record)

        # Update pool
        pool.remaining_amount -= Decimal(str(consume_amount))
        pool.consumed_amount += Decimal(str(consume_amount))
        pool.consumption_count += 1
        pool.last_consumed_date = tx_date
        if pool.first_consumed_date is None:
            pool.first_consumed_date = tx_date
        if pool.remaining_amount <= 0:
            pool.is_fully_consumed = True
            pool.fully_consumed_date = tx_date

        total_weighted_age += consume_amount * age_days
        remaining_amount -= consume_amount
        pools_used += 1

        consumption_breakdown.append({
            "pool_id": str(pool.id),
            "consumed_amount": consume_amount,
            "money_age_days": age_days,
        })

    # Calculate weighted average money age
    money_age = int(total_weighted_age / float(transaction.amount)) if float(transaction.amount) > 0 else 0

    # Determine health level
    config = await _get_user_config(db, current_user.id, data.book_id)
    if money_age < config.health_threshold:
        level = "health"
    elif money_age < config.warning_threshold:
        level = "warning"
    else:
        level = "danger"

    # Update transaction
    transaction.money_age = money_age
    transaction.money_age_level = level

    await db.commit()

    return MoneyAgeCalculateResponse(
        transaction_id=transaction.id,
        money_age=money_age,
        money_age_level=level,
        consumption_breakdown=consumption_breakdown,
        resource_pools_used=pools_used,
        calculation_timestamp=datetime.now(),
    )


# ============== Dashboard & Analytics ==============

@router.get("/dashboard", response_model=MoneyAgeDashboardResponse)
async def get_dashboard(
    book_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get money age dashboard data."""
    # Get average money age from recent expenses
    avg_result = await db.execute(
        select(func.avg(Transaction.money_age)).where(
            and_(
                Transaction.user_id == current_user.id,
                Transaction.book_id == book_id,
                Transaction.transaction_type == 1,
                Transaction.money_age.isnot(None),
            )
        )
    )
    avg_money_age = avg_result.scalar() or Decimal(0)

    # Get health distribution
    health_result = await db.execute(
        select(
            Transaction.money_age_level,
            func.count(Transaction.id),
        ).where(
            and_(
                Transaction.user_id == current_user.id,
                Transaction.book_id == book_id,
                Transaction.transaction_type == 1,
                Transaction.money_age_level.isnot(None),
            )
        ).group_by(Transaction.money_age_level)
    )
    health_counts = {row[0]: row[1] for row in health_result.all()}

    # Get resource pool stats
    pool_result = await db.execute(
        select(
            func.count(ResourcePool.id),
            func.sum(ResourcePool.remaining_amount),
        ).where(
            and_(
                ResourcePool.user_id == current_user.id,
                ResourcePool.book_id == book_id,
            )
        )
    )
    pool_stats = pool_result.one()

    active_pools_result = await db.execute(
        select(func.count(ResourcePool.id)).where(
            and_(
                ResourcePool.user_id == current_user.id,
                ResourcePool.book_id == book_id,
                ResourcePool.is_fully_consumed == False,
            )
        )
    )
    active_pools = active_pools_result.scalar() or 0

    # Determine overall health level
    total = sum(health_counts.values()) if health_counts else 0
    if total == 0:
        current_level = "health"
    elif health_counts.get("danger", 0) > total * 0.3:
        current_level = "danger"
    elif health_counts.get("warning", 0) > total * 0.3:
        current_level = "warning"
    else:
        current_level = "health"

    # Get trend data from snapshots (last 30 days)
    from datetime import timedelta
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=30)

    snapshot_result = await db.execute(
        select(MoneyAgeSnapshot).where(
            and_(
                MoneyAgeSnapshot.user_id == current_user.id,
                MoneyAgeSnapshot.book_id == book_id,
                MoneyAgeSnapshot.snapshot_type == 'daily',
                MoneyAgeSnapshot.snapshot_date >= start_date,
                MoneyAgeSnapshot.snapshot_date <= end_date,
            )
        ).order_by(MoneyAgeSnapshot.snapshot_date.asc())
    )
    snapshots = snapshot_result.scalars().all()

    trend_data = [
        {
            "date": snapshot.snapshot_date.isoformat(),
            "avg_age": float(snapshot.avg_money_age),
        }
        for snapshot in snapshots
    ]

    # If no snapshots, calculate from transactions grouped by date
    if not trend_data:
        tx_trend_result = await db.execute(
            select(
                func.date(Transaction.transaction_date).label('tx_date'),
                func.avg(Transaction.money_age).label('avg_age'),
            ).where(
                and_(
                    Transaction.user_id == current_user.id,
                    Transaction.book_id == book_id,
                    Transaction.transaction_type == 1,  # Expenses only
                    Transaction.money_age.isnot(None),
                    Transaction.transaction_date >= start_date,
                )
            ).group_by(func.date(Transaction.transaction_date))
            .order_by(func.date(Transaction.transaction_date).asc())
        )
        tx_trends = tx_trend_result.all()
        trend_data = [
            {
                "date": row.tx_date.isoformat(),
                "avg_age": float(row.avg_age) if row.avg_age else 0.0,
            }
            for row in tx_trends
        ]

    return MoneyAgeDashboardResponse(
        user_id=current_user.id,
        book_id=book_id,
        avg_money_age=avg_money_age,
        median_money_age=int(avg_money_age),  # Simplified
        current_health_level=current_level,
        health_count=health_counts.get("health", 0),
        warning_count=health_counts.get("warning", 0),
        danger_count=health_counts.get("danger", 0),
        total_resource_pools=pool_stats[0] or 0,
        active_resource_pools=active_pools,
        total_remaining_amount=pool_stats[1] or Decimal(0),
        recent_transactions=[],
        trend_data=trend_data,
    )


@router.post("/trend", response_model=MoneyAgeTrendResponse)
async def get_trend(
    data: MoneyAgeTrendRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get money age trend data."""
    # Get snapshots for the period
    result = await db.execute(
        select(MoneyAgeSnapshot).where(
            and_(
                MoneyAgeSnapshot.user_id == current_user.id,
                MoneyAgeSnapshot.book_id == data.book_id,
                MoneyAgeSnapshot.snapshot_date >= data.start_date,
                MoneyAgeSnapshot.snapshot_date <= data.end_date,
                MoneyAgeSnapshot.snapshot_type == data.granularity,
            )
        ).order_by(MoneyAgeSnapshot.snapshot_date.asc())
    )
    snapshots = result.scalars().all()

    data_points = [
        {
            "date": s.snapshot_date.isoformat(),
            "avg_money_age": float(s.avg_money_age),
            "health_level": s.health_level,
        }
        for s in snapshots
    ]

    # Calculate trend
    if len(data_points) >= 2:
        first_avg = data_points[0]["avg_money_age"]
        last_avg = data_points[-1]["avg_money_age"]
        if last_avg < first_avg * 0.9:
            trend = "improving"
        elif last_avg > first_avg * 1.1:
            trend = "declining"
        else:
            trend = "stable"
    else:
        trend = "stable"

    avg_overall = sum(d["avg_money_age"] for d in data_points) / len(data_points) if data_points else 0

    return MoneyAgeTrendResponse(
        book_id=data.book_id,
        start_date=data.start_date,
        end_date=data.end_date,
        granularity=data.granularity,
        data_points=data_points,
        avg_money_age=Decimal(str(avg_overall)),
        trend=trend,
    )


@router.get("/health", response_model=MoneyAgeHealthResponse)
async def get_health_analysis(
    book_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get money age health analysis."""
    config = await _get_user_config(db, current_user.id, book_id)

    # Get distribution by level
    result = await db.execute(
        select(
            Transaction.money_age_level,
            func.count(Transaction.id),
            func.sum(Transaction.amount),
            func.avg(Transaction.money_age),
        ).where(
            and_(
                Transaction.user_id == current_user.id,
                Transaction.book_id == book_id,
                Transaction.transaction_type == 1,
                Transaction.money_age_level.isnot(None),
            )
        ).group_by(Transaction.money_age_level)
    )
    rows = result.all()

    total_count = sum(r[1] for r in rows) if rows else 0
    distributions = []
    for row in rows:
        distributions.append(HealthLevelDistribution(
            level=row[0],
            count=row[1],
            percentage=Decimal(str(row[1] / total_count * 100)) if total_count > 0 else Decimal(0),
            total_amount=row[2] or Decimal(0),
            avg_money_age=Decimal(str(row[3] or 0)),
        ))

    # Determine overall level
    danger_pct = next((d.percentage for d in distributions if d.level == "danger"), Decimal(0))
    warning_pct = next((d.percentage for d in distributions if d.level == "warning"), Decimal(0))

    if danger_pct > 30:
        overall = "danger"
    elif warning_pct > 30:
        overall = "warning"
    else:
        overall = "health"

    # Generate recommendations
    recommendations = []
    if overall == "danger":
        recommendations.append("建议增加收入或减少支出，改善资金周转")
    if overall == "warning":
        recommendations.append("注意控制消费节奏，避免资金紧张")

    return MoneyAgeHealthResponse(
        book_id=book_id,
        overall_level=overall,
        distributions=distributions,
        recommendations=recommendations,
    )


# ============== Snapshots ==============

@router.get("/snapshots", response_model=List[MoneyAgeSnapshotResponse])
async def list_snapshots(
    book_id: UUID,
    snapshot_type: Optional[str] = Query(None, pattern="^(daily|weekly|monthly)$"),
    limit: int = Query(30, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List money age snapshots."""
    query = select(MoneyAgeSnapshot).where(
        and_(MoneyAgeSnapshot.user_id == current_user.id, MoneyAgeSnapshot.book_id == book_id)
    )
    if snapshot_type:
        query = query.where(MoneyAgeSnapshot.snapshot_type == snapshot_type)
    query = query.order_by(MoneyAgeSnapshot.snapshot_date.desc()).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


# ============== Configuration ==============

@router.get("/config", response_model=MoneyAgeConfigResponse)
async def get_config(
    book_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get money age configuration."""
    config = await _get_user_config(db, current_user.id, book_id)
    return config


@router.put("/config", response_model=MoneyAgeConfigResponse)
async def update_config(
    data: MoneyAgeConfigUpdate,
    book_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update money age configuration."""
    result = await db.execute(
        select(MoneyAgeConfig).where(MoneyAgeConfig.user_id == current_user.id)
    )
    config = result.scalar_one_or_none()

    if not config:
        config = MoneyAgeConfig(user_id=current_user.id, book_id=book_id)
        db.add(config)

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(config, field, value)

    await db.commit()
    await db.refresh(config)
    return config


# ============== Rebuild ==============

@router.post("/rebuild", response_model=MoneyAgeRebuildResponse)
async def rebuild_money_age(
    data: MoneyAgeRebuildRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Rebuild money age data for a book."""
    started_at = datetime.now()
    errors = []

    try:
        # Clear existing data if requested
        if data.clear_existing:
            await db.execute(
                ConsumptionRecord.__table__.delete().where(
                    and_(ConsumptionRecord.user_id == current_user.id, ConsumptionRecord.book_id == data.book_id)
                )
            )
            await db.execute(
                ResourcePool.__table__.delete().where(
                    and_(ResourcePool.user_id == current_user.id, ResourcePool.book_id == data.book_id)
                )
            )

        # Get income transactions to create resource pools (with limit for performance)
        income_query = select(Transaction).where(
            and_(
                Transaction.user_id == current_user.id,
                Transaction.book_id == data.book_id,
                Transaction.transaction_type == 2,  # Income
            )
        )
        if data.start_date:
            income_query = income_query.where(Transaction.transaction_date >= data.start_date)
        if data.end_date:
            income_query = income_query.where(Transaction.transaction_date <= data.end_date)

        income_result = await db.execute(income_query.order_by(Transaction.transaction_date.asc()).limit(10000))
        incomes = income_result.scalars().all()

        created_pools = 0
        for tx in incomes:
            pool = ResourcePool(
                user_id=current_user.id,
                book_id=data.book_id,
                income_transaction_id=tx.id,
                original_amount=tx.amount,
                remaining_amount=tx.amount,
                income_date=tx.transaction_date,
                account_id=tx.account_id,
                income_category_id=tx.category_id,
            )
            db.add(pool)
            created_pools += 1

        await db.commit()

        # Process expenses (with limit for performance)
        expense_query = select(Transaction).where(
            and_(
                Transaction.user_id == current_user.id,
                Transaction.book_id == data.book_id,
                Transaction.transaction_type == 1,  # Expense
            )
        )
        if data.start_date:
            expense_query = expense_query.where(Transaction.transaction_date >= data.start_date)
        if data.end_date:
            expense_query = expense_query.where(Transaction.transaction_date <= data.end_date)

        expense_result = await db.execute(expense_query.order_by(Transaction.transaction_date.asc()).limit(10000))
        expenses = expense_result.scalars().all()

        created_records = 0
        for tx in expenses:
            try:
                # Calculate money age for each expense
                await calculate_money_age(
                    MoneyAgeCalculateRequest(
                        transaction_id=tx.id,
                        book_id=data.book_id,
                        force_recalculate=True,
                    ),
                    db=db,
                    current_user=current_user,
                )
                created_records += 1
            except Exception as e:
                errors.append(f"Transaction {tx.id}: {str(e)}")

        completed_at = datetime.now()

        return MoneyAgeRebuildResponse(
            book_id=data.book_id,
            status="success" if not errors else "partial",
            processed_transactions=len(incomes) + len(expenses),
            created_resource_pools=created_pools,
            created_consumption_records=created_records,
            errors=errors,
            started_at=started_at,
            completed_at=completed_at,
            duration_seconds=(completed_at - started_at).total_seconds(),
        )

    except Exception as e:
        return MoneyAgeRebuildResponse(
            book_id=data.book_id,
            status="failed",
            processed_transactions=0,
            created_resource_pools=0,
            created_consumption_records=0,
            errors=[str(e)],
            started_at=started_at,
            completed_at=datetime.now(),
            duration_seconds=(datetime.now() - started_at).total_seconds(),
        )


# ============== Helper Functions ==============

async def _get_user_config(db: AsyncSession, user_id: UUID, book_id: UUID) -> MoneyAgeConfig:
    """Get or create user's money age config."""
    result = await db.execute(
        select(MoneyAgeConfig).where(MoneyAgeConfig.user_id == user_id)
    )
    config = result.scalar_one_or_none()

    if not config:
        config = MoneyAgeConfig(user_id=user_id, book_id=book_id)
        db.add(config)
        await db.commit()
        await db.refresh(config)

    return config
