"""Incidents endpoints."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List

from app.database import get_db
from app.models import Incident
from app.schemas import IncidentResponse

router = APIRouter()


@router.get("/incidents", response_model=List[IncidentResponse])
async def list_incidents(
    incident_type: Optional[str] = Query(None),
    severity: Optional[str] = Query(None),
    district: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
):
    """List incidents with optional filters."""
    query = select(Incident)
    conditions = []

    if incident_type:
        conditions.append(Incident.incident_type == incident_type)
    if severity:
        conditions.append(Incident.severity == severity)
    if district:
        conditions.append(func.lower(Incident.district).contains(district.lower()))
    if is_active is not None:
        conditions.append(Incident.is_active == is_active)

    if conditions:
        query = query.where(and_(*conditions))

    query = query.order_by(Incident.reported_at.desc()).offset(offset).limit(limit)
    result = await db.execute(query)
    incidents = result.scalars().all()
    return [IncidentResponse.model_validate(i) for i in incidents]


@router.get("/incidents/stats/summary")
async def incident_stats(db: AsyncSession = Depends(get_db)):
    """Get aggregate incident statistics."""
    total = await db.execute(select(func.count(Incident.id)))
    active = await db.execute(
        select(func.count(Incident.id)).where(Incident.is_active == True)
    )
    by_type = await db.execute(
        select(Incident.incident_type, func.count(Incident.id))
        .group_by(Incident.incident_type)
    )
    by_severity = await db.execute(
        select(Incident.severity, func.count(Incident.id))
        .group_by(Incident.severity)
    )
    by_district = await db.execute(
        select(Incident.district, func.count(Incident.id))
        .group_by(Incident.district)
    )
    return {
        "total_incidents": total.scalar() or 0,
        "active_incidents": active.scalar() or 0,
        "by_type": {row[0]: row[1] for row in by_type.all()},
        "by_severity": {row[0].value if hasattr(row[0], 'value') else row[0]: row[1] for row in by_severity.all()},
        "by_district": {row[0]: row[1] for row in by_district.all() if row[0]},
    }
