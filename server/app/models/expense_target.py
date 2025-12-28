"""Expense target model for monthly spending limits."""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Boolean, ForeignKey, Numeric
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ExpenseTarget(Base):
    """Monthly expense target model for controlling spending."""

    __tablename__ = "expense_targets"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)

    # Target definition
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    max_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)  # Monthly spending limit

    # Optional category filter (None = total spending)
    category_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True)

    # Time period
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    month: Mapped[int] = mapped_column(Integer, nullable=False)

    # Display settings
    icon_code: Mapped[int] = mapped_column(Integer, default=0xe8d4)  # Material Icons 'savings'
    color_value: Mapped[int] = mapped_column(Integer, default=0xFF4CAF50)  # Green

    # Alert settings
    alert_threshold: Mapped[int] = mapped_column(Integer, default=80)  # Alert when reaching X% of limit
    enable_notifications: Mapped[bool] = mapped_column(Boolean, default=True)

    # Status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", backref="expense_targets")
    book = relationship("Book", backref="expense_targets")
    category = relationship("Category", backref="expense_targets")
