"""Idempotency middleware based on Chapter 32 design.

Ensures that POST/PUT/PATCH requests with the same X-Idempotency-Key
return the same response without re-executing the operation.

Process:
1. Client sends request with X-Idempotency-Key header
2. Server checks Redis for existing result with that key
3. If found, return cached response (idempotent)
4. If not found, execute request and cache result
5. Cached results expire after configurable TTL
"""
import hashlib
import json
import logging
import time
from typing import Callable, Optional
from dataclasses import dataclass

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.core.redis import get_redis

logger = logging.getLogger(__name__)

# Header name for idempotency key
IDEMPOTENCY_KEY_HEADER = "X-Idempotency-Key"

# HTTP methods that support idempotency
IDEMPOTENT_METHODS = {"POST", "PUT", "PATCH"}

# Default TTL for cached responses (24 hours)
DEFAULT_TTL = 86400


@dataclass
class IdempotencyConfig:
    """Configuration for idempotency middleware."""
    enabled: bool = True
    ttl: int = DEFAULT_TTL
    key_prefix: str = "idempotency:"
    required_for_mutations: bool = False  # If True, require key for POST/PUT/PATCH


@dataclass
class CachedResponse:
    """Cached response data."""
    status_code: int
    body: str
    headers: dict
    created_at: float


