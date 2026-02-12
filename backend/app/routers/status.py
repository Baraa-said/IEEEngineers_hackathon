"""System status and health check endpoint."""

import time
from fastapi import APIRouter, Depends
from sqlalchemy import select, func, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import HealthFacility, Resource, Incident
from app.schemas import SystemStatus
from app.config import settings

router = APIRouter()

_start_time = time.time()


@router.get("/status", response_model=SystemStatus)
async def system_status(db: AsyncSession = Depends(get_db)):
    """
    Get comprehensive system status including:
    - Service health
    - Database connectivity
    - Data freshness
    - Record counts
    """
    # Check database
    db_connected = True
    try:
        await db.execute(text("SELECT 1"))
    except Exception:
        db_connected = False

    # Count records
    total_facilities = 0
    total_resources = 0
    active_incidents = 0
    try:
        result = await db.execute(select(func.count(HealthFacility.id)))
        total_facilities = result.scalar() or 0
        result = await db.execute(select(func.count(Resource.id)))
        total_resources = result.scalar() or 0
        result = await db.execute(
            select(func.count(Incident.id)).where(Incident.is_active == True)
        )
        active_incidents = result.scalar() or 0
    except Exception:
        pass

    # Data freshness
    data_freshness = {}
    try:
        result = await db.execute(
            select(func.max(HealthFacility.last_status_update))
        )
        last_update = result.scalar()
        data_freshness["facilities"] = last_update.isoformat() if last_update else "No data"

        result = await db.execute(
            select(func.max(Resource.last_status_update))
        )
        last_update = result.scalar()
        data_freshness["resources"] = last_update.isoformat() if last_update else "No data"

        result = await db.execute(
            select(func.max(Incident.reported_at))
        )
        last_update = result.scalar()
        data_freshness["incidents"] = last_update.isoformat() if last_update else "No data"
    except Exception:
        data_freshness = {"facilities": "Unknown", "resources": "Unknown", "incidents": "Unknown"}

    return SystemStatus(
        status="operational" if db_connected else "degraded",
        version=settings.APP_VERSION,
        uptime_seconds=round(time.time() - _start_time, 2),
        database_connected=db_connected,
        vector_db_connected=False,  # TODO: implement Pinecone health check
        cache_connected=False,  # TODO: implement Redis health check
        data_freshness=data_freshness,
        total_facilities=total_facilities,
        total_resources=total_resources,
        active_incidents=active_incidents,
    )
