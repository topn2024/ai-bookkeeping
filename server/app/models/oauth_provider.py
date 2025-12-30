"""OAuth provider model for third-party login integration."""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Boolean, ForeignKey, Text, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class OAuthProvider(Base):
    """OAuth provider binding for third-party login."""

    __tablename__ = "oauth_providers"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # Provider identification
    provider: Mapped[str] = mapped_column(String(20), nullable=False)  # wechat, apple, google
    provider_user_id: Mapped[str] = mapped_column(String(200), nullable=False)  # openid / sub / user_id

    # Provider user info (cached)
    provider_username: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # nickname
    provider_avatar: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)  # avatar url
    provider_email: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # email from provider
    provider_raw_data: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)  # full user info from provider

    # OAuth tokens (encrypted in production)
    access_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    refresh_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    token_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Metadata
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_login_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="oauth_providers")

    # Unique constraint: one user can only bind one account per provider
    __table_args__ = (
        # Unique index on provider + provider_user_id to prevent duplicate bindings
        {"sqlite_autoincrement": True},
    )


# Provider constants
class OAuthProviderType:
    WECHAT = "wechat"
    APPLE = "apple"
    GOOGLE = "google"

    @classmethod
    def all(cls) -> list:
        return [cls.WECHAT, cls.APPLE, cls.GOOGLE]

    @classmethod
    def get_display_name(cls, provider: str) -> str:
        names = {
            cls.WECHAT: "微信",
            cls.APPLE: "Apple",
            cls.GOOGLE: "Google",
        }
        return names.get(provider, provider)

    @classmethod
    def is_valid(cls, provider: str) -> bool:
        return provider in cls.all()
