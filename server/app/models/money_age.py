"""Money Age models for tracking financial health."""
import uuid
from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List, Dict
import json

from sqlalchemy import String, Integer, DateTime, Date, Boolean, ForeignKey, Numeric, Text, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class ResourcePool(Base):
    """
    Resource Pool model - tracks income sources and their consumption.
    Implements FIFO consumption strategy for money age calculation.
    """

    __tablename__ = "resource_pools"
    __table_args__ = (
        Index('idx_resource_pool_user_book', 'user_id', 'book_id'),
        Index('idx_resource_pool_transaction', 'income_transaction_id'),
        Index('idx_resource_pool_date', 'income_date'),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)

    # Income transaction that created this resource pool
    income_transaction_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("transactions.id"), nullable=False)

    # Financial tracking
    original_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)  # Original income amount
    remaining_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)  # Remaining unspent amount
    consumed_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), default=0)  # Total consumed amount

    # Date tracking
    income_date: Mapped[date] = mapped_column(Date, nullable=False)  # When income was received
    first_consumed_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)  # First consumption date
    last_consumed_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)  # Last consumption date
    fully_consumed_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)  # When fully consumed

    # Status tracking
    is_fully_consumed: Mapped[bool] = mapped_column(Boolean, default=False)
    consumption_count: Mapped[int] = mapped_column(Integer, default=0)  # Number of times consumed

    # Account tracking - which account holds this resource
    account_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)

    # Category tracking - what type of income (salary, bonus, investment, etc)
    income_category_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=False)

    # Metadata
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User")
    book = relationship("Book")
    income_transaction = relationship("Transaction", foreign_keys=[income_transaction_id])
    account = relationship("Account")
    income_category = relationship("Category")
    consumption_records = relationship("ConsumptionRecord", back_populates="resource_pool", cascade="all, delete-orphan")


class ConsumptionRecord(Base):
    """
    Consumption Record - tracks how resource pools are consumed by expenses.
    Implements detailed FIFO tracking for money age calculation.
    """

    __tablename__ = "consumption_records"
    __table_args__ = (
        Index('idx_consumption_expense', 'expense_transaction_id'),
        Index('idx_consumption_pool', 'resource_pool_id'),
        Index('idx_consumption_date', 'consumption_date'),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Link to resource pool being consumed
    resource_pool_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("resource_pools.id"), nullable=False)

    # Link to expense transaction doing the consumption
    expense_transaction_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("transactions.id"), nullable=False)

    # Amount consumed from this specific pool
    consumed_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)

    # Date tracking
    consumption_date: Mapped[date] = mapped_column(Date, nullable=False)

    # Calculated money age for this consumption (days between income and expense)
    money_age_days: Mapped[int] = mapped_column(Integer, nullable=False)

    # User and book for quick filtering
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    resource_pool = relationship("ResourcePool", back_populates="consumption_records")
    expense_transaction = relationship("Transaction", foreign_keys=[expense_transaction_id])
    user = relationship("User")
    book = relationship("Book")


class MoneyAgeSnapshot(Base):
    """
    Money Age Snapshot - periodic snapshots of user's money age statistics.
    Used for trend analysis and historical tracking.
    """

    __tablename__ = "money_age_snapshots"
    __table_args__ = (
        Index('idx_snapshot_user_date', 'user_id', 'snapshot_date'),
        Index('idx_snapshot_book', 'book_id'),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)

    snapshot_date: Mapped[date] = mapped_column(Date, nullable=False)
    snapshot_type: Mapped[str] = mapped_column(String(20), default='daily')  # daily/weekly/monthly

    # Aggregated statistics
    avg_money_age: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)  # Average money age
    median_money_age: Mapped[int] = mapped_column(Integer, nullable=True)  # Median money age
    min_money_age: Mapped[int] = mapped_column(Integer, nullable=True)
    max_money_age: Mapped[int] = mapped_column(Integer, nullable=True)

    # Health level distribution
    health_level: Mapped[str] = mapped_column(String(20), nullable=False)  # overall health level
    health_count: Mapped[int] = mapped_column(Integer, default=0)  # transactions in health range
    warning_count: Mapped[int] = mapped_column(Integer, default=0)  # transactions in warning range
    danger_count: Mapped[int] = mapped_column(Integer, default=0)  # transactions in danger range

    # Resource pool statistics
    total_resource_pools: Mapped[int] = mapped_column(Integer, default=0)
    active_resource_pools: Mapped[int] = mapped_column(Integer, default=0)
    total_remaining_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), default=0)

    # Transaction counts
    total_transactions: Mapped[int] = mapped_column(Integer, default=0)
    expense_transactions: Mapped[int] = mapped_column(Integer, default=0)
    income_transactions: Mapped[int] = mapped_column(Integer, default=0)

    # Detailed breakdown (JSON)
    category_breakdown: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)  # Money age by category
    monthly_trend: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)  # Monthly trend data

    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User")
    book = relationship("Book")


class MoneyAgeConfig(Base):
    """
    Money Age Configuration - user preferences for money age calculation.
    """

    __tablename__ = "money_age_configs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, unique=True)
    book_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("books.id"), nullable=False)

    # Consumption strategy: fifo, lifo, weighted_average
    consumption_strategy: Mapped[str] = mapped_column(String(20), default='fifo')

    # Health level thresholds (in days)
    health_threshold: Mapped[int] = mapped_column(Integer, default=30)  # < 30 days = healthy
    warning_threshold: Mapped[int] = mapped_column(Integer, default=60)  # 30-60 days = warning
    # > 60 days = danger

    # Auto-snapshot settings
    enable_daily_snapshot: Mapped[bool] = mapped_column(Boolean, default=True)
    enable_weekly_snapshot: Mapped[bool] = mapped_column(Boolean, default=True)
    enable_monthly_snapshot: Mapped[bool] = mapped_column(Boolean, default=True)

    # Notification settings
    enable_notifications: Mapped[bool] = mapped_column(Boolean, default=True)
    notify_on_warning: Mapped[bool] = mapped_column(Boolean, default=True)
    notify_on_danger: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User")
    book = relationship("Book")
