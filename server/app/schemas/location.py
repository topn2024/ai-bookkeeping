"""Location schemas - Chapter 14: Location Intelligence."""
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class LocationType:
    """Location type constants."""
    DAILY = 0
    DINING = 1
    SHOPPING = 2
    TRANSPORT = 3
    ENTERTAINMENT = 4
    MEDICAL = 5
    EDUCATION = 6
    RESIDENTIAL = 7
    WORKPLACE = 8
    TRAVEL = 9
    OTHER = 10


class GeoFenceAction:
    """GeoFence action constants."""
    REMIND_BUDGET = 0
    AUTO_CATEGORY = 1
    AUTO_VAULT = 2
    IMPULSE_GUARD = 3
    LOG_LOCATION = 4


# ============== Transaction Location ==============

class TransactionLocationData(BaseModel):
    """Structured location data for transactions."""
    latitude: Decimal = Field(..., ge=-90, le=90)
    longitude: Decimal = Field(..., ge=-180, le=180)
    place_name: Optional[str] = Field(None, max_length=200)
    address: Optional[str] = Field(None, max_length=500)
    city: Optional[str] = Field(None, max_length=100)
    district: Optional[str] = Field(None, max_length=100)
    location_type: Optional[int] = Field(None, ge=0, le=10)
    poi_id: Optional[str] = Field(None, max_length=100)


# ============== GeoFence ==============

class GeoFenceBase(BaseModel):
    """Base schema for geofence."""
    name: str = Field(..., min_length=1, max_length=100)
    center_latitude: Decimal = Field(..., ge=-90, le=90)
    center_longitude: Decimal = Field(..., ge=-180, le=180)
    radius_meters: float = Field(100.0, gt=0, le=50000)
    place_name: Optional[str] = Field(None, max_length=200)
    action: int = Field(GeoFenceAction.LOG_LOCATION, ge=0, le=4)
    linked_category_id: Optional[UUID] = None
    linked_vault_id: Optional[str] = Field(None, max_length=100)
    budget_limit: Optional[Decimal] = Field(None, ge=0)
    is_enabled: bool = True


class GeoFenceCreate(GeoFenceBase):
    """Schema for creating a geofence."""
    pass


class GeoFenceUpdate(BaseModel):
    """Schema for updating a geofence."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    center_latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    center_longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    radius_meters: Optional[float] = Field(None, gt=0, le=50000)
    place_name: Optional[str] = Field(None, max_length=200)
    action: Optional[int] = Field(None, ge=0, le=4)
    linked_category_id: Optional[UUID] = None
    linked_vault_id: Optional[str] = Field(None, max_length=100)
    budget_limit: Optional[Decimal] = Field(None, ge=0)
    is_enabled: Optional[bool] = None


class GeoFenceResponse(GeoFenceBase):
    """Schema for geofence response."""
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============== Frequent Location ==============

class FrequentLocationBase(BaseModel):
    """Base schema for frequent location."""
    latitude: Decimal = Field(..., ge=-90, le=90)
    longitude: Decimal = Field(..., ge=-180, le=180)
    place_name: Optional[str] = Field(None, max_length=200)
    address: Optional[str] = Field(None, max_length=500)
    city: Optional[str] = Field(None, max_length=100)
    district: Optional[str] = Field(None, max_length=100)
    location_type: Optional[int] = Field(None, ge=0, le=10)
    poi_id: Optional[str] = Field(None, max_length=100)
    default_category_id: Optional[UUID] = None
    default_vault_id: Optional[str] = Field(None, max_length=100)


class FrequentLocationCreate(FrequentLocationBase):
    """Schema for creating/updating a frequent location."""
    visit_count: int = Field(1, ge=0)
    total_spent: Decimal = Field(Decimal(0), ge=0)


class FrequentLocationUpdate(BaseModel):
    """Schema for updating frequent location stats."""
    visit_count: Optional[int] = Field(None, ge=0)
    total_spent: Optional[Decimal] = Field(None, ge=0)
    default_category_id: Optional[UUID] = None
    default_vault_id: Optional[str] = Field(None, max_length=100)


class FrequentLocationResponse(FrequentLocationBase):
    """Schema for frequent location response."""
    id: UUID
    user_id: UUID
    visit_count: int
    total_spent: Decimal
    average_spent: Decimal
    last_visit_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True


# ============== User Home Location ==============

class UserHomeLocationBase(BaseModel):
    """Base schema for user home/work location."""
    location_role: int = Field(0, ge=0, le=2)  # 0=home, 1=work, 2=other
    name: str = Field(..., min_length=1, max_length=100)
    latitude: Decimal = Field(..., ge=-90, le=90)
    longitude: Decimal = Field(..., ge=-180, le=180)
    city: Optional[str] = Field(None, max_length=100)
    radius_meters: float = Field(5000.0, gt=0, le=100000)
    is_primary: bool = False
    is_enabled: bool = True


class UserHomeLocationCreate(UserHomeLocationBase):
    """Schema for creating a home location."""
    pass


class UserHomeLocationUpdate(BaseModel):
    """Schema for updating a home location."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    latitude: Optional[Decimal] = Field(None, ge=-90, le=90)
    longitude: Optional[Decimal] = Field(None, ge=-180, le=180)
    city: Optional[str] = Field(None, max_length=100)
    radius_meters: Optional[float] = Field(None, gt=0, le=100000)
    is_primary: Optional[bool] = None
    is_enabled: Optional[bool] = None


class UserHomeLocationResponse(UserHomeLocationBase):
    """Schema for home location response."""
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============== Location Check ==============

class LocationCheckRequest(BaseModel):
    """Request to check if a location is within any geofence."""
    latitude: Decimal = Field(..., ge=-90, le=90)
    longitude: Decimal = Field(..., ge=-180, le=180)


class LocationCheckResponse(BaseModel):
    """Response for location check."""
    is_in_geofence: bool
    matched_fences: List[GeoFenceResponse]
    is_cross_region: bool  # True if outside home locations
    spending_context: str  # "local", "travel", "business_trip"


# ============== Location Statistics ==============

class LocationSpendingStats(BaseModel):
    """Spending statistics by location."""
    location_type: int
    location_type_name: str
    transaction_count: int
    total_amount: Decimal
    average_amount: Decimal


class LocationAnalyticsResponse(BaseModel):
    """Location-based analytics response."""
    spending_by_type: List[LocationSpendingStats]
    top_locations: List[FrequentLocationResponse]
    cross_region_spending: Decimal
    local_spending: Decimal
    cross_region_percentage: float
