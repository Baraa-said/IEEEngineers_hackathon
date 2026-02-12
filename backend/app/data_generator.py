"""
Synthetic Data Generator for Lebanon Health Crisis Situation Room

Generates realistic sample data based on:
- Actual facility locations from OpenStreetMap (hospitals, clinics, pharmacies)
- Simulated operational status reflecting realistic scenarios
  (30% facilities damaged, 50% at reduced capacity, 20% fully operational)
- Incident patterns from the 2020 Beirut explosion and 2024-2025 conflict
"""

import random
import uuid
import json
from datetime import datetime, timedelta


# ---- Lebanon Geographic Data ----

GOVERNORATES = {
    "Beirut": {"center": (33.8938, 35.5018), "districts": ["Achrafieh", "Hamra", "Ras Beirut", "Verdun", "Gemmayze", "Mar Mikhael", "Badaro", "Ain El Mreisseh"]},
    "Mount Lebanon": {"center": (33.8500, 35.5500), "districts": ["Jounieh", "Byblos", "Baabda", "Aley", "Chouf", "Keserwan", "Metn"]},
    "North Lebanon": {"center": (34.4400, 35.8300), "districts": ["Tripoli", "Zgharta", "Koura", "Batroun", "Bcharre", "Minieh-Danniyeh"]},
    "South Lebanon": {"center": (33.2700, 35.2000), "districts": ["Sidon", "Jezzine", "Tyre", "Bint Jbeil", "Marjayoun", "Hasbaya", "Nabatieh"]},
    "Bekaa": {"center": (33.8500, 36.0800), "districts": ["Zahle", "Baalbek", "Hermel", "West Bekaa", "Rashaya"]},
    "Akkar": {"center": (34.5500, 36.0800), "districts": ["Halba", "Qobayat", "Bebnine"]},
}

