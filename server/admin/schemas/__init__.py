"""Admin schemas."""
from admin.schemas.auth import (
    AdminLoginRequest,
    AdminLoginResponse,
    AdminTokenRefreshRequest,
    AdminTokenRefreshResponse,
    PasswordChangeRequest,
)
from admin.schemas.admin_user import (
    AdminUserCreate,
    AdminUserUpdate,
    AdminUserResponse,
    AdminUserListResponse,
)
from admin.schemas.dashboard import (
    DashboardStatsResponse,
    TrendDataPoint,
    TrendResponse,
)

__all__ = [
    "AdminLoginRequest",
    "AdminLoginResponse",
    "AdminTokenRefreshRequest",
    "AdminTokenRefreshResponse",
    "PasswordChangeRequest",
    "AdminUserCreate",
    "AdminUserUpdate",
    "AdminUserResponse",
    "AdminUserListResponse",
    "DashboardStatsResponse",
    "TrendDataPoint",
    "TrendResponse",
]
