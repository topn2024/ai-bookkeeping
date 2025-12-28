"""Transaction model."""
import uuid
from datetime import datetime, date, time
from decimal import Decimal
from typing import Optional, List

from sqlalchemy import String, Integer, DateTime, Date, Time, Boolean, ForeignKey, Numeric, ARRAY
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Transaction(Base):
    """Financial transaction model."""

    __tablename__ = "transactions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)
    account_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)
    target_account_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=True)  # for transfers
    category_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=False)
    transaction_type: Mapped[int] = mapped_column(Integer, nullable=False)  # 1: expense, 2: income, 3: transfer
    amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)
    fee: Mapped[Decimal] = mapped_column(Numeric(15, 2), default=0)  # transaction fee
    transaction_date: Mapped[date] = mapped_column(Date, nullable=False)
    transaction_time: Mapped[Optional[time]] = mapped_column(Time, nullable=True)
    note: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    tags: Mapped[Optional[List[str]]] = mapped_column(ARRAY(String(50)), nullable=True)
    images: Mapped[Optional[List[str]]] = mapped_column(ARRAY(String(500)), nullable=True)
    location: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    is_reimbursable: Mapped[bool] = mapped_column(Boolean, default=False)
    is_reimbursed: Mapped[bool] = mapped_column(Boolean, default=False)
    is_exclude_stats: Mapped[bool] = mapped_column(Boolean, default=False)
    source: Mapped[int] = mapped_column(Integer, default=0)  # 0: manual, 1: image, 2: voice, 3: email
    ai_confidence: Mapped[Optional[Decimal]] = mapped_column(Numeric(3, 2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="transactions")
    book = relationship("Book", back_populates="transactions")
    account = relationship("Account", foreign_keys=[account_id], back_populates="transactions")
    target_account = relationship("Account", foreign_keys=[target_account_id])
    category = relationship("Category")