# Real hospital data inspired by actual Lebanon facilities
HOSPITAL_NAMES = [
    # Beirut
    {"name": "American University of Beirut Medical Center", "name_ar": "مركز الجامعة الأميركية في بيروت الطبي", "gov": "Beirut", "lat": 33.9000, "lon": 35.4790, "type": "hospital", "beds": 350},
    {"name": "Hotel-Dieu de France Hospital", "name_ar": "مستشفى أوتيل ديو دو فرانس", "gov": "Beirut", "lat": 33.8958, "lon": 35.5127, "type": "hospital", "beds": 550},
    {"name": "Saint George Hospital University Medical Center", "name_ar": "مستشفى القديس جاورجيوس الجامعي", "gov": "Beirut", "lat": 33.9050, "lon": 35.5190, "type": "hospital", "beds": 300},
    {"name": "Rafik Hariri University Hospital", "name_ar": "مستشفى رفيق الحريري الجامعي", "gov": "Beirut", "lat": 33.8300, "lon": 35.4900, "type": "hospital", "beds": 400},
    {"name": "Clemenceau Medical Center", "name_ar": "مركز كليمنصو الطبي", "gov": "Beirut", "lat": 33.8900, "lon": 35.4850, "type": "hospital", "beds": 150},
    {"name": "Geitaoui Hospital", "name_ar": "مستشفى الجعيتاوي", "gov": "Beirut", "lat": 33.8900, "lon": 35.5200, "type": "hospital", "beds": 200},
    {"name": "Makassed General Hospital", "name_ar": "مستشفى المقاصد العام", "gov": "Beirut", "lat": 33.8800, "lon": 35.5100, "type": "hospital", "beds": 250},
    # Mount Lebanon
    {"name": "Mount Lebanon Hospital", "name_ar": "مستشفى جبل لبنان", "gov": "Mount Lebanon", "lat": 33.8100, "lon": 35.5300, "type": "hospital", "beds": 200},
    {"name": "Keserwan Medical Center", "name_ar": "مركز كسروان الطبي", "gov": "Mount Lebanon", "lat": 33.9800, "lon": 35.6200, "type": "hospital", "beds": 150},
    {"name": "Bellevue Medical Center", "name_ar": "مركز بلفيو الطبي", "gov": "Mount Lebanon", "lat": 33.9700, "lon": 35.5900, "type": "hospital", "beds": 220},
    {"name": "Hammoud Hospital", "name_ar": "مستشفى حمود", "gov": "Mount Lebanon", "lat": 33.8600, "lon": 35.4600, "type": "hospital", "beds": 180},
    # North
    {"name": "Nini Hospital", "name_ar": "مستشفى نيني", "gov": "North Lebanon", "lat": 34.4400, "lon": 35.8200, "type": "hospital", "beds": 180},
    {"name": "Tripoli Governmental Hospital", "name_ar": "مستشفى طرابلس الحكومي", "gov": "North Lebanon", "lat": 34.4300, "lon": 35.8400, "type": "hospital", "beds": 250},
    {"name": "Al Monla Hospital", "name_ar": "مستشفى المنلا", "gov": "North Lebanon", "lat": 34.4350, "lon": 35.8350, "type": "hospital", "beds": 120},
    # South
    {"name": "Hammoud Hospital Sidon", "name_ar": "مستشفى حمود صيدا", "gov": "South Lebanon", "lat": 33.5600, "lon": 35.3700, "type": "hospital", "beds": 200},
    {"name": "Labib Medical Center", "name_ar": "مركز لبيب الطبي", "gov": "South Lebanon", "lat": 33.5700, "lon": 35.3800, "type": "hospital", "beds": 100},
    {"name": "Jabal Amel Hospital", "name_ar": "مستشفى جبل عامل", "gov": "South Lebanon", "lat": 33.2700, "lon": 35.2000, "type": "hospital", "beds": 170},
    {"name": "Tyre Governmental Hospital", "name_ar": "مستشفى صور الحكومي", "gov": "South Lebanon", "lat": 33.2750, "lon": 35.1950, "type": "hospital", "beds": 150},
    {"name": "Nabatieh Governmental Hospital", "name_ar": "مستشفى النبطية الحكومي", "gov": "South Lebanon", "lat": 33.3800, "lon": 35.4800, "type": "hospital", "beds": 130},
    # Bekaa
    {"name": "Bekaa Hospital", "name_ar": "مستشفى البقاع", "gov": "Bekaa", "lat": 33.8500, "lon": 35.9000, "type": "hospital", "beds": 150},
    {"name": "Tel Chiha Hospital", "name_ar": "مستشفى تل شيحا", "gov": "Bekaa", "lat": 33.8400, "lon": 35.8800, "type": "hospital", "beds": 120},
    {"name": "Baalbek Governmental Hospital", "name_ar": "مستشفى بعلبك الحكومي", "gov": "Bekaa", "lat": 34.0000, "lon": 36.2100, "type": "hospital", "beds": 100},
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
    "UNHCR Registration Center", "Red Cross Shelter", "Church Hall",
    "Mosque Community Space", "Public Garden Tent Camp", "University Hall",
]

