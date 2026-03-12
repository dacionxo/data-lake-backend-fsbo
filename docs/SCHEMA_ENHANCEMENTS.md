# Schema Enhancements Documentation

This document describes all the enhancements integrated into `complete_schema.sql`.

## Overview

The following enhancements have been fully integrated into the complete schema:

1. ✅ **Address/Contact Normalization** - Helper views for consistent address/contact mapping
2. ✅ **Enum Lookup Tables** - Lookup tables for all enum values with foreign key support
3. ✅ **User ID Semantics** - Standardized and documented user_id usage
4. ✅ **Index Optimization** - Comprehensive indexes for high-volume queries
5. ✅ **Soft Delete Support** - Soft-delete columns for all CRM tables
6. ✅ **Read-Optimized Views** - Views for Prospect & Enrich UI and other screens
7. ✅ **Dashboard Aggregations** - Materialized views for dashboard analytics
8. ✅ **Schema Versioning** - Version tracking and enforcement mechanism

## 1. Address/Contact Normalization

### Views Created
- `address_view` - Unified view of addresses across all lead tables
- `address_normalized` - Normalized addresses with formatted strings
- `contact_view` - Unified view of contact information
- `contact_normalized` - Normalized contacts with primary contact method
- `geographic_distribution` - Geographic distribution analytics

### Usage
```sql
-- Query normalized addresses
SELECT * FROM address_normalized WHERE city = 'Los Angeles';

-- Get contact information consistently
SELECT * FROM contact_normalized WHERE has_contact_info = TRUE;
```

## 2. Enum Lookup Tables

### Tables Created
- `lead_status` - Status values for listings (fsbo, expired, active, etc.)
- `pipeline_status` - Pipeline run statuses (queued, running, completed, etc.)
- `user_role` - User roles (user, admin)
- `plan_tier` - Subscription tiers (free, starter, pro)
- `contact_status` - Contact status values
- `deal_stage` - Deal pipeline stages
- `task_status` - Task status values
- `task_priority` - Task priority levels
- `list_type` - List types
- `list_item_type` - List item types

### Benefits
- Data integrity through foreign keys (when migrated)
- Easier management of enum values
- Better query performance with indexes
- Audit trails for enum changes

### Usage
```sql
-- Query active enum values
SELECT * FROM lead_status WHERE active = TRUE ORDER BY display_order;

-- Validate enum value
SELECT validate_enum_value('lead_status', 'fsbo');
```

## 3. User ID Semantics Standardization

### Functions Created
- `validate_universal_user_id()` - Validates user_id for universal tables (optional)
- `validate_user_specific_user_id()` - Validates user_id for user-specific tables (required)

### Table Classifications
- **Universal Tables** (user_id optional/nullable):
  - `listings`, `fsbo_leads`, `expired_listings`, `frbo_leads`, `foreclosure_listings`

- **User-Specific Tables** (user_id NOT NULL):
  - `contacts`, `deals`, `tasks`, `lists`, `list_items`

See `user_id_semantics_schema.sql` for full documentation.

## 4. Index Optimization

### Indexes Created
- Composite indexes for common filter combinations (state/city, state/status, etc.)
- Partial indexes for common WHERE clauses (active = TRUE, deleted_at IS NULL)
- Price range indexes for filtering
- Full-text search indexes on descriptions
- Covering indexes for frequently selected columns

### Performance Impact
- Faster queries on high-volume lead tables
- Optimized filtering by city, state, status, created_at, list_price
- Improved dashboard query performance

## 5. Soft Delete Support

### Tables Updated
- `contacts` - Added `deleted_at`, `deleted_by`
- `deals` - Added `deleted_at`, `deleted_by`
- `tasks` - Added `deleted_at`, `deleted_by`
- `lists` - Added `deleted_at`, `deleted_by`
- `list_items` - Added `deleted_at`, `deleted_by`

### Views Created
- `contacts_active` - Active contacts only
- `deals_active` - Active deals only
- `tasks_active` - Active tasks only
- `lists_active` - Active lists only
- `list_items_active` - Active list items only

### Functions Created
- `soft_delete_contact()` - Soft delete a contact
- `restore_contact()` - Restore a soft-deleted contact

### Usage
```sql
-- Query active records only
SELECT * FROM contacts_active WHERE user_id = auth.uid();

-- Soft delete
SELECT soft_delete_contact(contact_id, auth.uid());
```

## 6. Read-Optimized Views

### Views Created
- `prospect_enrich_view` - Optimized for "Prospect & Enrich" UI page
  - Joins listings with enrichment data
  - Includes CRM state (contact_count, deal_count, task_count)
  - Includes list membership

### Usage
```sql
-- Query Prospect & Enrich page data
SELECT * FROM prospect_enrich_view 
WHERE city = 'Los Angeles' AND is_enriched = FALSE
ORDER BY created_at DESC;
```

## 7. Dashboard Aggregations

### Materialized Views Created
- `lead_counts_by_category` - Lead counts by category, status, location
- `status_funnel` - Pipeline status funnel showing progression

### Refresh Function
- `refresh_dashboard_aggregations()` - Refreshes all materialized views concurrently

### Usage
```sql
-- Query aggregations
SELECT * FROM lead_counts_by_category WHERE state = 'CA';

-- Refresh aggregations (run periodically)
SELECT refresh_dashboard_aggregations();
```

## 8. Schema Versioning

### Table Created
- `schema_versions` - Tracks all schema migrations

### Functions Created
- `get_current_schema_version()` - Returns current version
- `check_schema_version(version)` - Checks if version matches
- `require_schema_version(version)` - Raises error if mismatch
- `record_schema_migration(...)` - Records a migration

### CI/CD Integration
```bash
# Check schema version in CI
psql $DATABASE_URL -c "SELECT require_schema_version('2.0.0');"
```

### Current Version
- **Version**: `2.0.0`
- **Description**: Complete schema with all enhancements

## Migration Notes

### For Existing Databases

1. **Address/Contact Views**: Can be added immediately (read-only views)
2. **Enum Lookup Tables**: Add tables, then optionally migrate foreign keys later
3. **Soft Delete**: Add columns to CRM tables (existing data remains active)
4. **Indexes**: Can be added immediately (non-blocking)
5. **Views**: Can be added immediately (read-only)
6. **Aggregations**: Create materialized views, refresh periodically
7. **Versioning**: Add table, insert initial version

### Breaking Changes
None - all enhancements are backwards compatible.

### Performance Considerations
- Materialized views should be refreshed periodically (every 5-15 minutes)
- Indexes improve read performance but may slightly slow writes
- Views are computed on-the-fly but use underlying table indexes

## Related Files

- `scripts/supabase/address_normalization_schema.sql`
- `scripts/supabase/enum_lookup_tables_schema.sql`
- `scripts/supabase/user_id_semantics_schema.sql`
- `scripts/supabase/soft_delete_schema.sql`
- `scripts/supabase/index_optimization_schema.sql`
- `scripts/supabase/read_optimized_views_schema.sql`
- `scripts/supabase/dashboard_aggregations_schema.sql`
- `scripts/supabase/schema_versioning_schema.sql`

## Next Steps

1. **Migrate Foreign Keys**: Optionally add foreign keys from tables to lookup tables
2. **Update Application Code**: Use new views and soft-delete functions
3. **Set Up Refresh Jobs**: Schedule materialized view refreshes
4. **CI/CD Integration**: Add schema version checks to CI pipelines


