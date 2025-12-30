"""Backup model for storing user data backups."""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, DateTime, ForeignKey, BigInteger, Text, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Backup(Base):
    """User data backup record."""
    __tablename__ = "backups"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # Backup metadata
    name: Mapped[str] = mapped_column(String(100), nullable=False)  # 备份名称
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)  # 备份描述
    backup_type: Mapped[int] = mapped_column(Integer, default=0)  # 0=手动备份, 1=自动备份

    # Backup content (JSON)
    data: Mapped[str] = mapped_column(Text, nullable=False)  # JSON格式的备份数据

    # Statistics - 基础数据
    transaction_count: Mapped[int] = mapped_column(Integer, default=0)
    account_count: Mapped[int] = mapped_column(Integer, default=0)
    category_count: Mapped[int] = mapped_column(Integer, default=0)
    book_count: Mapped[int] = mapped_column(Integer, default=0)
    budget_count: Mapped[int] = mapped_column(Integer, default=0)

    # Statistics - 扩展数据（新增）
    credit_card_count: Mapped[int] = mapped_column(Integer, default=0)
    debt_count: Mapped[int] = mapped_column(Integer, default=0)
    savings_goal_count: Mapped[int] = mapped_column(Integer, default=0)
    bill_reminder_count: Mapped[int] = mapped_column(Integer, default=0)
    recurring_count: Mapped[int] = mapped_column(Integer, default=0)

    # File size in bytes
    size: Mapped[int] = mapped_column(BigInteger, default=0)

    # Device info
    device_name: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    device_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    app_version: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Relationships
    user = relationship("User", backref="backups")

    def __repr__(self):
        return f"<Backup {self.name} ({self.id})>"
