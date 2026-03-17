#!/usr/bin/env python3
"""Export database data into RAG-readable text files for the AI agent."""

import sqlite3
import json
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "situation_room.db")
RAG_DIR = os.path.join(os.path.dirname(__file__), "data", "rag")
os.makedirs(RAG_DIR, exist_ok=True)

conn = sqlite3.connect(DB_PATH)
conn.row_factory = sqlite3.Row
cur = conn.cursor()

# ---------- 1. Facilities ----------
cur.execute("SELECT * FROM health_facilities ORDER BY name")
facilities = [dict(r) for r in cur.fetchall()]
print(f"Facilities: {len(facilities)}")

lines = ["# Health Facilities in Palestine's West Bank\n"]
for f in facilities:
    lines.append(f"## {f['name']}")
    lines.append(f"- Type: {f.get('facility_type','N/A')}")
    lines.append(f"- Status: {f.get('status','N/A')}")
    lines.append(f"- District: {f.get('district','N/A')}, Governorate: {f.get('governorate','N/A')}")
    lines.append(f"- Coordinates: {f.get('latitude','N/A')}, {f.get('longitude','N/A')}")
    if f.get('total_beds'):
        lines.append(f"- Total beds: {f['total_beds']}, Available: {f.get('available_beds','N/A')}")
    if f.get('icu_beds'):
        lines.append(f"- ICU beds: {f['icu_beds']}, Available ICU: {f.get('icu_available','N/A')}")
    if f.get('trauma_beds') is not None:
        lines.append(f"- Trauma beds: {f['trauma_beds']}, Available: {f.get('trauma_available','N/A')}")
    if f.get('has_power') is not None:
        lines.append(f"- Power: {'Yes' if f['has_power'] else 'No'}")
    if f.get('has_generator') is not None:
        lines.append(f"- Generator: {'Yes' if f['has_generator'] else 'No'}")
    if f.get('has_oxygen') is not None:
        lines.append(f"- Oxygen: {'Yes' if f['has_oxygen'] else 'No'}")
    if f.get('oxygen_supply_hours'):
        lines.append(f"- Oxygen supply hours: {f['oxygen_supply_hours']}")
    if f.get('has_water') is not None:
        lines.append(f"- Water: {'Yes' if f['has_water'] else 'No'}")
    if f.get('ed_wait_time_minutes'):
        lines.append(f"- Emergency wait time: {f['ed_wait_time_minutes']} minutes")
    if f.get('specialties'):
        lines.append(f"- Specialties: {f['specialties']}")
    if f.get('phone'):
        lines.append(f"- Phone: {f['phone']}")
    if f.get('emergency_phone'):
        lines.append(f"- Emergency phone: {f['emergency_phone']}")
    if f.get('total_staff'):
        lines.append(f"- Total staff: {f['total_staff']}, Available: {f.get('available_staff','N/A')}")
    if f.get('doctors_on_duty'):
        lines.append(f"- Doctors on duty: {f['doctors_on_duty']}")
    if f.get('nurses_on_duty'):
        lines.append(f"- Nurses on duty: {f['nurses_on_duty']}")
    lines.append("")

with open(os.path.join(RAG_DIR, "facilities.md"), "w") as f:
    f.write("\n".join(lines))

# ---------- 2. Resources ----------
cur.execute("SELECT * FROM resources ORDER BY name")
resources = [dict(r) for r in cur.fetchall()]
print(f"Resources: {len(resources)}")

lines = ["# Emergency Resources in Palestine's West Bank\n"]
for r in resources:
    lines.append(f"## {r['name']}")
    lines.append(f"- Type: {r.get('resource_type','N/A')}")
    lines.append(f"- Status: {r.get('status','N/A')}")
    lines.append(f"- District: {r.get('district','N/A')}, Governorate: {r.get('governorate','N/A')}")
    lines.append(f"- Coordinates: {r.get('latitude','N/A')}, {r.get('longitude','N/A')}")
    if r.get('total_capacity'):
        lines.append(f"- Total capacity: {r['total_capacity']}, Current occupancy: {r.get('current_occupancy','N/A')}")
    if r.get('contact_phone'):
        lines.append(f"- Contact: {r['contact_phone']}")
    if r.get('details'):
        try:
            det = json.loads(r['details']) if isinstance(r['details'], str) else r['details']
            for k, v in det.items():
                lines.append(f"- {k}: {v}")
        except:
            pass
    lines.append("")

with open(os.path.join(RAG_DIR, "resources.md"), "w") as f:
    f.write("\n".join(lines))

