"""Family book related schemas."""
from datetime import datetime
from typing import Optional, List, Dict
from uuid import UUID
from decimal import Decimal

from pydantic import BaseModel, Field


# =============================================================================
# Book Invitation Schemas
# =============================================================================

class InvitationCreate(BaseModel):
    """Schema for creating a book invitation."""
    role: int = Field(default=1, ge=0, le=2, description="Role: 0=viewer, 1=member, 2=admin")
    expires_in_days: int = Field(default=7, ge=1, le=30, description="Expiry in days")
    max_uses: Optional[int] = Field(None, ge=1, description="Maximum uses, null for unlimited")
    generate_voice_code: bool = Field(default=False, description="Also generate a 6-digit voice code")


class InvitationResponse(BaseModel):
    """Schema for invitation response."""
    id: UUID
    book_id: UUID
    book_name: str
    inviter_id: UUID
    inviter_name: Optional[str] = None
    role: int
    code: str
    voice_code: Optional[str] = None
    voice_code_semantic: Optional[str] = None  # Semantic description for accessibility
    status: int
    max_uses: Optional[int] = None
    used_count: int
    created_at: datetime
    expires_at: datetime

    class Config:
        from_attributes = True


class InvitationAccept(BaseModel):
    """Schema for accepting an invitation."""
    code: str = Field(..., description="Invitation code or voice code")
    nickname: Optional[str] = Field(None, max_length=50, description="Nickname in the book")


class InvitationAcceptResponse(BaseModel):
    """Schema for invitation accept response."""
    success: bool
    book_id: UUID
    book_name: str
    role: int
    message: str


# =============================================================================
# Family Budget Schemas
# =============================================================================

class MemberBudgetCreate(BaseModel):
    """Schema for creating a member budget allocation."""
    user_id: UUID
    allocated: float = Field(..., ge=0)


class FamilyBudgetCreate(BaseModel):
    """Schema for creating a family budget."""
    period: str = Field(..., pattern=r"^\d{4}-\d{2}$", description="Period in YYYY-MM format")
    strategy: int = Field(default=0, ge=0, le=3, description="0=unified, 1=per_member, 2=per_category, 3=hybrid")
    total_budget: float = Field(..., gt=0)
    member_allocations: Optional[List[MemberBudgetCreate]] = None
    rules: Optional[Dict] = None


class FamilyBudgetUpdate(BaseModel):
    """Schema for updating a family budget."""
    total_budget: Optional[float] = Field(None, gt=0)
    strategy: Optional[int] = Field(None, ge=0, le=3)
    member_allocations: Optional[List[MemberBudgetCreate]] = None
    rules: Optional[Dict] = None


class MemberBudgetResponse(BaseModel):
    """Schema for member budget response."""
    id: UUID
    user_id: UUID
    user_name: Optional[str] = None
    allocated: float
    spent: float
    remaining: float
    percentage: float
    category_spent: Optional[Dict[str, float]] = None

    class Config:
        from_attributes = True


class FamilyBudgetResponse(BaseModel):
    """Schema for family budget response."""
    id: UUID
    book_id: UUID
    period: str
    strategy: int
    total_budget: float
    total_spent: float
    total_remaining: float
    usage_percentage: float
    member_budgets: List[MemberBudgetResponse]
    rules: Optional[Dict] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class BudgetAlertResponse(BaseModel):
    """Schema for budget alert."""
    type: str  # "threshold", "exceeded", "large_expense"
    threshold: int
    current_usage: float
    member_id: UUID
    member_name: Optional[str] = None
    message: str


# =============================================================================
# Transaction Split (AA) Schemas
# =============================================================================

class SplitParticipantCreate(BaseModel):
    """Schema for creating a split participant."""
    user_id: UUID
    amount: Optional[float] = None  # For exact split
    percentage: Optional[float] = None  # For percentage split
    shares: Optional[int] = None  # For shares split
    is_payer: bool = False


class TransactionSplitCreate(BaseModel):
    """Schema for creating a transaction split."""
    transaction_id: UUID
    split_type: int = Field(default=0, ge=0, le=3, description="0=equal, 1=percentage, 2=exact, 3=shares")
    participants: List[SplitParticipantCreate]


