"""Natural language query endpoint — the core API."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.database import get_db
from app.models import User
from app.schemas import QueryRequest, QueryResponse
from app.services.auth_service import get_current_user
from app.services.rag_pipeline import process_query

router = APIRouter()


@router.post("/query", response_model=QueryResponse)
async def submit_query(
    request: QueryRequest,
    db: AsyncSession = Depends(get_db),
    user: Optional[User] = Depends(get_current_user),
):
    """
    Submit a natural language query to the Situation Room Agent.

    The system will:
    1. Classify the query intent
    2. Extract entities (locations, facility types, constraints)
    3. Retrieve relevant data from the database
    4. Generate a comprehensive AI-powered response
    5. Return answer with map markers and data sources

    Example queries:
    - "Where is the nearest functional hospital with available trauma beds?"
    - "Show me all shelters within 5km of Ramallah with capacity for 100+ people"
    - "Which medical facilities still have power and oxygen supply?"
    """
    user_id = str(user.id) if user else None
    return await process_query(request, db, user_id)
