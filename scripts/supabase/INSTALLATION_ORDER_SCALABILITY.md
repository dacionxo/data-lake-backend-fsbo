# Installation Order for Scalability Optimizations

## ✅ Standalone Installation (Recommended)

The `scalability_optimizations.sql` file is **fully independent** and can be run standalone:

```bash
# Can be run independently - all checks are built-in
psql $DATABASE_URL -f scripts/supabase/scalability_optimizations.sql
```

The file automatically:
- ✅ Checks for table existence before creating policies
- ✅ Checks for materialized view existence before refreshing
- ✅ Uses IF NOT EXISTS for all indexes
- ✅ Handles missing extensions gracefully

## 📋 Installation Order (If Applying All Schemas)

If you want to apply all schema files in order:

```bash
# 1. Base schema (required)
psql $DATABASE_URL -f scripts/supabase/complete_schema.sql

# 2. Scalability optimizations (independent, can run standalone)
psql $DATABASE_URL -f scripts/supabase/scalability_optimizations.sql
```

## 🔍 What Gets Created

### Policies (Only if tables exist)
- Enhanced RLS policies with soft-delete filtering for:
  - `contacts`
  - `deals`
  - `tasks`
  - `lists`
  - `list_items`

### Indexes (Only if tables exist)
- 20+ composite indexes for optimal query performance
- Pagination indexes
- Covering indexes
- Full-text search indexes

### Functions (Always created)
- `get_user_dashboard_summary(user_id)` - Optimized dashboard query
- `refresh_dashboard_views_for_users()` - Refresh materialized views
- `check_database_performance()` - Performance monitoring

## ⚠️ Requirements

**Minimum Requirements:**
- PostgreSQL 12+ (Supabase uses PostgreSQL 15+)
- `uuid-ossp` extension (automatically created)
- Tables with `deleted_at` columns (for soft-delete policies)

**Optional Requirements:**
- `earthdistance` extension (for geospatial indexes, created if available)
- Materialized views (for refresh function, checked before refreshing)

## ✅ Verification

After installation, verify:

```sql
-- Check indexes were created
SELECT COUNT(*) FROM pg_indexes 
WHERE schemaname = 'public' 
AND indexname LIKE 'idx_%user%';

-- Check policies were updated
SELECT policyname, tablename 
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('contacts', 'deals', 'tasks')
AND policyname LIKE '%active%';

-- Test dashboard function
SELECT get_user_dashboard_summary(auth.uid());
```

## 🔄 Re-running

Safe to re-run multiple times:
- Policies are dropped and recreated
- Indexes use IF NOT EXISTS
- Functions are replaced (CREATE OR REPLACE)


