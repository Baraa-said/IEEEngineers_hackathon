"""Health facilities endpoints."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import UUID

from app.database import get_db
from app.models import HealthFacility, FacilityType, FacilityStatus
from app.schemas import FacilityResponse, FacilityCreate
from app.services.auth_service import get_current_user

router = APIRouter()


@router.get("/facilities", response_model=List[FacilityResponse])
async def list_facilities(
    facility_type: Optional[str] = Query(None, description="Filter by type"),
    status: Optional[str] = Query(None, description="Filter by status"),
    district: Optional[str] = Query(None, description="Filter by district"),
    governorate: Optional[str] = Query(None, description="Filter by governorate"),
    has_power: Optional[bool] = Query(None),
    has_oxygen: Optional[bool] = Query(None),
    has_emergency_department: Optional[bool] = Query(None),
    min_available_beds: Optional[int] = Query(None, ge=0),
    latitude: Optional[float] = Query(None, description="User latitude for distance calc"),
    longitude: Optional[float] = Query(None, description="User longitude for distance calc"),
    radius_km: Optional[float] = Query(None, description="Search radius in km"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    """
    List health facilities with optional filters.

    Supports filtering by type, status, location, equipment, and capacity.
    Returns distance from user when coordinates are provided.
    """
    query = select(HealthFacility)
    conditions = []

    if facility_type:
        conditions.append(HealthFacility.facility_type == facility_type)
    if status:
        conditions.append(HealthFacility.status == status)
    if district:
        conditions.append(func.lower(HealthFacility.district).contains(district.lower()))
    if governorate:
        conditions.append(func.lower(HealthFacility.governorate).contains(governorate.lower()))
    if has_power is not None:
        conditions.append(HealthFacility.has_power == has_power)
    if has_oxygen is not None:
        conditions.append(HealthFacility.has_oxygen == has_oxygen)
    if has_emergency_department is not None:
        conditions.append(HealthFacility.emergency_department == has_emergency_department)
    if min_available_beds is not None:
        conditions.append(HealthFacility.available_beds >= min_available_beds)

    if conditions:
        query = query.where(and_(*conditions))

    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    facilities = result.scalars().all()

    response_list = []
    for f in facilities:
        resp = FacilityResponse.model_validate(f)
        if latitude is not None and longitude is not None:
            from geopy.distance import geodesic
            dist = geodesic((latitude, longitude), (f.latitude, f.longitude)).km
            resp.distance_km = round(dist, 2)

            if radius_km and dist > radius_km:
                continue
        response_list.append(resp)

    # Sort by distance if coordinates provided
    if latitude is not None and longitude is not None:
        response_list.sort(key=lambda x: x.distance_km or 99999)

    return response_list


@router.get("/facilities/{facility_id}", response_model=FacilityResponse)
async def get_facility(
    facility_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get a specific facility by ID."""
    result = await db.execute(
        select(HealthFacility).where(HealthFacility.id == facility_id)
    )
    facility = result.scalar_one_or_none()
    if not facility:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Facility not found")
    return FacilityResponse.model_validate(facility)


@router.get("/facilities/stats/summary")
async def facility_stats(db: AsyncSession = Depends(get_db)):
    """Get aggregate facility statistics."""
    total = await db.execute(select(func.count(HealthFacility.id)))
    by_status = await db.execute(
        select(HealthFacility.status, func.count(HealthFacility.id))
        .group_by(HealthFacility.status)
    )
    by_type = await db.execute(
        select(HealthFacility.facility_type, func.count(HealthFacility.id))
        .group_by(HealthFacility.facility_type)
    )
    total_beds = await db.execute(select(func.sum(HealthFacility.total_beds)))
    avail_beds = await db.execute(select(func.sum(HealthFacility.available_beds)))

    return {
        "total_facilities": total.scalar() or 0,
        "by_status": {row[0].value: row[1] for row in by_status.all()},
        "by_type": {row[0].value: row[1] for row in by_type.all()},
        "total_beds": total_beds.scalar() or 0,
        "available_beds": avail_beds.scalar() or 0,
    }
