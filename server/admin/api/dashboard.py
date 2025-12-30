"""Admin dashboard endpoints."""
from datetime import datetime, timedelta, date
from decimal import Decimal
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, case
from sqlalchemy.sql import text

from app.core.database import get_db
from app.models.user import User
from app.models.transaction import Transaction
from app.models.account import Account
from app.models.book import Book
from app.models.category import Category
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.schemas.dashboard import (
    DashboardStatsResponse,
    StatCard,
    TrendDataPoint,
    TrendResponse,
    UserGrowthTrendResponse,
    TransactionTrendResponse,
    TransactionTypeDistribution,
    TopUser,
    TopUsersResponse,
    RecentTransaction,
    RecentTransactionsResponse,
)


router = APIRouter(prefix="/dashboard", tags=["Admin Dashboard"])


@router.get("/stats", response_model=DashboardStatsResponse)
async def get_dashboard_stats(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取仪表盘统计数据"""
    today = date.today()
    yesterday = today - timedelta(days=1)

    # 今日新增用户
    today_new_users = await db.execute(
        select(func.count(User.id))
        .where(func.date(User.created_at) == today)
    )
    today_new_users_count = today_new_users.scalar() or 0

    # 昨日新增用户（用于计算环比）
    yesterday_new_users = await db.execute(
        select(func.count(User.id))
        .where(func.date(User.created_at) == yesterday)
    )
    yesterday_new_users_count = yesterday_new_users.scalar() or 0

    # 今日活跃用户（有交易记录）
    today_active = await db.execute(
        select(func.count(func.distinct(Transaction.user_id)))
        .where(func.date(Transaction.created_at) == today)
    )
    today_active_count = today_active.scalar() or 0

    yesterday_active = await db.execute(
        select(func.count(func.distinct(Transaction.user_id)))
        .where(func.date(Transaction.created_at) == yesterday)
    )
    yesterday_active_count = yesterday_active.scalar() or 0

    # 今日交易笔数
    today_tx = await db.execute(
        select(func.count(Transaction.id))
        .where(func.date(Transaction.created_at) == today)
    )
    today_tx_count = today_tx.scalar() or 0

    yesterday_tx = await db.execute(
        select(func.count(Transaction.id))
        .where(func.date(Transaction.created_at) == yesterday)
    )
    yesterday_tx_count = yesterday_tx.scalar() or 0

    # 今日交易金额
    today_amount = await db.execute(
        select(func.sum(Transaction.amount))
        .where(func.date(Transaction.created_at) == today)
    )
    today_amount_sum = today_amount.scalar() or Decimal("0")

    yesterday_amount = await db.execute(
        select(func.sum(Transaction.amount))
        .where(func.date(Transaction.created_at) == yesterday)
    )
    yesterday_amount_sum = yesterday_amount.scalar() or Decimal("0")

    # 累计数据
    total_users = await db.execute(select(func.count(User.id)))
    total_users_count = total_users.scalar() or 0

    total_tx = await db.execute(select(func.count(Transaction.id)))
    total_tx_count = total_tx.scalar() or 0

    total_amount = await db.execute(select(func.sum(Transaction.amount)))
    total_amount_sum = total_amount.scalar() or Decimal("0")

    return DashboardStatsResponse(
        today_new_users=StatCard(
            value=today_new_users_count,
            label="今日新增用户",
            change=_calc_change(today_new_users_count, yesterday_new_users_count),
            change_type=_get_change_type(today_new_users_count, yesterday_new_users_count),
            icon="user-plus",
            color="#10B981",
        ),
        today_active_users=StatCard(
            value=today_active_count,
            label="今日活跃用户",
            change=_calc_change(today_active_count, yesterday_active_count),
            change_type=_get_change_type(today_active_count, yesterday_active_count),
            icon="users",
            color="#3B82F6",
        ),
        today_transactions=StatCard(
            value=today_tx_count,
            label="今日交易笔数",
            change=_calc_change(today_tx_count, yesterday_tx_count),
            change_type=_get_change_type(today_tx_count, yesterday_tx_count),
            icon="receipt",
            color="#8B5CF6",
        ),
        today_amount=StatCard(
            value=f"¥{today_amount_sum:,.2f}",
            label="今日交易金额",
            change=_calc_change(float(today_amount_sum), float(yesterday_amount_sum)),
            change_type=_get_change_type(float(today_amount_sum), float(yesterday_amount_sum)),
            icon="currency-yen",
            color="#F59E0B",
        ),
        total_users=total_users_count,
        total_transactions=total_tx_count,
        total_amount=f"{total_amount_sum:,.2f}",
    )


@router.get("/trend/users", response_model=UserGrowthTrendResponse)
async def get_user_growth_trend(
    period: str = Query("7d", regex="^(7d|30d|90d)$"),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取用户增长趋势"""
    days = {"7d": 7, "30d": 30, "90d": 90}[period]
    start_date = date.today() - timedelta(days=days - 1)

    # 新增用户趋势
    new_users_data = await _get_daily_counts(
        db, User, User.created_at, start_date, days
    )

    # 活跃用户趋势
    active_users_data = await _get_daily_active_users(db, start_date, days)

    return UserGrowthTrendResponse(
        new_users=TrendResponse(
            label="新增用户",
            data=new_users_data,
        ),
        active_users=TrendResponse(
            label="活跃用户",
            data=active_users_data,
        ),
        period=period,
    )


@router.get("/trend/transactions", response_model=TransactionTrendResponse)
async def get_transaction_trend(
    period: str = Query("7d", regex="^(7d|30d|90d)$"),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取交易趋势"""
    days = {"7d": 7, "30d": 30, "90d": 90}[period]
    start_date = date.today() - timedelta(days=days - 1)

    # 按类型统计交易
    income_data = await _get_transaction_trend_by_type(db, 2, start_date, days)  # 2=收入
    expense_data = await _get_transaction_trend_by_type(db, 1, start_date, days)  # 1=支出
    transfer_data = await _get_transaction_trend_by_type(db, 3, start_date, days)  # 3=转账

    # 总交易笔数
    total_data = await _get_daily_counts(
        db, Transaction, Transaction.created_at, start_date, days
    )

    return TransactionTrendResponse(
        income=TrendResponse(label="收入", data=income_data),
        expense=TrendResponse(label="支出", data=expense_data),
        transfer=TrendResponse(label="转账", data=transfer_data),
        total_count=TrendResponse(label="总交易", data=total_data),
        period=period,
    )


@router.get("/distribution/transaction-type", response_model=TransactionTypeDistribution)
async def get_transaction_type_distribution(
    period: str = Query("30d", regex="^(7d|30d|90d|all)$"),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取交易类型分布"""
    if period == "all":
        start_date = None
    else:
        days = {"7d": 7, "30d": 30, "90d": 90}[period]
        start_date = date.today() - timedelta(days=days)

    query = select(
        Transaction.transaction_type,
        func.count(Transaction.id).label("count"),
        func.sum(Transaction.amount).label("amount"),
    ).group_by(Transaction.transaction_type)

    if start_date:
        query = query.where(func.date(Transaction.created_at) >= start_date)

    result = await db.execute(query)
    rows = result.all()

    income_count = 0
    expense_count = 0
    transfer_count = 0
    income_amount = Decimal("0")
    expense_amount = Decimal("0")
    transfer_amount = Decimal("0")

    for row in rows:
        if row.transaction_type == 2:  # 收入
            income_count = row.count
            income_amount = row.amount or Decimal("0")
        elif row.transaction_type == 1:  # 支出
            expense_count = row.count
            expense_amount = row.amount or Decimal("0")
        elif row.transaction_type == 3:  # 转账
            transfer_count = row.count
            transfer_amount = row.amount or Decimal("0")

    total_amount = income_amount + expense_amount + transfer_amount
    if total_amount > 0:
        income_pct = float(income_amount / total_amount * 100)
        expense_pct = float(expense_amount / total_amount * 100)
        transfer_pct = float(transfer_amount / total_amount * 100)
    else:
        income_pct = expense_pct = transfer_pct = 0

    return TransactionTypeDistribution(
        income=round(income_pct, 1),
        expense=round(expense_pct, 1),
        transfer=round(transfer_pct, 1),
        income_count=income_count,
        expense_count=expense_count,
        transfer_count=transfer_count,
    )


@router.get("/top-users", response_model=TopUsersResponse)
async def get_top_users(
    limit: int = Query(10, ge=1, le=50),
    period: str = Query("30d", regex="^(7d|30d|90d|all)$"),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取TOP活跃用户"""
    if period == "all":
        start_date = None
    else:
        days = {"7d": 7, "30d": 30, "90d": 90}[period]
        start_date = date.today() - timedelta(days=days)

    query = (
        select(
            Transaction.user_id,
            func.count(Transaction.id).label("tx_count"),
            func.sum(Transaction.amount).label("total_amount"),
        )
        .group_by(Transaction.user_id)
        .order_by(func.count(Transaction.id).desc())
        .limit(limit)
    )

    if start_date:
        query = query.where(func.date(Transaction.created_at) >= start_date)

    result = await db.execute(query)
    rows = result.all()

    top_users = []
    for row in rows:
        # 获取用户信息
        user_result = await db.execute(
            select(User).where(User.id == row.user_id)
        )
        user = user_result.scalar_one_or_none()

        if user:
            top_users.append(TopUser(
                user_id=str(row.user_id),
                display_name=user.display_name or "未设置",
                email_masked=_mask_email(user.email),
                transaction_count=row.tx_count,
                total_amount=f"¥{row.total_amount:,.2f}" if row.total_amount else "¥0.00",
            ))

    return TopUsersResponse(items=top_users, period=period)


@router.get("/heatmap/activity")
async def get_activity_heatmap(
    days: int = Query(30, ge=7, le=90),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取用户活跃热力图 (DB-010) - 按小时/星期展示用户活跃分布"""
    start_date = date.today() - timedelta(days=days)

    # 按小时统计 (0-23)
    hourly_result = await db.execute(
        select(
            func.extract("hour", Transaction.created_at).label("hour"),
            func.count(Transaction.id).label("count"),
            func.count(func.distinct(Transaction.user_id)).label("users"),
        )
        .where(func.date(Transaction.created_at) >= start_date)
        .group_by(func.extract("hour", Transaction.created_at))
        .order_by("hour")
    )
    by_hour = {int(row.hour): {"count": row.count, "users": row.users} for row in hourly_result.all()}

    # 按星期统计 (0=周日, 1=周一, ..., 6=周六)
    dow_result = await db.execute(
        select(
            func.extract("dow", Transaction.created_at).label("dow"),
            func.count(Transaction.id).label("count"),
            func.count(func.distinct(Transaction.user_id)).label("users"),
        )
        .where(func.date(Transaction.created_at) >= start_date)
        .group_by(func.extract("dow", Transaction.created_at))
        .order_by("dow")
    )
    by_dow = {int(row.dow): {"count": row.count, "users": row.users} for row in dow_result.all()}

    # 按小时和星期组合统计 (热力图矩阵)
    matrix_result = await db.execute(
        select(
            func.extract("dow", Transaction.created_at).label("dow"),
            func.extract("hour", Transaction.created_at).label("hour"),
            func.count(Transaction.id).label("count"),
        )
        .where(func.date(Transaction.created_at) >= start_date)
        .group_by(
            func.extract("dow", Transaction.created_at),
            func.extract("hour", Transaction.created_at),
        )
    )

    # 构建7x24的矩阵
    heatmap_matrix = [[0 for _ in range(24)] for _ in range(7)]
    max_value = 0
    for row in matrix_result.all():
        dow = int(row.dow)
        hour = int(row.hour)
        count = row.count
        heatmap_matrix[dow][hour] = count
        if count > max_value:
            max_value = count

    # 找出峰值时段
    peak_hour = max(range(24), key=lambda h: by_hour.get(h, {}).get("count", 0)) if by_hour else 0
    peak_dow = max(range(7), key=lambda d: by_dow.get(d, {}).get("count", 0)) if by_dow else 0

    dow_names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    return {
        "period_days": days,
        "by_hour": [
            {"hour": h, "count": by_hour.get(h, {}).get("count", 0), "users": by_hour.get(h, {}).get("users", 0)}
            for h in range(24)
        ],
        "by_day_of_week": [
            {"day": d, "day_name": dow_names[d], "count": by_dow.get(d, {}).get("count", 0), "users": by_dow.get(d, {}).get("users", 0)}
            for d in range(7)
        ],
        "heatmap_matrix": heatmap_matrix,
        "max_value": max_value,
        "peak_hour": peak_hour,
        "peak_day": peak_dow,
        "peak_day_name": dow_names[peak_dow],
        "insights": [
            f"用户最活跃的时段是 {peak_hour}:00-{peak_hour+1}:00",
            f"用户最活跃的日期是 {dow_names[peak_dow]}",
        ],
    }


@router.get("/recent-users")
async def get_recent_users(
    limit: int = Query(10, ge=1, le=50),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取最近注册用户 (DB-012补充)"""
    result = await db.execute(
        select(User)
        .order_by(User.created_at.desc())
        .limit(limit)
    )
    users = result.scalars().all()

    items = []
    for user in users:
        # 获取用户交易数
        tx_count = await db.execute(
            select(func.count(Transaction.id))
            .where(Transaction.user_id == user.id)
        )
        transaction_count = tx_count.scalar() or 0

        items.append({
            "id": str(user.id),
            "display_name": user.display_name or "未设置",
            "email_masked": _mask_email(user.email),
            "avatar_url": user.avatar_url,
            "is_active": user.is_active if hasattr(user, 'is_active') else True,
            "transaction_count": transaction_count,
            "created_at": user.created_at,
        })

    return {"items": items}


@router.get("/recent-transactions", response_model=RecentTransactionsResponse)
async def get_recent_transactions(
    limit: int = Query(10, ge=1, le=50),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("dashboard:view")),
):
    """获取最近交易"""
    result = await db.execute(
        select(Transaction)
        .order_by(Transaction.created_at.desc())
        .limit(limit)
    )
    transactions = result.scalars().all()

    items = []
    for tx in transactions:
        # 获取用户
        user_result = await db.execute(
            select(User).where(User.id == tx.user_id)
        )
        user = user_result.scalar_one_or_none()

        # 获取分类
        category_result = await db.execute(
            select(Category).where(Category.id == tx.category_id)
        )
        category = category_result.scalar_one_or_none()

        type_names = {1: "支出", 2: "收入", 3: "转账"}

        items.append(RecentTransaction(
            id=str(tx.id),
            user_id=str(tx.user_id),
            user_display_name=user.display_name if user else "未知",
            transaction_type=tx.transaction_type,
            type_name=type_names.get(tx.transaction_type, "未知"),
            amount=f"¥{tx.amount:,.2f}",
            category_name=category.name if category else "未分类",
            note=tx.note[:20] + "..." if tx.note and len(tx.note) > 20 else tx.note,
            created_at=tx.created_at,
        ))

    return RecentTransactionsResponse(items=items)


# Helper functions
def _calc_change(current: float, previous: float) -> Optional[float]:
    """计算环比变化百分比"""
    if previous == 0:
        return None
    return round((current - previous) / previous * 100, 1)


def _get_change_type(current: float, previous: float) -> str:
    """获取变化类型"""
    if current > previous:
        return "up"
    elif current < previous:
        return "down"
    return "flat"


async def _get_daily_counts(
    db: AsyncSession,
    model,
    date_field,
    start_date: date,
    days: int,
) -> List[TrendDataPoint]:
    """获取每日计数"""
    result = await db.execute(
        select(
            func.date(date_field).label("day"),
            func.count(model.id).label("count"),
        )
        .where(func.date(date_field) >= start_date)
        .group_by(func.date(date_field))
        .order_by(func.date(date_field))
    )
    rows = {row.day: row.count for row in result.all()}

    # 填充缺失的日期
    data = []
    for i in range(days):
        d = start_date + timedelta(days=i)
        data.append(TrendDataPoint(
            date=d.isoformat(),
            value=rows.get(d, 0),
        ))

    return data


async def _get_daily_active_users(
    db: AsyncSession,
    start_date: date,
    days: int,
) -> List[TrendDataPoint]:
    """获取每日活跃用户数"""
    result = await db.execute(
        select(
            func.date(Transaction.created_at).label("day"),
            func.count(func.distinct(Transaction.user_id)).label("count"),
        )
        .where(func.date(Transaction.created_at) >= start_date)
        .group_by(func.date(Transaction.created_at))
        .order_by(func.date(Transaction.created_at))
    )
    rows = {row.day: row.count for row in result.all()}

    data = []
    for i in range(days):
        d = start_date + timedelta(days=i)
        data.append(TrendDataPoint(
            date=d.isoformat(),
            value=rows.get(d, 0),
        ))

    return data


async def _get_transaction_trend_by_type(
    db: AsyncSession,
    tx_type: int,
    start_date: date,
    days: int,
) -> List[TrendDataPoint]:
    """获取按类型的交易趋势"""
    result = await db.execute(
        select(
            func.date(Transaction.created_at).label("day"),
            func.sum(Transaction.amount).label("amount"),
        )
        .where(
            and_(
                func.date(Transaction.created_at) >= start_date,
                Transaction.transaction_type == tx_type,
            )
        )
        .group_by(func.date(Transaction.created_at))
        .order_by(func.date(Transaction.created_at))
    )
    rows = {row.day: float(row.amount or 0) for row in result.all()}

    data = []
    for i in range(days):
        d = start_date + timedelta(days=i)
        data.append(TrendDataPoint(
            date=d.isoformat(),
            value=rows.get(d, 0),
        ))

    return data


def _mask_email(email: str) -> str:
    """邮箱脱敏"""
    if not email or "@" not in email:
        return email

    parts = email.split("@")
    local = parts[0]

    if len(local) <= 2:
        masked = local[0] + "***"
    else:
        masked = local[0] + "***" + local[-1]

    return f"{masked}@{parts[1]}"
