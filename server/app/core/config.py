"""Application configuration.

All sensitive configuration values should be set via environment variables
or .env file. Never commit real credentials to the repository.
"""
import os
import sys
from functools import lru_cache
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings.

    All sensitive values should be configured via environment variables.
    See .env.example for required variables.
    """

    # App
    APP_NAME: str = "AI Bookkeeping"
    APP_BASE_URL: str = "http://localhost:8000"  # 应用基础URL，用于生成验证链接
    DEBUG: bool = False
    SECRET_KEY: str = ""  # Required: Set via environment variable

    # Database
    DATABASE_URL: str = ""  # Required: Set via environment variable

    # Redis
    REDIS_URL: str = ""  # Required: Set via environment variable

    # Celery
    CELERY_BROKER_URL: str = ""  # Defaults to REDIS_URL if not set
    CELERY_RESULT_BACKEND: str = ""  # Defaults to REDIS_URL if not set
    CELERY_TIMEZONE: str = "Asia/Shanghai"

    # JWT
    JWT_SECRET_KEY: str = ""  # Required: Set via environment variable
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # MinIO
    MINIO_ENDPOINT: str = "localhost:9000"
    MINIO_ACCESS_KEY: str = ""  # Required: Set via environment variable
    MINIO_SECRET_KEY: str = ""  # Required: Set via environment variable
    MINIO_BUCKET: str = "ai-bookkeeping"
    MINIO_SECURE: bool = False
    MINIO_PUBLIC_URL: str = ""  # Public URL for file downloads, e.g., https://39.105.12.124

    # AI APIs
    QWEN_API_KEY: str = ""  # Required: Set via environment variable
    ZHIPU_API_KEY: str = ""  # Optional: Set via environment variable

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

    # SMTP Email
    SMTP_HOST: str = ""  # e.g., smtp.gmail.com
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = ""  # Sender email address
    SMTP_FROM_NAME: str = "AI Bookkeeping"
    SMTP_USE_TLS: bool = True

    # Aliyun SMS (阿里云短信服务)
    ALIYUN_ACCESS_KEY_ID: str = ""  # Required for SMS
    ALIYUN_ACCESS_KEY_SECRET: str = ""  # Required for SMS
    ALIYUN_SMS_SIGN_NAME: str = "AI智能记账"  # SMS signature name
    ALIYUN_SMS_TEMPLATE_CODE: str = ""  # SMS template code for verification
    ALIYUN_SMS_REGION: str = "cn-hangzhou"  # Default region

    # Logging
    LOG_LEVEL: str = "INFO"

    # CORS - comma-separated list of allowed origins, or "*" for all
    CORS_ORIGINS: str = "*"

    # SSL/TLS
    SKIP_SSL_VERIFICATION: bool = False  # Set to True only for development

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"

    def validate_required_settings(self):
        """Validate that required settings are configured."""
        required_fields = {
            "SECRET_KEY": self.SECRET_KEY,
            "DATABASE_URL": self.DATABASE_URL,
            "REDIS_URL": self.REDIS_URL,
            "JWT_SECRET_KEY": self.JWT_SECRET_KEY,
        }

        missing = [name for name, value in required_fields.items() if not value]

        if missing:
            print(f"ERROR: Missing required configuration: {', '.join(missing)}", file=sys.stderr)
            print("Please set these environment variables or add them to .env file", file=sys.stderr)
            sys.exit(1)

        # Warn about insecure settings in production
        if not self.DEBUG:
            if self.CORS_ORIGINS == "*":
                print("WARNING: CORS_ORIGINS is set to '*' in production. This is insecure!", file=sys.stderr)

            if self.SKIP_SSL_VERIFICATION:
                print("WARNING: SKIP_SSL_VERIFICATION is enabled in production. This is insecure!", file=sys.stderr)


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings."""
    settings = Settings()
    settings.validate_required_settings()
    return settings


settings = get_settings()
