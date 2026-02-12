#!/usr/bin/env python3
"""
Load dummy data from dummy_data.json into the database via the API.
Edit dummy_data.json to add/modify your own data, then run:
    python load_dummy_data.py
"""

import json
import sys
import httpx
from pathlib import Path

API_URL = "http://localhost:8000"
DATA_FILE = Path(__file__).parent / "dummy_data.json"

def load():
    if not DATA_FILE.exists():
        print(f"❌ File not found: {DATA_FILE}")
        sys.exit(1)

    data = json.loads(DATA_FILE.read_text(encoding="utf-8"))
    headers = {"Content-Type": "application/json"}
    ok, fail = 0, 0

    with httpx.Client(base_url=API_URL, headers=headers, timeout=30) as c:
        # Facilities
        for item in data.get("facilities", []):
            try:
                r = c.post("/api/v1/facilities", json=item)
                r.raise_for_status()
                print(f"  ✅ Facility: {item['name']}")
                ok += 1
            except Exception as e:
                print(f"  ❌ Facility: {item['name']} — {e}")
                fail += 1

        # Resources
        for item in data.get("resources", []):
            try:
                r = c.post("/api/v1/resources", json=item)
                r.raise_for_status()
                print(f"  ✅ Resource: {item['name']}")
                ok += 1
            except Exception as e:
                print(f"  ❌ Resource: {item['name']} — {e}")
                fail += 1

        # Incidents
        for item in data.get("incidents", []):
            try:
                r = c.post("/api/v1/incidents", json=item)
                r.raise_for_status()
                print(f"  ✅ Incident: {item['title']}")
                ok += 1
            except Exception as e:
                print(f"  ❌ Incident: {item['title']} — {e}")
                fail += 1

    print(f"\n{'='*40}")
    print(f"✅ Loaded: {ok}  |  ❌ Failed: {fail}")


if __name__ == "__main__":
    print(f"📂 Loading data from: {DATA_FILE}")
    print(f"🌐 API: {API_URL}\n")
    load()
