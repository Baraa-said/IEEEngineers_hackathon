"""SQLAlchemy database models for the Situation Room Agent."""

import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Float, Integer, Boolean, DateTime, Text,
    ForeignKey, Enum as SQLEnum, JSON
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.database import Base
import enum


# --- Enums ---

class FacilityType(str, enum.Enum):
    HOSPITAL = "hospital"
    CLINIC = "clinic"
    PHARMACY = "pharmacy"
    FIELD_HOSPITAL = "field_hospital"
    HEALTH_CENTER = "health_center"


class FacilityStatus(str, enum.Enum):
    OPERATIONAL = "operational"
    REDUCED_CAPACITY = "reduced_capacity"
    DAMAGED = "damaged"
    OFFLINE = "offline"


class ResourceType(str, enum.Enum):
    AMBULANCE = "ambulance"
    MEDICAL_SUPPLY = "medical_supply"
    SHELTER = "shelter"
    DISTRIBUTION_POINT = "distribution_point"
    WATER_POINT = "water_point"


class ResourceStatus(str, enum.Enum):
    AVAILABLE = "available"
    IN_USE = "in_use"
    DEPLETED = "depleted"
    MAINTENANCE = "maintenance"


class IncidentSeverity(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class UserRole(str, enum.Enum):
    ADMIN = "admin"
    HEALTH_OFFICIAL = "health_official"
    EMERGENCY_RESPONDER = "emergency_responder"
    VIEWER = "viewer"


# --- Models ---

class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255), nullable=False)
    role = Column(SQLEnum(UserRole), default=UserRole.VIEWER, nullable=False)
    organization = Column(String(255))
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    queries = relationship("QueryLog", back_populates="user")


class HealthFacility(Base):
    __tablename__ = "health_facilities"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False, index=True)
    name_ar = Column(String(255))  # Arabic name
    facility_type = Column(SQLEnum(FacilityType), nullable=False, index=True)
    status = Column(SQLEnum(FacilityStatus), default=FacilityStatus.OPERATIONAL, index=True)

    # Location
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(Text)
    district = Column(String(100), index=True)
    governorate = Column(String(100), index=True)

    # Capacity
    total_beds = Column(Integer, default=0)
    available_beds = Column(Integer, default=0)
    icu_beds = Column(Integer, default=0)
    icu_available = Column(Integer, default=0)
    trauma_beds = Column(Integer, default=0)
    trauma_available = Column(Integer, default=0)

    # Equipment & Infrastructure
    has_power = Column(Boolean, default=True)
    has_generator = Column(Boolean, default=False)
    has_oxygen = Column(Boolean, default=True)
    has_water = Column(Boolean, default=True)
    oxygen_supply_hours = Column(Integer)

    # Services
    specialties = Column(JSON, default=list)  # List of specialties
    emergency_department = Column(Boolean, default=False)
    ed_wait_time_minutes = Column(Integer)  # Current ED wait time

    # Staff
    total_staff = Column(Integer, default=0)
    available_staff = Column(Integer, default=0)
    doctors_on_duty = Column(Integer, default=0)
    nurses_on_duty = Column(Integer, default=0)

    # Contact
    phone = Column(String(50))
    emergency_phone = Column(String(50))

    # Metadata
    last_status_update = Column(DateTime, default=datetime.utcnow)
    data_source = Column(String(100))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Resource(Base):
    __tablename__ = "resources"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    resource_type = Column(SQLEnum(ResourceType), nullable=False, index=True)
    status = Column(SQLEnum(ResourceStatus), default=ResourceStatus.AVAILABLE, index=True)

    # Location
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    address = Column(Text)
    district = Column(String(100), index=True)

    # Capacity (for shelters)
    total_capacity = Column(Integer)
    current_occupancy = Column(Integer, default=0)

    # Details
    description = Column(Text)
    details = Column(JSON, default=dict)  # Flexible details field

    # Contact
    contact_name = Column(String(255))
    contact_phone = Column(String(50))

    # Metadata
    last_status_update = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Incident(Base):
    __tablename__ = "incidents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(500), nullable=False)
    description = Column(Text)
    incident_type = Column(String(100), nullable=False, index=True)
    severity = Column(SQLEnum(IncidentSeverity), default=IncidentSeverity.MEDIUM, index=True)

    # Location
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    district = Column(String(100), index=True)
    affected_area_radius_km = Column(Float)

    # Status
    is_active = Column(Boolean, default=True, index=True)
    resolved_at = Column(DateTime)

    # Impact
    roads_affected = Column(JSON, default=list)
    facilities_affected = Column(JSON, default=list)

    # Metadata
    reported_by = Column(String(255))
    reported_at = Column(DateTime, default=datetime.utcnow)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class QueryLog(Base):
    __tablename__ = "query_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    query_text = Column(Text, nullable=False)
    query_type = Column(String(50))  # geographic, facility, resource, routing, statistical
    intent = Column(String(100))
    entities = Column(JSON, default=dict)

    # Response
    response_text = Column(Text)
    response_data = Column(JSON)
    confidence_score = Column(Float)
    data_sources = Column(JSON, default=list)
    response_time_ms = Column(Integer)

    # Metadata
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="queries")
