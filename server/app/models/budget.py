"""Budget model."""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import Integer, DateTime, ForeignKey, Numeric
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Budget(Base):
    """Budget model."""

    __tablename__ = "budgets"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)
    category_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True)  # NULL for total budget
    budget_type: Mapped[int] = mapped_column(Integer, nullable=False)  # 1: monthly, 2: yearly
    amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    month: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # NULL for yearly
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
