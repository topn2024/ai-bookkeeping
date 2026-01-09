"""Upgrade analytics model for tracking app upgrade events."""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Text, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class UpgradeAnalytics(Base):
    """Store upgrade analytics events from client apps."""

    __tablename__ = "upgrade_analytics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)

    # Event identification
    event_type: Mapped[str] = mapped_column(String(50), nullable=False, index=True,
                                           comment="Event type: check_update, download_start, etc.")
    platform: Mapped[str] = mapped_column(String(20), nullable=False, default="android",
                                         comment="Platform: android/ios")

    # Version info
    from_version: Mapped[str] = mapped_column(String(20), nullable=False,
                                             comment="Version before upgrade")
    to_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True,
                                                       comment="Target version for upgrade")
    from_build: Mapped[Optional[int]] = mapped_column(Integer, nullable=True,
                                                       comment="Build number before upgrade")
    to_build: Mapped[Optional[int]] = mapped_column(Integer, nullable=True,
                                                     comment="Target build number")

    # Download metrics
    download_progress: Mapped[Optional[int]] = mapped_column(Integer, nullable=True,
                                                             comment="Download progress percentage (0-100)")
    download_size: Mapped[Optional[int]] = mapped_column(Integer, nullable=True,
                                                         comment="Total download size in bytes")
    download_duration_ms: Mapped[Optional[int]] = mapped_column(Integer, nullable=True,
                                                                comment="Download duration in milliseconds")

    # Error info
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
                                                          comment="Error message if failed")
    error_code: Mapped[Optional[str]] = mapped_column(String(50), nullable=True,
                                                       comment="Error code for categorization")

    # Device info
    device_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True, index=True,
                                                      comment="Unique device identifier")
    device_model: Mapped[Optional[str]] = mapped_column(String(100), nullable=True,
                                                         comment="Device model name")

    # Extra data (JSON)
    extra_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True,
                                                       comment="Additional JSON data")

    # Timestamps
    event_time: Mapped[datetime] = mapped_column(DateTime, nullable=False,
                                                  comment="When the event occurred on client")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, nullable=False,
                                                  comment="When the event was recorded on server")

    # Indexes for common queries
    __table_args__ = (
        Index('ix_upgrade_analytics_event_time', 'event_time'),
        Index('ix_upgrade_analytics_version', 'to_version', 'event_type'),
        Index('ix_upgrade_analytics_platform_event', 'platform', 'event_type'),
    )

    def __repr__(self):
        return f"<UpgradeAnalytics {self.event_type} {self.from_version}->{self.to_version}>"
