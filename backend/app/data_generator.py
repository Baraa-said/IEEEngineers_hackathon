"""
Synthetic Data Generator for Palestine West Bank Health Crisis Situation Room

Generates realistic sample data based on:
- Actual facility locations from Palestinian Ministry of Health registries
- Simulated operational status reflecting realistic scenarios
  (40% facilities damaged in areas near separation wall/checkpoints,
   30% at reduced capacity, 30% fully operational)
- Incident patterns reflecting checkpoint closures, settler violence,
  military operations, and infrastructure damage
"""

import random
import uuid
import json
from datetime import datetime, timedelta


# ---- Palestine West Bank Geographic Data ----

GOVERNORATES = {
    "Ramallah and Al-Bireh": {"center": (31.9038, 35.2034), "districts": ["Ramallah", "Al-Bireh", "Birzeit", "Beit Rima", "Silwad", "Deir Dibwan", "Bani Zeid"]},
    "Nablus": {"center": (32.2211, 35.2544), "districts": ["Nablus City", "Balata", "Huwwara", "Beit Furik", "Asira", "Tell", "Aqraba"]},
    "Hebron": {"center": (31.5326, 35.0998), "districts": ["Hebron City", "Dura", "Yatta", "Halhul", "Beit Ummar", "Sa'ir", "Taffouh"]},
    "Bethlehem": {"center": (31.7054, 35.2024), "districts": ["Bethlehem City", "Beit Jala", "Beit Sahour", "Al-Khader", "Tuqu'", "Za'tara"]},
    "Jenin": {"center": (32.4610, 35.2998), "districts": ["Jenin City", "Jenin Camp", "Qabatiya", "Arraba", "Ya'bad", "Burqin"]},
    "Tulkarm": {"center": (32.3104, 35.0286), "districts": ["Tulkarm City", "Tulkarm Camp", "Anabta", "Bal'a", "Illar", "Deir al-Ghusun"]},
    "Qalqilya": {"center": (32.1892, 34.9706), "districts": ["Qalqilya City", "Azzun", "Jayous", "Kafr Thulth", "Habla"]},
    "Salfit": {"center": (32.0833, 35.1833), "districts": ["Salfit City", "Deir Istiya", "Kafr ad-Dik", "Bruqin", "Kifl Haris"]},
    "Tubas": {"center": (32.3208, 35.3694), "districts": ["Tubas City", "Tammun", "Tayasir", "Aqaba", "Bardala"]},
    "Jericho": {"center": (31.8667, 35.4500), "districts": ["Jericho City", "Al-Auja", "Aqabat Jabr Camp", "Ein al-Sultan Camp"]},
    "Jerusalem": {"center": (31.7683, 35.2137), "districts": ["Old City", "Shu'fat", "Al-Ram", "Abu Dis", "Al-Eizariya", "Anata", "Qalandiya"]},
}

