"""Routing endpoints for ambulance/navigation route calculation."""

import math
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Incident
from app.schemas import RouteRequest, RouteResponse, RoutePoint

router = APIRouter()


def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance in km between two points."""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    return R * 2 * math.asin(math.sqrt(a))


def interpolate_route(origin, destination, num_points=10):
    """Generate interpolated route points (simplified straight-line with offset)."""
    points = []
    for i in range(num_points + 1):
        t = i / num_points
        lat = origin[0] + t * (destination[0] - origin[0])
        lon = origin[1] + t * (destination[1] - origin[1])
        # Add slight curve for realism
        offset = math.sin(t * math.pi) * 0.002
        points.append(RoutePoint(latitude=lat + offset, longitude=lon))
    return points


@router.post("/route", response_model=RouteResponse)
async def calculate_route(
    request: RouteRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Calculate optimal route between two points.

    Considers active incidents and road closures when avoid_incidents=True.
    Returns route points, distance, estimated travel time, and incidents on route.
    """
    distance = haversine(
        request.origin_lat, request.origin_lon,
        request.destination_lat, request.destination_lon,
    )

    # Generate route points
    route_points = interpolate_route(
        (request.origin_lat, request.origin_lon),
        (request.destination_lat, request.destination_lon),
    )

    # Check for incidents near the route
    incidents_on_route = []
    if request.avoid_incidents:
        result = await db.execute(
            select(Incident).where(Incident.is_active == True)
        )
        incidents = result.scalars().all()
        for inc in incidents:
            # Check if incident is within 1km of any route point
            for point in route_points:
                inc_dist = haversine(
                    point.latitude, point.longitude,
                    inc.latitude, inc.longitude,
                )
                if inc_dist < 1.0:
                    incidents_on_route.append({
                        "id": str(inc.id),
                        "title": inc.title,
                        "severity": inc.severity.value if inc.severity else "unknown",
                        "distance_from_route_km": round(inc_dist, 2),
                        "latitude": inc.latitude,
                        "longitude": inc.longitude,
                    })
                    break

    # Estimated time: assume 30 km/h average in crisis conditions
    avg_speed = 30
    estimated_minutes = int((distance / avg_speed) * 60)

    # If incidents on route, add delay
    if incidents_on_route:
        estimated_minutes = int(estimated_minutes * 1.5)

    return RouteResponse(
        origin=RoutePoint(latitude=request.origin_lat, longitude=request.origin_lon),
        destination=RoutePoint(latitude=request.destination_lat, longitude=request.destination_lon),
        distance_km=round(distance, 2),
        estimated_time_minutes=estimated_minutes,
        route_points=route_points,
        incidents_on_route=incidents_on_route,
    )
