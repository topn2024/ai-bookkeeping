"""OAuth service for third-party login integration."""
import logging
import httpx
import jwt
from jwt import PyJWKClient
from datetime import datetime, timedelta
from typing import Optional, Tuple
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.config import settings
from app.models.user import User
from app.models.oauth_provider import OAuthProvider, OAuthProviderType
from app.schemas.oauth import OAuthCallbackData
from app.services.init_service import init_user_data

logger = logging.getLogger(__name__)

# Apple JWKS client (cached, thread-safe)
_apple_jwks_client: Optional[PyJWKClient] = None


def _get_apple_jwks_client() -> PyJWKClient:
    """Get or create Apple JWKS client with caching."""
    global _apple_jwks_client
    if _apple_jwks_client is None:
        _apple_jwks_client = PyJWKClient(
            "https://appleid.apple.com/auth/keys",
            cache_keys=True,
            lifespan=3600,
        )
    return _apple_jwks_client


class OAuthService:
    """Service for handling OAuth authentication with third-party providers."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_oauth_user_info(self, provider: str, code: str) -> OAuthCallbackData:
        """
        Exchange authorization code for access token and get user info.

        Args:
            provider: OAuth provider name (wechat, apple, google)
            code: Authorization code from OAuth provider

        Returns:
            OAuthCallbackData with user information
        """
        if provider == OAuthProviderType.WECHAT:
            return await self._get_wechat_user_info(code)
        elif provider == OAuthProviderType.APPLE:
            return await self._get_apple_user_info(code)
        elif provider == OAuthProviderType.GOOGLE:
            return await self._get_google_user_info(code)
        else:
            raise ValueError(f"Unsupported OAuth provider: {provider}")

    async def _get_wechat_user_info(self, code: str) -> OAuthCallbackData:
        """Get WeChat user info from authorization code."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Step 1: Exchange code for access token
            token_url = "https://api.weixin.qq.com/sns/oauth2/access_token"
            token_params = {
                "appid": settings.WECHAT_APP_ID,
                "secret": settings.WECHAT_APP_SECRET,
                "code": code,
                "grant_type": "authorization_code",
            }
            token_response = await client.get(token_url, params=token_params)
            token_data = token_response.json()

            if "errcode" in token_data:
                logger.error(f"WeChat token error: {token_data.get('errmsg', 'Unknown error')}")
                raise ValueError("WeChat authentication failed")

            access_token = token_data["access_token"]
            openid = token_data["openid"]
            refresh_token = token_data.get("refresh_token")
            expires_in = token_data.get("expires_in", 7200)

            # Step 2: Get user info
            userinfo_url = "https://api.weixin.qq.com/sns/userinfo"
            userinfo_params = {
                "access_token": access_token,
                "openid": openid,
                "lang": "zh_CN",
            }
            userinfo_response = await client.get(userinfo_url, params=userinfo_params)
            userinfo_data = userinfo_response.json()

            if "errcode" in userinfo_data:
                logger.error(f"WeChat userinfo error: {userinfo_data.get('errmsg', 'Unknown error')}")
                raise ValueError("WeChat authentication failed")

            return OAuthCallbackData(
                provider=OAuthProviderType.WECHAT,
                provider_user_id=userinfo_data.get("unionid") or openid,
                provider_username=userinfo_data.get("nickname"),
                provider_avatar=userinfo_data.get("headimgurl"),
                provider_email=None,  # WeChat doesn't provide email
                provider_raw_data=userinfo_data,
                access_token=access_token,
                refresh_token=refresh_token,
                token_expires_at=datetime.utcnow() + timedelta(seconds=expires_in),
            )

    async def _get_apple_user_info(self, code: str) -> OAuthCallbackData:
        """Get Apple user info from authorization code."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Step 1: Exchange code for tokens
            token_url = "https://appleid.apple.com/auth/token"

            # Generate client secret (JWT)
            client_secret = self._generate_apple_client_secret()

            token_data = {
                "client_id": settings.APPLE_CLIENT_ID,
                "client_secret": client_secret,
                "code": code,
                "grant_type": "authorization_code",
            }

            token_response = await client.post(token_url, data=token_data)
            token_result = token_response.json()

            if "error" in token_result:
                logger.error(f"Apple token error: {token_result.get('error_description', token_result.get('error'))}")
                raise ValueError("Apple authentication failed")

            id_token = token_result["id_token"]
            access_token = token_result.get("access_token")
            refresh_token = token_result.get("refresh_token")
            expires_in = token_result.get("expires_in", 3600)

            # Step 2: Decode and verify ID token signature using Apple's JWKS
            try:
                jwks_client = _get_apple_jwks_client()
                signing_key = jwks_client.get_signing_key_from_jwt(id_token)
                id_token_payload = jwt.decode(
                    id_token,
                    key=signing_key.key,
                    algorithms=["RS256"],
                    audience=settings.APPLE_CLIENT_ID,
                    issuer="https://appleid.apple.com",
                )
            except jwt.InvalidTokenError as e:
                logger.error(f"Apple ID token verification failed: {e}")
                raise ValueError("Invalid Apple ID token")

            return OAuthCallbackData(
                provider=OAuthProviderType.APPLE,
                provider_user_id=id_token_payload["sub"],
                provider_username=id_token_payload.get("name"),
                provider_avatar=None,  # Apple doesn't provide avatar
                provider_email=id_token_payload.get("email"),
                provider_raw_data=id_token_payload,
                access_token=access_token,
                refresh_token=refresh_token,
                token_expires_at=datetime.utcnow() + timedelta(seconds=expires_in),
            )

    def _generate_apple_client_secret(self) -> str:
        """Generate Apple client secret JWT."""
        now = datetime.utcnow()
        payload = {
            "iss": settings.APPLE_TEAM_ID,
            "iat": now,
            "exp": now + timedelta(days=180),
            "aud": "https://appleid.apple.com",
            "sub": settings.APPLE_CLIENT_ID,
        }

        # Sign with Apple private key
        return jwt.encode(
            payload,
            settings.APPLE_PRIVATE_KEY,
            algorithm="ES256",
            headers={"kid": settings.APPLE_KEY_ID},
        )

    async def _get_google_user_info(self, code: str) -> OAuthCallbackData:
        """Get Google user info from authorization code."""
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Step 1: Exchange code for access token
            token_url = "https://oauth2.googleapis.com/token"
            token_data = {
                "client_id": settings.GOOGLE_CLIENT_ID,
                "client_secret": settings.GOOGLE_CLIENT_SECRET,
                "code": code,
                "grant_type": "authorization_code",
                "redirect_uri": settings.GOOGLE_REDIRECT_URI,
            }

            token_response = await client.post(token_url, data=token_data)
            token_result = token_response.json()

            if "error" in token_result:
                logger.error(f"Google token error: {token_result.get('error_description', token_result.get('error'))}")
                raise ValueError("Google authentication failed")

            access_token = token_result["access_token"]
            refresh_token = token_result.get("refresh_token")
            expires_in = token_result.get("expires_in", 3600)

            # Step 2: Get user info
            userinfo_url = "https://www.googleapis.com/oauth2/v2/userinfo"
            headers = {"Authorization": f"Bearer {access_token}"}

            userinfo_response = await client.get(userinfo_url, headers=headers)
            userinfo_data = userinfo_response.json()

            if "error" in userinfo_data:
                logger.error(f"Google userinfo error: {userinfo_data.get('error', {}).get('message', 'Unknown error')}")
                raise ValueError("Google authentication failed")

            return OAuthCallbackData(
                provider=OAuthProviderType.GOOGLE,
                provider_user_id=userinfo_data["id"],
                provider_username=userinfo_data.get("name"),
                provider_avatar=userinfo_data.get("picture"),
                provider_email=userinfo_data.get("email"),
                provider_raw_data=userinfo_data,
                access_token=access_token,
                refresh_token=refresh_token,
                token_expires_at=datetime.utcnow() + timedelta(seconds=expires_in),
            )

    async def find_or_create_user(self, oauth_data: OAuthCallbackData) -> Tuple[User, OAuthProvider, bool]:
        """
        Find existing user or create new user from OAuth data.

        Returns:
            Tuple of (user, oauth_provider, is_new_user)
        """
        # Check if OAuth provider binding already exists
        result = await self.db.execute(
            select(OAuthProvider).where(
                OAuthProvider.provider == oauth_data.provider,
                OAuthProvider.provider_user_id == oauth_data.provider_user_id,
            )
        )
        existing_provider = result.scalar_one_or_none()

        if existing_provider:
            # Update OAuth provider info
            existing_provider.provider_username = oauth_data.provider_username
            existing_provider.provider_avatar = oauth_data.provider_avatar
            existing_provider.provider_email = oauth_data.provider_email
            existing_provider.provider_raw_data = oauth_data.provider_raw_data
            existing_provider.access_token = oauth_data.access_token
            existing_provider.refresh_token = oauth_data.refresh_token
            existing_provider.token_expires_at = oauth_data.token_expires_at
            existing_provider.last_login_at = datetime.utcnow()

            # Get associated user
            user_result = await self.db.execute(
                select(User).where(User.id == existing_provider.user_id)
            )
            user = user_result.scalar_one()

            return user, existing_provider, False

        # Check if user exists with same email (for linking)
        user = None
        if oauth_data.provider_email:
            result = await self.db.execute(
                select(User).where(User.email == oauth_data.provider_email)
            )
            user = result.scalar_one_or_none()

        is_new_user = user is None

        if is_new_user:
            # Create new user
            user = User(
                email=oauth_data.provider_email,
                nickname=oauth_data.provider_username or f"User_{oauth_data.provider_user_id[:8]}",
                avatar_url=oauth_data.provider_avatar,
                password_hash="",  # OAuth users don't have password
            )
            self.db.add(user)
            await self.db.flush()

            # Initialize user data
            await init_user_data(self.db, user)

        # Create OAuth provider binding
        oauth_provider = OAuthProvider(
            user_id=user.id,
            provider=oauth_data.provider,
            provider_user_id=oauth_data.provider_user_id,
            provider_username=oauth_data.provider_username,
            provider_avatar=oauth_data.provider_avatar,
            provider_email=oauth_data.provider_email,
            provider_raw_data=oauth_data.provider_raw_data,
            access_token=oauth_data.access_token,
            refresh_token=oauth_data.refresh_token,
            token_expires_at=oauth_data.token_expires_at,
            last_login_at=datetime.utcnow(),
        )
        self.db.add(oauth_provider)

        return user, oauth_provider, is_new_user

    async def bind_oauth_to_user(
        self, user_id: UUID, oauth_data: OAuthCallbackData
    ) -> OAuthProvider:
        """
        Bind OAuth account to existing user.

        Args:
            user_id: Existing user's ID
            oauth_data: OAuth provider data

        Returns:
            Created OAuthProvider
        """
        # Check if this OAuth account is already bound to another user
        result = await self.db.execute(
            select(OAuthProvider).where(
                OAuthProvider.provider == oauth_data.provider,
                OAuthProvider.provider_user_id == oauth_data.provider_user_id,
            )
        )
        existing = result.scalar_one_or_none()

        if existing:
            if existing.user_id != user_id:
                raise ValueError(f"This {oauth_data.provider} account is already bound to another user")
            # Already bound to same user, update info
            existing.provider_username = oauth_data.provider_username
            existing.provider_avatar = oauth_data.provider_avatar
            existing.provider_email = oauth_data.provider_email
            existing.provider_raw_data = oauth_data.provider_raw_data
            existing.access_token = oauth_data.access_token
            existing.refresh_token = oauth_data.refresh_token
            existing.token_expires_at = oauth_data.token_expires_at
            return existing

        # Check if user already has this provider bound
        result = await self.db.execute(
            select(OAuthProvider).where(
                OAuthProvider.user_id == user_id,
                OAuthProvider.provider == oauth_data.provider,
            )
        )
        existing_for_user = result.scalar_one_or_none()

        if existing_for_user:
            raise ValueError(f"User already has a {oauth_data.provider} account bound")

        # Create new binding
        oauth_provider = OAuthProvider(
            user_id=user_id,
            provider=oauth_data.provider,
            provider_user_id=oauth_data.provider_user_id,
            provider_username=oauth_data.provider_username,
            provider_avatar=oauth_data.provider_avatar,
            provider_email=oauth_data.provider_email,
            provider_raw_data=oauth_data.provider_raw_data,
            access_token=oauth_data.access_token,
            refresh_token=oauth_data.refresh_token,
            token_expires_at=oauth_data.token_expires_at,
        )
        self.db.add(oauth_provider)

        return oauth_provider

    async def unbind_oauth(self, user_id: UUID, provider: str) -> bool:
        """
        Unbind OAuth account from user.

        Args:
            user_id: User's ID
            provider: OAuth provider to unbind

        Returns:
            True if successfully unbound
        """
        result = await self.db.execute(
            select(OAuthProvider).where(
                OAuthProvider.user_id == user_id,
                OAuthProvider.provider == provider,
            )
        )
        oauth_provider = result.scalar_one_or_none()

        if not oauth_provider:
            raise ValueError(f"No {provider} account bound to this user")

        # Check if user has other login methods
        user_result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = user_result.scalar_one()

        # Count other OAuth providers
        providers_result = await self.db.execute(
            select(OAuthProvider).where(
                OAuthProvider.user_id == user_id,
                OAuthProvider.provider != provider,
            )
        )
        other_providers = providers_result.scalars().all()

        # User must have at least one login method (password or OAuth)
        has_password = bool(user.password_hash)
        has_other_oauth = len(other_providers) > 0

        if not has_password and not has_other_oauth:
            raise ValueError("Cannot unbind the only login method. Please set a password first.")

        await self.db.delete(oauth_provider)
        return True

    async def get_user_oauth_providers(self, user_id: UUID) -> list:
        """Get all OAuth providers bound to a user."""
        result = await self.db.execute(
            select(OAuthProvider).where(OAuthProvider.user_id == user_id)
        )
        return result.scalars().all()