# Real hospital data based on actual West Bank facilities
HOSPITAL_NAMES = [
    # Ramallah
    {"name": "Palestine Medical Complex", "name_ar": "مجمع فلسطين الطبي", "gov": "Ramallah and Al-Bireh", "lat": 31.9060, "lon": 35.2030, "type": "hospital", "beds": 256},
    {"name": "Al-Istishari Arab Hospital", "name_ar": "المستشفى الاستشاري العربي", "gov": "Ramallah and Al-Bireh", "lat": 31.9120, "lon": 35.2100, "type": "hospital", "beds": 120},
    {"name": "Red Crescent Hospital Ramallah", "name_ar": "مستشفى الهلال الأحمر رام الله", "gov": "Ramallah and Al-Bireh", "lat": 31.8990, "lon": 35.2050, "type": "hospital", "beds": 70},
    # Nablus
    {"name": "Rafidia Surgical Hospital", "name_ar": "مستشفى رفيديا الجراحي", "gov": "Nablus", "lat": 32.2280, "lon": 35.2410, "type": "hospital", "beds": 179},
    {"name": "Al-Watani Hospital Nablus", "name_ar": "المستشفى الوطني نابلس", "gov": "Nablus", "lat": 32.2220, "lon": 35.2600, "type": "hospital", "beds": 100},
    {"name": "Al-Najah National University Hospital", "name_ar": "مستشفى جامعة النجاح الوطنية", "gov": "Nablus", "lat": 32.2300, "lon": 35.2500, "type": "hospital", "beds": 120},
    # Hebron
    {"name": "Alia Governmental Hospital", "name_ar": "مستشفى عالية الحكومي", "gov": "Hebron", "lat": 31.5350, "lon": 35.0950, "type": "hospital", "beds": 200},
    {"name": "Al-Ahli Hospital Hebron", "name_ar": "مستشفى الأهلي الخليل", "gov": "Hebron", "lat": 31.5300, "lon": 35.1050, "type": "hospital", "beds": 150},
    {"name": "Abu Al-Hasan Al-Qasim Hospital", "name_ar": "مستشفى أبو الحسن القاسم", "gov": "Hebron", "lat": 31.4200, "lon": 35.0800, "type": "hospital", "beds": 80},
    # Bethlehem
    {"name": "Al-Hussein Hospital Beit Jala", "name_ar": "مستشفى الحسين بيت جالا", "gov": "Bethlehem", "lat": 31.7150, "lon": 35.1900, "type": "hospital", "beds": 168},
    {"name": "Holy Family Hospital", "name_ar": "مستشفى العائلة المقدسة", "gov": "Bethlehem", "lat": 31.7040, "lon": 35.2000, "type": "hospital", "beds": 80},
    {"name": "Caritas Baby Hospital", "name_ar": "مستشفى كاريتاس للأطفال", "gov": "Bethlehem", "lat": 31.7100, "lon": 35.1950, "type": "hospital", "beds": 82},
    # Jenin
    {"name": "Khalil Suleiman Hospital Jenin", "name_ar": "مستشفى خليل سليمان جنين", "gov": "Jenin", "lat": 32.4620, "lon": 35.2970, "type": "hospital", "beds": 110},
    {"name": "Al-Razi Hospital Jenin", "name_ar": "مستشفى الرازي جنين", "gov": "Jenin", "lat": 32.4600, "lon": 35.3020, "type": "hospital", "beds": 60},
    # Tulkarm
    {"name": "Thabet Thabet Hospital", "name_ar": "مستشفى ثابت ثابت", "gov": "Tulkarm", "lat": 32.3110, "lon": 35.0280, "type": "hospital", "beds": 134},
    # Qalqilya
    {"name": "Darwish Nazzal Hospital", "name_ar": "مستشفى درويش نزال", "gov": "Qalqilya", "lat": 32.1900, "lon": 34.9700, "type": "hospital", "beds": 62},
    # Salfit
    {"name": "Yasser Arafat Hospital Salfit", "name_ar": "مستشفى ياسر عرفات سلفيت", "gov": "Salfit", "lat": 32.0840, "lon": 35.1840, "type": "hospital", "beds": 50},
    # Tubas
    {"name": "Tubas Turkish Hospital", "name_ar": "مستشفى طوباس التركي", "gov": "Tubas", "lat": 32.3210, "lon": 35.3700, "type": "hospital", "beds": 50},
    # Jericho
    {"name": "Jericho Governmental Hospital", "name_ar": "مستشفى أريحا الحكومي", "gov": "Jericho", "lat": 31.8670, "lon": 35.4490, "type": "hospital", "beds": 54},
    # Jerusalem
    {"name": "Augusta Victoria Hospital", "name_ar": "مستشفى المطلع (أوغستا فكتوريا)", "gov": "Jerusalem", "lat": 31.7800, "lon": 35.2450, "type": "hospital", "beds": 100},
    {"name": "Al-Makassed Islamic Charitable Hospital", "name_ar": "مستشفى المقاصد الخيرية الإسلامية", "gov": "Jerusalem", "lat": 31.7700, "lon": 35.2400, "type": "hospital", "beds": 250},
    {"name": "St. Joseph Hospital Jerusalem", "name_ar": "مستشفى سانت جوزيف القدس", "gov": "Jerusalem", "lat": 31.7850, "lon": 35.2300, "type": "hospital", "beds": 100},
]

CLINIC_NAMES = [
    "Primary Health Care Center", "Community Health Clinic", "Family Medicine Center",
    "Medical Dispensary", "Maternal Health Center", "Pediatric Clinic",
    "Emergency Care Point", "Mobile Health Unit", "UN Health Post",
]

SPECIALTIES = [
    "Emergency Medicine", "Trauma Surgery", "Internal Medicine", "Pediatrics",
    "Obstetrics & Gynecology", "Cardiology", "Orthopedics", "Neurology",
    "Radiology", "Anesthesiology", "General Surgery", "ICU",
]

