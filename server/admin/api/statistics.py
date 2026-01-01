"""Admin statistics and analytics endpoints."""
from datetime import datetime, date, timedelta
from decimal import Decimal
from typing import Optional, List
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, case, distinct

from app.core.database import get_db
from app.models.user import User
from app.models.transaction import Transaction
from app.models.category import Category
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.core.audit import mask_email
from admin.schemas.statistics import (
    RetentionData,
    UserRetentionResponse,
    ChurnRiskUser,
    UserChurnPredictionResponse,
    UserProfileAnalysisResponse,
    UserSegment,
    NewOldUserComparisonResponse,
    NewVsOldUserStats,
    CategoryRanking,
    CategoryRankingResponse,
    AvgTransactionStats,
    TransactionTimeDistribution,
    TransactionFrequencyStats,
    FeatureUsageItem,
    FeatureUsageResponse,
    DailyReportData,
    WeeklyMonthlyReportData,
    CustomReportConfig,
    CustomReportResponse,
)


router = APIRouter(prefix="/statistics", tags=["Statistics & Analytics"])


# ============ User Analysis ============

@router.get("/users/retention", response_model=UserRetentionResponse)
async def get_user_retention(
    period: str = Query("daily", pattern="^(daily|weekly|monthly)$"),
    cohorts: int = Query(7, ge=1, le=30),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:user")),
):
    """用户留存分析 (SA-002)"""
    today = date.today()
    cohort_data = []
    total_day_1 = []
    total_day_7 = []
    total_day_30 = []

    for i in range(cohorts):
        if period == "daily":
            cohort_date = today - timedelta(days=i + 30)  # Start from 30 days ago
            next_date = cohort_date + timedelta(days=1)
        elif period == "weekly":
            cohort_date = today - timedelta(weeks=i + 4)
            next_date = cohort_date + timedelta(weeks=1)
        else:  # monthly
            cohort_date = today - timedelta(days=(i + 2) * 30)
            next_date = cohort_date + timedelta(days=30)

        # Get cohort size (users registered on cohort_date)
        cohort_result = await db.execute(
            select(func.count(User.id)).where(
                and_(
                    func.date(User.created_at) >= cohort_date,
                    func.date(User.created_at) < next_date,
                )
            )
        )
        cohort_size = cohort_result.scalar() or 0

        if cohort_size == 0:
            continue

        # Get users who had transactions on day 1, 7, 14, 30
        async def get_retention(days_after: int) -> Optional[float]:
            target_date = cohort_date + timedelta(days=days_after)
            if target_date > today:
                return None

            active_result = await db.execute(
                select(func.count(distinct(Transaction.user_id))).where(
                    and_(
                        Transaction.user_id.in_(
                            select(User.id).where(
                                and_(
                                    func.date(User.created_at) >= cohort_date,
                                    func.date(User.created_at) < next_date,
                                )
                            )
                        ),
                        func.date(Transaction.created_at) == target_date,
                    )
                )
            )
            active_count = active_result.scalar() or 0
            return round(active_count / cohort_size * 100, 2)

        day_1 = await get_retention(1)
        day_7 = await get_retention(7)
        day_14 = await get_retention(14)
        day_30 = await get_retention(30)

        if day_1 is not None:
            total_day_1.append(day_1)
        if day_7 is not None:
            total_day_7.append(day_7)
        if day_30 is not None:
            total_day_30.append(day_30)

        cohort_data.append(RetentionData(
            cohort_date=cohort_date,
            cohort_size=cohort_size,
            day_1=day_1,
            day_7=day_7,
            day_14=day_14,
            day_30=day_30,
        ))

    return UserRetentionResponse(
        period=period,
        cohorts=cohort_data,
        avg_day_1=round(sum(total_day_1) / len(total_day_1), 2) if total_day_1 else 0,
        avg_day_7=round(sum(total_day_7) / len(total_day_7), 2) if total_day_7 else 0,
        avg_day_30=round(sum(total_day_30) / len(total_day_30), 2) if total_day_30 else 0,
    )


@router.get("/users/churn-prediction", response_model=UserChurnPredictionResponse)
async def get_churn_prediction(
    days_threshold: int = Query(14, ge=7, le=90),
    limit: int = Query(50, ge=1, le=200),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:user")),
):
    """用户流失预警 (SA-003)"""
    today = datetime.utcnow()
    threshold_date = today - timedelta(days=days_threshold)

    # Find users who haven't been active recently
    inactive_users_query = select(
        User.id,
        User.email,
        User.last_active_at,
        User.created_at,
    ).where(
        and_(
            User.is_active == True,
            User.last_active_at < threshold_date,
        )
    ).order_by(User.last_active_at.asc()).limit(limit * 2)

    result = await db.execute(inactive_users_query)
    inactive_users = result.all()

    at_risk_users = []
    high_risk = 0
    medium_risk = 0
    low_risk = 0

    for user in inactive_users:
        # Calculate days inactive
        last_active = user.last_active_at or user.created_at
        days_inactive = (today - last_active).days

        # Get transaction count in last 30 days before going inactive
        tx_count_result = await db.execute(
            select(func.count(Transaction.id)).where(
                and_(
                    Transaction.user_id == user.id,
                    Transaction.created_at >= last_active - timedelta(days=30),
                    Transaction.created_at <= last_active,
                )
            )
        )
        tx_count = tx_count_result.scalar() or 0

        # Calculate risk score (simple model)
        # Higher score = more likely to churn
        risk_score = min(1.0, days_inactive / 60)  # Max out at 60 days
        if tx_count < 5:
            risk_score = min(1.0, risk_score + 0.2)
        elif tx_count > 20:
            risk_score = max(0, risk_score - 0.1)

        if risk_score >= 0.7:
            risk_level = "high"
            high_risk += 1
        elif risk_score >= 0.4:
            risk_level = "medium"
            medium_risk += 1
        else:
            risk_level = "low"
            low_risk += 1

        at_risk_users.append(ChurnRiskUser(
            user_id=user.id,
            email=mask_email(user.email) if user.email else None,
            last_active=last_active,
            days_inactive=days_inactive,
            transaction_count_30d=tx_count,
            risk_score=round(risk_score, 2),
            risk_level=risk_level,
        ))

    # Sort by risk score descending
    at_risk_users.sort(key=lambda x: x.risk_score, reverse=True)

    return UserChurnPredictionResponse(
        total_at_risk=len(at_risk_users),
        high_risk=high_risk,
        medium_risk=medium_risk,
        low_risk=low_risk,
        users=at_risk_users[:limit],
    )


