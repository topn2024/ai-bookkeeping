"""API v1 routers."""
from fastapi import APIRouter

from app.api.v1.auth import router as auth_router
from app.api.v1.oauth import router as oauth_router
from app.api.v1.books import router as books_router
from app.api.v1.book_members import router as book_members_router
from app.api.v1.accounts import router as accounts_router
from app.api.v1.categories import router as categories_router
from app.api.v1.transactions import router as transactions_router
from app.api.v1.budgets import router as budgets_router
from app.api.v1.stats import router as stats_router
from app.api.v1.ai import router as ai_router
from app.api.v1.email_bindings import router as email_bindings_router
from app.api.v1.expense_targets import router as expense_targets_router
from app.api.v1.sync import router as sync_router
from app.api.v1.files import router as files_router
from app.api.v1.backup import router as backup_router
from app.api.v1.config import router as config_router
from app.api.v1.app_upgrade import router as app_upgrade_router
from app.api.v1.users import router as users_router
# Family book routers
from app.api.v1.invitations import router as invitations_router, accept_router as invitations_accept_router
from app.api.v1.family_budget import router as family_budget_router
from app.api.v1.splits import router as splits_router
from app.api.v1.saving_goals import router as saving_goals_router
from app.api.v1.family_stats import router as family_stats_router

api_router = APIRouter()

api_router.include_router(auth_router)
api_router.include_router(users_router)
api_router.include_router(oauth_router)
api_router.include_router(books_router)
api_router.include_router(book_members_router)
api_router.include_router(accounts_router)
api_router.include_router(categories_router)
api_router.include_router(transactions_router)
api_router.include_router(budgets_router)
api_router.include_router(stats_router)
api_router.include_router(ai_router)
api_router.include_router(email_bindings_router)
api_router.include_router(expense_targets_router)
api_router.include_router(sync_router)
api_router.include_router(files_router)
api_router.include_router(backup_router)
api_router.include_router(config_router)
api_router.include_router(app_upgrade_router)
# Family book routers
api_router.include_router(invitations_router)
api_router.include_router(invitations_accept_router)
api_router.include_router(family_budget_router)
api_router.include_router(splits_router)
api_router.include_router(saving_goals_router)
api_router.include_router(family_stats_router)
