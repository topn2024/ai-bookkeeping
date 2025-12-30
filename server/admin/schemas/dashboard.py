"""Dashboard schemas."""
from datetime import datetime, date
from typing import List, Optional, Dict, Any
from decimal import Decimal

from pydantic import BaseModel, Field


class StatCard(BaseModel):
    """统计卡片"""
    value: int | float | str
    label: str
    change: Optional[float] = None  # 环比变化百分比
    change_type: Optional[str] = None  # up/down/flat
    icon: Optional[str] = None
    color: Optional[str] = None


class DashboardStatsResponse(BaseModel):
    """仪表盘统计数据"""
    # 今日数据
    today_new_users: StatCard
    today_active_users: StatCard
    today_transactions: StatCard
    today_amount: StatCard

    # 累计数据
    total_users: int
    total_transactions: int
    total_amount: str  # Decimal as string


class TrendDataPoint(BaseModel):
    """趋势数据点"""
    date: str  # YYYY-MM-DD
    value: int | float


class TrendResponse(BaseModel):
    """趋势数据响应"""
    label: str
    data: List[TrendDataPoint]


class UserGrowthTrendResponse(BaseModel):
    """用户增长趋势"""
    new_users: TrendResponse
    active_users: TrendResponse
    period: str  # 7d, 30d, custom


class TransactionTrendResponse(BaseModel):
    """交易趋势"""
    income: TrendResponse
    expense: TrendResponse
    transfer: TrendResponse
    total_count: TrendResponse
    period: str


class TransactionTypeDistribution(BaseModel):
    """交易类型分布"""
    income: float
    expense: float
    transfer: float
    income_count: int
    expense_count: int
    transfer_count: int


class TopUser(BaseModel):
    """TOP用户"""
    user_id: str
    display_name: str
    email_masked: str
    transaction_count: int
    total_amount: str


class TopUsersResponse(BaseModel):
    """TOP用户列表"""
    items: List[TopUser]
    period: str


class RecentTransaction(BaseModel):
    """最近交易"""
    id: str
    user_id: str
    user_display_name: str
    transaction_type: int
    type_name: str
    amount: str
    category_name: str
    note: Optional[str] = None
    created_at: datetime


class RecentTransactionsResponse(BaseModel):
    """最近交易列表"""
    items: List[RecentTransaction]


class HeatmapData(BaseModel):
    """热力图数据"""
    hour: int  # 0-23
    weekday: int  # 0-6 (Monday-Sunday)
    value: int


class ActivityHeatmapResponse(BaseModel):
    """活跃度热力图"""
    data: List[HeatmapData]
    max_value: int


class SystemStatusResponse(BaseModel):
    """系统状态"""
    api_status: str  # healthy, degraded, down
    db_status: str
    redis_status: str
    storage_usage_percent: float
    online_users: int
    api_requests_today: int
    error_rate: float
