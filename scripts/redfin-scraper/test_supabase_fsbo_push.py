#!/usr/bin/env python3
"""
Test script: try one upsert to fsbo_leads and print the result to stdout.
Run from scripts/redfin-scraper with the same env as FSBO.py (set SUPABASE_SERVICE_ROLE_KEY
for RLS bypass). Use this to verify connection and see the exact error if push fails.

  cd scripts/redfin-scraper
  set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
  python test_supabase_fsbo_push.py
"""
import os
import sys

# Use service role key if set (same as supabase_client)
url = os.environ.get("SUPABASE_URL", "https://bqkucdaefpfkunceftye.supabase.co")
anon = os.environ.get("SUPABASE_KEY", "")
service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
key = service_key if service_key else anon

print("Supabase config:")
print(f"  SUPABASE_URL = {url[:50]}...")
print(f"  Using key: {'SERVICE_ROLE' if service_key else 'ANON'} (set SUPABASE_SERVICE_ROLE_KEY to bypass RLS)")
print()

try:
    from supabase import create_client
    client = create_client(url, key)
except Exception as e:
    print(f"ERROR creating client: {e}")
    sys.exit(1)

# Minimal payload that matches fsbo_leads (required: property_url, listing_id, etc.)
test_row = {
    "listing_id": "test_listing_999",
    "property_url": "https://www.redfin.com/test/Test-Address-00000/home/test_listing_999",
    "fsbo_source": "redfin_fsbo",
    "street": "Test St",
    "city": "Test City",
    "state": "TX",
    "zip_code": "00000",
    "status": "fsbo",
}

print("Attempting upsert into fsbo_leads (one test row)...")
try:
    r = client.table("fsbo_leads").upsert(test_row, on_conflict="property_url").execute()
    print("SUCCESS: upsert completed.")
    if hasattr(r, "data") and r.data:
        print(f"  Returned rows: {len(r.data)}")
    if hasattr(r, "error") and r.error:
        print(f"  Response error: {r.error}")
except Exception as e:
    print(f"FAILED: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

# Optional: count rows (works with service_role; anon may be restricted by RLS)
print()
print("Counting rows in fsbo_leads...")
try:
    count_r = client.table("fsbo_leads").select("property_url", count="exact").limit(1).execute()
    total = getattr(count_r, "count", None) or (len(count_r.data) if count_r.data else "?")
    print(f"  Total rows (count): {total}")
except Exception as e:
    print(f"  Count failed (RLS or schema): {e}")

print()
print("Done. If you saw SUCCESS, run FSBO.py with the same env to push 100 listings.")
