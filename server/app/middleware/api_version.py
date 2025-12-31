"""API Version Compatibility Middleware.

Ensures client API versions are compatible with the server.
Returns appropriate errors for outdated clients.
"""
import logging
from typing import Optional, Tuple
from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)


class APIVersionConfig:
    """API Version configuration."""

    # Current API version (semantic versioning)
    CURRENT_VERSION = "1.0.0"

    # Minimum supported API version
    # Clients below this version will receive 426 Upgrade Required
    MIN_SUPPORTED_VERSION = "1.0.0"

    # Version header names
    REQUEST_HEADER = "X-API-Version"
    RESPONSE_HEADER = "X-API-Version"
    MIN_VERSION_HEADER = "X-API-Min-Version"

    # Paths that skip version checking (public endpoints)
    SKIP_PATHS = [
        "/health",
        "/docs",
        "/redoc",
        "/openapi.json",
        "/api/v1/app-upgrade",  # Allow upgrade check without version header
    ]


def parse_version(version_string: str) -> Tuple[int, int, int]:
    """Parse version string into tuple.

    Args:
        version_string: Version string like "1.2.3"

    Returns:
        Tuple of (major, minor, patch)
    """
    try:
        parts = version_string.strip().split(".")
        major = int(parts[0]) if len(parts) > 0 else 0
        minor = int(parts[1]) if len(parts) > 1 else 0
        patch = int(parts[2]) if len(parts) > 2 else 0
        return (major, minor, patch)
    except (ValueError, IndexError):
        return (0, 0, 0)


def compare_versions(v1: str, v2: str) -> int:
    """Compare two version strings.

    Args:
        v1: First version string
        v2: Second version string

    Returns:
        -1 if v1 < v2, 0 if equal, 1 if v1 > v2
    """
    t1 = parse_version(v1)
    t2 = parse_version(v2)

    if t1 < t2:
        return -1
    elif t1 > t2:
        return 1
    return 0


def is_version_supported(client_version: str) -> bool:
    """Check if a client version is supported.

    Args:
        client_version: Client's API version string

    Returns:
        True if supported, False if too old
    """
    return compare_versions(client_version, APIVersionConfig.MIN_SUPPORTED_VERSION) >= 0


class APIVersionMiddleware(BaseHTTPMiddleware):
    """Middleware to check and enforce API version compatibility.

    This middleware:
    1. Reads X-API-Version header from requests
    2. Checks if client version meets minimum requirements
    3. Returns 426 Upgrade Required for outdated clients
    4. Adds version headers to all responses
    """

    async def dispatch(self, request: Request, call_next):
        """Process the request and check API version."""
        path = request.url.path

        # Skip version check for certain paths
        if self._should_skip(path):
            response = await call_next(request)
            self._add_version_headers(response)
            return response

        # Get client API version from header
        client_version = request.headers.get(APIVersionConfig.REQUEST_HEADER)

        # If no version header, log warning but allow (for backwards compatibility)
        if not client_version:
            logger.debug(f"No API version header for {path}")
            response = await call_next(request)
            self._add_version_headers(response)
            return response

        # Check if version is supported
        if not is_version_supported(client_version):
            logger.warning(
                f"Unsupported API version {client_version} for {path}. "
                f"Minimum required: {APIVersionConfig.MIN_SUPPORTED_VERSION}"
            )
            return self._upgrade_required_response(client_version)

        # Version is OK, proceed with request
        response = await call_next(request)
        self._add_version_headers(response)
        return response

    def _should_skip(self, path: str) -> bool:
        """Check if path should skip version checking."""
        for skip_path in APIVersionConfig.SKIP_PATHS:
            if path.startswith(skip_path):
                return True
        return False

    def _add_version_headers(self, response):
        """Add API version headers to response."""
        response.headers[APIVersionConfig.RESPONSE_HEADER] = APIVersionConfig.CURRENT_VERSION
        response.headers[APIVersionConfig.MIN_VERSION_HEADER] = APIVersionConfig.MIN_SUPPORTED_VERSION

    def _upgrade_required_response(self, client_version: str) -> JSONResponse:
        """Return 426 Upgrade Required response."""
        return JSONResponse(
            status_code=426,
            content={
                "error": "upgrade_required",
                "message": "Your app version is too old. Please update to continue.",
                "message_zh": "您的应用版本过旧，请更新后继续使用。",
                "client_version": client_version,
                "min_version": APIVersionConfig.MIN_SUPPORTED_VERSION,
                "current_version": APIVersionConfig.CURRENT_VERSION,
            },
            headers={
                APIVersionConfig.RESPONSE_HEADER: APIVersionConfig.CURRENT_VERSION,
                APIVersionConfig.MIN_VERSION_HEADER: APIVersionConfig.MIN_SUPPORTED_VERSION,
                "Upgrade": "API-Version",
            }
        )


class DeprecationWarningMiddleware(BaseHTTPMiddleware):
    """Middleware to warn about deprecated API versions.

    Adds deprecation warnings for clients using old but still supported versions.
    """

    # Version below which to show deprecation warning
    DEPRECATION_THRESHOLD = "1.0.0"

    async def dispatch(self, request: Request, call_next):
        """Process request and add deprecation warnings if needed."""
        response = await call_next(request)

        client_version = request.headers.get(APIVersionConfig.REQUEST_HEADER)
        if client_version and compare_versions(client_version, self.DEPRECATION_THRESHOLD) < 0:
            response.headers["X-API-Deprecated"] = "true"
            response.headers["X-API-Deprecation-Message"] = (
                f"API version {client_version} is deprecated. "
                f"Please upgrade to {APIVersionConfig.CURRENT_VERSION}."
            )

        return response