SHELTER_NAMES = [
    "Municipal Shelter", "School Shelter", "Community Center", "Sports Hall",
    "UNRWA Center", "Red Crescent Shelter", "Mosque Community Space",
    "Church Hall", "Public Park Tent Camp", "University Hall",
]

INCIDENT_TYPES = [
    "road_closure", "checkpoint_closure", "structural_damage", "power_outage",
    "water_disruption", "security_incident", "medical_emergency",
    "settler_violence", "building_demolition", "communication_outage",
]


def jitter(center_lat, center_lon, spread=0.05):
    """Add random geographic jitter around a center point."""
    return (
        center_lat + random.uniform(-spread, spread),
        center_lon + random.uniform(-spread, spread),
    )


def generate_facilities():
    """Generate health facility data."""
    facilities = []

    # Add known hospitals
    for h in HOSPITAL_NAMES:
        gov_data = GOVERNORATES[h["gov"]]
        districts = gov_data["districts"]
        status_roll = random.random()
        # Higher damage near separation wall and military zones
        if h["gov"] in ("Jenin", "Tulkarm", "Qalqilya", "Hebron", "Jerusalem"):
            if status_roll < 0.4:
                status = "damaged"
            elif status_roll < 0.8:
                status = "reduced_capacity"
            else:
                status = "operational"
        else:
            if status_roll < 0.15:
                status = "damaged"
            elif status_roll < 0.45:
                status = "reduced_capacity"
            else:
                status = "operational"

        bed_factor = {"operational": 0.6, "reduced_capacity": 0.3, "damaged": 0.05, "offline": 0}[status]
        total_beds = h["beds"]
        available_beds = int(total_beds * bed_factor * random.uniform(0.5, 1.0))
        icu_beds = int(total_beds * 0.1)
        trauma_beds = int(total_beds * 0.08)

        has_power = status != "damaged" or random.random() > 0.5
        has_oxygen = status == "operational" or (status == "reduced_capacity" and random.random() > 0.3)

        num_specialties = random.randint(3, 8) if status != "damaged" else random.randint(1, 3)
        specialties = random.sample(SPECIALTIES, min(num_specialties, len(SPECIALTIES)))

        facilities.append({
            "id": str(uuid.uuid4()),
            "name": h["name"],
            "name_ar": h["name_ar"],
            "facility_type": "hospital",
            "status": status,
            "latitude": h["lat"],
            "longitude": h["lon"],
            "address": f"{random.choice(districts)}, {h['gov']}, Palestine",
            "district": random.choice(districts),
            "governorate": h["gov"],
            "total_beds": total_beds,
            "available_beds": available_beds,
            "icu_beds": icu_beds,
            "icu_available": int(icu_beds * bed_factor * random.uniform(0.3, 0.8)),
            "trauma_beds": trauma_beds,
            "trauma_available": int(trauma_beds * bed_factor * random.uniform(0.2, 0.7)),
            "has_power": has_power,
            "has_generator": random.random() > 0.3,
            "has_oxygen": has_oxygen,
            "has_water": status != "damaged" or random.random() > 0.3,
            "oxygen_supply_hours": random.randint(4, 72) if has_oxygen else 0,
            "specialties": specialties,
            "emergency_department": True,
            "ed_wait_time_minutes": random.choice([15, 30, 45, 60, 90, 120]) if status == "operational" else None,
            "total_staff": random.randint(50, 500),
            "available_staff": random.randint(20, 200),
            "doctors_on_duty": random.randint(5, 40),
            "nurses_on_duty": random.randint(10, 80),
            "phone": f"+970 {random.choice(['2','4','9'])} {random.randint(2000000,2999999)}",
            "emergency_phone": f"+970 {random.choice(['2','4','9'])} {random.randint(2000000,2999999)}",
            "last_status_update": (datetime.utcnow() - timedelta(minutes=random.randint(5, 120))).isoformat(),
            "data_source": "MOH_Palestine_registry",
        })

    # Generate clinics and health centers
    for gov_name, gov_data in GOVERNORATES.items():
        num_clinics = random.randint(5, 12)
        for i in range(num_clinics):
            lat, lon = jitter(*gov_data["center"], spread=0.08)
            district = random.choice(gov_data["districts"])
            clinic_type = random.choice(["clinic", "health_center", "pharmacy"])
            status_roll = random.random()

            if gov_name in ("Jenin", "Tulkarm", "Qalqilya", "Hebron", "Jerusalem"):
                if status_roll < 0.35:
                    status = "damaged"
                elif status_roll < 0.7:
                    status = "reduced_capacity"
                else:
                    status = "operational"
            else:
                if status_roll < 0.1:
                    status = "offline"
                elif status_roll < 0.3:
                    status = "damaged"
                elif status_roll < 0.5:
                    status = "reduced_capacity"
                else:
                    status = "operational"

            beds = random.randint(5, 30) if clinic_type != "pharmacy" else 0

            facilities.append({
                "id": str(uuid.uuid4()),
                "name": f"{district} {random.choice(CLINIC_NAMES)} {i+1}",
                "name_ar": None,
                "facility_type": clinic_type,
                "status": status,
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "address": f"{district}, {gov_name}, Palestine",
                "district": district,
                "governorate": gov_name,
                "total_beds": beds,
                "available_beds": int(beds * 0.5) if status == "operational" else int(beds * 0.2),
                "icu_beds": 0,
                "icu_available": 0,
                "trauma_beds": 0,
                "trauma_available": 0,
                "has_power": status not in ("damaged", "offline"),
                "has_generator": random.random() > 0.6,
                "has_oxygen": clinic_type != "pharmacy" and random.random() > 0.4,
                "has_water": status not in ("offline",),
                "oxygen_supply_hours": random.randint(2, 24) if clinic_type != "pharmacy" else None,
                "specialties": random.sample(SPECIALTIES[:6], random.randint(1, 3)),
                "emergency_department": random.random() > 0.7,
                "ed_wait_time_minutes": random.choice([10, 20, 30, 45]) if status == "operational" else None,
                "total_staff": random.randint(5, 30),
                "available_staff": random.randint(2, 15),
                "doctors_on_duty": random.randint(1, 5),
                "nurses_on_duty": random.randint(2, 10),
                "phone": f"+970 {random.choice(['2','4','9'])} {random.randint(2000000,2999999)}",
                "emergency_phone": None,
                "last_status_update": (datetime.utcnow() - timedelta(minutes=random.randint(10, 360))).isoformat(),
                "data_source": "field_report",
            })

    return facilities