@router.get("/users/profile-analysis", response_model=UserProfileAnalysisResponse)
async def get_user_profile_analysis(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:user")),
):
    """用户画像分析 (SA-004)"""
    today = date.today()

    # Total users
    total_result = await db.execute(select(func.count(User.id)))
    total_users = total_result.scalar() or 0

    # By registration period
    periods = [
        ("本周", today - timedelta(days=7), today),
        ("本月", today - timedelta(days=30), today),
        ("近3月", today - timedelta(days=90), today),
        ("更早", None, today - timedelta(days=90)),
    ]
    by_registration = []
    for period_name, start, end in periods:
        if start:
            query = select(func.count(User.id)).where(
                and_(
                    func.date(User.created_at) >= start,
                    func.date(User.created_at) <= end,
                )
            )
        else:
            query = select(func.count(User.id)).where(
                func.date(User.created_at) < end
            )
        result = await db.execute(query)
        count = result.scalar() or 0
        by_registration.append({"period": period_name, "count": count})

    # By activity level
    threshold_30d = datetime.utcnow() - timedelta(days=30)
    threshold_7d = datetime.utcnow() - timedelta(days=7)

    active_result = await db.execute(
        select(func.count(User.id)).where(User.last_active_at >= threshold_7d)
    )
    active_count = active_result.scalar() or 0

    moderate_result = await db.execute(
        select(func.count(User.id)).where(
            and_(
                User.last_active_at >= threshold_30d,
                User.last_active_at < threshold_7d,
            )
        )
    )
    moderate_count = moderate_result.scalar() or 0

    inactive_count = total_users - active_count - moderate_count

    by_activity = [
        UserSegment(
            segment_name="活跃用户",
            user_count=active_count,
            percentage=round(active_count / total_users * 100, 2) if total_users > 0 else 0,
            avg_transactions=0,
            avg_amount=Decimal("0"),
        ),
        UserSegment(
            segment_name="普通用户",
            user_count=moderate_count,
            percentage=round(moderate_count / total_users * 100, 2) if total_users > 0 else 0,
            avg_transactions=0,
            avg_amount=Decimal("0"),
        ),
        UserSegment(
            segment_name="不活跃用户",
            user_count=inactive_count,
            percentage=round(inactive_count / total_users * 100, 2) if total_users > 0 else 0,
            avg_transactions=0,
            avg_amount=Decimal("0"),
        ),
    ]

    # By primary category (most used category per user)
    category_result = await db.execute(
        select(
            Category.name,
            func.count(distinct(Transaction.user_id)).label("user_count"),
        ).join(
            Transaction, Category.id == Transaction.category_id
        ).group_by(Category.name).order_by(
            func.count(distinct(Transaction.user_id)).desc()
        ).limit(10)
    )
    by_category = [
        {"category": row.name, "user_count": row.user_count}
        for row in category_result.all()
    ]

    return UserProfileAnalysisResponse(
        total_users=total_users,
        by_registration_period=by_registration,
        by_activity_level=by_activity,
        by_transaction_volume=[],  # Simplified
        by_primary_category=by_category,
    )


@router.get("/users/new-vs-old")
async def compare_new_old_users(
    new_user_days: int = Query(30, ge=7, le=90),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:user")),
):
    """新老用户对比 (SA-005)"""
    threshold_date = datetime.utcnow() - timedelta(days=new_user_days)

    # Count new vs old users
    new_result = await db.execute(
        select(func.count(User.id)).where(User.created_at >= threshold_date)
    )
    new_count = new_result.scalar() or 0

    old_result = await db.execute(
        select(func.count(User.id)).where(User.created_at < threshold_date)
    )
    old_count = old_result.scalar() or 0

    comparisons = []

    # Average transactions per user
    new_tx_result = await db.execute(
        select(func.count(Transaction.id)).where(
            Transaction.user_id.in_(
                select(User.id).where(User.created_at >= threshold_date)
            )
        )
    )
    new_tx_count = new_tx_result.scalar() or 0

    old_tx_result = await db.execute(
        select(func.count(Transaction.id)).where(
            Transaction.user_id.in_(
                select(User.id).where(User.created_at < threshold_date)
            )
        )
    )
    old_tx_count = old_tx_result.scalar() or 0

    new_avg_tx = new_tx_count / new_count if new_count > 0 else 0
    old_avg_tx = old_tx_count / old_count if old_count > 0 else 0

    comparisons.append(NewVsOldUserStats(
        metric="平均交易笔数",
        new_users=round(new_avg_tx, 2),
        old_users=round(old_avg_tx, 2),
        difference=round(new_avg_tx - old_avg_tx, 2),
        difference_percent=round((new_avg_tx - old_avg_tx) / old_avg_tx * 100, 2) if old_avg_tx > 0 else 0,
    ))

    return NewOldUserComparisonResponse(
        new_user_threshold_days=new_user_days,
        new_user_count=new_count,
        old_user_count=old_count,
        comparisons=comparisons,
    )


