"""
RAG (Retrieval-Augmented Generation) pipeline for the Situation Room Agent.

This is the core intelligence component that processes natural language queries
by combining semantic search with LLM-powered response generation.
"""

import json
import time
import uuid
import logging
from datetime import datetime
from typing import Optional, List, Dict, Any, Tuple

from sqlalchemy import select, func, and_, or_, cast, Float
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import (
    HealthFacility, Resource, Incident, QueryLog,
    FacilityStatus, FacilityType, ResourceType, ResourceStatus,
    IncidentSeverity,
)
from app.schemas import (
    QueryRequest, QueryResponse, QuerySource, MapMarker,
)

logger = logging.getLogger(__name__)


# ---- Query Classification ----

QUERY_TYPES = {
    "facility_search": [
        "hospital", "clinic", "health center", "pharmacy", "facility",
        "medical", "trauma", "icu", "emergency department", "ed",
        "مستشفى", "عيادة", "صيدلية",
    ],
    "resource_search": [
        "ambulance", "shelter", "supply", "distribution", "water",
        "food", "medicine", "equipment", "إسعاف", "مأوى",
    ],
    "status_query": [
        "status", "operational", "power", "oxygen", "water supply",
        "capacity", "beds", "available", "wait time", "حالة",
    ],
    "geographic_search": [
        "nearest", "closest", "within", "near", "km", "distance",
        "route", "direction", "map", "area", "zone", "الأقرب",
    ],
    "statistical": [
        "how many", "total", "count", "percentage", "average",
        "distribution", "summary", "statistics", "كم عدد",
    ],
}


def classify_query(query: str) -> str:
    """Classify the query into a type based on keyword matching."""
    query_lower = query.lower()
    scores = {}
    for qtype, keywords in QUERY_TYPES.items():
        scores[qtype] = sum(1 for kw in keywords if kw in query_lower)
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "facility_search"


def extract_entities(query: str) -> Dict[str, Any]:
    """Extract entities from the query: locations, numbers, facility types, etc."""
    query_lower = query.lower()
    entities: Dict[str, Any] = {}

    # Extract distance constraints
    import re
    dist_match = re.search(r'(\d+)\s*km', query_lower)
    if dist_match:
        entities["radius_km"] = float(dist_match.group(1))

    # Extract capacity constraints
    cap_match = re.search(r'(\d+)\+?\s*(?:people|person|capacity|beds|bed)', query_lower)
    if cap_match:
        entities["min_capacity"] = int(cap_match.group(1))

    # Extract facility types
    for ft in FacilityType:
        if ft.value.replace("_", " ") in query_lower:
            entities["facility_type"] = ft.value

    # Default: if "hospital" mentioned explicitly
    if "hospital" in query_lower and "facility_type" not in entities:
        entities["facility_type"] = "hospital"

    # Extract resource types
    for rt in ResourceType:
        if rt.value.replace("_", " ") in query_lower:
            entities["resource_type"] = rt.value

    # Extract status constraints
    if any(w in query_lower for w in ["functional", "operational", "working", "open"]):
        entities["status"] = "operational"

    # Extract equipment needs
    if "oxygen" in query_lower:
        entities["needs_oxygen"] = True
    if "power" in query_lower or "electricity" in query_lower:
        entities["needs_power"] = True
    if "trauma" in query_lower:
        entities["needs_trauma"] = True

    # Extract districts / governorates
    westbank_districts = [
        "ramallah", "al-bireh", "nablus", "hebron", "al-khalil", "bethlehem",
        "jenin", "tulkarm", "qalqilya", "salfit", "tubas", "jericho",
        "jerusalem", "huwara", "beit jala", "beit sahour", "dura",
        "yatta", "azzun", "anabta", "silwad", "birzeit", "al-aghwar",
    ]
    for dist in westbank_districts:
        if dist in query_lower:
            entities["district"] = dist.title()

    return entities


# ---- Database Retrieval ----

def haversine_distance_sql(lat1: float, lon1: float, lat2_col, lon2_col):
    """Haversine formula in SQL for distance calculation (returns km)."""
    from sqlalchemy import func as sqlfunc
    import math
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    dlat = func.radians(cast(lat2_col, Float)) - lat1_rad
    dlon = func.radians(cast(lon2_col, Float)) - lon1_rad
    a = (
        func.power(func.sin(dlat / 2), 2)
        + math.cos(lat1_rad)
        * func.cos(func.radians(cast(lat2_col, Float)))
        * func.power(func.sin(dlon / 2), 2)
    )
    return 6371 * 2 * func.asin(func.sqrt(a))