# ---------- 3. Incidents ----------
cur.execute("SELECT * FROM incidents ORDER BY created_at DESC")
incidents = [dict(r) for r in cur.fetchall()]
print(f"Incidents: {len(incidents)}")

lines = ["# Active Incidents in Palestine's West Bank\n"]
for inc in incidents:
    lines.append(f"## {inc.get('title','Untitled Incident')}")
    lines.append(f"- Type: {inc.get('incident_type','N/A')}")
    lines.append(f"- Severity: {inc.get('severity','N/A')}")
    lines.append(f"- District: {inc.get('district','N/A')}, Governorate: {inc.get('governorate','N/A')}")
    lines.append(f"- Coordinates: {inc.get('latitude','N/A')}, {inc.get('longitude','N/A')}")
    if inc.get('description'):
        lines.append(f"- Description: {inc['description']}")
    if inc.get('roads_affected'):
        lines.append(f"- Roads affected: {inc['roads_affected']}")
    if inc.get('facilities_affected'):
        lines.append(f"- Facilities affected: {inc['facilities_affected']}")
    if inc.get('estimated_affected_people'):
        lines.append(f"- Estimated affected people: {inc['estimated_affected_people']}")
    if inc.get('is_active') is not None:
        lines.append(f"- Active: {'Yes' if inc['is_active'] else 'No'}")
    if inc.get('created_at'):
        lines.append(f"- Reported: {inc['created_at']}")
    lines.append("")

with open(os.path.join(RAG_DIR, "incidents.md"), "w") as f:
    f.write("\n".join(lines))

# ---------- 4. Summary / Statistics ----------
stats_lines = ["# West Bank Crisis Dashboard Summary\n"]

cur.execute("SELECT COUNT(*) as cnt FROM health_facilities")
total_fac = cur.fetchone()['cnt']
cur.execute("SELECT COUNT(*) as cnt FROM health_facilities WHERE status='operational'")
op_fac = cur.fetchone()['cnt']
cur.execute("SELECT SUM(total_beds) as s, SUM(available_beds) as a FROM health_facilities")
bed_row = dict(cur.fetchone())
cur.execute("SELECT SUM(icu_beds) as s, SUM(icu_available) as a FROM health_facilities")
icu_row = dict(cur.fetchone())

stats_lines.append(f"## Health Facilities Overview")
stats_lines.append(f"- Total facilities: {total_fac}")
stats_lines.append(f"- Operational: {op_fac}")
stats_lines.append(f"- Total beds: {bed_row['s'] or 0}, Available beds: {bed_row['a'] or 0}")
stats_lines.append(f"- Total ICU beds: {icu_row['s'] or 0}, Available ICU beds: {icu_row['a'] or 0}")
stats_lines.append("")

# Resources by type
cur.execute("SELECT resource_type, COUNT(*) as cnt, SUM(total_capacity) as cap, SUM(current_occupancy) as occ FROM resources GROUP BY resource_type")
stats_lines.append(f"## Resources Overview")
for row in cur.fetchall():
    row = dict(row)
    stats_lines.append(f"- {row['resource_type']}: {row['cnt']} units, capacity {row['cap'] or 'N/A'}, occupancy {row['occ'] or 'N/A'}")
stats_lines.append("")

# Incidents
cur.execute("SELECT severity, COUNT(*) as cnt FROM incidents WHERE is_active=1 GROUP BY severity")
stats_lines.append(f"## Active Incidents")
for row in cur.fetchall():
    row = dict(row)
    stats_lines.append(f"- {row['severity']}: {row['cnt']}")
stats_lines.append("")

# Facility types
cur.execute("SELECT facility_type, COUNT(*) as cnt FROM health_facilities GROUP BY facility_type")
stats_lines.append(f"## Facilities by Type")
for row in cur.fetchall():
    row = dict(row)
    stats_lines.append(f"- {row['facility_type']}: {row['cnt']}")
stats_lines.append("")

# Districts
cur.execute("SELECT DISTINCT governorate FROM health_facilities ORDER BY governorate")
govs = [dict(r)['governorate'] for r in cur.fetchall()]
stats_lines.append(f"## Governorates Covered")
for g in govs:
    stats_lines.append(f"- {g}")
stats_lines.append("")

with open(os.path.join(RAG_DIR, "statistics.md"), "w") as f:
    f.write("\n".join(stats_lines))

conn.close()
print(f"\nRAG files written to {RAG_DIR}/")
print("Files: facilities.md, resources.md, incidents.md, statistics.md")
