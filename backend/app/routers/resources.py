"""Resources endpoints (ambulances, shelters, supplies, etc.)."""

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import UUID, uuid4
from datetime import datetime, timezone

from app.database import get_db
from app.models import Resource, ResourceType, ResourceStatus
from app.schemas import ResourceResponse, ResourceFilter, ResourceCreate, ResourceUpdate

router = APIRouter()


@router.get("/resources", response_model=List[ResourceResponse])
async def list_resources(
    resource_type: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    district: Optional[str] = Query(None),
    min_capacity: Optional[int] = Query(None, ge=0),
    latitude: Optional[float] = Query(None),
    longitude: Optional[float] = Query(None),
    radius_km: Optional[float] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    """
    List resources with optional filters.

    Supports filtering by type, status, location, and capacity.
    """
    query = select(Resource)
    conditions = []

    if resource_type:
        conditions.append(Resource.resource_type == resource_type)
    if status:
        conditions.append(Resource.status == status)
    if district:
        conditions.append(func.lower(Resource.district).contains(district.lower()))
    if min_capacity:
        conditions.append(Resource.total_capacity >= min_capacity)

    if conditions:
        query = query.where(and_(*conditions))

    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    resources = result.scalars().all()

    response_list = []
    for r in resources:
        resp = ResourceResponse.model_validate(r)
        if latitude is not None and longitude is not None:
            from geopy.distance import geodesic
            dist = geodesic((latitude, longitude), (r.latitude, r.longitude)).km
            resp.distance_km = round(dist, 2)
            if radius_km and dist > radius_km:
                continue
        response_list.append(resp)

    if latitude is not None and longitude is not None:
        response_list.sort(key=lambda x: x.distance_km or 99999)

    return response_list


@router.get("/resources/{resource_id}", response_model=ResourceResponse)
async def get_resource(resource_id: UUID, db: AsyncSession = Depends(get_db)):
    """Get a specific resource by ID."""
    result = await db.execute(select(Resource).where(Resource.id == resource_id))
    resource = result.scalar_one_or_none()
    if not resource:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Resource not found")
    return ResourceResponse.model_validate(resource)


@router.get("/resources/stats/summary")
async def resource_stats(db: AsyncSession = Depends(get_db)):
    """Get aggregate resource statistics."""
    by_type = await db.execute(
        select(Resource.resource_type, func.count(Resource.id))
        .group_by(Resource.resource_type)
    )
    by_status = await db.execute(
        select(Resource.status, func.count(Resource.id))
        .group_by(Resource.status)
    )
    total_shelter_capacity = await db.execute(
        select(func.sum(Resource.total_capacity)).where(
            Resource.resource_type == ResourceType.SHELTER
        )
    )
    return {
        "by_type": {row[0].value: row[1] for row in by_type.all()},
        "by_status": {row[0].value: row[1] for row in by_status.all()},
        "total_shelter_capacity": total_shelter_capacity.scalar() or 0,
    }


@router.post("/resources", response_model=ResourceResponse, status_code=201)
async def create_resource(data: ResourceCreate, db: AsyncSession = Depends(get_db)):
    """Create a new resource."""
    resource = Resource(
        id=str(uuid4()),
        name=data.name,
        resource_type=data.resource_type,
        status=data.status,
        latitude=data.latitude,
        longitude=data.longitude,
        address=data.address,
        district=data.district,
        total_capacity=data.total_capacity,
        current_occupancy=data.current_occupancy,
        description=data.description,
        contact_name=data.contact_name,
        contact_phone=data.contact_phone,
        last_status_update=datetime.now(timezone.utc),
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(resource)
    await db.commit()
    await db.refresh(resource)
    return ResourceResponse.model_validate(resource)


@router.put("/resources/{resource_id}", response_model=ResourceResponse)
async def update_resource(resource_id: UUID, data: ResourceUpdate, db: AsyncSession = Depends(get_db)):
    """Update an existing resource."""
    result = await db.execute(select(Resource).where(Resource.id == str(resource_id)))
    resource = result.scalar_one_or_none()
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(resource, field, value)
    resource.updated_at = datetime.now(timezone.utc)
    resource.last_status_update = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(resource)
    return ResourceResponse.model_validate(resource)


@router.delete("/resources/{resource_id}")
async def delete_resource(resource_id: UUID, db: AsyncSession = Depends(get_db)):
    """Delete a resource."""
    result = await db.execute(select(Resource).where(Resource.id == str(resource_id)))
    resource = result.scalar_one_or_none()
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    await db.delete(resource)
    await db.commit()
    return {"status": "deleted", "id": str(resource_id)}