async def search_facilities(
    db: AsyncSession,
    entities: Dict[str, Any],
    user_lat: Optional[float] = None,
    user_lon: Optional[float] = None,
    limit: int = 10,
) -> List[Dict[str, Any]]:
    """Search health facilities based on extracted entities."""
    query = select(HealthFacility)
    conditions = []

    if entities.get("facility_type"):
        conditions.append(HealthFacility.facility_type == entities["facility_type"])

    if entities.get("status"):
        conditions.append(HealthFacility.status == entities["status"])

    if entities.get("needs_oxygen"):
        conditions.append(HealthFacility.has_oxygen == True)

    if entities.get("needs_power"):
        conditions.append(HealthFacility.has_power == True)

    if entities.get("needs_trauma"):
        conditions.append(HealthFacility.trauma_available > 0)

    if entities.get("min_capacity"):
        conditions.append(HealthFacility.available_beds >= entities["min_capacity"])

    if entities.get("district"):
        conditions.append(
            or_(
                func.lower(HealthFacility.district).contains(entities["district"].lower()),
                func.lower(HealthFacility.governorate).contains(entities["district"].lower()),
            )
        )

    if conditions:
        query = query.where(and_(*conditions))

    result = await db.execute(query)
    facilities = result.scalars().all()

    # Calculate distances if user location provided
    facility_list = []
    for f in facilities:
        fdict = {
            "id": str(f.id),
            "name": f.name,
            "name_ar": f.name_ar,
            "facility_type": f.facility_type.value if f.facility_type else None,
            "status": f.status.value if f.status else None,
            "latitude": f.latitude,
            "longitude": f.longitude,
            "address": f.address,
            "district": f.district,
            "governorate": f.governorate,
            "total_beds": f.total_beds,
            "available_beds": f.available_beds,
            "icu_beds": f.icu_beds,
            "icu_available": f.icu_available,
            "trauma_beds": f.trauma_beds,
            "trauma_available": f.trauma_available,
            "has_power": f.has_power,
            "has_generator": f.has_generator,
            "has_oxygen": f.has_oxygen,
            "has_water": f.has_water,
            "specialties": f.specialties or [],
            "emergency_department": f.emergency_department,
            "ed_wait_time_minutes": f.ed_wait_time_minutes,
            "doctors_on_duty": f.doctors_on_duty,
            "nurses_on_duty": f.nurses_on_duty,
            "phone": f.phone,
            "emergency_phone": f.emergency_phone,
            "last_status_update": f.last_status_update.isoformat() if f.last_status_update else None,
        }

        if user_lat is not None and user_lon is not None:
            from geopy.distance import geodesic
            dist = geodesic((user_lat, user_lon), (f.latitude, f.longitude)).km
            fdict["distance_km"] = round(dist, 2)
        facility_list.append(fdict)

    # Sort by distance if available, otherwise by available beds
    if user_lat is not None:
        facility_list.sort(key=lambda x: x.get("distance_km", 99999))

        # Filter by radius
        radius = entities.get("radius_km", 50)
        facility_list = [f for f in facility_list if f.get("distance_km", 0) <= radius]
    else:
        facility_list.sort(key=lambda x: x.get("available_beds", 0), reverse=True)

    return facility_list[:limit]


