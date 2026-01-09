"""Database models."""
from app.models.user import User
from app.models.book import (
    Book, BookMember, BookInvitation,
    FamilyBudget, MemberBudget,
    FamilySavingGoal, GoalContribution,
    TransactionSplit, SplitParticipant
)
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction
from app.models.budget import Budget
from app.models.email_binding import EmailBinding, EmailType
from app.models.expense_target import ExpenseTarget
from app.models.oauth_provider import OAuthProvider, OAuthProviderType
from app.models.backup import Backup
from app.models.app_version import AppVersion
from app.models.upgrade_analytics import UpgradeAnalytics

# Money Age models (Chapter 14+)
from app.models.money_age import (
    ResourcePool, ConsumptionRecord, MoneyAgeSnapshot, MoneyAgeConfig
)

# Location models (Chapter 14: Location Intelligence)
from app.models.location import (
    GeoFence, FrequentLocation, UserHomeLocation,
    LocationType, GeoFenceAction
)

__all__ = [
    "User",
    "Book",
    "BookMember",
    "BookInvitation",
    "FamilyBudget",
    "MemberBudget",
    "FamilySavingGoal",
    "GoalContribution",
    "TransactionSplit",
    "SplitParticipant",
    "Account",
    "Category",
    "Transaction",
    "Budget",
    "EmailBinding",
    "EmailType",
    "ExpenseTarget",
    "OAuthProvider",
    "OAuthProviderType",
    "Backup",
    "AppVersion",
    "UpgradeAnalytics",
    # Money Age
    "ResourcePool",
    "ConsumptionRecord",
    "MoneyAgeSnapshot",
    "MoneyAgeConfig",
    # Location
    "GeoFence",
    "FrequentLocation",
    "UserHomeLocation",
    "LocationType",
    "GeoFenceAction",
]