def generate_resources():
    """Generate resource data (shelters, ambulances, supplies, etc.)."""
    resources = []

    # Shelters
    for gov_name, gov_data in GOVERNORATES.items():
        num_shelters = random.randint(3, 8)
        for i in range(num_shelters):
            lat, lon = jitter(*gov_data["center"], spread=0.06)
            district = random.choice(gov_data["districts"])
            capacity = random.choice([50, 100, 150, 200, 300, 500])
            occupancy = int(capacity * random.uniform(0.2, 0.95))

            resources.append({
                "id": str(uuid.uuid4()),
                "name": f"{district} {random.choice(SHELTER_NAMES)}",
                "resource_type": "shelter",
                "status": "available" if occupancy < capacity * 0.9 else "in_use",
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "address": f"{district}, {gov_name}",
                "district": district,
                "total_capacity": capacity,
                "current_occupancy": occupancy,
                "description": f"Shelter facility in {district} with basic amenities",
                "details": {
                    "has_water": random.random() > 0.2,
                    "has_food": random.random() > 0.3,
                    "has_medical": random.random() > 0.5,
                    "has_electricity": random.random() > 0.4,
                    "accessibility": random.choice(["full", "partial", "limited"]),
                },
                "contact_name": f"Coordinator {district}",
                "contact_phone": f"+970 59 {random.randint(1000000,9999999)}",
                "last_status_update": (datetime.utcnow() - timedelta(minutes=random.randint(30, 240))).isoformat(),
            })

    # Ambulances
    for gov_name, gov_data in GOVERNORATES.items():
        num_ambulances = random.randint(3, 10)
        for i in range(num_ambulances):
            lat, lon = jitter(*gov_data["center"], spread=0.04)
            status = random.choice(["available", "in_use", "in_use", "maintenance"])
            resources.append({
                "id": str(uuid.uuid4()),
                "name": f"Ambulance {gov_name[:3].upper()}-{i+1:03d}",
                "resource_type": "ambulance",
                "status": status,
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "address": f"{gov_name}, Palestine",
                "district": random.choice(gov_data["districts"]),
                "total_capacity": None,
                "current_occupancy": None,
                "description": f"Emergency ambulance unit serving {gov_name}",
                "details": {
                    "vehicle_type": random.choice(["BLS", "ALS", "MICU"]),
                    "crew_size": random.randint(2, 4),
                    "equipment": random.sample(["defibrillator", "ventilator", "oxygen", "IV", "stretcher"], 3),
                },
                "contact_name": f"Dispatch {gov_name}",
                "contact_phone": f"+970 59 {random.randint(1000000,9999999)}",
                "last_status_update": (datetime.utcnow() - timedelta(minutes=random.randint(1, 30))).isoformat(),
            })

    # Medical supply distribution points
    for gov_name, gov_data in GOVERNORATES.items():
        num_points = random.randint(2, 5)
        for i in range(num_points):
            lat, lon = jitter(*gov_data["center"], spread=0.05)
            resources.append({
                "id": str(uuid.uuid4()),
                "name": f"{random.choice(gov_data['districts'])} Distribution Point",
                "resource_type": "distribution_point",
                "status": random.choice(["available", "available", "depleted"]),
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "address": f"{random.choice(gov_data['districts'])}, {gov_name}",
                "district": random.choice(gov_data["districts"]),
                "total_capacity": None,
                "current_occupancy": None,
                "description": "Medical supply and essential goods distribution",
                "details": {
                    "supplies_available": random.sample([
                        "bandages", "antibiotics", "painkillers", "insulin",
                        "blood_products", "surgical_kits", "IV_fluids", "vaccines",
                    ], random.randint(2, 5)),
                    "operating_hours": "08:00-18:00",
                    "organization": random.choice(["Palestinian Red Crescent", "UNRWA", "WHO", "MSF", "UNICEF"]),
                },
                "contact_name": f"Supply Manager",
                "contact_phone": f"+970 59 {random.randint(1000000,9999999)}",
                "last_status_update": (datetime.utcnow() - timedelta(hours=random.randint(1, 12))).isoformat(),
            })

    # Water points
    for gov_name, gov_data in GOVERNORATES.items():
        num_water = random.randint(1, 4)
        for i in range(num_water):
            lat, lon = jitter(*gov_data["center"], spread=0.05)
            resources.append({
                "id": str(uuid.uuid4()),
                "name": f"{random.choice(gov_data['districts'])} Water Point",
                "resource_type": "water_point",
                "status": random.choice(["available", "available", "depleted"]),
                "latitude": round(lat, 6),
                "longitude": round(lon, 6),
                "address": f"{random.choice(gov_data['districts'])}, {gov_name}",
                "district": random.choice(gov_data["districts"]),
                "total_capacity": random.choice([5000, 10000, 20000]),
                "current_occupancy": None,
                "description": "Clean water distribution point",
                "details": {
                    "water_source": random.choice(["tanker", "well", "municipal", "NGO_supply"]),
                    "daily_capacity_liters": random.choice([5000, 10000, 20000]),
                },
                "contact_name": "Water Coordinator",
                "contact_phone": f"+970 59 {random.randint(1000000,9999999)}",
                "last_status_update": (datetime.utcnow() - timedelta(hours=random.randint(1, 24))).isoformat(),
            })

    return resources


