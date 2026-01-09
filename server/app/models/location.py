"""Location models for geofence and frequent locations - Chapter 14."""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import String, Integer, DateTime, Boolean, ForeignKey, Numeric, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class LocationType:
    """Location type enumeration matching Flutter LocationType."""
    DAILY = 0           # 日常消费场所
    DINING = 1          # 餐饮场所
    SHOPPING = 2        # 购物场所
    TRANSPORT = 3       # 交通场所
    ENTERTAINMENT = 4   # 娱乐场所
    MEDICAL = 5         # 医疗场所
    EDUCATION = 6       # 教育场所
    RESIDENTIAL = 7     # 住宅区域
    WORKPLACE = 8       # 工作区域
    TRAVEL = 9          # 旅行目的地
    OTHER = 10          # 其他


class GeoFenceAction:
    """Geofence trigger actions matching Flutter GeoFenceAction."""
    REMIND_BUDGET = 0       # 提醒预算状态
    AUTO_CATEGORY = 1       # 自动设置分类
    AUTO_VAULT = 2          # 自动关联小金库
    IMPULSE_GUARD = 3       # 触发冲动消费防护
    LOG_LOCATION = 4        # 记录位置


class GeoFence(Base):
    """Geographic fence for location-based automation.

    Supports:
    - Budget reminders when entering areas
    - Auto-categorization based on location
    - Impulse spending protection in high-risk zones
    """

    __tablename__ = "geo_fences"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Fence definition
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    center_latitude: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    center_longitude: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    radius_meters: Mapped[float] = mapped_column(Float, nullable=False, default=100.0)
    place_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)

    # Action configuration
    action: Mapped[int] = mapped_column(Integer, nullable=False, default=GeoFenceAction.LOG_LOCATION)
    linked_category_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True)
    linked_vault_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)  # Local vault ID from Flutter
    budget_limit: Mapped[Optional[Decimal]] = mapped_column(Numeric(15, 2), nullable=True)

    # Status
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User", backref="geo_fences")
    linked_category = relationship("Category", foreign_keys=[linked_category_id])


class FrequentLocation(Base):
    """Frequently visited location for smart suggestions.

    Tracks:
    - Visit count and total spending
    - Default category for auto-fill
    - Average spending patterns
    """

    __tablename__ = "frequent_locations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Location info
    latitude: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    longitude: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    place_name: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    address: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    district: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    location_type: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    poi_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Usage statistics
    visit_count: Mapped[int] = mapped_column(Integer, default=1)
    total_spent: Mapped[Decimal] = mapped_column(Numeric(15, 2), default=0)

    # Defaults for auto-fill
    default_category_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("categories.id"), nullable=True)
    default_vault_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)

    # Timestamps
    last_visit_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User", backref="frequent_locations")
    default_category = relationship("Category", foreign_keys=[default_category_id])

    @property
    def average_spent(self) -> Decimal:
        """Calculate average spending per visit."""
        if self.visit_count > 0:
            return self.total_spent / self.visit_count
        return Decimal(0)


class UserHomeLocation(Base):
    """User's home/work locations for cross-region detection.

    Used to distinguish:
    - Local daily spending
    - Travel/business trip spending
    """

    __tablename__ = "user_home_locations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Location type: 0=home, 1=work, 2=other_frequent
    location_role: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    name: Mapped[str] = mapped_column(String(100), nullable=False)

    # Location
    latitude: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    longitude: Mapped[Decimal] = mapped_column(Numeric(10, 7), nullable=False)
    city: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    radius_meters: Mapped[float] = mapped_column(Float, default=5000.0)  # Default 5km radius

    # Status
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)

    # Relationships
    user = relationship("User", backref="home_locations")
