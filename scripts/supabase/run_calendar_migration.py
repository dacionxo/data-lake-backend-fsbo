"""
Execute Calendar Time Handling Migration

This script reads the migration SQL file and provides instructions
for applying it via Supabase Dashboard or CLI.
"""

import os
import sys

# Read the migration file
migration_file = os.path.join(os.path.dirname(__file__), 'migrations', 'calendar_time_handling.sql')

if not os.path.exists(migration_file):
    print(f"Error: Migration file not found at {migration_file}")
    sys.exit(1)

with open(migration_file, 'r', encoding='utf-8') as f:
    sql_content = f.read()

print("=" * 80)
print("Calendar Time Handling Migration")
print("=" * 80)
print("\nThis migration adds:")
print("  - event_timezone column for per-event timezone override")
print("  - start_date/end_date columns for all-day events")
print("  - recurrence_timezone column for DST-aware recurring events")
print("  - Updated constraints and helper functions")
print("\n" + "=" * 80)
print("\nTo apply this migration:")
print("\n1. SUPABASE DASHBOARD (Recommended):")
print("   - Go to https://supabase.com/dashboard")
print("   - Select your project")
print("   - Navigate to SQL Editor")
print("   - Create a new query")
print("   - Copy and paste the SQL below")
print("   - Click 'Run'")
print("\n2. SUPABASE CLI:")
print("   - Run: supabase db execute -f supabase/migrations/calendar_time_handling.sql")
print("\n" + "=" * 80)
print("\nSQL Migration Content:")
print("=" * 80)
print(sql_content)
print("=" * 80)

# Optionally, you could use psycopg2 to execute directly if credentials are available
# But for security, it's better to use the dashboard or CLI

