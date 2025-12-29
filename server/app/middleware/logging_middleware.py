"""Request logging middleware."""
import logging
import time
import uuid
from typing import Callable

from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.logging import request_id_var

logger = logging.getLogger(__name__)


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware for logging HTTP requests and responses."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Generate unique request ID
        request_id = str(uuid.uuid4())[:8]
        request_id_var.set(request_id)

        # Add request_id to request state for access in route handlers
        request.state.request_id = request_id

        # Record start time
        start_time = time.perf_counter()

        # Get request info
        method = request.method
        path = request.url.path
        query = str(request.query_params) if request.query_params else ""
        client_ip = request.client.host if request.client else "unknown"

        # Log request
        logger.info(
            f"Request: {method} {path}"
            + (f"?{query}" if query else "")
            + f" | client: {client_ip}"
        )

        # Process request
        try:
            response = await call_next(request)

            # Calculate duration
            duration_ms = (time.perf_counter() - start_time) * 1000

            # Log response
            log_level = logging.INFO
            if response.status_code >= 500:
                log_level = logging.ERROR
            elif response.status_code >= 400:
                log_level = logging.WARNING

            logger.log(
                log_level,
                f"Response: {method} {path} | "
                f"status: {response.status_code} | "
                f"duration: {duration_ms:.2f}ms",
            )

            # Add request_id to response headers
            response.headers["X-Request-ID"] = request_id

            return response

        except Exception as e:
            # Calculate duration
            duration_ms = (time.perf_counter() - start_time) * 1000

            # Log exception
            logger.exception(
                f"Exception: {method} {path} | "
                f"error: {type(e).__name__}: {str(e)} | "
                f"duration: {duration_ms:.2f}ms"
            )
            raise
        finally:
            # Clear request_id context
            request_id_var.set(None)


class SlowRequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware for logging slow requests."""

    SLOW_REQUEST_THRESHOLD_MS = 1000  # 1 second

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()

        response = await call_next(request)

        duration_ms = (time.perf_counter() - start_time) * 1000

        if duration_ms > self.SLOW_REQUEST_THRESHOLD_MS:
            logger.warning(
                f"Slow request detected: {request.method} {request.url.path} | "
                f"duration: {duration_ms:.2f}ms | "
                f"threshold: {self.SLOW_REQUEST_THRESHOLD_MS}ms"
            )

        return response