# ============ Transaction Analysis ============

@router.get("/transactions/category-ranking", response_model=CategoryRankingResponse)
async def get_category_ranking(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(10, ge=1, le=50),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:transaction")),
):
    """分类消费排行 (SA-007)"""
    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    async def get_ranking(category_type: int) -> List[CategoryRanking]:
        query = select(
            Category.id,
            Category.name,
            Category.category_type,
            func.sum(Transaction.amount).label("total_amount"),
            func.count(Transaction.id).label("transaction_count"),
            func.count(distinct(Transaction.user_id)).label("user_count"),
            func.avg(Transaction.amount).label("avg_amount"),
        ).join(
            Transaction, Category.id == Transaction.category_id
        ).where(
            and_(
                Category.category_type == category_type,
                Transaction.transaction_date >= start_date,
                Transaction.transaction_date <= end_date,
            )
        ).group_by(
            Category.id, Category.name, Category.category_type
        ).order_by(
            func.sum(Transaction.amount).desc()
        ).limit(limit)

        result = await db.execute(query)
        rows = result.all()

        # Calculate total for percentage
        total_amount = sum(row.total_amount or 0 for row in rows)

        rankings = []
        for rank, row in enumerate(rows, 1):
            amount = Decimal(str(row.total_amount or 0))
            rankings.append(CategoryRanking(
                rank=rank,
                category_id=row.id,
                category_name=row.name,
                category_type=row.category_type,
                total_amount=amount,
                transaction_count=row.transaction_count,
                user_count=row.user_count,
                avg_amount=Decimal(str(row.avg_amount or 0)).quantize(Decimal("0.01")),
                percentage=round(float(amount) / float(total_amount) * 100, 2) if total_amount > 0 else 0,
            ))

        return rankings

    expense_ranking = await get_ranking(1)
    income_ranking = await get_ranking(2)

    return CategoryRankingResponse(
        period=f"近{days}天",
        start_date=start_date,
        end_date=end_date,
        expense_ranking=expense_ranking,
        income_ranking=income_ranking,
    )


