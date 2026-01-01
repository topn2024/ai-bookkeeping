"""OAuth authentication endpoints for third-party login."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import create_access_token, create_refresh_token
from app.models.user import User
from app.models.oauth_provider import OAuthProviderType
from app.schemas.user import Token, UserResponse
from app.schemas.oauth import (
    OAuthLoginRequest,
    OAuthBindRequest,
    OAuthProviderResponse,
    OAuthProviderListResponse,
)
from app.api.deps import get_current_user
from app.services.oauth_service import OAuthService


router = APIRouter(prefix="/auth/oauth", tags=["OAuth"])


@router.post("/login", response_model=Token)
async def oauth_login(
    request: OAuthLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Login or register with OAuth provider.

    Exchanges authorization code for user info and either:
    - Returns existing user's token if OAuth account is already bound
    - Creates new user and returns token if OAuth account is new
    - Links to existing user if email matches

    Supported providers: wechat, apple, google
    """
    if not OAuthProviderType.is_valid(request.provider):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid OAuth provider. Supported: {OAuthProviderType.all()}",
        )

    try:
        oauth_service = OAuthService(db)

        # Get user info from OAuth provider
        oauth_data = await oauth_service.get_oauth_user_info(request.provider, request.code)

        # Find or create user
        user, oauth_provider, is_new_user = await oauth_service.find_or_create_user(oauth_data)

        await db.commit()
        await db.refresh(user)

        # Generate tokens
        access_token = create_access_token(str(user.id))
        refresh_token = create_refresh_token(str(user.id))

        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            user=UserResponse.model_validate(user),
        )

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OAuth authentication failed: {str(e)}",
        )


@router.post("/bind/{provider}", response_model=OAuthProviderResponse)
async def bind_oauth_account(
    provider: str,
    request: OAuthBindRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Bind OAuth account to current user.

    This allows users to add additional login methods to their account.
    """
    if not OAuthProviderType.is_valid(provider):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid OAuth provider. Supported: {OAuthProviderType.all()}",
        )

    try:
        oauth_service = OAuthService(db)

        # Get user info from OAuth provider
        oauth_data = await oauth_service.get_oauth_user_info(provider, request.code)

        # Bind to current user
        oauth_provider = await oauth_service.bind_oauth_to_user(current_user.id, oauth_data)

        await db.commit()
        await db.refresh(oauth_provider)

        return OAuthProviderResponse.model_validate(oauth_provider)

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to bind OAuth account: {str(e)}",
        )


@router.delete("/unbind/{provider}")
async def unbind_oauth_account(
    provider: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Unbind OAuth account from current user.

    Note: User must have at least one login method (password or another OAuth provider).
    """
    if not OAuthProviderType.is_valid(provider):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid OAuth provider. Supported: {OAuthProviderType.all()}",
        )

    try:
        oauth_service = OAuthService(db)
        await oauth_service.unbind_oauth(current_user.id, provider)
        await db.commit()

        return {"message": f"Successfully unbound {provider} account"}

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to unbind OAuth account: {str(e)}",
        )


@router.get("/providers", response_model=OAuthProviderListResponse)
async def get_oauth_providers(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Get list of OAuth providers bound to current user.

    Also returns available providers that can be bound.
    """
    oauth_service = OAuthService(db)
    bound_providers = await oauth_service.get_user_oauth_providers(current_user.id)

    # Build available providers list with bound status
    bound_provider_names = {p.provider for p in bound_providers}
    available_providers = [
        {
            "provider": p,
            "name": OAuthProviderType.get_display_name(p),
            "bound": p in bound_provider_names,
        }
        for p in OAuthProviderType.all()
    ]

    return OAuthProviderListResponse(
        providers=[OAuthProviderResponse.model_validate(p) for p in bound_providers],
        available_providers=available_providers,
    )


@router.get("/config")
async def get_oauth_config():
    """
    Get OAuth configuration for frontend.

    Returns client IDs and redirect URIs (NOT secrets) for frontend OAuth initialization.
    """
    from app.core.config import settings

    return {
        "wechat": {
            "enabled": bool(settings.WECHAT_APP_ID),
            "app_id": settings.WECHAT_APP_ID if settings.WECHAT_APP_ID else None,
        },
        "apple": {
            "enabled": bool(settings.APPLE_CLIENT_ID),
            "client_id": settings.APPLE_CLIENT_ID if settings.APPLE_CLIENT_ID else None,
        },
        "google": {
            "enabled": bool(settings.GOOGLE_CLIENT_ID),
            "client_id": settings.GOOGLE_CLIENT_ID if settings.GOOGLE_CLIENT_ID else None,
            "redirect_uri": settings.GOOGLE_REDIRECT_URI if settings.GOOGLE_REDIRECT_URI else None,
        },
    }
