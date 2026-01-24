"""Location API endpoints - Chapter 14: Location Intelligence."""
from decimal import Decimal
from math import radians, sin, cos, sqrt, atan2
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.location import GeoFence, FrequentLocation, UserHomeLocation, LocationType
from app.models.transaction import Transaction
from app.schemas.location import (
    GeoFenceCreate, GeoFenceUpdate, GeoFenceResponse,
    FrequentLocationCreate, FrequentLocationUpdate, FrequentLocationResponse,
    UserHomeLocationCreate, UserHomeLocationUpdate, UserHomeLocationResponse,
    LocationCheckRequest, LocationCheckResponse,
    LocationSpendingStats, LocationAnalyticsResponse,
)

router = APIRouter(prefix="/locations", tags=["Locations"])


# ============== Helper Functions ==============

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance between two points in meters using Haversine formula."""
    R = 6371000  # Earth's radius in meters

    lat1_rad = radians(lat1)
    lat2_rad = radians(lat2)
    delta_lat = radians(lat2 - lat1)
    delta_lon = radians(lon2 - lon1)

    a = sin(delta_lat / 2) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))

    return R * c


def get_location_type_name(location_type: int) -> str:
    """Get display name for location type."""
    names = {
        0: "日常消费",
        1: "餐饮",
        2: "购物",
        3: "交通",
        4: "娱乐",
        5: "医疗",
        6: "教育",
        7: "住宅",
        8: "工作",
        9: "旅行",
        10: "其他",
    }
    return names.get(location_type, "未知")


# ============== GeoFence Endpoints ==============

@router.post("/geofences", response_model=GeoFenceResponse, status_code=status.HTTP_201_CREATED)
async def create_geofence(
    data: GeoFenceCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new geofence."""
    geofence = GeoFence(
        user_id=current_user.id,
        **data.model_dump(),
    )
    db.add(geofence)
    await db.commit()
    await db.refresh(geofence)
    return geofence