def generate_incidents():
    """Generate active incident data."""
    incidents = []

    incident_templates = [
        {"title": "Checkpoint closure on Ramallah-Nablus road", "type": "checkpoint_closure", "sev": "high", "gov": "Ramallah and Al-Bireh", "roads": ["Ramallah-Nablus Road"]},
        {"title": "Power outage in Jenin refugee camp", "type": "power_outage", "sev": "medium", "gov": "Jenin", "roads": []},
        {"title": "Building demolition in Hebron old city", "type": "building_demolition", "sev": "critical", "gov": "Hebron", "roads": ["Shuhada Street", "Old City Road"]},
        {"title": "Water supply cut off in Tulkarm", "type": "water_disruption", "sev": "high", "gov": "Tulkarm", "roads": []},
        {"title": "Military checkpoint on Bethlehem-Jerusalem road", "type": "checkpoint_closure", "sev": "high", "gov": "Bethlehem", "roads": ["Bethlehem-Jerusalem Road", "Route 60"]},
        {"title": "Settler violence near Nablus villages", "type": "settler_violence", "sev": "critical", "gov": "Nablus", "roads": ["Huwara Road", "Route 60"]},
        {"title": "Unexploded ordnance found near Tubas", "type": "unexploded_ordnance", "sev": "critical", "gov": "Tubas", "roads": ["Jordan Valley Road"]},
        {"title": "Communication tower damaged in Salfit", "type": "communication_outage", "sev": "high", "gov": "Salfit", "roads": []},
        {"title": "Medical supply convoy blocked at Qalandiya", "type": "checkpoint_closure", "sev": "critical", "gov": "Jerusalem", "roads": ["Qalandiya Checkpoint Road"]},
        {"title": "Road closure near Qalqilya separation wall", "type": "road_closure", "sev": "high", "gov": "Qalqilya", "roads": ["Qalqilya-Nablus Road"]},
        {"title": "Military raid in Jenin camp", "type": "security_incident", "sev": "critical", "gov": "Jenin", "roads": ["Jenin Camp Road"]},
        {"title": "Agricultural land access blocked in Salfit", "type": "road_closure", "sev": "medium", "gov": "Salfit", "roads": ["Agricultural Road"]},
        {"title": "Ambulance access denied at Huwara checkpoint", "type": "checkpoint_closure", "sev": "critical", "gov": "Nablus", "roads": ["Huwara Checkpoint Road"]},
        {"title": "Structural damage from military operation in Tulkarm", "type": "structural_damage", "sev": "high", "gov": "Tulkarm", "roads": ["Tulkarm Camp Road"]},
        {"title": "Mass casualty event in Jericho area", "type": "medical_emergency", "sev": "high", "gov": "Jericho", "roads": []},
    ]

    for template in incident_templates:
        gov_data = GOVERNORATES[template["gov"]]
        lat, lon = jitter(*gov_data["center"], spread=0.03)

        incidents.append({
            "id": str(uuid.uuid4()),
            "title": template["title"],
            "description": f"Active incident: {template['title']}. Reported by field team. Response in progress.",
            "incident_type": template["type"],
            "severity": template["sev"],
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "district": random.choice(gov_data["districts"]),
            "affected_area_radius_km": random.uniform(0.5, 5.0),
            "is_active": random.random() > 0.2,  # 80% active
            "roads_affected": template["roads"],
            "facilities_affected": [],
            "reported_by": random.choice(["Field Team Alpha", "Palestinian Civil Defense", "PRCS", "Palestinian Red Crescent", "Municipal Authority", "UNRWA"]),
            "reported_at": (datetime.utcnow() - timedelta(hours=random.randint(1, 48))).isoformat(),
        })

    return incidents


