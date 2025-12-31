"""FastAPI application entry point."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.database import engine
from app.core.logging import setup_logging, get_logger
from app.middleware import RequestLoggingMiddleware, SlowRequestLoggingMiddleware
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
    await engine.dispose()
    logger.info("Database connections closed")


app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
    description="AI-powered personal bookkeeping API",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Logging middleware (order matters: last added = first executed)
app.add_middleware(SlowRequestLoggingMiddleware)
app.add_middleware(RequestLoggingMiddleware)

# API Version compatibility middleware
app.add_middleware(APIVersionMiddleware)

# Include API routes
app.include_router(api_router, prefix="/api/v1")

# Include Admin API routes
app.include_router(admin_router, prefix="/admin")


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    from app.middleware.api_version import APIVersionConfig
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
        "api_version": APIVersionConfig.CURRENT_VERSION,
    }


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
