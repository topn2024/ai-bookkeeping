"""Book model."""
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Boolean, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class Book(Base):
    """Book (ledger) model."""

    __tablename__ = "books"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    icon: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    cover_image: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    book_type: Mapped[int] = mapped_column(Integer, default=0)  # 0: normal, 1: family, 2: business
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)

    # Relationships
    user = relationship("User", back_populates="books")
    transactions = relationship("Transaction", back_populates="book", lazy="dynamic")
    members = relationship("BookMember", back_populates="book", lazy="dynamic")


class BookMember(Base):
    """Book member model for collaboration."""

    __tablename__ = "book_members"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    role: Mapped[int] = mapped_column(Integer, default=0)  # 0: member, 1: admin, 2: owner
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)

    # Relationships
    book = relationship("Book", back_populates="members")
