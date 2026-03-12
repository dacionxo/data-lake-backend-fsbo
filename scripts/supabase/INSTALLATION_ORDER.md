# Schema Installation Order

This document provides the correct installation order for all schema files to ensure dependencies are resolved properly.

## Installation Sequence

### 1. Core Extensions and Utilities
**Files:**
- None (extensions created inline in each schema file)

**Dependencies:** None  
**Notes:** Each schema file creates extensions as needed with `IF NOT EXISTS`.

---

### 2. Lookup Tables (Enums)
**Files:**
- `enum_lookup_tables_schema.sql`

**Dependencies:** None  
**Notes:** Creates lookup tables for enums. These are referenced by other tables but foreign keys are optional initially.

---

### 3. Address Normalization
**Files:**
- `address_normalization_schema.sql`

**Dependencies:** All lead tables (listings, fsbo_leads, etc.)  
**Notes:** Creates views that query existing tables. Safe to install after lead tables exist.

---

### 4. User ID Semantics Documentation
**Files:**
- `user_id_semantics_schema.sql`

**Dependencies:** All tables with user_id columns  
**Notes:** Documentation and helper functions. Safe to install anytime.

---

### 5. Soft Delete Support
**Files:**
- `soft_delete_schema.sql`

**Dependencies:** CRM tables (contacts, deals, tasks, lists, list_items)  
**Notes:** Adds `deleted_at` columns to existing tables. Must install after CRM tables exist.

---

### 6. Index Optimization
**Files:**
- `index_optimization_schema.sql`

**Dependencies:** All tables  
**Notes:** Creates indexes on existing tables. Safe to install after all tables exist.

---

### 7. Read-Optimized Views
**Files:**
- `read_optimized_views_schema.sql`
- `prospect_enrich_view.sql` (detailed implementation)

**Dependencies:** All tables, address normalization views  
**Notes:** Views depend on underlying tables and may reference address views.

---

### 8. Dashboard Aggregations
**Files:**
- `dashboard_aggregations_schema.sql`

**Dependencies:** All tables  
**Notes:** Materialized views require all source tables to exist. May take time to build.

---

### 9. Schema Versioning
**Files:**
- `schema_versioning_schema.sql`

**Dependencies:** None  
**Notes:** Can be installed at any time. Recommended to install early to track all migrations.

---

### 10. Feature Flags (if not already installed)
**Files:**
- `feature_flags_schema.sql`

**Dependencies:** None  
**Notes:** Standalone schema. Can be installed independently.

---

### 11. Data Lake Ingestion Metadata (if not already installed)
**Files:**
- `data_lake_ingestion_schema.sql`

**Dependencies:** None (conditional FKs)  
**Notes:** Standalone with conditional foreign keys.

---

### 12. Data Lake Zones (if not already installed)
**Files:**
- `data_lake_zones_schema.sql`

**Dependencies:** Optional - pipeline_runs table  
**Notes:** Standalone with conditional foreign keys.

---

### 13. Complete Schema (Main Schema)
**Files:**
- `complete_schema.sql`

**Dependencies:** None (standalone)  
**Notes:** This is the main schema file. Install before views that depend on these tables.

---

## Recommended Full Installation Order

```bash
# 1. Main schema (all tables)
psql $DATABASE_URL -f scripts/supabase/complete_schema.sql

# 2. Lookup tables (enums)
psql $DATABASE_URL -f scripts/supabase/enum_lookup_tables_schema.sql

# 3. Feature flags and ingestion metadata
psql $DATABASE_URL -f scripts/supabase/feature_flags_schema.sql
psql $DATABASE_URL -f scripts/supabase/data_lake_ingestion_schema.sql
psql $DATABASE_URL -f scripts/supabase/data_lake_zones_schema.sql

# 4. Schema versioning (track future migrations)
psql $DATABASE_URL -f scripts/supabase/schema_versioning_schema.sql

# 5. User ID semantics (documentation)
psql $DATABASE_URL -f scripts/supabase/user_id_semantics_schema.sql

# 6. Soft delete support
psql $DATABASE_URL -f scripts/supabase/soft_delete_schema.sql

# 7. Address normalization
psql $DATABASE_URL -f scripts/supabase/address_normalization_schema.sql

# 8. Index optimization
psql $DATABASE_URL -f scripts/supabase/index_optimization_schema.sql

# 9. Read-optimized views
psql $DATABASE_URL -f scripts/supabase/read_optimized_views_schema.sql
psql $DATABASE_URL -f scripts/supabase/prospect_enrich_view.sql

# 10. Dashboard aggregations (may take time)
psql $DATABASE_URL -f scripts/supabase/dashboard_aggregations_schema.sql

# 11. Refresh materialized views
psql $DATABASE_URL -c "SELECT refresh_dashboard_aggregations();"
```

## Installation Script

A PowerShell script to automate installation:

```powershell
# install-schemas.ps1
$schemas = @(
    "scripts/supabase/complete_schema.sql",
    "scripts/supabase/enum_lookup_tables_schema.sql",
    "scripts/supabase/feature_flags_schema.sql",
    "scripts/supabase/data_lake_ingestion_schema.sql",
    "scripts/supabase/data_lake_zones_schema.sql",
    "scripts/supabase/schema_versioning_schema.sql",
    "scripts/supabase/user_id_semantics_schema.sql",
    "scripts/supabase/soft_delete_schema.sql",
    "scripts/supabase/address_normalization_schema.sql",
    "scripts/supabase/index_optimization_schema.sql",
    "scripts/supabase/read_optimized_views_schema.sql",
    "scripts/supabase/prospect_enrich_view.sql",
    "scripts/supabase/dashboard_aggregations_schema.sql"
)

$databaseUrl = $env:DATABASE_URL
if (-not $databaseUrl) {
    Write-Host "Error: DATABASE_URL environment variable not set" -ForegroundColor Red
    exit 1
}

foreach ($schema in $schemas) {
    Write-Host "Installing: $schema" -ForegroundColor Cyan
    psql $databaseUrl -f $schema
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error installing $schema" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Refreshing materialized views..." -ForegroundColor Cyan
psql $databaseUrl -c "SELECT refresh_dashboard_aggregations();"

Write-Host "Schema installation complete!" -ForegroundColor Green
```

## Troubleshooting

### Foreign Key Errors
If you get foreign key errors, ensure tables are created before views that reference them.

### View Creation Errors
Views depend on tables. Ensure all referenced tables exist before creating views.

### Materialized View Build Time
Large materialized views may take several minutes to build. Be patient.

### Missing Extensions
Each schema file creates extensions as needed. If errors occur, manually create:
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron"; -- Optional, for scheduled refreshes
```

## Verification

After installation, verify schemas:

```sql
-- Check tables exist
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- Check views exist
SELECT viewname FROM pg_views 
WHERE schemaname = 'public' 
ORDER BY viewname;

-- Check materialized views exist
SELECT matviewname FROM pg_matviews 
WHERE schemaname = 'public' 
ORDER BY matviewname;

-- Check indexes
SELECT indexname FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY indexname;

-- Check schema version
SELECT get_current_schema_version();
```
