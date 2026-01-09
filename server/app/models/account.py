"""Account model."""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Boolean, ForeignKey, Numeric
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class Account(Base):
    """Financial account model (cash, bank card, credit card, etc.)."""

    __tablename__ = "accounts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    account_type: Mapped[int] = mapped_column(Integer, nullable=False)  # 1: cash, 2: debit, 3: credit, 4: alipay, 5: wechat
    icon: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    balance: Mapped[Decimal] = mapped_column(Numeric(15, 2), default=0)
    credit_limit: Mapped[Optional[Decimal]] = mapped_column(Numeric(15, 2), nullable=True)  # credit card limit
    bill_day: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # bill date
    repay_day: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # payment due date
    currency: Mapped[str] = mapped_column(String(10), default='CNY')  # Account currency
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User", back_populates="accounts")
    transactions = relationship("Transaction", foreign_keys="Transaction.account_id", back_populates="account", lazy="dynamic")
