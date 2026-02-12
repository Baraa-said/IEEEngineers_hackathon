"""Pydantic schemas for request/response validation."""

from pydantic import BaseModel, Field, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime
from uuid import UUID
from enum import Enum


# --- Enums ---

class FacilityTypeEnum(str, Enum):
    HOSPITAL = "hospital"
    CLINIC = "clinic"
    PHARMACY = "pharmacy"
    FIELD_HOSPITAL = "field_hospital"
    HEALTH_CENTER = "health_center"


class FacilityStatusEnum(str, Enum):
    OPERATIONAL = "operational"
    REDUCED_CAPACITY = "reduced_capacity"
    DAMAGED = "damaged"
    OFFLINE = "offline"


class ResourceTypeEnum(str, Enum):
    AMBULANCE = "ambulance"
    MEDICAL_SUPPLY = "medical_supply"
    SHELTER = "shelter"
    DISTRIBUTION_POINT = "distribution_point"
    WATER_POINT = "water_point"


class UserRoleEnum(str, Enum):
    ADMIN = "admin"
    HEALTH_OFFICIAL = "health_official"
    EMERGENCY_RESPONDER = "emergency_responder"
    VIEWER = "viewer"


# --- Auth Schemas ---

class UserCreate(BaseModel):
    email: str
    password: str = Field(min_length=8)
    full_name: str
    role: UserRoleEnum = UserRoleEnum.VIEWER
    organization: Optional[str] = None


class UserResponse(BaseModel):
    id: UUID
    email: str
    full_name: str
    role: UserRoleEnum
    organization: Optional[str]
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse


class LoginRequest(BaseModel):
    email: str
    password: str


# --- Query Schemas ---

class QueryRequest(BaseModel):
    query: str = Field(..., min_length=3, max_length=1000, description="Natural language query")
    latitude: Optional[float] = Field(None, description="User's current latitude")
    longitude: Optional[float] = Field(None, description="User's current longitude")
    language: str = Field("en", description="Response language (en/ar)")
    max_results: int = Field(10, ge=1, le=50)


class QuerySource(BaseModel):
    name: str
    freshness: str
    record_count: int


class MapMarker(BaseModel):
    latitude: float
    longitude: float
    label: str
    type: str
    status: Optional[str] = None
    details: Optional[Dict[str, Any]] = None


class QueryResponse(BaseModel):
    query_id: UUID
    query: str
    answer: str
    confidence_score: float = Field(ge=0.0, le=1.0)
    data_sources: List[QuerySource]
    map_markers: List[MapMarker] = []
    statistics: Optional[Dict[str, Any]] = None
    response_time_ms: int
    timestamp: datetime
    language: str


# --- Facility Schemas ---

class FacilityBase(BaseModel):
    name: str
    name_ar: Optional[str] = None
    facility_type: FacilityTypeEnum
    latitude: float
    longitude: float
    address: Optional[str] = None
    district: Optional[str] = None
    governorate: Optional[str] = None


class FacilityCreate(FacilityBase):
    status: FacilityStatusEnum = FacilityStatusEnum.OPERATIONAL
    total_beds: int = 0
    available_beds: int = 0
    icu_beds: int = 0
    icu_available: int = 0
    trauma_beds: int = 0
    trauma_available: int = 0
    has_power: bool = True
    has_generator: bool = False
    has_oxygen: bool = True
    has_water: bool = True
    specialties: List[str] = []
    emergency_department: bool = False
    phone: Optional[str] = None
    emergency_phone: Optional[str] = None


class FacilityResponse(FacilityBase):
    id: UUID
    status: FacilityStatusEnum
    total_beds: int
    available_beds: int
    icu_beds: int
    icu_available: int
    trauma_beds: int
    trauma_available: int
    has_power: bool
    has_generator: bool
    has_oxygen: bool
    has_water: bool
    specialties: List[str]
    emergency_department: bool
    ed_wait_time_minutes: Optional[int]
    total_staff: int
    available_staff: int
    doctors_on_duty: int
    nurses_on_duty: int
    phone: Optional[str]
    emergency_phone: Optional[str]
    last_status_update: datetime
    distance_km: Optional[float] = None  # Calculated field

    class Config:
        from_attributes = True


class FacilityFilter(BaseModel):
    facility_type: Optional[FacilityTypeEnum] = None
    status: Optional[FacilityStatusEnum] = None
    district: Optional[str] = None
    governorate: Optional[str] = None
    has_power: Optional[bool] = None
    has_oxygen: Optional[bool] = None
    has_emergency_department: Optional[bool] = None
    min_available_beds: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_km: Optional[float] = Field(None, description="Search radius in kilometers")
    specialties: Optional[List[str]] = None


# --- Resource Schemas ---

class ResourceResponse(BaseModel):
    id: UUID
    name: str
    resource_type: ResourceTypeEnum
    status: str
    latitude: float
    longitude: float
    address: Optional[str]
    district: Optional[str]
    total_capacity: Optional[int]
    current_occupancy: Optional[int]
    description: Optional[str]
    details: Optional[Dict[str, Any]]
    contact_name: Optional[str]
    contact_phone: Optional[str]
    last_status_update: datetime
    distance_km: Optional[float] = None

    class Config:
        from_attributes = True


class ResourceFilter(BaseModel):
    resource_type: Optional[ResourceTypeEnum] = None
    status: Optional[str] = None
    district: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_km: Optional[float] = None
    min_capacity: Optional[int] = None


# --- Route Schemas ---

class RouteRequest(BaseModel):
    origin_lat: float
    origin_lon: float
    destination_lat: float
    destination_lon: float
    avoid_incidents: bool = True


class RoutePoint(BaseModel):
    latitude: float
    longitude: float


class RouteResponse(BaseModel):
    origin: RoutePoint
    destination: RoutePoint
    distance_km: float
    estimated_time_minutes: int
    route_points: List[RoutePoint]
    incidents_on_route: List[Dict[str, Any]] = []
    alternative_routes: List[Dict[str, Any]] = []


# --- Status Schemas ---

class SystemStatus(BaseModel):
    status: str
    version: str
    uptime_seconds: float
    database_connected: bool
    vector_db_connected: bool
    cache_connected: bool
    data_freshness: Dict[str, str]
    total_facilities: int
    total_resources: int
    active_incidents: int


# --- Incident Schemas ---

class IncidentResponse(BaseModel):
    id: UUID
    title: str
    description: Optional[str]
    incident_type: str
    severity: str
    latitude: float
    longitude: float
    district: Optional[str]
    is_active: bool
    reported_at: datetime

    class Config:
        from_attributes = True
