"""FastAPI application entry point."""

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from app.config import settings
from app.database import init_db, close_db
from app.routers import query, facilities, resources, routes, status, auth, incidents, dashboard, chat
from app.middleware.rate_limiter import RateLimitMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    # Startup
    await init_db()
    yield
    # Shutdown
    await close_db()


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "Natural Language Situation Room Agent API for Palestine West Bank Crisis Response. "
        "Enables crisis managers to query complex operational data using conversational language."
    ),
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting
app.add_middleware(RateLimitMiddleware)

# Routers
app.include_router(auth.router, prefix="/api/v1", tags=["Authentication"])
app.include_router(query.router, prefix="/api/v1", tags=["Natural Language Query"])
app.include_router(facilities.router, prefix="/api/v1", tags=["Facilities"])
app.include_router(resources.router, prefix="/api/v1", tags=["Resources"])
app.include_router(routes.router, prefix="/api/v1", tags=["Routing"])
app.include_router(status.router, prefix="/api/v1", tags=["System Status"])
app.include_router(incidents.router, prefix="/api/v1", tags=["Incidents"])
app.include_router(dashboard.router, prefix="/api/v1", tags=["Dashboard"])
app.include_router(chat.router, prefix="/api/v1", tags=["AI Chat Agent"])

# Serve the admin dashboard
_dashboard_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "dashboard")
if os.path.isdir(_dashboard_dir):
    app.mount("/dashboard/static", StaticFiles(directory=_dashboard_dir), name="dashboard-static")


@app.get("/dashboard", tags=["Dashboard"])
async def serve_dashboard():
    html = os.path.join(_dashboard_dir, "index.html")
    return FileResponse(html, media_type="text/html")


@app.get("/", tags=["Root"])
async def root():
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "operational",
        "docs": "/docs",
    }


@app.get("/health", tags=["Root"])
async def health():
    return {"status": "healthy"}


@app.post("/api/v1/rag/reload", tags=["AI Chat Agent"])
async def reload_rag():
    """Re-read the RAG markdown files from data/rag/."""
    from app.services.ollama_rag import reload_rag_documents
    reload_rag_documents()
    return {"status": "ok", "message": "RAG documents reloaded"}


@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "healthy"}
