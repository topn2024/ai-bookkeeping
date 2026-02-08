"""Admin platform main application."""
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from admin.api import admin_router
from app.core.logging import setup_logging
from app.middleware import RequestLoggingMiddleware, SlowRequestLoggingMiddleware

# Initialize logging
setup_logging()
logger = logging.getLogger(__name__)


# ============ Security Headers Middleware ============

class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """添加安全响应头"""

    async def dispatch(self, request: Request, call_next):
        response: Response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        # HSTS - only enable when behind HTTPS
        if request.headers.get("x-forwarded-proto") == "https":
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    logger.info("Admin API starting up...")
    yield
    # Shutdown
    logger.info("Admin API shutting down...")


def create_admin_app() -> FastAPI:
    """Create the admin FastAPI application."""
    is_debug = os.getenv("DEBUG", "false").lower() == "true"

    app = FastAPI(
        title="AI智能记账 - 管理平台API",
        description="企业级后台管理系统API",
        version="1.0.0",
        # 生产环境关闭API文档
        docs_url="/docs" if is_debug else None,
        redoc_url="/redoc" if is_debug else None,
        lifespan=lifespan,
    )

    # CORS配置 - 从环境变量读取，收紧默认值
    admin_cors_origins = os.getenv(
        "ADMIN_CORS_ORIGINS",
        "http://localhost:3000,http://localhost:5173",
    ).split(",")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=[origin.strip() for origin in admin_cors_origins],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "X-Requested-With"],
    )

    # 安全响应头中间件
    app.add_middleware(SecurityHeadersMiddleware)

    # 日志中间件 (order matters: last added = first executed)
    app.add_middleware(SlowRequestLoggingMiddleware)
    app.add_middleware(RequestLoggingMiddleware)

    # 注册路由
    app.include_router(admin_router, prefix="/admin")

    @app.get("/health")
    async def health_check():
        """健康检查"""
        return {"status": "healthy", "service": "admin-api"}

    return app


# 创建应用实例
app = create_admin_app()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "admin.main:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
    )
