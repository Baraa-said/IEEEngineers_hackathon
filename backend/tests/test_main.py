"""Tests for the Situation Room Agent backend."""

import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.services.rag_pipeline import classify_query, extract_entities


# ---- Unit Tests for RAG Pipeline ----

class TestQueryClassification:
    def test_facility_search(self):
        assert classify_query("Where is the nearest hospital?") == "geographic_search"

    def test_resource_search(self):
        assert classify_query("Find available ambulances") == "resource_search"

    def test_status_query(self):
        assert classify_query("What is the status of hospitals?") == "status_query"

    def test_geographic_search(self):
        assert classify_query("Show facilities within 10km") == "geographic_search"

    def test_statistical_query(self):
        assert classify_query("How many hospitals are operational?") == "statistical"


class TestEntityExtraction:
    def test_extract_distance(self):
        entities = extract_entities("Show hospitals within 5km")
        assert entities.get("radius_km") == 5.0

    def test_extract_capacity(self):
        entities = extract_entities("Shelters with capacity for 100 people")
        assert entities.get("min_capacity") == 100

    def test_extract_oxygen(self):
        entities = extract_entities("Facilities with oxygen supply")
        assert entities.get("needs_oxygen") is True

    def test_extract_trauma(self):
        entities = extract_entities("Hospital with trauma beds")
        assert entities.get("needs_trauma") is True
        assert entities.get("facility_type") == "hospital"

    def test_extract_district(self):
        entities = extract_entities("Hospitals in Beirut area")
        assert entities.get("district") == "Beirut"


# ---- API Integration Tests ----

@pytest.mark.asyncio
class TestAPIEndpoints:
    async def test_root(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/")
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "operational"

    async def test_health(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/health")
            assert response.status_code == 200

    async def test_query_validation(self):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # Too short query
            response = await client.post(
                "/api/v1/query",
                json={"query": "ab"},
            )
            assert response.status_code == 422


# ---- Data Generator Tests ----

class TestDataGenerator:
    def test_generate_all(self):
        from app.data_generator import generate_all_data
        data = generate_all_data()
        assert len(data["facilities"]) > 20
        assert len(data["resources"]) > 20
        assert len(data["incidents"]) > 5
        assert "metadata" in data

    def test_facilities_have_location(self):
        from app.data_generator import generate_all_data
        data = generate_all_data()
        for f in data["facilities"]:
            assert "latitude" in f
            assert "longitude" in f
            assert 33.0 < f["latitude"] < 35.0  # Lebanon latitude range
            assert 35.0 < f["longitude"] < 37.0  # Lebanon longitude range

    def test_facilities_have_status(self):
        from app.data_generator import generate_all_data
        data = generate_all_data()
        valid_statuses = {"operational", "reduced_capacity", "damaged", "offline"}
        for f in data["facilities"]:
            assert f["status"] in valid_statuses