class IdempotencyMiddleware(BaseHTTPMiddleware):
    """Middleware to ensure idempotent request handling."""

    def __init__(
        self,
        app,
        config: Optional[IdempotencyConfig] = None,
    ):
        super().__init__(app)
        self.config = config or IdempotencyConfig()

        # Paths to exclude from idempotency checks
        self.exclude_paths = {
            "/health",
            "/ready",
            "/live",
            "/docs",
            "/redoc",
            "/openapi.json",
        }

        # Paths that must use idempotency keys
        self.required_paths = {
            "/api/v1/transactions",
            "/api/v1/accounts",
            "/api/v1/budgets",
        }

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if not self.config.enabled:
            return await call_next(request)

        path = request.url.path
        method = request.method

        # Skip excluded paths and non-mutation methods
        if path in self.exclude_paths or method not in IDEMPOTENT_METHODS:
            return await call_next(request)

        # Get idempotency key from header
        idempotency_key = request.headers.get(IDEMPOTENCY_KEY_HEADER)

        # Check if idempotency key is required
        if not idempotency_key:
            if self.config.required_for_mutations and self._is_required_path(path):
                return JSONResponse(
                    status_code=400,
                    content={
                        "error": "idempotency_key_required",
                        "message": f"Header '{IDEMPOTENCY_KEY_HEADER}' is required for this endpoint",
                    },
                )
            # No key provided, process normally
            return await call_next(request)

        # Validate key format
        if not self._is_valid_key(idempotency_key):
            return JSONResponse(
                status_code=400,
                content={
                    "error": "invalid_idempotency_key",
                    "message": "Idempotency key must be a non-empty string (max 255 chars)",
                },
            )

        # Generate cache key including user context
        user_id = getattr(request.state, "user_id", "anonymous")
        cache_key = self._generate_cache_key(idempotency_key, user_id, path, method)

        # Check for cached response
        cached = await self._get_cached_response(cache_key)
        if cached:
            logger.info(f"Returning cached response for idempotency key: {idempotency_key[:16]}...")
            return self._build_response(cached, is_cached=True)

        # Atomically check and set in-flight status (prevents TOCTOU race)
        if not await self._try_acquire_in_flight(cache_key):
            logger.warning(f"Duplicate concurrent request detected: {idempotency_key[:16]}...")
            return JSONResponse(
                status_code=409,
                content={
                    "error": "request_in_flight",
                    "message": "A request with this idempotency key is currently being processed",
                },
            )

        try:
            # Execute the request
            response = await call_next(request)

            # Cache successful responses
            if response.status_code < 500:
                await self._cache_response(cache_key, response)

            # Add idempotency headers
            response.headers["X-Idempotency-Key"] = idempotency_key
            response.headers["X-Idempotency-Cached"] = "false"

            return response

        except Exception as e:
            logger.error(f"Error processing idempotent request: {e}")
            raise
        finally:
            # Clear in-flight marker
            await self._clear_in_flight(cache_key)

    def _is_required_path(self, path: str) -> bool:
        """Check if path requires idempotency key."""
        return any(path.startswith(p) for p in self.required_paths)

    def _is_valid_key(self, key: str) -> bool:
        """Validate idempotency key format."""
        if not key or not isinstance(key, str):
            return False
        if len(key) > 255:
            return False
        return True

    def _generate_cache_key(
        self,
        idempotency_key: str,
        user_id: str,
        path: str,
        method: str,
    ) -> str:
        """Generate unique cache key for the request."""
        # Include user context to prevent cross-user idempotency issues
        key_data = f"{user_id}:{method}:{path}:{idempotency_key}"
        key_hash = hashlib.sha256(key_data.encode()).hexdigest()[:32]
        return f"{self.config.key_prefix}{key_hash}"

    async def _get_cached_response(self, cache_key: str) -> Optional[CachedResponse]:
        """Get cached response from Redis."""
        redis_client = await get_redis()
        if not redis_client:
            return None

        try:
            data = await redis_client.get(cache_key)
            if data:
                parsed = json.loads(data)
                return CachedResponse(**parsed)
        except Exception as e:
            logger.error(f"Error getting cached response: {e}")

        return None

    async def _cache_response(self, cache_key: str, response: Response):
        """Cache response in Redis."""
        redis_client = await get_redis()
        if not redis_client:
            return

        try:
            # Read response body
            body = b""
            async for chunk in response.body_iterator:
                body += chunk

            # Create new response with the body
            response.body_iterator = iter([body])

            cached = CachedResponse(
                status_code=response.status_code,
                body=body.decode("utf-8"),
                headers=dict(response.headers),
                created_at=time.time(),
            )

            await redis_client.set(
                cache_key,
                json.dumps(cached.__dict__),
                ex=self.config.ttl,
            )
            logger.debug(f"Cached response with TTL {self.config.ttl}s")

        except Exception as e:
            logger.error(f"Error caching response: {e}")

    def _build_response(self, cached: CachedResponse, is_cached: bool = True) -> Response:
        """Build response from cached data."""
        response = Response(
            content=cached.body,
            status_code=cached.status_code,
            media_type="application/json",
        )

        # Restore headers (except some that should be fresh)
        for key, value in cached.headers.items():
            if key.lower() not in ("date", "server", "content-length"):
                response.headers[key] = value

        response.headers["X-Idempotency-Cached"] = str(is_cached).lower()

        return response

    async def _try_acquire_in_flight(self, cache_key: str) -> bool:
        """Atomically check and set in-flight status using Redis SET NX.

        Returns True if acquired (no other request in-flight), False if already in-flight.
        """
        redis_client = await get_redis()
        if not redis_client:
            return True  # Allow if Redis unavailable

        try:
            in_flight_key = f"{cache_key}:inflight"
            result = await redis_client.set(in_flight_key, "1", ex=60, nx=True)
            return result is not None  # True = acquired, False = already in-flight
        except Exception as e:
            logger.error(f"Error acquiring in-flight lock: {e}")
            return True  # Allow on error

    async def _clear_in_flight(self, cache_key: str):
        """Clear in-flight marker."""
        redis_client = await get_redis()
        if not redis_client:
            return

        try:
            in_flight_key = f"{cache_key}:inflight"
            await redis_client.delete(in_flight_key)
        except Exception as e:
            logger.error(f"Error clearing in-flight status: {e}")


def idempotency_key_dependency(request: Request) -> Optional[str]:
    """FastAPI dependency to get idempotency key from request."""
    return request.headers.get(IDEMPOTENCY_KEY_HEADER)
