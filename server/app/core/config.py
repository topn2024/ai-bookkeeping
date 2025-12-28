"""Application configuration."""
import os
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings."""

    # App
    APP_NAME: str = "AI Bookkeeping"
    DEBUG: bool = False
    SECRET_KEY: str = "your-secret-key-change-in-production"

    # Database
    DATABASE_URL: str = "postgresql+asyncpg://ai_bookkeeping:AiBookkeeping@2024@localhost:5432/ai_bookkeeping"

    # Redis
    REDIS_URL: str = "redis://:AiBookkeeping@2024@localhost:6379/0"

    # JWT
    JWT_SECRET_KEY: str = "jwt-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # MinIO
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = "minioadmin"
    MINIO_SECRET_KEY: str = "AiBookkeeping@2024"
    MINIO_BUCKET: str = "ai-bookkeeping"
    MINIO_SECURE: bool = False

    # AI APIs
    QWEN_API_KEY: str = ""
    ZHIPU_API_KEY: str = ""

    # OAuth - WeChat
    WECHAT_APP_ID: str = ""
    WECHAT_APP_SECRET: str = ""

    # OAuth - Apple Sign In
    APPLE_CLIENT_ID: str = ""  # Bundle ID or Service ID
    APPLE_TEAM_ID: str = ""
    APPLE_KEY_ID: str = ""
    APPLE_PRIVATE_KEY: str = ""  # P8 private key content

    # OAuth - Google
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    GOOGLE_REDIRECT_URI: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings."""
    return Settings()


settings = get_settings()