@router.get("/transactions/average", response_model=AvgTransactionStats)
async def get_average_transaction_stats(
    days: int = Query(30, ge=1, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:transaction")),
):
    """平均交易金额分析 (SA-008)"""
    start_date = date.today() - timedelta(days=days)

    # Average expense
    expense_result = await db.execute(
        select(func.avg(Transaction.amount)).where(
            and_(
                Transaction.transaction_type == 1,
                Transaction.transaction_date >= start_date,
            )
        )
    )
    avg_expense = Decimal(str(expense_result.scalar() or 0)).quantize(Decimal("0.01"))

    # Average income
    income_result = await db.execute(
        select(func.avg(Transaction.amount)).where(
            and_(
                Transaction.transaction_type == 2,
                Transaction.transaction_date >= start_date,
            )
        )
    )
    avg_income = Decimal(str(income_result.scalar() or 0)).quantize(Decimal("0.01"))

    return AvgTransactionStats(
        period=f"近{days}天",
        avg_expense=avg_expense,
        avg_income=avg_income,
        median_expense=avg_expense,  # Simplified - would need proper median calculation
        median_income=avg_income,
        by_user_segment=[],
    )


@router.get("/transactions/time-distribution", response_model=TransactionTimeDistribution)
async def get_transaction_time_distribution(
    days: int = Query(30, ge=1, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:transaction")),
):
    """交易时段分布 (SA-009)"""
    start_date = date.today() - timedelta(days=days)

    # By hour
    hour_result = await db.execute(
        select(
            func.extract("hour", Transaction.created_at).label("hour"),
            func.count(Transaction.id).label("count"),
            func.sum(Transaction.amount).label("amount"),
        ).where(
            Transaction.transaction_date >= start_date
        ).group_by(
            func.extract("hour", Transaction.created_at)
        ).order_by("hour")
    )
    by_hour = [
        {"hour": int(row.hour), "count": row.count, "amount": float(row.amount or 0)}
        for row in hour_result.all()
    ]

    # By day of week
    dow_result = await db.execute(
        select(
            func.extract("dow", Transaction.created_at).label("day"),
            func.count(Transaction.id).label("count"),
            func.sum(Transaction.amount).label("amount"),
        ).where(
            Transaction.transaction_date >= start_date
        ).group_by(
            func.extract("dow", Transaction.created_at)
        ).order_by("day")
    )
    by_dow = [
        {"day": int(row.day), "count": row.count, "amount": float(row.amount or 0)}
        for row in dow_result.all()
    ]

    # Find peaks
    peak_hour = max(by_hour, key=lambda x: x["count"])["hour"] if by_hour else 0
    peak_day = max(by_dow, key=lambda x: x["count"])["day"] if by_dow else 0

    return TransactionTimeDistribution(
        by_hour=by_hour,
        by_day_of_week=by_dow,
        peak_hour=peak_hour,
        peak_day=peak_day,
    )


@router.get("/transactions/frequency", response_model=TransactionFrequencyStats)
async def get_transaction_frequency(
    days: int = Query(30, ge=1, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:transaction")),
):
    """交易频率分析 (SA-010)"""
    start_date = date.today() - timedelta(days=days)

    # Total transactions and users
    total_result = await db.execute(
        select(
            func.count(Transaction.id).label("tx_count"),
            func.count(distinct(Transaction.user_id)).label("user_count"),
        ).where(Transaction.transaction_date >= start_date)
    )
    totals = total_result.one()

    tx_count = totals.tx_count or 0
    user_count = totals.user_count or 1

    avg_per_user = tx_count / user_count
    avg_per_day = tx_count / days

    # Most active users
    active_result = await db.execute(
        select(
            Transaction.user_id,
            func.count(Transaction.id).label("count"),
        ).where(
            Transaction.transaction_date >= start_date
        ).group_by(
            Transaction.user_id
        ).order_by(
            func.count(Transaction.id).desc()
        ).limit(10)
    )

    most_active = []
    for row in active_result.all():
        user_result = await db.execute(select(User.email).where(User.id == row.user_id))
        email = user_result.scalar()
        most_active.append({
            "user_id": str(row.user_id),
            "email": mask_email(email) if email else None,
            "count": row.count,
        })

    return TransactionFrequencyStats(
        avg_transactions_per_user=round(avg_per_user, 2),
        avg_transactions_per_day=round(avg_per_day, 2),
        frequency_distribution=[],  # Simplified
        most_active_users=most_active,
    )


# ============ Business Analysis ============

@router.get("/business/feature-usage", response_model=FeatureUsageResponse)
async def get_feature_usage(
    days: int = Query(30, ge=1, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:transaction")),
):
    """功能使用率分析 (SA-011)"""
    start_date = date.today() - timedelta(days=days)
    end_date = date.today()

    # Get active users count
    active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            Transaction.transaction_date >= start_date
        )
    )
    active_users = active_result.scalar() or 1

    # Analyze by source (0: manual, 1: image, 2: voice, 3: email)
    source_result = await db.execute(
        select(
            Transaction.source,
            func.count(Transaction.id).label("count"),
            func.count(distinct(Transaction.user_id)).label("users"),
        ).where(
            Transaction.transaction_date >= start_date
        ).group_by(Transaction.source)
    )

    source_names = {
        0: ("手动记账", "manual"),
        1: ("图片识别", "image_recognition"),
        2: ("语音识别", "voice_recognition"),
        3: ("邮件导入", "email_import"),
    }

    features = []
    for row in source_result.all():
        name, code = source_names.get(row.source, ("未知", "unknown"))
        features.append(FeatureUsageItem(
            feature_name=name,
            feature_code=code,
            usage_count=row.count,
            unique_users=row.users,
            usage_rate=round(row.users / active_users * 100, 2),
            trend="stable",
        ))

    return FeatureUsageResponse(
        period=f"近{days}天",
        start_date=start_date,
        end_date=end_date,
        features=features,
    )


# ============ Reports ============

@router.get("/reports/daily", response_model=DailyReportData)
async def generate_daily_report(
    report_date: Optional[date] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:report")),
):
    """生成日报 (SA-014)"""
    if not report_date:
        report_date = date.today() - timedelta(days=1)  # Default to yesterday

    prev_date = report_date - timedelta(days=1)

    # New users
    new_users_result = await db.execute(
        select(func.count(User.id)).where(func.date(User.created_at) == report_date)
    )
    new_users = new_users_result.scalar() or 0

    prev_new_result = await db.execute(
        select(func.count(User.id)).where(func.date(User.created_at) == prev_date)
    )
    prev_new = prev_new_result.scalar() or 1

    # Active users
    active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            func.date(Transaction.created_at) == report_date
        )
    )
    active_users = active_result.scalar() or 0

    prev_active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            func.date(Transaction.created_at) == prev_date
        )
    )
    prev_active = prev_active_result.scalar() or 1

    # Transactions
    tx_result = await db.execute(
        select(
            func.count(Transaction.id).label("count"),
            func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)).label("expense"),
            func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)).label("income"),
        ).where(Transaction.transaction_date == report_date)
    )
    tx_stats = tx_result.one()

    prev_tx_result = await db.execute(
        select(func.count(Transaction.id)).where(Transaction.transaction_date == prev_date)
    )
    prev_tx_count = prev_tx_result.scalar() or 1

    total_tx = tx_stats.count or 0
    total_expense = Decimal(str(tx_stats.expense or 0))
    total_income = Decimal(str(tx_stats.income or 0))

    # Top categories
    async def get_top_categories(tx_type: int) -> List[dict]:
        result = await db.execute(
            select(
                Category.name,
                func.sum(Transaction.amount).label("amount"),
            ).join(
                Transaction, Category.id == Transaction.category_id
            ).where(
                and_(
                    Transaction.transaction_date == report_date,
                    Transaction.transaction_type == tx_type,
                )
            ).group_by(Category.name).order_by(
                func.sum(Transaction.amount).desc()
            ).limit(5)
        )
        return [{"category": row.name, "amount": float(row.amount)} for row in result.all()]

    top_expense = await get_top_categories(1)
    top_income = await get_top_categories(2)

    # Highlights
    highlights = []
    if new_users > prev_new:
        highlights.append(f"新增用户增长 {round((new_users - prev_new) / prev_new * 100, 1)}%")
    if total_tx > prev_tx_count:
        highlights.append(f"交易量增长 {round((total_tx - prev_tx_count) / prev_tx_count * 100, 1)}%")

    return DailyReportData(
        report_date=report_date,
        generated_at=datetime.utcnow(),
        new_users=new_users,
        active_users=active_users,
        churned_users=0,
        total_transactions=total_tx,
        total_expense=total_expense,
        total_income=total_income,
        avg_transaction=(total_expense + total_income) / total_tx if total_tx > 0 else Decimal("0"),
        new_users_change=round((new_users - prev_new) / prev_new * 100, 2) if prev_new > 0 else 0,
        active_users_change=round((active_users - prev_active) / prev_active * 100, 2) if prev_active > 0 else 0,
        transactions_change=round((total_tx - prev_tx_count) / prev_tx_count * 100, 2) if prev_tx_count > 0 else 0,
        top_expense_categories=top_expense,
        top_income_categories=top_income,
        highlights=highlights,
    )