@router.get("/geofences", response_model=List[GeoFenceResponse])
async def list_geofences(
    is_enabled: Optional[bool] = Query(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all geofences for the current user."""
    query = select(GeoFence).where(GeoFence.user_id == current_user.id)
    if is_enabled is not None:
        query = query.where(GeoFence.is_enabled == is_enabled)
    query = query.order_by(GeoFence.created_at.desc())

    result = await db.execute(query)
    return result.scalars().all()


@router.get("/geofences/{geofence_id}", response_model=GeoFenceResponse)
async def get_geofence(
    geofence_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a specific geofence."""
    result = await db.execute(
        select(GeoFence).where(
            and_(GeoFence.id == geofence_id, GeoFence.user_id == current_user.id)
        )
    )
    geofence = result.scalar_one_or_none()
    if not geofence:
        raise HTTPException(status_code=404, detail="Geofence not found")
    return geofence


@router.patch("/geofences/{geofence_id}", response_model=GeoFenceResponse)
async def update_geofence(
    geofence_id: UUID,
    data: GeoFenceUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a geofence."""
    result = await db.execute(
        select(GeoFence).where(
            and_(GeoFence.id == geofence_id, GeoFence.user_id == current_user.id)
        )
    )
    geofence = result.scalar_one_or_none()
    if not geofence:
        raise HTTPException(status_code=404, detail="Geofence not found")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(geofence, field, value)

    await db.commit()
    await db.refresh(geofence)
    return geofence


@router.delete("/geofences/{geofence_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_geofence(
    geofence_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a geofence."""
    result = await db.execute(
        select(GeoFence).where(
            and_(GeoFence.id == geofence_id, GeoFence.user_id == current_user.id)
        )
    )
    geofence = result.scalar_one_or_none()
    if not geofence:
        raise HTTPException(status_code=404, detail="Geofence not found")

    await db.delete(geofence)
    await db.commit()


# ============== Frequent Location Endpoints ==============

@router.post("/frequent", response_model=FrequentLocationResponse, status_code=status.HTTP_201_CREATED)
async def create_or_update_frequent_location(
    data: FrequentLocationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create or update a frequent location.

    If a location with matching coordinates (within 50m) exists, update it.
    Otherwise, create a new one.
    """
    # Check for existing nearby location
    result = await db.execute(
        select(FrequentLocation).where(FrequentLocation.user_id == current_user.id)
    )
    existing_locations = result.scalars().all()

    for loc in existing_locations:
        distance = haversine_distance(
            float(data.latitude), float(data.longitude),
            float(loc.latitude), float(loc.longitude)
        )
        if distance < 50:  # Within 50 meters
            # Update existing
            loc.visit_count += data.visit_count
            loc.total_spent += data.total_spent
            if data.place_name:
                loc.place_name = data.place_name
            if data.default_category_id:
                loc.default_category_id = data.default_category_id
            await db.commit()
            await db.refresh(loc)
            return loc

    # Create new
    location = FrequentLocation(
        user_id=current_user.id,
        **data.model_dump(),
    )
    db.add(location)
    await db.commit()
    await db.refresh(location)
    return location


@router.get("/frequent", response_model=List[FrequentLocationResponse])
async def list_frequent_locations(
    limit: int = Query(20, ge=1, le=100),
    order_by: str = Query("visit_count", pattern="^(visit_count|total_spent|last_visit_at)$"),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List frequent locations ordered by specified field."""
    query = select(FrequentLocation).where(FrequentLocation.user_id == current_user.id)

    if order_by == "visit_count":
        query = query.order_by(FrequentLocation.visit_count.desc())
    elif order_by == "total_spent":
        query = query.order_by(FrequentLocation.total_spent.desc())
    else:
        query = query.order_by(FrequentLocation.last_visit_at.desc())

    query = query.limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


@router.patch("/frequent/{location_id}", response_model=FrequentLocationResponse)
async def update_frequent_location(
    location_id: UUID,
    data: FrequentLocationUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a frequent location."""
    result = await db.execute(
        select(FrequentLocation).where(
            and_(FrequentLocation.id == location_id, FrequentLocation.user_id == current_user.id)
        )
    )
    location = result.scalar_one_or_none()
    if not location:
        raise HTTPException(status_code=404, detail="Frequent location not found")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(location, field, value)

    await db.commit()
    await db.refresh(location)
    return location


@router.delete("/frequent/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_frequent_location(
    location_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a frequent location."""
    result = await db.execute(
        select(FrequentLocation).where(
            and_(FrequentLocation.id == location_id, FrequentLocation.user_id == current_user.id)
        )
    )
    location = result.scalar_one_or_none()
    if not location:
        raise HTTPException(status_code=404, detail="Frequent location not found")

    await db.delete(location)
    await db.commit()


# ============== Home Location Endpoints ==============

@router.post("/home", response_model=UserHomeLocationResponse, status_code=status.HTTP_201_CREATED)
async def create_home_location(
    data: UserHomeLocationCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new home/work location."""
    # If this is set as primary, unset other primaries of same role
    if data.is_primary:
        await db.execute(
            select(UserHomeLocation).where(
                and_(
                    UserHomeLocation.user_id == current_user.id,
                    UserHomeLocation.location_role == data.location_role,
                    UserHomeLocation.is_primary == True,
                )
            )
        )
        # Note: This should use update, simplified for now

    location = UserHomeLocation(
        user_id=current_user.id,
        **data.model_dump(),
    )
    db.add(location)
    await db.commit()
    await db.refresh(location)
    return location


@router.get("/home", response_model=List[UserHomeLocationResponse])
async def list_home_locations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List all home/work locations."""
    result = await db.execute(
        select(UserHomeLocation)
        .where(UserHomeLocation.user_id == current_user.id)
        .order_by(UserHomeLocation.location_role, UserHomeLocation.is_primary.desc())
    )
    return result.scalars().all()


@router.patch("/home/{location_id}", response_model=UserHomeLocationResponse)
async def update_home_location(
    location_id: UUID,
    data: UserHomeLocationUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update a home/work location."""
    result = await db.execute(
        select(UserHomeLocation).where(
            and_(UserHomeLocation.id == location_id, UserHomeLocation.user_id == current_user.id)
        )
    )
    location = result.scalar_one_or_none()
    if not location:
        raise HTTPException(status_code=404, detail="Home location not found")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(location, field, value)

    await db.commit()
    await db.refresh(location)
    return location


@router.delete("/home/{location_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_home_location(
    location_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a home/work location."""
    result = await db.execute(
        select(UserHomeLocation).where(
            and_(UserHomeLocation.id == location_id, UserHomeLocation.user_id == current_user.id)
        )
    )
    location = result.scalar_one_or_none()
    if not location:
        raise HTTPException(status_code=404, detail="Home location not found")

    await db.delete(location)
    await db.commit()


# ============== Location Check ==============

@router.post("/check", response_model=LocationCheckResponse)
async def check_location(
    data: LocationCheckRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Check if a location is within any geofence and determine spending context."""
    lat = float(data.latitude)
    lon = float(data.longitude)

    # Check geofences
    geofences_result = await db.execute(
        select(GeoFence).where(
            and_(GeoFence.user_id == current_user.id, GeoFence.is_enabled == True)
        )
    )
    geofences = geofences_result.scalars().all()

    matched = []
    for fence in geofences:
        distance = haversine_distance(
            lat, lon,
            float(fence.center_latitude), float(fence.center_longitude)
        )
        if distance <= fence.radius_meters:
            matched.append(fence)

    # Check home locations for cross-region detection
    home_result = await db.execute(
        select(UserHomeLocation).where(
            and_(UserHomeLocation.user_id == current_user.id, UserHomeLocation.is_enabled == True)
        )
    )
    home_locations = home_result.scalars().all()

    is_cross_region = True
    spending_context = "travel"

    for home in home_locations:
        distance = haversine_distance(
            lat, lon,
            float(home.latitude), float(home.longitude)
        )
        if distance <= home.radius_meters:
            is_cross_region = False
            if home.location_role == 0:
                spending_context = "local"
            elif home.location_role == 1:
                spending_context = "business_trip"
            break

    return LocationCheckResponse(
        is_in_geofence=len(matched) > 0,
        matched_fences=matched,
        is_cross_region=is_cross_region,
        spending_context=spending_context,
    )


# ============== Analytics ==============

@router.get("/analytics", response_model=LocationAnalyticsResponse)
async def get_location_analytics(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get location-based spending analytics."""
    # Get spending by location type
    type_stats_query = (
        select(
            Transaction.location_type,
            func.count(Transaction.id).label("count"),
            func.sum(Transaction.amount).label("total"),
        )
        .where(
            and_(
                Transaction.user_id == current_user.id,
                Transaction.transaction_type == 1,  # Expense only
                Transaction.location_type.isnot(None),
            )
        )
        .group_by(Transaction.location_type)
    )
    type_result = await db.execute(type_stats_query)
    type_rows = type_result.all()

    spending_by_type = [
        LocationSpendingStats(
            location_type=row.location_type or 10,
            location_type_name=get_location_type_name(row.location_type or 10),
            transaction_count=row.count,
            total_amount=row.total or Decimal(0),
            average_amount=(row.total or Decimal(0)) / row.count if row.count > 0 else Decimal(0),
        )
        for row in type_rows
    ]

    # Get top frequent locations
    freq_result = await db.execute(
        select(FrequentLocation)
        .where(FrequentLocation.user_id == current_user.id)
        .order_by(FrequentLocation.total_spent.desc())
        .limit(10)
    )
    top_locations = freq_result.scalars().all()

    # Calculate cross-region vs local spending (simplified)
    # In production, would join with home_locations to calculate properly
    total_spending = sum(s.total_amount for s in spending_by_type)
    travel_spending = sum(
        s.total_amount for s in spending_by_type
        if s.location_type == LocationType.TRAVEL
    )

    return LocationAnalyticsResponse(
        spending_by_type=spending_by_type,
        top_locations=top_locations,
        cross_region_spending=travel_spending,
        local_spending=total_spending - travel_spending,
        cross_region_percentage=float(travel_spending / total_spending * 100) if total_spending > 0 else 0,
    )