class SplitParticipantResponse(BaseModel):
    """Schema for split participant response."""
    id: UUID
    user_id: UUID
    user_name: Optional[str] = None
    amount: float
    percentage: Optional[float] = None
    shares: Optional[int] = None
    is_payer: bool
    is_settled: bool
    settled_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TransactionSplitResponse(BaseModel):
    """Schema for transaction split response."""
    id: UUID
    transaction_id: UUID
    split_type: int
    status: int
    total_amount: float
    settled_amount: float
    participants: List[SplitParticipantResponse]
    created_at: datetime
    settled_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class SplitSettleRequest(BaseModel):
    """Schema for settling a split participant."""
    participant_id: UUID


# =============================================================================
# Family Saving Goal Schemas
# =============================================================================

class GoalContributionCreate(BaseModel):
    """Schema for creating a goal contribution."""
    amount: float = Field(..., gt=0)
    note: Optional[str] = Field(None, max_length=200)


class GoalContributionResponse(BaseModel):
    """Schema for goal contribution response."""
    id: UUID
    goal_id: UUID
    user_id: UUID
    user_name: Optional[str] = None
    amount: float
    note: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class FamilySavingGoalCreate(BaseModel):
    """Schema for creating a family saving goal."""
    name: str = Field(..., max_length=100)
    description: Optional[str] = None
    icon: Optional[str] = Field(None, max_length=50)
    target_amount: float = Field(..., gt=0)
    deadline: Optional[datetime] = None


class FamilySavingGoalUpdate(BaseModel):
    """Schema for updating a family saving goal."""
    name: Optional[str] = Field(None, max_length=100)
    description: Optional[str] = None
    icon: Optional[str] = Field(None, max_length=50)
    target_amount: Optional[float] = Field(None, gt=0)
    deadline: Optional[datetime] = None
    status: Optional[int] = Field(None, ge=0, le=2)


class FamilySavingGoalResponse(BaseModel):
    """Schema for family saving goal response."""
    id: UUID
    book_id: UUID
    name: str
    description: Optional[str] = None
    icon: Optional[str] = None
    target_amount: float
    current_amount: float
    progress_percentage: float
    deadline: Optional[datetime] = None
    status: int
    created_by: UUID
    creator_name: Optional[str] = None
    created_at: datetime
    completed_at: Optional[datetime] = None
    recent_contributions: Optional[List[GoalContributionResponse]] = None

    class Config:
        from_attributes = True


# =============================================================================
# Family Dashboard & Statistics Schemas
# =============================================================================

class MemberContribution(BaseModel):
    """Schema for member contribution in statistics."""
    member_id: UUID
    member_name: str
    avatar_url: Optional[str] = None
    income: float
    expense: float
    transaction_count: int
    contribution_percentage: float
    top_categories: List[str]


class FamilySummary(BaseModel):
    """Schema for family financial summary."""
    total_income: float
    total_expense: float
    net_savings: float
    savings_rate: float
    transaction_count: int
    avg_daily_expense: float


class CategoryBreakdown(BaseModel):
    """Schema for category breakdown."""
    category_id: UUID
    category_name: str
    category_icon: Optional[str] = None
    amount: float
    percentage: float
    member_breakdown: Optional[Dict[str, float]] = None  # member_id -> amount


class PendingSplit(BaseModel):
    """Schema for pending split."""
    split_id: UUID
    transaction_id: UUID
    description: str
    total_amount: float
    your_amount: float
    payer_name: str
    created_at: datetime


class FamilyDashboardResponse(BaseModel):
    """Schema for family dashboard data."""
    book_id: UUID
    book_name: str
    period: str
    summary: FamilySummary
    member_contributions: List[MemberContribution]
    category_breakdown: List[CategoryBreakdown]
    budget_status: Optional[FamilyBudgetResponse] = None
    pending_splits: List[PendingSplit]
    saving_goals: List[FamilySavingGoalResponse]


class FamilyLeaderboardEntry(BaseModel):
    """Schema for family leaderboard entry."""
    rank: int
    member_id: UUID
    member_name: str
    avatar_url: Optional[str] = None
    metric_value: float
    metric_name: str


class FamilyLeaderboardResponse(BaseModel):
    """Schema for family leaderboard response."""
    book_id: UUID
    period: str
    leaderboard_type: str  # "savings", "expense_control", "contribution"
    entries: List[FamilyLeaderboardEntry]
