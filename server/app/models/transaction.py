"""Transaction model."""
import uuid
from datetime import datetime, date, time
from decimal import Decimal
from typing import Optional, List

from sqlalchemy import String, Integer, DateTime, Date, Time, Boolean, ForeignKey, Numeric, ARRAY
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


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
    location: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)  # Legacy: simple location string

    # Structured location fields (Chapter 14: Location Intelligence)
    location_latitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 7), nullable=True)  # -90 to 90
    location_longitude: Mapped[Optional[Decimal]] = mapped_column(Numeric(10, 7), nullable=True)  # -180 to 180
    location_place_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)  # e.g., "沃尔玛超市"
    location_address: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)  # Full address
    location_city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    location_district: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    location_type: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # 0-10: LocationType enum
    location_poi_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # Map service POI ID
    geofence_region: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # home/work/shopping etc
    is_cross_region: Mapped[bool] = mapped_column(Boolean, default=False)  # Cross-region transaction flag

    # Money Age fields - for tracking financial health
    money_age: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # Age in days
    money_age_level: Mapped[Optional[str]] = mapped_column(String(20), nullable=True)  # health/warning/danger
    resource_pool_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)  # For income tracking

    is_reimbursable: Mapped[bool] = mapped_column(Boolean, default=False)
    is_reimbursed: Mapped[bool] = mapped_column(Boolean, default=False)
    is_exclude_stats: Mapped[bool] = mapped_column(Boolean, default=False)
    source: Mapped[int] = mapped_column(Integer, default=0)  # 0: manual, 1: image, 2: voice, 3: email
    ai_confidence: Mapped[Optional[Decimal]] = mapped_column(Numeric(3, 2), nullable=True)

    # Source file fields - for storing original images/audio from AI recognition
    source_file_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)  # MinIO file URL after sync
    source_file_type: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)  # MIME type: image/jpeg, audio/m4a
    source_file_size: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # File size in bytes
    recognition_raw_response: Mapped[Optional[str]] = mapped_column(String(5000), nullable=True)  # AI raw response JSON
    recognition_timestamp: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)  # When AI recognition happened
    source_file_expires_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)  # File expiry time

    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Family book related fields
    visibility: Mapped[int] = mapped_column(Integer, default=1)  # 0: private, 1: all_members, 2: admins_only

    # Relationships
    user = relationship("User", back_populates="transactions")
    book = relationship("Book", back_populates="transactions")
    account = relationship("Account", foreign_keys=[account_id], back_populates="transactions")
    target_account = relationship("Account", foreign_keys=[target_account_id])
    category = relationship("Category")
    split_info = relationship("TransactionSplit", back_populates="transaction", uselist=False, cascade="all, delete-orphan")
