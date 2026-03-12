# Data Lake Schema Files

This directory contains independent schema files for the NextDeal Data Lake system. These schemas are **independent** from `complete_schema.sql` and can be installed separately.

## Schema Files

### 1. `data_lake_ingestion_schema.sql` 
**Install first** - No dependencies except Supabase built-ins.

Creates:
- Pipeline tracking tables (`pipelines`, `pipeline_runs`, `pipeline_run_events`)
- Functions for pipeline run management
- RLS policies

### 2. `data_lake_zones_schema.sql`
**Install second** - Depends on ingestion schema.

Creates:
- RAW zone tables (`raw_redfin_responses`, `raw_csv_imports`, `raw_apollo_imports`)
- STAGING zone tables (`fsbo_raw`, `import_staging`)
- Zone transition tracking (`zone_transitions`)
- RLS policies

### 3. `complete_schema.sql`
**Optional** - Main application schema (may be out of date).

Contains:
- User tables
- Listings tables
- CRM tables
- Other application-specific tables

**Note:** The zone and ingestion schemas work independently of this file.

## Installation

See [INSTALLATION_ORDER.md](./INSTALLATION_ORDER.md) for detailed installation instructions.

## Quick Install

```sql
-- In Supabase SQL Editor, run in order:

-- 1. Ingestion schema (no dependencies)
\i data_lake_ingestion_schema.sql

-- 2. Zones schema (depends on ingestion)
\i data_lake_zones_schema.sql
```

## Schema Independence

✅ **Independent from `complete_schema.sql`**
- Can be installed on fresh Supabase projects
- Only require Supabase built-in `auth.users` table
- Gracefully handle missing `users` table in RLS policies

✅ **Zone schema depends on ingestion schema**
- This is by design - zones reference pipeline runs for data lineage
- Clear error message if ingestion schema isn't installed first

✅ **No circular dependencies**
- Ingestion → Zones (one-way dependency)
- No dependencies on application tables