async def search_resources(
    db: AsyncSession,
    entities: Dict[str, Any],
    user_lat: Optional[float] = None,
    user_lon: Optional[float] = None,
    limit: int = 10,
) -> List[Dict[str, Any]]:
    """Search resources based on extracted entities."""
    query = select(Resource)
    conditions = []

    if entities.get("resource_type"):
        conditions.append(Resource.resource_type == entities["resource_type"])

    if entities.get("district"):
        conditions.append(
            func.lower(Resource.district).contains(entities["district"].lower())
        )

    if entities.get("min_capacity"):
        conditions.append(Resource.total_capacity >= entities["min_capacity"])

    # Default: only available resources
    conditions.append(Resource.status == ResourceStatus.AVAILABLE)

    if conditions:
        query = query.where(and_(*conditions))

    result = await db.execute(query)
    resources = result.scalars().all()

    resource_list = []
    for r in resources:
        rdict = {
            "id": str(r.id),
            "name": r.name,
            "resource_type": r.resource_type.value if r.resource_type else None,
            "status": r.status.value if r.status else None,
            "latitude": r.latitude,
            "longitude": r.longitude,
            "address": r.address,
            "district": r.district,
            "total_capacity": r.total_capacity,
            "current_occupancy": r.current_occupancy,
            "available_capacity": (r.total_capacity or 0) - (r.current_occupancy or 0),
            "description": r.description,
            "details": r.details,
            "contact_name": r.contact_name,
            "contact_phone": r.contact_phone,
        }

        if user_lat is not None and user_lon is not None:
            from geopy.distance import geodesic
            dist = geodesic((user_lat, user_lon), (r.latitude, r.longitude)).km
            rdict["distance_km"] = round(dist, 2)
        resource_list.append(rdict)

    if user_lat is not None:
        resource_list.sort(key=lambda x: x.get("distance_km", 99999))
        radius = entities.get("radius_km", 50)
        resource_list = [r for r in resource_list if r.get("distance_km", 0) <= radius]

    return resource_list[:limit]


async def get_active_incidents(
    db: AsyncSession,
    entities: Dict[str, Any],
    user_lat: Optional[float] = None,
    user_lon: Optional[float] = None,
) -> List[Dict[str, Any]]:
    """Get active incidents, optionally filtered by location."""
    query = select(Incident).where(Incident.is_active == True)

    if entities.get("district"):
        query = query.where(
            func.lower(Incident.district).contains(entities["district"].lower())
        )

    result = await db.execute(query)
    incidents = result.scalars().all()

    incident_list = []
    for inc in incidents:
        idict = {
            "id": str(inc.id),
            "title": inc.title,
            "description": inc.description,
            "incident_type": inc.incident_type,
            "severity": inc.severity.value if inc.severity else None,
            "latitude": inc.latitude,
            "longitude": inc.longitude,
            "district": inc.district,
            "roads_affected": inc.roads_affected,
            "reported_at": inc.reported_at.isoformat() if inc.reported_at else None,
        }
        if user_lat is not None and user_lon is not None:
            from geopy.distance import geodesic
            dist = geodesic((user_lat, user_lon), (inc.latitude, inc.longitude)).km
            idict["distance_km"] = round(dist, 2)
        incident_list.append(idict)

    return incident_list


async def get_statistics(db: AsyncSession) -> Dict[str, Any]:
    """Get aggregate statistics for the situation."""
    # Facility stats
    total_facilities = await db.execute(select(func.count(HealthFacility.id)))
    operational = await db.execute(
        select(func.count(HealthFacility.id)).where(
            HealthFacility.status == FacilityStatus.OPERATIONAL
        )
    )
    damaged = await db.execute(
        select(func.count(HealthFacility.id)).where(
            HealthFacility.status == FacilityStatus.DAMAGED
        )
    )
    total_beds = await db.execute(select(func.sum(HealthFacility.total_beds)))
    available_beds = await db.execute(select(func.sum(HealthFacility.available_beds)))

    # Resource stats
    total_resources = await db.execute(select(func.count(Resource.id)))
    total_shelters = await db.execute(
        select(func.count(Resource.id)).where(Resource.resource_type == ResourceType.SHELTER)
    )

    # Incident stats
    active_incidents = await db.execute(
        select(func.count(Incident.id)).where(Incident.is_active == True)
    )

    return {
        "total_facilities": total_facilities.scalar() or 0,
        "operational_facilities": operational.scalar() or 0,
        "damaged_facilities": damaged.scalar() or 0,
        "total_beds": total_beds.scalar() or 0,
        "available_beds": available_beds.scalar() or 0,
        "total_resources": total_resources.scalar() or 0,
        "total_shelters": total_shelters.scalar() or 0,
        "active_incidents": active_incidents.scalar() or 0,
    }


# ---- LLM Response Generation ----

def build_system_prompt() -> str:
    return """You are a Crisis Situation Room AI Agent for Palestine West Bank's health and humanitarian emergency response.
Your role is to help crisis managers and first responders by answering questions about:
- Health facility status, capacity, and availability
- Resource locations and availability (ambulances, shelters, supplies)
- Active incidents and their impact on operations
- Geographic information and routing

Guidelines:
1. Always provide factual, data-driven answers based on the retrieved information.
2. Include specific numbers (beds available, distances, wait times) when available.
3. Prioritize actionable information that helps decision-making.
4. If data is insufficient, clearly state what information is missing.
5. Include confidence levels when estimates are involved.
6. Format responses for clarity: use bullet points for lists, bold for critical info.
7. Always mention data freshness (when the data was last updated).
8. Support both English and Arabic responses as requested.
9. Never make up data. If you don't have information, say so explicitly.
10. For geographic queries, always mention distances and directions when available."""


