"""OAuth provider schemas."""
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class OAuthLoginRequest(BaseModel):
    """Request schema for OAuth login/register."""
    provider: str = Field(..., description="OAuth provider: wechat, apple, google")
    code: str = Field(..., description="Authorization code from OAuth provider")
    # For WeChat, this is the code; for Apple/Google, this is the authorization code

    # Optional: used for binding to existing account
    access_token: Optional[str] = Field(None, description="Existing user's access token for binding")


class OAuthCallbackData(BaseModel):
    """Data received from OAuth provider callback."""
    provider: str
    provider_user_id: str
    provider_username: Optional[str] = None
    provider_avatar: Optional[str] = None
    provider_email: Optional[str] = None
    provider_raw_data: Optional[dict] = None
    access_token: Optional[str] = None
    refresh_token: Optional[str] = None
    token_expires_at: Optional[datetime] = None


class OAuthProviderResponse(BaseModel):
    """Response schema for OAuth provider binding."""
    id: UUID
    provider: str
    provider_username: Optional[str] = None
    provider_avatar: Optional[str] = None
    provider_email: Optional[str] = None
    is_active: bool
    last_login_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class OAuthProviderListResponse(BaseModel):
    """Response schema for list of OAuth provider bindings."""
    providers: List[OAuthProviderResponse]

    # Available providers that can be bound
    available_providers: List[dict] = Field(
        default_factory=lambda: [
            {"provider": "wechat", "name": "微信", "bound": False},
            {"provider": "apple", "name": "Apple", "bound": False},
            {"provider": "google", "name": "Google", "bound": False},
        ]
    )


class OAuthBindRequest(BaseModel):
    """Request schema for binding OAuth account to existing user."""
    code: str = Field(..., description="Authorization code from OAuth provider")


class OAuthUnbindRequest(BaseModel):
    """Request schema for unbinding OAuth account."""
    provider: str = Field(..., description="OAuth provider to unbind")


class WeChatTokenResponse(BaseModel):
    """WeChat access token response."""
    access_token: str
    expires_in: int
    refresh_token: str
    openid: str
    scope: str
    unionid: Optional[str] = None


class WeChatUserInfo(BaseModel):
    """WeChat user info response."""
    openid: str
    nickname: str
    sex: int
    province: str
    city: str
    country: str
    headimgurl: str
    privilege: List[str] = []
    unionid: Optional[str] = None


class AppleTokenResponse(BaseModel):
    """Apple ID token response."""
    access_token: str
    token_type: str
    expires_in: int
    refresh_token: str
    id_token: str


class GoogleTokenResponse(BaseModel):
    """Google OAuth token response."""
    access_token: str
    expires_in: int
    refresh_token: Optional[str] = None
    scope: str
    token_type: str
    id_token: str


class GoogleUserInfo(BaseModel):
    """Google user info response."""
    id: str
    email: str
    verified_email: bool
    name: str
    given_name: Optional[str] = None
    family_name: Optional[str] = None
    picture: Optional[str] = None
    locale: Optional[str] = None
