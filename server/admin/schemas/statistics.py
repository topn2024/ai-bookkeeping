"""Schemas for statistics and analytics module."""
from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List, Dict, Any
from uuid import UUID

from pydantic import BaseModel, Field


# ============ User Analysis Schemas ============

class RetentionData(BaseModel):
    """Retention data for a cohort."""
    cohort_date: date
    cohort_size: int
    day_1: Optional[float] = None
    day_7: Optional[float] = None
    day_14: Optional[float] = None
    day_30: Optional[float] = None


class UserRetentionResponse(BaseModel):
    """User retention analysis response (SA-002)."""
    period: str  # "daily", "weekly", "monthly"
    cohorts: List[RetentionData]
    avg_day_1: float
    avg_day_7: float
    avg_day_30: float


class ChurnRiskUser(BaseModel):
    """User at risk of churning."""
    user_id: UUID
    email: Optional[str] = None  # Masked
    last_active: datetime
    days_inactive: int
    transaction_count_30d: int
    risk_score: float  # 0-1, higher = more likely to churn
    risk_level: str  # "low", "medium", "high"


class UserChurnPredictionResponse(BaseModel):
    """User churn prediction response (SA-003)."""
    total_at_risk: int
    high_risk: int
    medium_risk: int
    low_risk: int
    users: List[ChurnRiskUser]


class UserSegment(BaseModel):
    """User segment data."""
    segment_name: str
    user_count: int
    percentage: float
    avg_transactions: float
    avg_amount: Decimal


class UserProfileAnalysisResponse(BaseModel):
    """User profile analysis response (SA-004)."""
    total_users: int
    by_registration_period: List[dict]  # [{period, count}]
    by_activity_level: List[UserSegment]  # active, moderate, inactive
    by_transaction_volume: List[UserSegment]  # high, medium, low
    by_primary_category: List[dict]  # [{category, user_count}]


class NewVsOldUserStats(BaseModel):
    """Stats comparing new and old users."""
    metric: str
    new_users: float
    old_users: float
    difference: float
    difference_percent: float


class NewOldUserComparisonResponse(BaseModel):
    """New vs old user comparison response (SA-005)."""
    new_user_threshold_days: int
    new_user_count: int
    old_user_count: int
    comparisons: List[NewVsOldUserStats]


# ============ Transaction Analysis Schemas ============

class CategoryRanking(BaseModel):
    """Category spending ranking item."""
    rank: int
    category_id: UUID
    category_name: str
    category_type: int
    total_amount: Decimal
    transaction_count: int
    user_count: int
    avg_amount: Decimal
    percentage: float


class CategoryRankingResponse(BaseModel):
    """Category ranking response (SA-007)."""
    period: str
    start_date: date
    end_date: date
    expense_ranking: List[CategoryRanking]
    income_ranking: List[CategoryRanking]


class AvgTransactionStats(BaseModel):
    """Average transaction statistics."""
    period: str
    avg_expense: Decimal
    avg_income: Decimal
    median_expense: Decimal
    median_income: Decimal
    by_user_segment: List[dict]  # [{segment, avg_expense, avg_income}]


class TransactionTimeDistribution(BaseModel):
    """Transaction time distribution (SA-009)."""
    by_hour: List[dict]  # [{hour: 0-23, count, amount}]
    by_day_of_week: List[dict]  # [{day: 0-6, count, amount}]
    peak_hour: int
    peak_day: int


class TransactionFrequencyStats(BaseModel):
    """Transaction frequency statistics (SA-010)."""
    avg_transactions_per_user: float
    avg_transactions_per_day: float
    frequency_distribution: List[dict]  # [{range: "0-5", user_count}]
    most_active_users: List[dict]  # [{user_id, email, count}]


# ============ Business Analysis Schemas ============

class FeatureUsageItem(BaseModel):
    """Feature usage statistics item."""
    feature_name: str
    feature_code: str
    usage_count: int
    unique_users: int
    usage_rate: float  # percentage of active users
    trend: str  # "up", "down", "stable"


class FeatureUsageResponse(BaseModel):
    """Feature usage response (SA-011)."""
    period: str
    start_date: date
    end_date: date
    features: List[FeatureUsageItem]


class ConversionFunnelStep(BaseModel):
    """Conversion funnel step."""
    step_name: str
    user_count: int
    conversion_rate: float
    drop_off_rate: float


class MemberConversionResponse(BaseModel):
    """Member conversion analysis response (SA-012)."""
    total_free_users: int
    total_paid_users: int
    conversion_rate: float
    funnel: List[ConversionFunnelStep]
    conversion_by_period: List[dict]  # [{period, conversions, rate}]


# ============ Report Schemas ============

class DailyReportData(BaseModel):
    """Daily report data (SA-014)."""
    report_date: date
    generated_at: datetime

    # User metrics
    new_users: int
    active_users: int
    churned_users: int

    # Transaction metrics
    total_transactions: int
    total_expense: Decimal
    total_income: Decimal
    avg_transaction: Decimal

    # Comparison with previous day
    new_users_change: float
    active_users_change: float
    transactions_change: float

    # Top categories
    top_expense_categories: List[dict]
    top_income_categories: List[dict]

    # Highlights
    highlights: List[str]


class WeeklyMonthlyReportData(BaseModel):
    """Weekly/Monthly report data (SA-015)."""
    report_type: str  # "weekly" or "monthly"
    start_date: date
    end_date: date
    generated_at: datetime

    # Summary
    total_new_users: int
    total_active_users: int
    retention_rate: float

    total_transactions: int
    total_expense: Decimal
    total_income: Decimal

    # Trends
    daily_breakdown: List[dict]

    # Comparisons
    vs_previous_period: dict

    # Analysis
    top_growing_categories: List[dict]
    declining_categories: List[dict]
    user_segments: List[dict]

    # Recommendations
    insights: List[str]


class CustomReportConfig(BaseModel):
    """Custom report configuration (SA-016)."""
    name: str = Field(..., min_length=1, max_length=100)
    start_date: date
    end_date: date
    metrics: List[str]  # List of metric codes to include
    dimensions: List[str]  # Group by dimensions
    filters: Optional[Dict[str, Any]] = None
    format: str = Field("json", pattern="^(json|csv|excel)$")


class CustomReportResponse(BaseModel):
    """Custom report response."""
    report_id: str
    name: str
    generated_at: datetime
    config: CustomReportConfig
    data: List[Dict[str, Any]]
    summary: Dict[str, Any]
