"""Incidents endpoints."""

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import uuid4
from datetime import datetime, timezone
from pydantic import BaseModel

from app.database import get_db
from app.models import Incident
from app.schemas import IncidentResponse, IncidentCreate, IncidentUpdate

router = APIRouter()


# ─── SOS Schema ───
class SOSReport(BaseModel):
    emergency_type: str  # red_crescent, civil_defense, police, nearest_hospital
    latitude: float
    longitude: float
    description: Optional[str] = None
    reported_by: Optional[str] = None


# ─── SOS Endpoint ───
@router.post("/sos", status_code=201)
async def send_sos(data: SOSReport, db: AsyncSession = Depends(get_db)):
    """Receive an SOS emergency report from the mobile app.
    Creates an incident marked as SOS with critical severity."""
    type_titles = {
        "red_crescent": "SOS — Red Crescent Called",
        "civil_defense": "SOS — Civil Defense Called",
        "police": "SOS — Police Called",
        "nearest_hospital": "SOS — Nearest Hospital Requested",
    }
    title = type_titles.get(data.emergency_type, f"SOS — {data.emergency_type}")

    incident = Incident(
        id=str(uuid4()),
        title=title,
        description=data.description or f"SOS alert: {data.emergency_type}",
        incident_type="sos",
        severity="critical",
        latitude=data.latitude,
        longitude=data.longitude,
        district=None,
        is_active=True,
        reported_by=data.reported_by or "Mobile App User",
        reported_at=datetime.now(timezone.utc),
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(incident)
    await db.commit()
    await db.refresh(incident)
    return {
        "status": "received",
        "id": incident.id,
        "title": incident.title,
        "message": "SOS alert received. Help is on the way.",
    }


# ─── Recent SOS alerts for dashboard polling ───
@router.get("/sos/recent")
async def recent_sos(
    minutes: int = Query(30, ge=1, le=1440),
    db: AsyncSession = Depends(get_db),
):
    """Get SOS incidents from the last N minutes (for dashboard real-time alerts)."""
    from datetime import timedelta
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=minutes)
    result = await db.execute(
        select(Incident)
        .where(
            and_(
                Incident.incident_type == "sos",
                Incident.reported_at >= cutoff,
                Incident.is_active == True,
            )
        )
        .order_by(Incident.reported_at.desc())
        .limit(50)
    )
    alerts = result.scalars().all()
    return [
        {
            "id": a.id,
            "title": a.title,
            "latitude": a.latitude,
            "longitude": a.longitude,
            "reported_at": (a.reported_at.isoformat() + "Z") if a.reported_at else None,
            "reported_by": a.reported_by,
            "description": a.description,
            "is_active": a.is_active,
        }
        for a in alerts
    ]


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


@router.post("/incidents", response_model=IncidentResponse, status_code=201)
async def create_incident(data: IncidentCreate, db: AsyncSession = Depends(get_db)):
    """Create a new incident."""
    incident = Incident(
        id=str(uuid4()),
        title=data.title,
        description=data.description,
        incident_type=data.incident_type,
        severity=data.severity,
        latitude=data.latitude,
        longitude=data.longitude,
        district=data.district,
        is_active=data.is_active,
        reported_by=data.reported_by,
        reported_at=datetime.now(timezone.utc),
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    db.add(incident)
    await db.commit()
    await db.refresh(incident)
    return IncidentResponse.model_validate(incident)


@router.put("/incidents/{incident_id}", response_model=IncidentResponse)
async def update_incident(incident_id: str, data: IncidentUpdate, db: AsyncSession = Depends(get_db)):
    """Update an existing incident."""
    result = await db.execute(select(Incident).where(Incident.id == incident_id))
    incident = result.scalar_one_or_none()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(incident, field, value)
    incident.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(incident)
    return IncidentResponse.model_validate(incident)


@router.delete("/incidents/{incident_id}")
async def delete_incident(incident_id: str, db: AsyncSession = Depends(get_db)):
    """Delete an incident."""
    result = await db.execute(select(Incident).where(Incident.id == incident_id))
    incident = result.scalar_one_or_none()
    if not incident:
        raise HTTPException(status_code=404, detail="Incident not found")
    await db.delete(incident)
    await db.commit()
    return {"status": "deleted", "id": incident_id}