def generate_all_data():
    """Generate all synthetic data and save to JSON files."""
    random.seed(42)  # For reproducibility

    facilities = generate_facilities()
    resources = generate_resources()
    incidents = generate_incidents()

    data = {
        "facilities": facilities,
        "resources": resources,
        "incidents": incidents,
        "metadata": {
            "generated_at": datetime.utcnow().isoformat(),
            "total_facilities": len(facilities),
            "total_resources": len(resources),
            "total_incidents": len(incidents),
            "data_version": "1.0",
            "context": "Palestine West Bank Crisis Response - Synthetic Data",
        },
    }

    return data


if __name__ == "__main__":
    import os

    data = generate_all_data()

    # Save to files
    output_dir = os.path.join(os.path.dirname(__file__), "..", "data", "sample")
    os.makedirs(output_dir, exist_ok=True)

    with open(os.path.join(output_dir, "all_data.json"), "w") as f:
        json.dump(data, f, indent=2, default=str)

    with open(os.path.join(output_dir, "facilities.json"), "w") as f:
        json.dump(data["facilities"], f, indent=2, default=str)

    with open(os.path.join(output_dir, "resources.json"), "w") as f:
        json.dump(data["resources"], f, indent=2, default=str)

    with open(os.path.join(output_dir, "incidents.json"), "w") as f:
        json.dump(data["incidents"], f, indent=2, default=str)

    print(f"✅ Generated {len(data['facilities'])} facilities")
    print(f"✅ Generated {len(data['resources'])} resources")
    print(f"✅ Generated {len(data['incidents'])} incidents")
    print(f"📁 Data saved to {output_dir}")
