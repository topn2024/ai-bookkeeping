"""Rate limiting middleware based on Chapter 32 design.

Rate limiting levels:
- Global: 5,000 QPS total
- API-level: Different limits per endpoint
- User-level: Based on membership tier
- IP-level: 100 QPS per IP

Uses sliding window algorithm for smooth limiting.
"""
import logging
import time
from typing import Callable, Optional, Dict, Tuple
from dataclasses import dataclass
from enum import IntEnum

from fastapi import Request, Response, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.redis import get_redis

logger = logging.getLogger(__name__)


class MemberLevel(IntEnum):
    """User membership levels with rate limits."""
    FREE = 0        # 100 requests/minute
    BASIC = 1       # 500 requests/minute
    PREMIUM = 2     # 2000 requests/minute
    UNLIMITED = 99  # No limit


@dataclass
class RateLimitConfig:
    """Rate limit configuration."""
    requests: int       # Max requests
    window_seconds: int  # Time window in seconds

    def key_suffix(self) -> str:
        return f"{self.requests}_{self.window_seconds}"


# Default rate limits
DEFAULT_LIMITS = {
    # Global limit: 5000 QPS
    "global": RateLimitConfig(5000, 1),
    # IP limit: 100 requests per second
    "ip": RateLimitConfig(100, 1),
    # User limits by membership level (per minute)
    "user": {
        MemberLevel.FREE: RateLimitConfig(100, 60),
        MemberLevel.BASIC: RateLimitConfig(500, 60),
        MemberLevel.PREMIUM: RateLimitConfig(2000, 60),
        MemberLevel.UNLIMITED: None,  # No limit
    },
}

# API-specific rate limits (method:path_pattern -> config)
API_LIMITS: Dict[str, RateLimitConfig] = {
    # AI recognition endpoints - more expensive
    "POST:/api/v1/recognition/image": RateLimitConfig(10, 60),
    "POST:/api/v1/recognition/voice": RateLimitConfig(20, 60),
    "POST:/api/v1/recognition/email": RateLimitConfig(5, 60),
    # Transaction endpoints
    "POST:/api/v1/transactions": RateLimitConfig(100, 60),
    "GET:/api/v1/transactions": RateLimitConfig(200, 60),
    # Auth endpoints - prevent brute force
    "POST:/api/v1/auth/login": RateLimitConfig(10, 60),
    "POST:/api/v1/auth/register": RateLimitConfig(5, 60),
    "POST:/api/v1/auth/sms-code": RateLimitConfig(3, 60),
}


class RateLimitExceeded(HTTPException):
    """Exception raised when rate limit is exceeded."""

    def __init__(
        self,
        limit_type: str,
        limit: int,
        window: int,
        retry_after: int
    ):
        detail = {
            "error": "rate_limit_exceeded",
            "limit_type": limit_type,
            "limit": limit,
            "window_seconds": window,
            "retry_after": retry_after,
            "message": f"Rate limit exceeded: {limit} requests per {window}s"
        }
        super().__init__(status_code=429, detail=detail)
        self.retry_after = retry_after


