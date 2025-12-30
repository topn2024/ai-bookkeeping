"""Admin API routers."""
from fastapi import APIRouter

from admin.api.auth import router as auth_router
from admin.api.dashboard import router as dashboard_router
from admin.api.users import router as users_router
from admin.api.admins import router as admins_router
from admin.api.logs import router as logs_router
from admin.api.transactions import router as transactions_router
from admin.api.books import router as books_router
from admin.api.categories import router as categories_router
from admin.api.backups import router as backups_router
from admin.api.statistics import router as statistics_router
from admin.api.monitoring import router as monitoring_router
from admin.api.settings import router as settings_router
from admin.api.app_versions import router as app_versions_router

admin_router = APIRouter()

admin_router.include_router(auth_router)
admin_router.include_router(dashboard_router)
admin_router.include_router(users_router)
admin_router.include_router(admins_router)
admin_router.include_router(logs_router)
admin_router.include_router(transactions_router)
admin_router.include_router(books_router)
admin_router.include_router(categories_router)
admin_router.include_router(backups_router)
admin_router.include_router(statistics_router)
admin_router.include_router(monitoring_router)
admin_router.include_router(settings_router)
admin_router.include_router(app_versions_router)
