"""Dashboard aggregate endpoint — returns all stats in one call."""

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import HealthFacility, Resource, Incident, QueryLog

router = APIRouter()


@router.get("/dashboard/stats")
async def dashboard_stats(db: AsyncSession = Depends(get_db)):
    """Single endpoint returning everything the admin dashboard needs."""

    # ── Facilities ──────────────────────────────────────────
    total_fac = (await db.execute(select(func.count(HealthFacility.id)))).scalar() or 0
    fac_by_status = {
        row[0].value: row[1]
        for row in (
            await db.execute(
                select(HealthFacility.status, func.count(HealthFacility.id))
                .group_by(HealthFacility.status)
            )
        ).all()
    }
    fac_by_type = {
        row[0].value: row[1]
        for row in (
            await db.execute(
                select(HealthFacility.facility_type, func.count(HealthFacility.id))
                .group_by(HealthFacility.facility_type)
            )
        ).all()
    }
    fac_by_gov = {
        row[0]: row[1]
        for row in (
            await db.execute(
                select(HealthFacility.governorate, func.count(HealthFacility.id))
                .group_by(HealthFacility.governorate)
            )
        ).all()
        if row[0]
    }
    total_beds = (await db.execute(select(func.sum(HealthFacility.total_beds)))).scalar() or 0
    avail_beds = (await db.execute(select(func.sum(HealthFacility.available_beds)))).scalar() or 0
    total_icu = (await db.execute(select(func.sum(HealthFacility.icu_beds)))).scalar() or 0
    avail_icu = (await db.execute(select(func.sum(HealthFacility.icu_available)))).scalar() or 0
    with_power = (await db.execute(select(func.count(HealthFacility.id)).where(HealthFacility.has_power == True))).scalar() or 0
    with_oxygen = (await db.execute(select(func.count(HealthFacility.id)).where(HealthFacility.has_oxygen == True))).scalar() or 0

    # ── Resources ───────────────────────────────────────────
    total_res = (await db.execute(select(func.count(Resource.id)))).scalar() or 0
    res_by_type = {
        row[0].value: row[1]
        for row in (
            await db.execute(
                select(Resource.resource_type, func.count(Resource.id))
                .group_by(Resource.resource_type)
            )
        ).all()
    }
    res_by_status = {
        row[0].value: row[1]
        for row in (
            await db.execute(
                select(Resource.status, func.count(Resource.id))
                .group_by(Resource.status)
            )
        ).all()
    }
    shelter_cap = (
        await db.execute(
            select(func.sum(Resource.total_capacity)).where(
                Resource.resource_type == "shelter"
            )
        )
    ).scalar() or 0
    shelter_occ = (
        await db.execute(
            select(func.sum(Resource.current_occupancy)).where(
                Resource.resource_type == "shelter"
            )
        )
    ).scalar() or 0

    # ── Incidents ───────────────────────────────────────────
    total_inc = (await db.execute(select(func.count(Incident.id)))).scalar() or 0
    active_inc = (
        await db.execute(
            select(func.count(Incident.id)).where(Incident.is_active == True)
        )
    ).scalar() or 0
    inc_by_type = {
        row[0]: row[1]
        for row in (
            await db.execute(
                select(Incident.incident_type, func.count(Incident.id))
                .group_by(Incident.incident_type)
            )
        ).all()
    }
    inc_by_severity = {
        (row[0].value if hasattr(row[0], "value") else row[0]): row[1]
        for row in (
            await db.execute(
                select(Incident.severity, func.count(Incident.id))
                .group_by(Incident.severity)
            )
        ).all()
    }
    inc_by_district = {
        row[0]: row[1]
        for row in (
            await db.execute(
                select(Incident.district, func.count(Incident.id))
                .group_by(Incident.district)
            )
        ).all()
        if row[0]
    }

    # ── Queries ─────────────────────────────────────────────
    total_queries = (await db.execute(select(func.count(QueryLog.id)))).scalar() or 0
    avg_confidence = (await db.execute(select(func.avg(QueryLog.confidence_score)))).scalar()
    avg_response_ms = (await db.execute(select(func.avg(QueryLog.response_time_ms)))).scalar()

    return {
        "facilities": {
            "total": total_fac,
            "by_status": fac_by_status,
            "by_type": fac_by_type,
            "by_governorate": fac_by_gov,
            "total_beds": total_beds,
            "available_beds": avail_beds,
            "total_icu": total_icu,
            "available_icu": avail_icu,
            "with_power": with_power,
            "with_oxygen": with_oxygen,
        },
        "resources": {
            "total": total_res,
            "by_type": res_by_type,
            "by_status": res_by_status,
            "shelter_capacity": shelter_cap,
            "shelter_occupancy": shelter_occ,
        },
        "incidents": {
            "total": total_inc,
            "active": active_inc,
            "by_type": inc_by_type,
            "by_severity": inc_by_severity,
            "by_district": inc_by_district,
        },
        "queries": {
            "total": total_queries,
            "avg_confidence": round(avg_confidence, 2) if avg_confidence else 0,
            "avg_response_ms": round(avg_response_ms, 0) if avg_response_ms else 0,
        },
    }
