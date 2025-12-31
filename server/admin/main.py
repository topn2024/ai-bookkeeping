"""Admin platform main application."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from admin.api import admin_router
from app.core.logging import setup_logging
from app.middleware import RequestLoggingMiddleware, SlowRequestLoggingMiddleware

# Initialize logging
setup_logging()
logger = logging.getLogger(__name__)


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
    app = FastAPI(
        title="AI智能记账 - 管理平台API",
        description="企业级后台管理系统API",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc",
        lifespan=lifespan,
    )

    # CORS配置
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://localhost:3000",  # 开发环境
            "http://localhost:5173",  # Vite开发服务器
            "https://admin.yourdomain.com",  # 生产环境
        ],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

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
