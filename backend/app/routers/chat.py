"""AI Agent chat endpoint — multi-turn RAG conversation powered by Ollama."""

import time
import logging
from typing import Optional

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import User
from app.schemas import ChatRequest, ChatResponse, MapMarker
from app.services.auth_service import get_current_user
from app.services.rag_pipeline import (
    classify_query,
    extract_entities,
    search_facilities,
    search_resources,
)
from app.services.ollama_rag import retrieve_context, generate_reply

logger = logging.getLogger(__name__)

router = APIRouter()


async def _build_markers(
    message: str,
    db: AsyncSession,
    lat: Optional[float],
    lon: Optional[float],
) -> list:
    """Run the existing DB search to build map markers for the response."""
    query_type = classify_query(message)
    entities = extract_entities(message)

    markers = []
    facilities, resources = [], []

    if query_type in ("facility_search", "geographic_search", "status_query", "statistical"):
        facilities = await search_facilities(db, entities, lat, lon, 10)
    if query_type in ("resource_search", "geographic_search"):
        resources = await search_resources(db, entities, lat, lon, 10)

    for f in facilities:
        markers.append(MapMarker(
            latitude=f["latitude"],
            longitude=f["longitude"],
            label=f["name"],
            type=f["facility_type"],
            status=f["status"],
            details={
                "available_beds": f.get("available_beds"),
                "distance_km": f.get("distance_km"),
            },
        ))
    for r in resources:
        markers.append(MapMarker(
            latitude=r["latitude"],
            longitude=r["longitude"],
            label=r["name"],
            type=r["resource_type"],
            status=r["status"],
            details={
                "capacity": r.get("total_capacity"),
                "distance_km": r.get("distance_km"),
            },
        ))
    return markers


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
    user: Optional[User] = Depends(get_current_user),
):
    """Multi-turn AI chat with file-based RAG + Ollama.
    Supports text, voice transcription, and photo descriptions.
    """
    start = time.time()

    # 1. Retrieve relevant context from RAG markdown files
    context = retrieve_context(request.message, top_k=15)

    # 2. Build map markers from DB (for the frontend map)
    markers = await _build_markers(
        request.message, db, request.latitude, request.longitude,
    )

    # 3. Generate reply via Ollama
    reply, confidence = await generate_reply(
        message=request.message,
        context=context,
        history=request.history,
        image_desc=request.image_description,
        language=request.language,
    )

    elapsed = int((time.time() - start) * 1000)

    return ChatResponse(
        reply=reply,
        map_markers=markers,
        confidence=confidence,
        response_time_ms=elapsed,
    )
