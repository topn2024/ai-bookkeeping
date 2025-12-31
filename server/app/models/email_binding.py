"""Email binding model for storing user email authorization."""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Boolean, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class EmailBinding(Base):
    """Email binding model for storing OAuth tokens and sync status."""

    __tablename__ = "email_bindings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    email: Mapped[str] = mapped_column(String(100), nullable=False)
    email_type: Mapped[int] = mapped_column(Integer, nullable=False)  # 1: Gmail, 2: Outlook, 3: QQ, 4: 163, 5: IMAP

    # OAuth tokens (for Gmail/Outlook)
    access_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    refresh_token: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    token_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # IMAP credentials (for QQ/163/custom IMAP)
    imap_server: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    imap_port: Mapped[Optional[int]] = mapped_column(Integer, nullable=True, default=993)
    imap_password: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # Encrypted

    # Sync status
    last_sync_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)
    last_sync_message_id: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)  # For incremental sync
    sync_error: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User", back_populates="email_bindings")


# Email type constants
class EmailType:
    GMAIL = 1
    OUTLOOK = 2
    QQ = 3
    NETEASE_163 = 4
    IMAP = 5  # Custom IMAP server

    @classmethod
    def get_name(cls, email_type: int) -> str:
        names = {
            cls.GMAIL: "Gmail",
            cls.OUTLOOK: "Outlook",
            cls.QQ: "QQ邮箱",
            cls.NETEASE_163: "163邮箱",
            cls.IMAP: "自定义IMAP",
        }
        return names.get(email_type, "未知")
