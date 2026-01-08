"""Pydantic schemas for API request/response models."""

# User schemas
from app.schemas.user import UserCreate, UserLogin, UserResponse, UserUpdate, Token

# Book schemas
from app.schemas.book import BookCreate, BookUpdate, BookResponse

# Book member schemas
from app.schemas.book_member import (
    BookMemberCreate, BookMemberUpdate, BookMemberResponse, BookMemberList
)

# Account schemas
from app.schemas.account import AccountCreate, AccountUpdate, AccountResponse

# Category schemas
from app.schemas.category import CategoryCreate, CategoryUpdate, CategoryResponse

# Transaction schemas
from app.schemas.transaction import (
    TransactionCreate, TransactionUpdate, TransactionResponse, TransactionList
)

# Budget schemas
from app.schemas.budget import (
    BudgetCreate, BudgetUpdate, BudgetResponse, BudgetList
)

# Stats schemas
from app.schemas.stats import (
    StatsOverview, StatsTrend, StatsCategory, CategoryStats, DailyStats, BudgetStats
)

# Expense target schemas
from app.schemas.expense_target import (
    ExpenseTargetCreate, ExpenseTargetUpdate, ExpenseTargetResponse,
    ExpenseTargetList, ExpenseTargetSummary
)

# Sync schemas (including SyncData classes)
from app.schemas.sync import (
    SyncPushRequest, SyncPushResponse, SyncPullRequest, SyncPullResponse,
    SyncStatusResponse, EntitySyncResult, EntityData, EntityChange, ConflictInfo,
    TransactionSyncData, AccountSyncData, CategorySyncData, BookSyncData, BudgetSyncData
)

# Backup schemas
from app.schemas.backup import (
    BackupCreate, BackupResponse, BackupListResponse, BackupDetailResponse,
    BackupData, RestoreRequest, RestoreResponse
)

# OAuth schemas
from app.schemas.oauth import (
    OAuthCallbackData, OAuthProviderResponse, OAuthProviderListResponse,
    OAuthLoginRequest, OAuthBindRequest, OAuthUnbindRequest,
    GoogleTokenResponse, GoogleUserInfo,
    WeChatTokenResponse, WeChatUserInfo,
    AppleTokenResponse
)

# Family book schemas
from app.schemas.family import (
    InvitationCreate, InvitationResponse, InvitationAccept, InvitationAcceptResponse,
    FamilyBudgetCreate, FamilyBudgetUpdate, FamilyBudgetResponse, MemberBudgetResponse,
    BudgetAlertResponse, MemberBudgetCreate,
    TransactionSplitCreate, TransactionSplitResponse, SplitParticipantResponse,
    SplitParticipantCreate, SplitSettleRequest,
    FamilySavingGoalCreate, FamilySavingGoalUpdate, FamilySavingGoalResponse,
    GoalContributionCreate, GoalContributionResponse,
    FamilyDashboardResponse, FamilySummary, MemberContribution, CategoryBreakdown,
    PendingSplit, FamilyLeaderboardEntry, FamilyLeaderboardResponse
)


__all__ = [
    # User
    "UserCreate", "UserLogin", "UserResponse", "UserUpdate", "Token",
    # Book
    "BookCreate", "BookUpdate", "BookResponse",
    # Book member
    "BookMemberCreate", "BookMemberUpdate", "BookMemberResponse", "BookMemberList",
    # Account
    "AccountCreate", "AccountUpdate", "AccountResponse",
    # Category
    "CategoryCreate", "CategoryUpdate", "CategoryResponse",
    # Transaction
    "TransactionCreate", "TransactionUpdate", "TransactionResponse", "TransactionList",
    # Budget
    "BudgetCreate", "BudgetUpdate", "BudgetResponse", "BudgetList",
    # Stats
    "StatsOverview", "StatsTrend", "StatsCategory", "CategoryStats", "DailyStats", "BudgetStats",
    # Expense target
    "ExpenseTargetCreate", "ExpenseTargetUpdate", "ExpenseTargetResponse",
    "ExpenseTargetList", "ExpenseTargetSummary",
    # Sync
    "SyncPushRequest", "SyncPushResponse", "SyncPullRequest", "SyncPullResponse",
    "SyncStatusResponse", "EntitySyncResult", "EntityData", "EntityChange", "ConflictInfo",
    "TransactionSyncData", "AccountSyncData", "CategorySyncData", "BookSyncData", "BudgetSyncData",
    # Backup
    "BackupCreate", "BackupResponse", "BackupListResponse", "BackupDetailResponse",
    "BackupData", "RestoreRequest", "RestoreResponse",
    # OAuth
    "OAuthCallbackData", "OAuthProviderResponse", "OAuthProviderListResponse",
    "OAuthLoginRequest", "OAuthBindRequest", "OAuthUnbindRequest",
    "GoogleTokenResponse", "GoogleUserInfo",
    "WeChatTokenResponse", "WeChatUserInfo",
    "AppleTokenResponse",
    # Family book
    "InvitationCreate", "InvitationResponse", "InvitationAccept", "InvitationAcceptResponse",
    "FamilyBudgetCreate", "FamilyBudgetUpdate", "FamilyBudgetResponse", "MemberBudgetResponse",
    "BudgetAlertResponse", "MemberBudgetCreate",
    "TransactionSplitCreate", "TransactionSplitResponse", "SplitParticipantResponse",
    "SplitParticipantCreate", "SplitSettleRequest",
    "FamilySavingGoalCreate", "FamilySavingGoalUpdate", "FamilySavingGoalResponse",
    "GoalContributionCreate", "GoalContributionResponse",
    "FamilyDashboardResponse", "FamilySummary", "MemberContribution", "CategoryBreakdown",
    "PendingSplit", "FamilyLeaderboardEntry", "FamilyLeaderboardResponse",
]
