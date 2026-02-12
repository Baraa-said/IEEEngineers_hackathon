# 🏥 Natural Language Situation Room Agent

### AI4Purpose Hackathon — Lebanon Health Crisis Response

> An AI-powered crisis management platform that enables health officials and emergency responders to query complex, multi-source data using natural language — combining LLM/RAG intelligence, GIS mapping, and a mobile-first Flutter interface.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [API Documentation](#api-documentation)
- [Mobile App](#mobile-app)
- [Demo Scenarios](#demo-scenarios)
- [Ethics & Data Privacy](#ethics--data-privacy)
- [Team](#team)

---

## Overview

During the Lebanon health crisis, decision-makers face fragmented data across multiple systems (hospital capacity, medical supplies, displacement patterns, infrastructure damage). This tool unifies that data behind a **natural language interface** — ask questions in plain English or Arabic and get instant, actionable answers with map visualizations.

### Problem Statement

- Health officials need real-time facility status across regions
- Emergency responders need optimal routing avoiding conflict zones
- Resource managers need supply chain visibility across 6 governorates
- All stakeholders need a single source of truth accessible on mobile devices

### Our Solution

A three-tier architecture:

1. **RAG Intelligence Layer** — Classifies queries, extracts entities, retrieves relevant data, and generates contextual LLM responses
2. **Geospatial Data Platform** — PostgreSQL-backed facility/resource/incident tracking with coordinate-aware queries
3. **Mobile-First Interface** — Flutter app with interactive maps, voice input, offline caching, and emergency mode

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter Mobile App                     │
│  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌────────┐ │
│  │  Query    │  │   Map    │  │ Facilities│  │Settings│ │
│  │  Screen   │  │  Screen  │  │  Screen   │  │ Screen │ │
│  └────┬─────┘  └────┬─────┘  └─────┬─────┘  └────────┘ │
│       │              │              │                     │
│       └──────────────┼──────────────┘                     │
│                      │                                     │
│              ┌───────┴───────┐                             │
│              │  API Service  │ (Dio + Auth Interceptor)    │
│              └───────┬───────┘                             │
└──────────────────────┼─────────────────────────────────────┘
                       │ HTTPS
┌──────────────────────┼─────────────────────────────────────┐
│                 FastAPI Backend                             │
│  ┌───────────────────┴────────────────────┐                │
│  │           API Gateway (Routers)         │                │
│  │  /auth  /query  /facilities  /resources │                │
│  │  /routes  /status                       │                │
│  └───────────────────┬────────────────────┘                │
│                      │                                      │
│  ┌───────────────────┴────────────────────┐                │
│  │          RAG Pipeline                   │                │
│  │  Query Classification → Entity Extract  │                │
│  │  → Data Retrieval → LLM Generation     │                │
│  └───────────────────┬────────────────────┘                │
│                      │                                      │
│  ┌──────────┐  ┌─────┴──────┐  ┌──────────────┐           │
│  │PostgreSQL│  │   Redis    │  │ OpenAI API   │           │
│  │ + Data   │  │   Cache    │  │ (optional)   │           │
│  └──────────┘  └────────────┘  └──────────────┘           │
└────────────────────────────────────────────────────────────┘
```

---

## Features

### Natural Language Querying
- Query types: facility search, resource tracking, incident reporting, route planning, statistics
- Entity extraction: location, capacity, resource type, severity, distance
- Confidence scoring on all responses
- Bilingual support (English/Arabic query suggestions)

### Interactive Map
- Facility markers with status-based color coding
- Filter by facility type (hospital, clinic, shelter, distribution point)
- Facility detail panel with bed capacity, ICU, oxygen, power, trauma level
- Route visualization avoiding active incident zones

### Crisis Data Management
- 22 real Lebanese hospitals + 60+ clinics across 6 governorates
- Real-time resource tracking (ambulances, medical supplies, blood units)
- Incident tracking with severity levels and affected area radius
- Statistics dashboard with governorate-level breakdowns

### Offline & Emergency Mode
- Hive-based local caching of queries and facility data
- Automatic fallback to cached results when API is unreachable
- Emergency mode for degraded-network environments

---

## Tech Stack

| Layer         | Technology                                    |
|---------------|-----------------------------------------------|
| **Backend**   | Python 3.11, FastAPI, SQLAlchemy (async)      |
| **AI/LLM**   | LangChain, OpenAI GPT-4 Turbo, RAG pipeline  |
| **Database**  | PostgreSQL 15, Redis 7                        |
| **Mobile**    | Flutter 3.x, Riverpod, Dio, flutter_map      |
| **Infra**     | Docker Compose                                |
| **Auth**      | JWT (HS256), bcrypt                           |

---

## Getting Started

### Prerequisites

- Docker & Docker Compose
- (Optional) OpenAI API key for LLM-powered responses
- (Optional) Flutter SDK 3.x for mobile development

### 1. Clone & Configure

```bash
git clone <repo-url>
cd IEEEngineers_hackathon

# Copy environment template
cp .env.example .env

# (Optional) Add your OpenAI API key to .env
# OPENAI_API_KEY=sk-...
```

### 2. Start Backend Services

```bash
docker-compose up --build
```

This will:
- Start PostgreSQL on port 5432
- Start Redis on port 6379
- Build and start the FastAPI backend on port 8000
- Automatically seed the database with synthetic Lebanon health data

### 3. Verify API

```bash
# Health check
curl http://localhost:8000/api/v1/status/health

# API documentation (interactive)
open http://localhost:8000/docs
```

### 4. Run Mobile App (Optional)

```bash
cd mobile_app
flutter pub get
flutter run
```

### 5. Run Without Docker

```bash
# Terminal 1: Start PostgreSQL and Redis locally

# Terminal 2: Backend
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -m app.seed_db
uvicorn app.main:app --reload

# Terminal 3: Mobile
cd mobile_app
flutter run
```

---

## API Documentation

Once the backend is running, visit **http://localhost:8000/docs** for the interactive Swagger UI.

### Key Endpoints

| Method | Endpoint                         | Description                        |
|--------|----------------------------------|------------------------------------|
| POST   | `/api/v1/auth/register`         | Register a new user                |
| POST   | `/api/v1/auth/login`            | Login and receive JWT token        |
| GET    | `/api/v1/auth/me`               | Get current user profile           |
| POST   | `/api/v1/query/`                | Submit natural language query       |
| GET    | `/api/v1/facilities/`           | List facilities with filters       |
| GET    | `/api/v1/facilities/{id}`       | Get facility details               |
| GET    | `/api/v1/facilities/stats`      | Facility statistics                |
| GET    | `/api/v1/resources/`            | List resources with filters        |
| GET    | `/api/v1/resources/{id}`        | Get resource details               |
| GET    | `/api/v1/resources/stats`       | Resource statistics                |
| POST   | `/api/v1/routes/calculate`      | Calculate safe route               |
| GET    | `/api/v1/status/health`         | System health check                |
| GET    | `/api/v1/status/system`         | Full system status                 |

### Example Query

```bash
curl -X POST http://localhost:8000/api/v1/query/ \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Show me operational hospitals near Beirut with available ICU beds",
    "language": "en",
    "include_map": true

  }'
```

**Response:**
```json
{
  "answer": "Found 5 operational hospitals near Beirut with available ICU capacity...",
  "confidence": 0.92,
  "query_type": "facility_search",
  "data_sources": ["health_facilities_db"],
  "map_markers": [...],
  "metadata": {
    "entities_extracted": {"location": "Beirut", "facility_type": "hospital"},
    "processing_time_ms": 340
  }
}
```

---

## Demo Scenarios

### Scenario 1: Hospital Capacity Check
> **Query:** "How many hospital beds are available in South Lebanon?"
>
> Demonstrates: Entity extraction (location: South Lebanon), facility search, capacity aggregation

### Scenario 2: Emergency Resource Location
> **Query:** "Where are the nearest ambulances to Tyre?"
>
> Demonstrates: Resource search with distance calculation, map markers

### Scenario 3: Safe Route Planning
> **Query:** "Find a safe route from Beirut to Sidon avoiding conflict zones"
>
> Demonstrates: Route calculation with incident avoidance, waypoint generation

### Scenario 4: Crisis Statistics
> **Query:** "Give me a summary of the health situation in Bekaa Valley"
>
> Demonstrates: Statistics aggregation, multi-metric response (facilities, resources, incidents)

### Scenario 5: Supply Chain Tracking
> **Query:** "What medical supplies are running low across all regions?"
>
> Demonstrates: Resource filtering by status, cross-regional aggregation

### Demo Credentials
```
Admin:     admin@situation-room.lb / admin123
Official:  health@situation-room.lb / health123
Responder: responder@situation-room.lb / responder123
```

---

## Ethics & Data Privacy

### Data Ethics
- All data in this prototype is **synthetic** — no real patient or facility data is used
- Facility names and locations are based on publicly available information
- The system is designed with privacy-by-design principles

### Responsible AI
- Confidence scores accompany every AI-generated response
- Data sources are transparently cited in every answer
- The system clearly indicates when it cannot answer a query
- Fallback mechanisms ensure service without LLM dependency

### Access Control
- Role-based access (admin, health_official, emergency_responder, viewer)
- JWT authentication with token expiry
- Rate limiting to prevent abuse (100 req/min authenticated, 10 req/min unauthenticated)

### Crisis-Specific Considerations
- Emergency mode for low-bandwidth scenarios
- Offline-first mobile design for field workers
- Arabic language support for local stakeholders
- No personally identifiable health information is stored or transmitted

---

## Project Structure

```
IEEEngineers_hackathon/
├── backend/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py              # FastAPI application entry point
│   │   ├── config.py            # Settings & environment config
│   │   ├── database.py          # Async SQLAlchemy setup
│   │   ├── models.py            # Database models
│   │   ├── schemas.py           # Pydantic request/response schemas
│   │   ├── data_generator.py    # Synthetic Lebanon data generator
│   │   ├── seed_db.py           # Database seeder
│   │   ├── middleware/
│   │   │   └── rate_limiter.py  # Rate limiting middleware
│   │   ├── services/
│   │   │   ├── rag_pipeline.py  # Core RAG intelligence
│   │   │   └── auth_service.py  # JWT authentication
│   │   └── routers/
│   │       ├── auth.py          # Auth endpoints
│   │       ├── query.py         # NL query endpoint
│   │       ├── facilities.py    # Facility CRUD
│   │       ├── resources.py     # Resource CRUD
│   │       ├── routes.py        # Safe route calculation
│   │       └── status.py        # Health & system status
│   ├── tests/
│   │   └── test_main.py         # Unit tests
│   ├── Dockerfile
│   └── requirements.txt
├── mobile_app/
│   ├── lib/
│   │   ├── main.dart            # App entry point
│   │   ├── app.dart             # MaterialApp setup
│   │   ├── core/
│   │   │   ├── theme.dart       # Theme system (light/dark/emergency)
│   │   │   └── constants.dart   # API config & query suggestions
│   │   ├── models/
│   │   │   ├── query_result.dart # Query result models
│   │   │   └── facility.dart    # Facility model
│   │   ├── services/
│   │   │   └── api_service.dart # Dio HTTP client
│   │   ├── providers/
│   │   │   ├── auth_provider.dart    # Auth state management
│   │   │   └── query_provider.dart   # Query state management
│   │   └── screens/
│   │       ├── login_screen.dart
│   │       ├── home_screen.dart
│   │       ├── query_screen.dart
│   │       ├── map_screen.dart
│   │       ├── facilities_screen.dart
│   │       └── settings_screen.dart
│   └── pubspec.yaml
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md
```

---

## Team

**IEEEngineers** — AI4Purpose Hackathon 2024

---

## License

This project is built for the AI4Purpose Hackathon. All synthetic data is generated for demonstration purposes only.