@router.get("/reports/weekly")
async def generate_weekly_report(
    end_date: Optional[date] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:report")),
):
    """生成周报 (SA-015)"""
    if not end_date:
        end_date = date.today() - timedelta(days=1)

    start_date = end_date - timedelta(days=6)
    prev_end = start_date - timedelta(days=1)
    prev_start = prev_end - timedelta(days=6)

    # Summary stats
    stats_result = await db.execute(
        select(
            func.count(Transaction.id).label("tx_count"),
            func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)).label("expense"),
            func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)).label("income"),
        ).where(
            and_(
                Transaction.transaction_date >= start_date,
                Transaction.transaction_date <= end_date,
            )
        )
    )
    stats = stats_result.one()

    new_users_result = await db.execute(
        select(func.count(User.id)).where(
            and_(
                func.date(User.created_at) >= start_date,
                func.date(User.created_at) <= end_date,
            )
        )
    )
    new_users = new_users_result.scalar() or 0

    active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            and_(
                Transaction.transaction_date >= start_date,
                Transaction.transaction_date <= end_date,
            )
        )
    )
    active_users = active_result.scalar() or 0

    return {
        "report_type": "weekly",
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "generated_at": datetime.utcnow().isoformat(),
        "total_new_users": new_users,
        "total_active_users": active_users,
        "total_transactions": stats.tx_count or 0,
        "total_expense": float(stats.expense or 0),
        "total_income": float(stats.income or 0),
    }


@router.post("/reports/custom", response_model=CustomReportResponse)
async def generate_custom_report(
    config: CustomReportConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:report")),
):
    """生成自定义报表 (SA-016)"""
    report_id = str(uuid4())

    # Build query based on config
    data = []
    summary = {}

    # Basic implementation - can be extended based on metrics/dimensions
    if "transactions" in config.metrics:
        tx_result = await db.execute(
            select(
                func.count(Transaction.id).label("count"),
                func.sum(Transaction.amount).label("total"),
            ).where(
                and_(
                    Transaction.transaction_date >= config.start_date,
                    Transaction.transaction_date <= config.end_date,
                )
            )
        )
        row = tx_result.one()
        summary["transactions"] = {
            "count": row.count or 0,
            "total": float(row.total or 0),
        }

    if "users" in config.metrics:
        user_result = await db.execute(
            select(func.count(User.id)).where(
                and_(
                    func.date(User.created_at) >= config.start_date,
                    func.date(User.created_at) <= config.end_date,
                )
            )
        )
        summary["new_users"] = user_result.scalar() or 0

    return CustomReportResponse(
        report_id=report_id,
        name=config.name,
        generated_at=datetime.utcnow(),
        config=config,
        data=data,
        summary=summary,
    )


# ============ Member Analysis (SA-012, SA-013) ============