def build_context_prompt(
    facilities: List[Dict],
    resources: List[Dict],
    incidents: List[Dict],
    statistics: Dict[str, Any],
) -> str:
    """Build context from retrieved data for the LLM."""
    context_parts = []

    if facilities:
        context_parts.append("## Available Health Facilities Data")
        for f in facilities[:10]:
            parts = [f"- **{f['name']}** ({f['facility_type']})"]
            parts.append(f"  Status: {f['status']}")
            if f.get("distance_km") is not None:
                parts.append(f"  Distance: {f['distance_km']} km")
            parts.append(f"  Available beds: {f['available_beds']}/{f['total_beds']}")
            if f.get("trauma_available"):
                parts.append(f"  Trauma beds available: {f['trauma_available']}")
            if f.get("icu_available"):
                parts.append(f"  ICU beds available: {f['icu_available']}")
            parts.append(f"  Power: {'Yes' if f['has_power'] else 'No'}, Oxygen: {'Yes' if f['has_oxygen'] else 'No'}")
            if f.get("ed_wait_time_minutes"):
                parts.append(f"  ED Wait time: {f['ed_wait_time_minutes']} min")
            if f.get("specialties"):
                parts.append(f"  Specialties: {', '.join(f['specialties'])}")
            if f.get("phone"):
                parts.append(f"  Contact: {f['phone']}")
            context_parts.append("\n".join(parts))

    if resources:
        context_parts.append("\n## Available Resources Data")
        for r in resources[:10]:
            parts = [f"- **{r['name']}** ({r['resource_type']})"]
            parts.append(f"  Status: {r['status']}")
            if r.get("distance_km") is not None:
                parts.append(f"  Distance: {r['distance_km']} km")
            if r.get("total_capacity"):
                parts.append(f"  Capacity: {r.get('current_occupancy', 0)}/{r['total_capacity']}")
            if r.get("contact_phone"):
                parts.append(f"  Contact: {r['contact_phone']}")
            context_parts.append("\n".join(parts))

    if incidents:
        context_parts.append("\n## Active Incidents")
        for inc in incidents[:5]:
            parts = [f"- **{inc['title']}** (Severity: {inc['severity']})"]
            parts.append(f"  Type: {inc['incident_type']}")
            if inc.get("distance_km") is not None:
                parts.append(f"  Distance: {inc['distance_km']} km")
            if inc.get("roads_affected"):
                parts.append(f"  Roads affected: {', '.join(inc['roads_affected'])}")
            context_parts.append("\n".join(parts))

    if statistics:
        context_parts.append("\n## Current Statistics")
        context_parts.append(f"- Total facilities: {statistics['total_facilities']}")
        context_parts.append(f"- Operational: {statistics['operational_facilities']}")
        context_parts.append(f"- Damaged: {statistics['damaged_facilities']}")
        context_parts.append(f"- Total beds: {statistics['total_beds']}")
        context_parts.append(f"- Available beds: {statistics['available_beds']}")
        context_parts.append(f"- Active incidents: {statistics['active_incidents']}")

    return "\n".join(context_parts) if context_parts else "No relevant data found in the database."


async def generate_llm_response(
    query: str,
    context: str,
    language: str = "en",
) -> Tuple[str, float]:
    """Generate a response using OpenAI's API. Returns (response_text, confidence_score)."""

    if not settings.OPENAI_API_KEY or settings.OPENAI_API_KEY == "your_openai_api_key_here":
        # Fallback: generate a structured response without LLM
        return _generate_fallback_response(query, context, language), 0.75

    try:
        from openai import AsyncOpenAI
        client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

        lang_instruction = ""
        if language == "ar":
            lang_instruction = "\nRespond in Arabic (العربية). Use RTL-friendly formatting."

        messages = [
            {"role": "system", "content": build_system_prompt() + lang_instruction},
            {"role": "user", "content": f"Query: {query}\n\nRetrieved Data:\n{context}"},
        ]

        response = await client.chat.completions.create(
            model=settings.OPENAI_MODEL,
            messages=messages,
            temperature=0.3,
            max_tokens=1000,
        )

        answer = response.choices[0].message.content
        # Estimate confidence based on context availability
        confidence = 0.9 if len(context) > 200 else 0.7
        return answer, confidence

    except Exception as e:
        logger.error(f"LLM API error: {e}")
        return _generate_fallback_response(query, context, language), 0.6


