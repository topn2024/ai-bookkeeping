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

api_router = APIRouter()

api_router.include_router(auth_router)
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