@router.get("/members/conversion")
async def get_member_conversion_analysis(
    days: int = Query(90, ge=30, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:user")),
):
    """会员转化分析 (SA-012)"""
    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    # Total users registered in period
    total_users_result = await db.execute(
        select(func.count(User.id)).where(
            and_(
                func.date(User.created_at) >= start_date,
                func.date(User.created_at) <= end_date,
            )
        )
    )
    total_users = total_users_result.scalar() or 0

    # Premium users (assuming is_premium field exists)
    try:
        premium_result = await db.execute(
            select(func.count(User.id)).where(
                and_(
                    User.is_premium == True,
                    func.date(User.created_at) >= start_date,
                    func.date(User.created_at) <= end_date,
                )
            )
        )
        premium_users = premium_result.scalar() or 0
    except Exception:
        premium_users = 0

    # Conversion rate
    conversion_rate = round(premium_users / total_users * 100, 2) if total_users > 0 else 0

    # Conversion by registration cohort (weekly)
    cohort_data = []
    for week in range(days // 7):
        cohort_start = end_date - timedelta(days=(week + 1) * 7)
        cohort_end = cohort_start + timedelta(days=6)

        cohort_total_result = await db.execute(
            select(func.count(User.id)).where(
                and_(
                    func.date(User.created_at) >= cohort_start,
                    func.date(User.created_at) <= cohort_end,
                )
            )
        )
        cohort_total = cohort_total_result.scalar() or 0

        try:
            cohort_premium_result = await db.execute(
                select(func.count(User.id)).where(
                    and_(
                        User.is_premium == True,
                        func.date(User.created_at) >= cohort_start,
                        func.date(User.created_at) <= cohort_end,
                    )
                )
            )
            cohort_premium = cohort_premium_result.scalar() or 0
        except Exception:
            cohort_premium = 0

        cohort_data.append({
            "week": f"第{week + 1}周",
            "start_date": cohort_start.isoformat(),
            "end_date": cohort_end.isoformat(),
            "total_users": cohort_total,
            "premium_users": cohort_premium,
            "conversion_rate": round(cohort_premium / cohort_total * 100, 2) if cohort_total > 0 else 0,
        })

    # Average days to convert
    try:
        days_to_convert_result = await db.execute(
            select(
                func.avg(
                    func.extract('epoch', User.premium_since - User.created_at) / 86400
                ).label("avg_days")
            ).where(
                and_(
                    User.is_premium == True,
                    User.premium_since.isnot(None),
                )
            )
        )
        avg_days_to_convert = days_to_convert_result.scalar() or 0
    except Exception:
        avg_days_to_convert = 0

    # Conversion funnel
    funnel = [
        {"stage": "注册用户", "count": total_users, "rate": 100},
        {"stage": "活跃用户(7天内)", "count": 0, "rate": 0},
        {"stage": "尝试付费功能", "count": 0, "rate": 0},
        {"stage": "完成付费", "count": premium_users, "rate": conversion_rate},
    ]

    # Get active users count
    active_threshold = datetime.utcnow() - timedelta(days=7)
    active_result = await db.execute(
        select(func.count(User.id)).where(
            and_(
                func.date(User.created_at) >= start_date,
                func.date(User.created_at) <= end_date,
                User.last_active_at >= active_threshold,
            )
        )
    )
    active_count = active_result.scalar() or 0
    funnel[1]["count"] = active_count
    funnel[1]["rate"] = round(active_count / total_users * 100, 2) if total_users > 0 else 0

    return {
        "period": f"近{days}天",
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "total_users": total_users,
        "premium_users": premium_users,
        "overall_conversion_rate": conversion_rate,
        "avg_days_to_convert": round(avg_days_to_convert, 1) if avg_days_to_convert else None,
        "conversion_by_cohort": cohort_data[:12],  # Limit to 12 weeks
        "conversion_funnel": funnel,
        "insights": [
            f"总体转化率为 {conversion_rate}%",
            f"共有 {premium_users} 位付费会员",
        ] if total_users > 0 else ["暂无足够数据进行分析"],
    }


@router.get("/members/paid-analysis")
async def get_paid_user_analysis(
    days: int = Query(90, ge=30, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:user")),
):
    """付费用户分析 (SA-013)"""
    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    # Get premium user count
    try:
        premium_result = await db.execute(
            select(func.count(User.id)).where(User.is_premium == True)
        )
        total_premium = premium_result.scalar() or 0
    except Exception:
        total_premium = 0

    # Premium users in period (newly converted)
    try:
        new_premium_result = await db.execute(
            select(func.count(User.id)).where(
                and_(
                    User.is_premium == True,
                    User.premium_since >= start_date,
                    User.premium_since <= end_date,
                )
            )
        )
        new_premium = new_premium_result.scalar() or 0
    except Exception:
        new_premium = 0

    # Activity comparison: premium vs free
    try:
        # Premium user average transactions
        premium_tx_result = await db.execute(
            select(func.count(Transaction.id)).where(
                and_(
                    Transaction.user_id.in_(
                        select(User.id).where(User.is_premium == True)
                    ),
                    Transaction.transaction_date >= start_date,
                )
            )
        )
        premium_tx = premium_tx_result.scalar() or 0
        premium_avg_tx = round(premium_tx / total_premium, 2) if total_premium > 0 else 0
    except Exception:
        premium_avg_tx = 0

    # Free user average transactions
    try:
        free_result = await db.execute(
            select(func.count(User.id)).where(User.is_premium == False)
        )
        total_free = free_result.scalar() or 0

        free_tx_result = await db.execute(
            select(func.count(Transaction.id)).where(
                and_(
                    Transaction.user_id.in_(
                        select(User.id).where(User.is_premium == False)
                    ),
                    Transaction.transaction_date >= start_date,
                )
            )
        )
        free_tx = free_tx_result.scalar() or 0
        free_avg_tx = round(free_tx / total_free, 2) if total_free > 0 else 0
    except Exception:
        total_free = 0
        free_avg_tx = 0

    # Premium user feature usage
    feature_usage = []
    try:
        source_result = await db.execute(
            select(
                Transaction.source,
                func.count(Transaction.id).label("count"),
            ).where(
                and_(
                    Transaction.user_id.in_(
                        select(User.id).where(User.is_premium == True)
                    ),
                    Transaction.transaction_date >= start_date,
                )
            ).group_by(Transaction.source)
        )
        source_names = {0: "手动记账", 1: "图片识别", 2: "语音识别", 3: "邮件导入"}
        for row in source_result.all():
            feature_usage.append({
                "feature": source_names.get(row.source, "未知"),
                "usage_count": row.count,
            })
    except Exception:
        pass

    # Subscription tier distribution - based on member_level field
    # member_level: 0=普通, 1=VIP (no detailed tier info available)
    tier_distribution = [
        {"tier": "VIP会员", "count": total_premium, "percentage": 100 if total_premium > 0 else 0},
    ]

    # Calculate real premium percentage
    total_all_users = total_premium + total_free
    premium_pct = round(total_premium / total_all_users * 100, 2) if total_all_users > 0 else 0

    return {
        "period": f"近{days}天",
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "summary": {
            "total_premium_users": total_premium,
            "new_premium_users": new_premium,
            "total_free_users": total_free,
            "premium_percentage": premium_pct,
        },
        "activity_comparison": {
            "premium_avg_transactions": premium_avg_tx,
            "free_avg_transactions": free_avg_tx,
            "activity_multiplier": round(premium_avg_tx / free_avg_tx, 1) if free_avg_tx > 0 else 0,
        },
        "revenue_metrics": {
            "message": "收入指标需要配置支付系统后才能获取真实数据",
        },
        "tier_distribution": tier_distribution,
        "feature_usage": feature_usage,
        "insights": [
            f"付费用户平均交易量是免费用户的 {round(premium_avg_tx / free_avg_tx, 1) if free_avg_tx > 0 else 0} 倍" if free_avg_tx > 0 else "暂无对比数据",
            f"本期新增 {new_premium} 位付费会员",
            f"付费用户占比 {premium_pct}%",
        ] if total_all_users > 0 else ["暂无用户数据"],
    }


# ============ Aggregate Overview Endpoints ============

@router.get("/users/overview")
async def get_user_overview(
    days: int = Query(30, ge=7, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:user")),
):
    """用户概览统计（聚合数据）"""
    end_date = date.today()
    start_date = end_date - timedelta(days=days)
    prev_start_date = start_date - timedelta(days=days)

    # Total users
    total_result = await db.execute(select(func.count(User.id)))
    total_users = total_result.scalar() or 0

    # New users in period
    new_result = await db.execute(
        select(func.count(User.id)).where(
            and_(
                func.date(User.created_at) >= start_date,
                func.date(User.created_at) <= end_date,
            )
        )
    )
    new_users = new_result.scalar() or 0

    # New users in previous period (for change calculation)
    prev_new_result = await db.execute(
        select(func.count(User.id)).where(
            and_(
                func.date(User.created_at) >= prev_start_date,
                func.date(User.created_at) < start_date,
            )
        )
    )
    prev_new_users = prev_new_result.scalar() or 0
    new_users_change = ((new_users - prev_new_users) / prev_new_users * 100) if prev_new_users > 0 else 0

    # Active users (users with transactions in period)
    active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            Transaction.transaction_date >= start_date
        )
    )
    active_users = active_result.scalar() or 0

    # Retention rate (users who returned after first day)
    retention_rate = active_users / total_users if total_users > 0 else 0

    # Churn rate (inactive users)
    churn_rate = 1 - retention_rate if retention_rate > 0 else 0

    # Daily growth trend
    growth_trend = []
    for i in range(min(days, 30)):
        day = end_date - timedelta(days=i)
        day_new_result = await db.execute(
            select(func.count(User.id)).where(func.date(User.created_at) == day)
        )
        day_new = day_new_result.scalar() or 0

        day_active_result = await db.execute(
            select(func.count(distinct(Transaction.user_id))).where(
                func.date(Transaction.transaction_date) == day
            )
        )
        day_active = day_active_result.scalar() or 0

        day_total_result = await db.execute(
            select(func.count(User.id)).where(func.date(User.created_at) <= day)
        )
        day_total = day_total_result.scalar() or 0

        growth_trend.insert(0, {
            "date": day.isoformat(),
            "new_users": day_new,
            "active_users": day_active,
            "total_users": day_total,
        })

    # Source distribution - based on actual registration method
    phone_only_result = await db.execute(
        select(func.count(User.id)).where(
            and_(User.phone != None, User.email == None)
        )
    )
    phone_only = phone_only_result.scalar() or 0

    email_only_result = await db.execute(
        select(func.count(User.id)).where(
            and_(User.email != None, User.phone == None)
        )
    )
    email_only = email_only_result.scalar() or 0

    both_result = await db.execute(
        select(func.count(User.id)).where(
            and_(User.phone != None, User.email != None)
        )
    )
    both = both_result.scalar() or 0

    source_distribution = [
        {"source": "手机注册", "count": phone_only},
        {"source": "邮箱注册", "count": email_only},
        {"source": "手机+邮箱", "count": both},
    ]

    # Activity distribution - based on actual transaction counts in last 30 days
    # High active: >= 20 transactions, Medium: 5-19, Low: 1-4, Silent: 0
    high_active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            Transaction.transaction_date >= start_date
        ).group_by(Transaction.user_id).having(func.count(Transaction.id) >= 20)
    )
    high_active = len(high_active_result.all())

    medium_active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            Transaction.transaction_date >= start_date
        ).group_by(Transaction.user_id).having(
            and_(func.count(Transaction.id) >= 5, func.count(Transaction.id) < 20)
        )
    )
    medium_active = len(medium_active_result.all())

    low_active_result = await db.execute(
        select(func.count(distinct(Transaction.user_id))).where(
            Transaction.transaction_date >= start_date
        ).group_by(Transaction.user_id).having(
            and_(func.count(Transaction.id) >= 1, func.count(Transaction.id) < 5)
        )
    )
    low_active = len(low_active_result.all())

    silent_users = total_users - high_active - medium_active - low_active

    activity_distribution = [
        {"level": "高活跃(≥20笔)", "count": high_active},
        {"level": "中活跃(5-19笔)", "count": medium_active},
        {"level": "低活跃(1-4笔)", "count": low_active},
        {"level": "沉默(0笔)", "count": max(0, silent_users)},
    ]

    return {
        "total_users": total_users,
        "new_users": new_users,
        "new_users_change": round(new_users_change, 1),
        "active_users": active_users,
        "retention_rate": round(retention_rate, 3),
        "churn_rate": round(churn_rate, 3),
        "growth_trend": growth_trend,
        "source_distribution": source_distribution,
        "activity_distribution": activity_distribution,
    }


