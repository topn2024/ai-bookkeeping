"""Client configuration endpoints."""
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.config import get_settings
from app.api.deps import get_current_user
from app.models.user import User


router = APIRouter(prefix="/config", tags=["Configuration"])


class AIConfig(BaseModel):
    """AI API configuration for client."""
    qwen_api_key: str
    zhipu_api_key: str | None = None


class AppConfig(BaseModel):
    """Application configuration for client."""
    ai: AIConfig
    version: str = "1.0.0"


@router.get("/ai", response_model=AIConfig)
async def get_ai_config(
    current_user: User = Depends(get_current_user),
):
    """Get AI API configuration.

    Returns API keys for AI services. Requires authentication.
    """
    settings = get_settings()
    return AIConfig(
        qwen_api_key=settings.QWEN_API_KEY,
        zhipu_api_key=settings.ZHIPU_API_KEY if settings.ZHIPU_API_KEY else None,
    )


@router.get("/app", response_model=AppConfig)
async def get_app_config(
    current_user: User = Depends(get_current_user),
):
    """Get full application configuration.

    Returns all client configuration. Requires authentication.
    """
    settings = get_settings()
    return AppConfig(
        ai=AIConfig(
            qwen_api_key=settings.QWEN_API_KEY,
            zhipu_api_key=settings.ZHIPU_API_KEY if settings.ZHIPU_API_KEY else None,
        ),
        version="1.0.0",
    )
