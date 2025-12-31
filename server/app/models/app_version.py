"""App version model for managing app releases and updates."""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, DateTime, Integer, Boolean, Text, BigInteger
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AppVersion(Base):
    """APP version management table for remote updates."""
    __tablename__ = "app_versions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )

    # Version info
    version_name: Mapped[str] = mapped_column(String(20), nullable=False)  # e.g., "1.2.1"
    version_code: Mapped[int] = mapped_column(Integer, nullable=False)  # e.g., 18

    # Platform (android/ios)
    platform: Mapped[str] = mapped_column(String(20), default="android")

    # APK file info (Android) - Full package
    file_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)  # MinIO URL
    file_size: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)  # File size in bytes
    file_md5: Mapped[Optional[str]] = mapped_column(String(32), nullable=True)  # MD5 checksum

    # Patch file info (Incremental update / 增量更新)
    patch_from_version: Mapped[Optional[str]] = mapped_column(
        String(20), nullable=True
    )  # Base version for patch (e.g., "1.2.0")
    patch_from_code: Mapped[Optional[int]] = mapped_column(
        Integer, nullable=True
    )  # Base version code for patch
    patch_file_url: Mapped[Optional[str]] = mapped_column(
        String(500), nullable=True
    )  # Patch file URL
    patch_file_size: Mapped[Optional[int]] = mapped_column(
        BigInteger, nullable=True
    )  # Patch file size in bytes
    patch_file_md5: Mapped[Optional[str]] = mapped_column(
        String(32), nullable=True
    )  # Patch file MD5 checksum

    # Update info
    release_notes: Mapped[str] = mapped_column(Text, nullable=False)  # Release notes (markdown)
    release_notes_en: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # English release notes

    # Update strategy
    is_force_update: Mapped[bool] = mapped_column(Boolean, default=False)  # Force update flag
    min_supported_version: Mapped[Optional[str]] = mapped_column(
        String(20), nullable=True
    )  # Minimum supported version, older versions must update

    # Gradual rollout (灰度发布)
    rollout_percentage: Mapped[int] = mapped_column(
        Integer, default=100
    )  # 0-100, percentage of users who will see this update
    rollout_start_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime, nullable=True
    )  # When gradual rollout started

    # Release status: 0=draft, 1=published, 2=deprecated
    status: Mapped[int] = mapped_column(Integer, default=0)
    published_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    # Audit fields
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    created_by: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # Creator username

    def __repr__(self):
        return f"<AppVersion {self.version_name}+{self.version_code} ({self.platform})>"

    @property
    def status_text(self) -> str:
        """Get status text."""
        status_map = {0: "draft", 1: "published", 2: "deprecated"}
        return status_map.get(self.status, "unknown")

    @property
    def is_published(self) -> bool:
        """Check if version is published."""
        return self.status == 1

    @property
    def full_version(self) -> str:
        """Get full version string."""
        return f"{self.version_name}+{self.version_code}"