class RateLimiter:
    """Sliding window rate limiter using Redis."""

    PREFIX = "ratelimit:"

    async def is_allowed(
        self,
        key: str,
        limit: int,
        window_seconds: int
    ) -> Tuple[bool, int, int]:
        """
        Check if request is allowed under rate limit.

        Returns:
            Tuple of (allowed, current_count, remaining)
        """
        redis_client = await get_redis()

        if not redis_client:
            # If Redis is not available, allow the request
            # but log a warning
            logger.warning("Redis not available for rate limiting, allowing request")
            return True, 0, limit

        full_key = f"{self.PREFIX}{key}"
        now = time.time()
        window_start = now - window_seconds

        pipe = redis_client.pipeline()

        try:
            # Remove old entries outside the window
            pipe.zremrangebyscore(full_key, 0, window_start)
            # Count current requests in window
            pipe.zcard(full_key)
            # Add current request with timestamp
            pipe.zadd(full_key, {str(now): now})
            # Set expiration
            pipe.expire(full_key, window_seconds + 1)

            results = await pipe.execute()
            current_count = results[1]

            if current_count >= limit:
                # Get oldest entry to calculate retry_after
                oldest = await redis_client.zrange(full_key, 0, 0, withscores=True)
                if oldest:
                    retry_after = int(window_seconds - (now - oldest[0][1]))
                else:
                    retry_after = window_seconds
                return False, current_count, 0

            remaining = limit - current_count - 1
            return True, current_count + 1, remaining

        except Exception as e:
            logger.error(f"Rate limit check error: {e}")
            return True, 0, limit

    async def get_remaining(self, key: str, limit: int, window_seconds: int) -> int:
        """Get remaining requests in the current window."""
        redis_client = await get_redis()
        if not redis_client:
            return limit

        full_key = f"{self.PREFIX}{key}"
        now = time.time()
        window_start = now - window_seconds

        try:
            await redis_client.zremrangebyscore(full_key, 0, window_start)
            current_count = await redis_client.zcard(full_key)
            return max(0, limit - current_count)
        except Exception as e:
            logger.error(f"Get remaining error: {e}")
            return limit


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Rate limiting middleware with multi-level limits."""

    def __init__(self, app, enabled: bool = True):
        super().__init__(app)
        self.enabled = enabled
        self.limiter = RateLimiter()

        # Paths to exclude from rate limiting
        self.exclude_paths = {
            "/health",
            "/ready",
            "/live",
            "/docs",
            "/redoc",
            "/openapi.json",
        }

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if not self.enabled:
            return await call_next(request)

        path = request.url.path

        # Skip excluded paths
        if path in self.exclude_paths:
            return await call_next(request)

        # Get client IP
        client_ip = self._get_client_ip(request)

        # Get user ID if authenticated
        user_id = getattr(request.state, "user_id", None)
        member_level = getattr(request.state, "member_level", MemberLevel.FREE)

        # Check limits in order: Global -> IP -> API -> User
        await self._check_global_limit()
        await self._check_ip_limit(client_ip)
        await self._check_api_limit(request.method, path, client_ip, user_id)

        if user_id:
            await self._check_user_limit(user_id, member_level)

        # All limits passed, process request
        response = await call_next(request)

        # Add rate limit headers
        response.headers["X-RateLimit-Limit"] = "varies"
        response.headers["X-RateLimit-Policy"] = "sliding-window"

        return response

    def _get_client_ip(self, request: Request) -> str:
        """Extract client IP from request."""
        # Check X-Forwarded-For header
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()

        # Check X-Real-IP header
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip

        # Fall back to direct client IP
        if request.client:
            return request.client.host

        return "unknown"

    async def _check_global_limit(self):
        """Check global rate limit."""
        config = DEFAULT_LIMITS["global"]
        allowed, count, remaining = await self.limiter.is_allowed(
            "global",
            config.requests,
            config.window_seconds
        )

        if not allowed:
            logger.warning(f"Global rate limit exceeded: {count}/{config.requests}")
            raise RateLimitExceeded(
                "global",
                config.requests,
                config.window_seconds,
                config.window_seconds
            )

    async def _check_ip_limit(self, client_ip: str):
        """Check IP-based rate limit."""
        config = DEFAULT_LIMITS["ip"]
        allowed, count, remaining = await self.limiter.is_allowed(
            f"ip:{client_ip}",
            config.requests,
            config.window_seconds
        )

        if not allowed:
            logger.warning(f"IP rate limit exceeded for {client_ip}: {count}/{config.requests}")
            raise RateLimitExceeded(
                "ip",
                config.requests,
                config.window_seconds,
                config.window_seconds
            )

    async def _check_api_limit(
        self,
        method: str,
        path: str,
        client_ip: str,
        user_id: Optional[str]
    ):
        """Check API-specific rate limit."""
        api_key = f"{method}:{path}"
        config = API_LIMITS.get(api_key)

        if not config:
            # Try pattern matching for parameterized paths
            for pattern, cfg in API_LIMITS.items():
                if self._path_matches(pattern, f"{method}:{path}"):
                    config = cfg
                    break

        if not config:
            return  # No specific limit for this API

        # Use user_id if available, otherwise IP
        identifier = user_id or client_ip
        limit_key = f"api:{api_key}:{identifier}"

        allowed, count, remaining = await self.limiter.is_allowed(
            limit_key,
            config.requests,
            config.window_seconds
        )

        if not allowed:
            logger.warning(f"API rate limit exceeded for {api_key}: {count}/{config.requests}")
            raise RateLimitExceeded(
                "api",
                config.requests,
                config.window_seconds,
                config.window_seconds
            )

    async def _check_user_limit(self, user_id: str, member_level: int):
        """Check user-based rate limit."""
        user_limits = DEFAULT_LIMITS["user"]
        config = user_limits.get(member_level, user_limits[MemberLevel.FREE])

        if config is None:
            return  # Unlimited user

        allowed, count, remaining = await self.limiter.is_allowed(
            f"user:{user_id}",
            config.requests,
            config.window_seconds
        )

        if not allowed:
            logger.warning(f"User rate limit exceeded for {user_id}: {count}/{config.requests}")
            raise RateLimitExceeded(
                "user",
                config.requests,
                config.window_seconds,
                config.window_seconds
            )

    def _path_matches(self, pattern: str, path: str) -> bool:
        """Check if path matches pattern (simple prefix matching)."""
        # Remove any trailing path parameters
        pattern_base = pattern.split(":")[0] + ":" + pattern.split(":")[1].split("/{")[0]
        path_base = path.split(":")[0] + ":" + path.split(":")[1].rsplit("/", 1)[0] if "/" in path.split(":")[1] else path

        return path.startswith(pattern_base)


# Rate limit decorator for specific endpoints
def rate_limit(requests: int, window_seconds: int = 60):
    """Decorator to apply custom rate limit to an endpoint."""
    def decorator(func):
        func._rate_limit = RateLimitConfig(requests, window_seconds)
        return func
    return decorator