def _generate_fallback_response(query: str, context: str, language: str) -> str:
    """Generate a structured response without LLM (for demo/fallback)."""
    if "No relevant data found" in context:
        return (
            "I couldn't find specific data matching your query. "
            "Please try refining your search with more specific terms, "
            "or check the available categories: hospitals, clinics, shelters, ambulances."
        )

    # Return the context as a formatted answer
    return (
        f"Based on the available data for your query:\n\n{context}\n\n"
        "Note: This response was generated from direct data retrieval. "
        "For more detailed analysis, ensure the AI model API key is configured."
    )


# ---- Main Pipeline ----

async def process_query(
    request: QueryRequest,
    db: AsyncSession,
    user_id: Optional[str] = None,
) -> QueryResponse:
    """Main RAG pipeline: process a natural language query end-to-end."""
    start_time = time.time()

    # Step 1: Classify query
    query_type = classify_query(request.query)

    # Step 2: Extract entities
    entities = extract_entities(request.query)

    # Step 3: Retrieve relevant data based on query type
    facilities = []
    resources = []
    incidents = []
    statistics = {}

    if query_type in ("facility_search", "geographic_search", "status_query"):
        facilities = await search_facilities(
            db, entities, request.latitude, request.longitude, request.max_results
        )

    if query_type in ("resource_search", "geographic_search"):
        resources = await search_resources(
            db, entities, request.latitude, request.longitude, request.max_results
        )

    if query_type in ("geographic_search", "status_query"):
        incidents = await get_active_incidents(
            db, entities, request.latitude, request.longitude
        )

    if query_type == "statistical":
        statistics = await get_statistics(db)
        facilities = await search_facilities(db, entities, request.latitude, request.longitude, 5)

    # Step 4: Build context
    context = build_context_prompt(facilities, resources, incidents, statistics)

    # Step 5: Generate response with LLM
    answer, confidence = await generate_llm_response(
        request.query, context, request.language
    )

    # Step 6: Build map markers
    map_markers = []
    for f in facilities:
        map_markers.append(MapMarker(
            latitude=f["latitude"],
            longitude=f["longitude"],
            label=f["name"],
            type=f["facility_type"],
            status=f["status"],
            details={
                "available_beds": f["available_beds"],
                "has_power": f["has_power"],
                "has_oxygen": f["has_oxygen"],
                "distance_km": f.get("distance_km"),
            },
        ))
    for r in resources:
        map_markers.append(MapMarker(
            latitude=r["latitude"],
            longitude=r["longitude"],
            label=r["name"],
            type=r["resource_type"],
            status=r["status"],
            details={
                "capacity": r.get("total_capacity"),
                "occupancy": r.get("current_occupancy"),
                "distance_km": r.get("distance_km"),
            },
        ))

    elapsed_ms = int((time.time() - start_time) * 1000)
    query_id = uuid.uuid4()

    # Log query
    try:
        log_entry = QueryLog(
            id=query_id,
            user_id=uuid.UUID(user_id) if user_id else None,
            query_text=request.query,
            query_type=query_type,
            entities=entities,
            response_text=answer,
            confidence_score=confidence,
            data_sources=["health_facilities", "resources", "incidents"],
            response_time_ms=elapsed_ms,
        )
        db.add(log_entry)
    except Exception as e:
        logger.warning(f"Failed to log query: {e}")

    return QueryResponse(
        query_id=query_id,
        query=request.query,
        answer=answer,
        confidence_score=confidence,
        data_sources=[
            QuerySource(name="Health Facilities DB", freshness="Real-time", record_count=len(facilities)),
            QuerySource(name="Resources DB", freshness="Real-time", record_count=len(resources)),
            QuerySource(name="Incidents DB", freshness="Real-time", record_count=len(incidents)),
        ],
        map_markers=map_markers,
        statistics=statistics if statistics else None,
        response_time_ms=elapsed_ms,
        timestamp=datetime.utcnow(),
        language=request.language,
    )
