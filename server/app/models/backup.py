"""Backup model for storing user data backups."""
from datetime import datetime
from typing import Optional
from uuid import UUID, uuid4

from sqlalchemy import Column, String, DateTime, ForeignKey, BigInteger, Text, Integer
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship

from app.core.database import Base


class Backup(Base):
    """User data backup record."""
    __tablename__ = "backups"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    # Backup metadata
    name = Column(String(100), nullable=False)  # 备份名称
    description = Column(String(500), nullable=True)  # 备份描述
    backup_type = Column(Integer, default=0)  # 0=手动备份, 1=自动备份

    # Backup content (JSON)
    data = Column(Text, nullable=False)  # JSON格式的备份数据

    # Statistics - 基础数据
    transaction_count = Column(Integer, default=0)
    account_count = Column(Integer, default=0)
    category_count = Column(Integer, default=0)
    book_count = Column(Integer, default=0)
    budget_count = Column(Integer, default=0)

    # Statistics - 扩展数据（新增）
    credit_card_count = Column(Integer, default=0)
    debt_count = Column(Integer, default=0)
    savings_goal_count = Column(Integer, default=0)
    bill_reminder_count = Column(Integer, default=0)
    recurring_count = Column(Integer, default=0)

    # File size in bytes
    size = Column(BigInteger, default=0)

    # Device info
    device_name = Column(String(100), nullable=True)
    device_id = Column(String(100), nullable=True)
    app_version = Column(String(20), nullable=True)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    user = relationship("User", backref="backups")

    def __repr__(self):
        return f"<Backup {self.name} ({self.id})>"
