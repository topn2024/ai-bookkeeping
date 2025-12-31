"""Upgrade analytics model for tracking app upgrade events."""
from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text, Index
from app.core.database import Base


class UpgradeAnalytics(Base):
    """Store upgrade analytics events from client apps."""

    __tablename__ = "upgrade_analytics"

    id = Column(Integer, primary_key=True, autoincrement=True)

    # Event identification
    event_type = Column(String(50), nullable=False, index=True,
                       comment="Event type: check_update, download_start, etc.")
    platform = Column(String(20), nullable=False, default="android",
                     comment="Platform: android/ios")

    # Version info
    from_version = Column(String(20), nullable=False,
                         comment="Version before upgrade")
    to_version = Column(String(20), nullable=True,
                       comment="Target version for upgrade")
    from_build = Column(Integer, nullable=True,
                       comment="Build number before upgrade")
    to_build = Column(Integer, nullable=True,
                     comment="Target build number")

    # Download metrics
    download_progress = Column(Integer, nullable=True,
                              comment="Download progress percentage (0-100)")
    download_size = Column(Integer, nullable=True,
                          comment="Total download size in bytes")
    download_duration_ms = Column(Integer, nullable=True,
                                 comment="Download duration in milliseconds")

    # Error info
    error_message = Column(Text, nullable=True,
                          comment="Error message if failed")
    error_code = Column(String(50), nullable=True,
                       comment="Error code for categorization")

    # Device info
    device_id = Column(String(100), nullable=True, index=True,
                      comment="Unique device identifier")
    device_model = Column(String(100), nullable=True,
                         comment="Device model name")

    # Extra data (JSON)
    extra_data = Column(Text, nullable=True,
                       comment="Additional JSON data")

    # Timestamps
    event_time = Column(DateTime, nullable=False,
                       comment="When the event occurred on client")
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False,
                       comment="When the event was recorded on server")

    # Indexes for common queries
    __table_args__ = (
        Index('ix_upgrade_analytics_event_time', 'event_time'),
        Index('ix_upgrade_analytics_version', 'to_version', 'event_type'),
        Index('ix_upgrade_analytics_platform_event', 'platform', 'event_type'),
    )

    def __repr__(self):
        return f"<UpgradeAnalytics {self.event_type} {self.from_version}->{self.to_version}>"