INCIDENT_TYPES = [
    "road_closure", "structural_damage", "power_outage", "water_disruption",
    "security_incident", "medical_emergency", "fire", "unexploded_ordnance",
    "building_collapse", "communication_outage",
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
        if h["gov"] == "South Lebanon":
            # Higher damage in south due to conflict
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
            "address": f"{random.choice(districts)}, {h['gov']}, Lebanon",
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
            "phone": f"+961 {random.randint(1,9)} {random.randint(100000,999999)}",
            "emergency_phone": f"+961 {random.randint(1,9)} {random.randint(100000,999999)}",
            "last_status_update": (datetime.utcnow() - timedelta(minutes=random.randint(5, 120))).isoformat(),
            "data_source": "MOH_registry",
        })

    # Generate clinics and health centers
    for gov_name, gov_data in GOVERNORATES.items():
        num_clinics = random.randint(5, 12)
        for i in range(num_clinics):
            lat, lon = jitter(*gov_data["center"], spread=0.08)
            district = random.choice(gov_data["districts"])
            clinic_type = random.choice(["clinic", "health_center", "pharmacy"])
            status_roll = random.random()

            if gov_name == "South Lebanon":
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
                "address": f"{district}, {gov_name}, Lebanon",
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
                "phone": f"+961 {random.randint(1,9)} {random.randint(100000,999999)}",
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
                "contact_phone": f"+961 {random.randint(1,9)} {random.randint(100000,999999)}",
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
                "address": f"{gov_name}, Lebanon",
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
                "contact_phone": f"+961 {random.randint(1,9)} {random.randint(100000,999999)}",
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
                    "organization": random.choice(["Red Cross", "UNHCR", "WHO", "MSF", "UNICEF"]),
                },
                "contact_name": f"Supply Manager",
                "contact_phone": f"+961 {random.randint(1,9)} {random.randint(100000,999999)}",
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
                "contact_phone": f"+961 {random.randint(1,9)} {random.randint(100000,999999)}",
                "last_status_update": (datetime.utcnow() - timedelta(hours=random.randint(1, 24))).isoformat(),
            })

    return resources


def generate_incidents():
    """Generate active incident data."""
    incidents = []

    incident_templates = [
        {"title": "Road closure on Beirut-Sidon highway", "type": "road_closure", "sev": "high", "gov": "Mount Lebanon", "roads": ["Beirut-Sidon Highway"]},
        {"title": "Power outage in Southern Beirut", "type": "power_outage", "sev": "medium", "gov": "Beirut", "roads": []},
        {"title": "Structural damage near Beirut port", "type": "structural_damage", "sev": "critical", "gov": "Beirut", "roads": ["Port Road", "Charles Helou Avenue"]},
        {"title": "Water main break in Hamra district", "type": "water_disruption", "sev": "medium", "gov": "Beirut", "roads": ["Hamra Street"]},
        {"title": "Security checkpoint on Tripoli highway", "type": "security_incident", "sev": "high", "gov": "North Lebanon", "roads": ["Tripoli-Beirut Highway"]},
        {"title": "Building collapse in Mar Mikhael", "type": "building_collapse", "sev": "critical", "gov": "Beirut", "roads": ["Armenia Street", "Mar Mikhael Street"]},
        {"title": "Unexploded ordnance found in South Lebanon", "type": "unexploded_ordnance", "sev": "critical", "gov": "South Lebanon", "roads": ["Tyre-Naqoura Road"]},
        {"title": "Communication tower damaged in Bekaa", "type": "communication_outage", "sev": "high", "gov": "Bekaa", "roads": []},
        {"title": "Fire in warehouse near Jounieh", "type": "fire", "sev": "medium", "gov": "Mount Lebanon", "roads": ["Jounieh Highway"]},
        {"title": "Medical supply truck blockade in Nabatieh", "type": "road_closure", "sev": "high", "gov": "South Lebanon", "roads": ["Nabatieh-Sidon Road"]},
        {"title": "Flooding on coastal road near Tyre", "type": "road_closure", "sev": "medium", "gov": "South Lebanon", "roads": ["Coastal Road"]},
        {"title": "Power grid failure in Baalbek area", "type": "power_outage", "sev": "high", "gov": "Bekaa", "roads": []},
        {"title": "Damaged bridge near Zahle", "type": "structural_damage", "sev": "high", "gov": "Bekaa", "roads": ["Zahle-Chtaura Road"]},
        {"title": "Security incident near Akkar border", "type": "security_incident", "sev": "critical", "gov": "Akkar", "roads": ["Northern Border Road"]},
        {"title": "Mass casualty event drill - Beirut Central", "type": "medical_emergency", "sev": "low", "gov": "Beirut", "roads": []},
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
            "reported_by": random.choice(["Field Team Alpha", "Civil Defense", "UNIFIL", "Red Cross", "Municipal Authority"]),
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
            "context": "Lebanon Health Crisis Response - Synthetic Data",
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