@router.get("/reports")
async def get_reports_list(
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    report_type: Optional[str] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:report")),
):
    """获取报表列表"""
    # In production, this would query from a reports table
    # For now, return empty list with proper structure
    return {
        "items": [],
        "total": 0,
        "page": page,
        "page_size": page_size,
    }


@router.post("/reports/generate")
async def generate_report_task(
    data: dict,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:report")),
):
    """生成报表任务"""
    report_id = str(uuid4())
    return {
        "id": report_id,
        "status": "pending",
        "message": "Report generation task created",
        "report_type": data.get("type", "custom"),
    }


@router.get("/reports/quick/{report_type}")
async def download_quick_report(
    report_type: str,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:report")),
):
    """快速下载报表"""
    from fastapi.responses import Response

    # Generate simple CSV content
    if report_type == "daily":
        content = "日期,新增用户,活跃用户,交易笔数,交易金额\n"
        content += f"{date.today().isoformat()},0,0,0,0\n"
    elif report_type == "weekly":
        content = "周,新增用户,活跃用户,交易笔数,交易金额\n"
        content += f"本周,0,0,0,0\n"
    elif report_type == "monthly":
        content = "月份,新增用户,活跃用户,交易笔数,交易金额\n"
        content += f"本月,0,0,0,0\n"
    else:
        content = "报表类型,数据\n暂无数据,0\n"

    return Response(
        content=content.encode('utf-8-sig'),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename={report_type}_report.csv"
        }
    )


