"""
Database seeder — loads synthetic data into PostgreSQL.

Usage:
    python -m app.seed_db
"""

import asyncio
import json
import os
import uuid
from datetime import datetime

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

from app.config import settings
from app.database import Base
from app.models import (
    HealthFacility, Resource, Incident, User,
    FacilityType, FacilityStatus, ResourceType, ResourceStatus,
    IncidentSeverity, UserRole,
)
from app.services.auth_service import hash_password
from app.data_generator import generate_all_data


async def seed_database():
    """Seed the database with synthetic data."""
    engine = create_async_engine(settings.DATABASE_URL, echo=False)

    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
        print("✅ Database tables created")

    session_factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with session_factory() as session:
        # Create demo users
        demo_users = [
            User(
                email="admin@situationroom.ps",
                hashed_password=hash_password("admin123!"),
                full_name="Admin User",
                role=UserRole.ADMIN,
                organization="Palestinian Ministry of Health",
            ),
            User(
                email="responder@situationroom.ps",
                hashed_password=hash_password("responder123!"),
                full_name="Field Responder",
                role=UserRole.EMERGENCY_RESPONDER,
                organization="Palestinian Red Crescent",
            ),
            User(
                email="official@situationroom.ps",
                hashed_password=hash_password("official123!"),
                full_name="Health Official",
                role=UserRole.HEALTH_OFFICIAL,
                organization="WHO Palestine",
            ),
        ]
        for u in demo_users:
            session.add(u)
        await session.flush()
        print(f"✅ Created {len(demo_users)} demo users")

        # Generate synthetic data
        data = generate_all_data()

        # Seed facilities
        for f_data in data["facilities"]:
            facility = HealthFacility(
                id=f_data["id"],
                name=f_data["name"],
                name_ar=f_data.get("name_ar"),
                facility_type=FacilityType(f_data["facility_type"]),
                status=FacilityStatus(f_data["status"]),
                latitude=f_data["latitude"],
                longitude=f_data["longitude"],
                address=f_data.get("address"),
                district=f_data.get("district"),
                governorate=f_data.get("governorate"),
                total_beds=f_data.get("total_beds", 0),
                available_beds=f_data.get("available_beds", 0),
                icu_beds=f_data.get("icu_beds", 0),
                icu_available=f_data.get("icu_available", 0),
                trauma_beds=f_data.get("trauma_beds", 0),
                trauma_available=f_data.get("trauma_available", 0),
                has_power=f_data.get("has_power", True),
                has_generator=f_data.get("has_generator", False),
                has_oxygen=f_data.get("has_oxygen", True),
                has_water=f_data.get("has_water", True),
                oxygen_supply_hours=f_data.get("oxygen_supply_hours"),
                specialties=f_data.get("specialties", []),
                emergency_department=f_data.get("emergency_department", False),
                ed_wait_time_minutes=f_data.get("ed_wait_time_minutes"),
                total_staff=f_data.get("total_staff", 0),
                available_staff=f_data.get("available_staff", 0),
                doctors_on_duty=f_data.get("doctors_on_duty", 0),
                nurses_on_duty=f_data.get("nurses_on_duty", 0),
                phone=f_data.get("phone"),
                emergency_phone=f_data.get("emergency_phone"),
                last_status_update=datetime.fromisoformat(f_data["last_status_update"]) if f_data.get("last_status_update") else datetime.utcnow(),
                data_source=f_data.get("data_source"),
            )
            session.add(facility)
        print(f"✅ Seeded {len(data['facilities'])} facilities")

        # Seed resources
        for r_data in data["resources"]:
            resource = Resource(
                id=r_data["id"],
                name=r_data["name"],
                resource_type=ResourceType(r_data["resource_type"]),
                status=ResourceStatus(r_data["status"]),
                latitude=r_data["latitude"],
                longitude=r_data["longitude"],
                address=r_data.get("address"),
                district=r_data.get("district"),
                total_capacity=r_data.get("total_capacity"),
                current_occupancy=r_data.get("current_occupancy"),
                description=r_data.get("description"),
                details=r_data.get("details"),
                contact_name=r_data.get("contact_name"),
                contact_phone=r_data.get("contact_phone"),
                last_status_update=datetime.fromisoformat(r_data["last_status_update"]) if r_data.get("last_status_update") else datetime.utcnow(),
            )
            session.add(resource)
        print(f"✅ Seeded {len(data['resources'])} resources")

        # Seed incidents
        for i_data in data["incidents"]:
            incident = Incident(
                id=i_data["id"],
                title=i_data["title"],
                description=i_data.get("description"),
                incident_type=i_data["incident_type"],
                severity=IncidentSeverity(i_data["severity"]),
                latitude=i_data["latitude"],
                longitude=i_data["longitude"],
                district=i_data.get("district"),
                affected_area_radius_km=i_data.get("affected_area_radius_km"),
                is_active=i_data.get("is_active", True),
                roads_affected=i_data.get("roads_affected", []),
                facilities_affected=i_data.get("facilities_affected", []),
                reported_by=i_data.get("reported_by"),
                reported_at=datetime.fromisoformat(i_data["reported_at"]) if i_data.get("reported_at") else datetime.utcnow(),
            )
            session.add(incident)
        print(f"✅ Seeded {len(data['incidents'])} incidents")

        await session.commit()
        print("\n🎉 Database seeding complete!")
        print(f"   Demo login: admin@situationroom.ps / admin123!")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed_database())
