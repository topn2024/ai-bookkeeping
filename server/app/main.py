"""FastAPI application entry point."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import engine
from app.core.logging import setup_logging, get_logger
from app.core.redis import get_redis, close_redis, redis_manager
from app.middleware import (
    RequestLoggingMiddleware,
    SlowRequestLoggingMiddleware,
    RateLimitMiddleware,
    IdempotencyMiddleware,
)
from app.middleware.api_version import APIVersionMiddleware
from app.models import *  # noqa: Import all models for table creation
from app.api.v1 import api_router
from app.services.init_service import init_system_categories
from app.core.database import AsyncSessionLocal

# Admin API
from admin.api import admin_router

# Initialize logging first
setup_logging()
logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events."""
    logger.info("Application starting up...")

    # Initialize Redis connection (using enhanced manager)
    await redis_manager.connect(settings.REDIS_URL)
    redis_client = await get_redis()
    if redis_client:
        logger.info("Redis connection initialized for rate limiting and caching")
    else:
        logger.warning("Redis not available, rate limiting and caching will be disabled")

    # Initialize distributed consistency services
    logger.info("Initializing distributed consistency services...")
    try:
        from app.services.cache_consistency_service import cache_service
        from app.services.distributed_lock_service import distributed_lock
        from app.services.data_integrity_service import data_integrity

        # Services are singletons, just log their availability
        logger.info(f"Cache service initialized (hit_rate tracking enabled)")
        logger.info(f"Distributed lock service initialized")
        logger.info(f"Data integrity service initialized")
    except ImportError as e:
        logger.warning(f"Some distributed services unavailable: {e}")

    # Startup: Create tables and initialize system data
    async with engine.begin() as conn:
        # Create all tables
        from app.core.database import Base
        await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables created/verified")

    # Initialize system categories
    async with AsyncSessionLocal() as db:
        await init_system_categories(db)
        await db.commit()
        logger.info("System categories initialized")

    logger.info(f"Application {settings.APP_NAME} started successfully")
    yield

    # Shutdown
    logger.info("Application shutting down...")

    # Close AI service httpx client
    try:
        from app.services.ai_service import ai_service
        await ai_service.close()
        logger.info("AI service client closed")
    except Exception as e:
        logger.warning(f"Error closing AI service: {e}")

    # Cleanup distributed services
    try:
        from app.services.cache_consistency_service import cache_service
        from app.services.distributed_lock_service import distributed_lock

        await cache_service.close()
        logger.info("Cache service closed")

        await distributed_lock.close()
        logger.info("Distributed lock service closed")
    except Exception as e:
        logger.warning(f"Error closing distributed services: {e}")

    await close_redis()
    logger.info("Redis connection closed")
    await engine.dispose()
    logger.info("Database connections closed")


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="AI-powered personal bookkeeping API",
    lifespan=lifespan,
)

# CORS middleware
cors_origins = settings.CORS_ORIGINS.split(",") if settings.CORS_ORIGINS != "*" else ["*"]
if cors_origins == ["*"]:
    logger.warning("CORS_ORIGINS is set to '*'. This is insecure for production!")
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Requested-With", "X-API-Version", "X-Idempotency-Key"],
)

# Logging middleware (order matters: last added = first executed)
app.add_middleware(SlowRequestLoggingMiddleware)
app.add_middleware(RequestLoggingMiddleware)

# Rate limiting middleware
app.add_middleware(RateLimitMiddleware, enabled=True)

# Idempotency middleware
app.add_middleware(IdempotencyMiddleware)

# API Version compatibility middleware
app.add_middleware(APIVersionMiddleware)

# Include API routes
app.include_router(api_router, prefix="/api/v1")

# Include Admin API routes
app.include_router(admin_router, prefix="/admin")


@app.get("/health")
async def health_check():
    """Health check endpoint - basic liveness check."""
    from app.middleware.api_version import APIVersionConfig
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "api_version": APIVersionConfig.CURRENT_VERSION,
    }


@app.get("/live")
async def liveness_check():
    """Kubernetes liveness probe endpoint.

    Returns 200 if the application is running.
    This is a lightweight check that doesn't verify dependencies.
    """
    return {"status": "alive"}


@app.get("/ready")
async def readiness_check():
    """Kubernetes readiness probe endpoint.

    Returns 200 if the application is ready to receive traffic.
    Checks all critical dependencies (database, Redis, etc.).
    """
    from sqlalchemy import text
    from app.core.circuit_breaker import get_all_circuit_breakers

    checks = {
        "database": {"status": "unknown", "latency_ms": 0},
        "redis": {"status": "unknown", "latency_ms": 0},
    }
    all_healthy = True

    # Check database connection
    import time
    try:
        start = time.perf_counter()
        async with AsyncSessionLocal() as db:
            await db.execute(text("SELECT 1"))
        latency = (time.perf_counter() - start) * 1000
        checks["database"] = {"status": "healthy", "latency_ms": round(latency, 2)}
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        checks["database"] = {"status": "unhealthy", "error": str(e)}
        all_healthy = False

    # Check Redis connection (using enhanced manager)
    try:
        redis_health = await redis_manager.health_check()
        if redis_health.get("connected"):
            checks["redis"] = {
                "status": "healthy",
                "latency_ms": redis_health.get("latency_ms", 0),
                "version": redis_health.get("redis_version", "unknown"),
            }
        else:
            checks["redis"] = {
                "status": "not_configured",
                "error": redis_health.get("error"),
            }
    except Exception as e:
        logger.error(f"Redis health check failed: {e}")
        checks["redis"] = {"status": "unhealthy", "error": str(e)}
        all_healthy = False

    # Check distributed services
    try:
        from app.services.cache_consistency_service import cache_service
        from app.services.distributed_lock_service import distributed_lock
        from app.services.data_integrity_service import data_integrity

        checks["distributed_services"] = {
            "cache": cache_service.get_stats_summary(),
            "lock": distributed_lock.get_stats_summary(),
            "integrity": data_integrity.get_summary(),
        }
    except Exception as e:
        checks["distributed_services"] = {"status": "unavailable", "error": str(e)}

    # Check circuit breakers
    circuit_breakers = get_all_circuit_breakers()
    cb_status = {}
    for name, cb in circuit_breakers.items():
        cb_info = cb.get_status()
        cb_status[name] = {
            "state": cb_info["state"],
            "failures": cb_info["stats"]["consecutive_failures"],
        }
        if cb.is_open:
            all_healthy = False

    if cb_status:
        checks["circuit_breakers"] = cb_status

    from fastapi.responses import JSONResponse

    status_code = 200 if all_healthy else 503
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ready" if all_healthy else "not_ready",
            "checks": checks,
        }
    )


@app.get("/")
async def root():
    """Root endpoint."""
    from app.middleware.api_version import APIVersionConfig
    return {
        "message": f"Welcome to {settings.APP_NAME} API",
        "docs": "/docs",
        "version": "1.0.0",
        "api_version": APIVersionConfig.CURRENT_VERSION,
        "min_api_version": APIVersionConfig.MIN_SUPPORTED_VERSION,
    }