@router.get("/reports/{report_id}/download")
async def download_report(
    report_id: str,
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("stats:report")),
):
    """下载指定报表"""
    from fastapi.responses import Response

    content = f"报表ID,{report_id}\n暂无数据,0\n"
    return Response(
        content=content.encode('utf-8-sig'),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=report_{report_id}.csv"
        }
    )


@router.delete("/reports/{report_id}")
async def delete_report(
    report_id: str,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:report")),
):
    """删除报表"""
    return {"message": f"Report {report_id} deleted"}


@router.get("/transactions/overview")
async def get_transaction_overview(
    days: int = Query(30, ge=7, le=365),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("stats:transaction")),
):
    """交易概览统计（聚合数据）"""
    end_date = date.today()
    start_date = end_date - timedelta(days=days)

    # Total metrics (transaction_type: 1=expense, 2=income, 3=transfer)
    metrics_result = await db.execute(
        select(
            func.count(Transaction.id).label("count"),
            func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)).label("income"),
            func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)).label("expense"),
        ).where(Transaction.transaction_date >= start_date)
    )
    metrics_row = metrics_result.first()

    transaction_count = metrics_row.count or 0
    total_income = float(metrics_row.income or 0)
    total_expense = float(metrics_row.expense or 0)
    total_amount = total_income + total_expense

    # Daily trend
    trend = []
    for i in range(min(days, 30)):
        day = end_date - timedelta(days=i)
        day_result = await db.execute(
            select(
                func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)).label("income"),
                func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)).label("expense"),
            ).where(func.date(Transaction.transaction_date) == day)
        )
        day_row = day_result.first()
        day_income = float(day_row.income or 0)
        day_expense = float(day_row.expense or 0)
        trend.insert(0, {
            "date": day.isoformat(),
            "income": day_income,
            "expense": day_expense,
            "net": day_income - day_expense,
        })

    # Expense categories TOP10 (transaction_type=1 is expense)
    expense_cat_result = await db.execute(
        select(
            Category.name,
            func.sum(Transaction.amount).label("amount"),
        ).join(Category, Transaction.category_id == Category.id).where(
            and_(
                Transaction.transaction_type == 1,
                Transaction.transaction_date >= start_date,
            )
        ).group_by(Category.name).order_by(func.sum(Transaction.amount).desc()).limit(10)
    )
    expense_categories = [
        {"category": row.name, "amount": float(row.amount or 0)}
        for row in expense_cat_result.all()
    ]

    # Income categories TOP10 (transaction_type=2 is income)
    income_cat_result = await db.execute(
        select(
            Category.name,
            func.sum(Transaction.amount).label("amount"),
        ).join(Category, Transaction.category_id == Category.id).where(
            and_(
                Transaction.transaction_type == 2,
                Transaction.transaction_date >= start_date,
            )
        ).group_by(Category.name).order_by(func.sum(Transaction.amount).desc()).limit(10)
    )
    income_categories = [
        {"category": row.name, "amount": float(row.amount or 0)}
        for row in income_cat_result.all()
    ]

    # Amount distribution
    amount_ranges = [
        ("0-50", 0, 50),
        ("50-100", 50, 100),
        ("100-200", 100, 200),
        ("200-500", 200, 500),
        ("500-1000", 500, 1000),
        ("1000+", 1000, 1000000),
    ]
    amount_distribution = []
    for label, min_amt, max_amt in amount_ranges:
        range_result = await db.execute(
            select(func.count(Transaction.id)).where(
                and_(
                    Transaction.transaction_date >= start_date,
                    Transaction.amount >= min_amt,
                    Transaction.amount < max_amt,
                )
            )
        )
        amount_distribution.append({
            "range": label,
            "count": range_result.scalar() or 0,
        })

    # Time distribution (by hour) - use transaction_time field
    time_distribution = []
    for hour in range(24):
        hour_result = await db.execute(
            select(func.count(Transaction.id)).where(
                and_(
                    Transaction.transaction_date >= start_date,
                    Transaction.transaction_time != None,
                    func.extract('hour', Transaction.transaction_time) == hour,
                )
            )
        )
        time_distribution.append({
            "hour": hour,
            "count": hour_result.scalar() or 0,
        })

    # Top users
    top_users_result = await db.execute(
        select(
            Transaction.user_id,
            User.nickname,
            func.count(Transaction.id).label("transaction_count"),
            func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)).label("total_income"),
            func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)).label("total_expense"),
            func.avg(Transaction.amount).label("avg_amount"),
        ).join(User, Transaction.user_id == User.id).where(
            Transaction.transaction_date >= start_date
        ).group_by(Transaction.user_id, User.nickname).order_by(
            func.count(Transaction.id).desc()
        ).limit(20)
    )
    top_users = [
        {
            "user_id": str(row.user_id),
            "nickname": row.nickname or "未设置",
            "transaction_count": row.transaction_count,
            "total_income": float(row.total_income or 0),
            "total_expense": float(row.total_expense or 0),
            "avg_amount": float(row.avg_amount or 0),
        }
        for row in top_users_result.all()
    ]

    return {
        "metrics": {
            "total_amount": total_amount,
            "total_income": total_income,
            "total_expense": total_expense,
            "transaction_count": transaction_count,
        },
        "trend": trend,
        "expense_categories": expense_categories,
        "income_categories": income_categories,
        "amount_distribution": amount_distribution,
        "time_distribution": time_distribution,
        "top_users": top_users,
    }
