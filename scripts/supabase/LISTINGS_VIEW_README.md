# Unified Listings View - Documentation

## Overview

This document explains how to make the `listings` table in Supabase a compiled/aggregated view of all other listing tables in the schema.

## Problem

Currently, the application aggregates listings from multiple tables (listings, expired_listings, fsbo_leads, frbo_leads, imports, trash, foreclosure_listings, probate_leads) at the application level. This requires multiple queries and client-side aggregation.

## Solution Options

### Option 1: Regular View (Recommended for Most Cases)

**File:** `create_listings_view.sql`

**Pros:**
- Always up-to-date (real-time data)
- No storage duplication
- Simple to implement
- No maintenance required

**Cons:**
- Slightly slower queries (unions are computed on each query)
- Can't create indexes directly on views

**Best For:** Most use cases where real-time data is important and query performance is acceptable.

### Option 2: Materialized View (Recommended for High Performance)

**File:** `create_listings_materialized_view.sql`

**Pros:**
- Much faster queries (pre-computed)
- Can create indexes for optimal performance
- Better for large datasets

**Cons:**
- Data can be stale (needs periodic refresh)
- Requires storage space
- Requires maintenance (refresh schedule)

**Best For:** High-traffic applications with large datasets where slightly stale data is acceptable.

## Implementation

### Step 1: Choose Your Approach

Decide whether you need:
- **Real-time data** → Use regular view (`create_listings_view.sql`)
- **High performance** → Use materialized view (`create_listings_materialized_view.sql`)

### Step 2: Run the SQL Script

1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of your chosen SQL file
4. Click "Run"

### Step 3: Update Your Application Code

#### For Regular View:

Update your queries to use `listings_unified` instead of aggregating in the application:

```typescript
// Before (application-level aggregation)
const tablesToFetch = ['listings', 'expired_listings', 'fsbo_leads', ...]
const results = await Promise.all(tablesToFetch.map(table => 
  supabase.from(table).select('*')
))
const data = results.flatMap(r => r.data || [])

// After (using view)
const { data } = await supabase
  .from('listings_unified')
  .select('*')
  .order('created_at', { ascending: false })
```

#### For Materialized View:

Same as above, but use `listings_unified_materialized`:

```typescript
const { data } = await supabase
  .from('listings_unified_materialized')
  .select('*')
  .order('created_at', { ascending: false })
```

**Important:** If using materialized view, set up a refresh schedule (see below).

### Step 4: Update the Hook (Optional)

You can simplify `useProspectData.ts` to use the view:

```typescript
if (activeCategory === 'all') {
  // Simply query the unified view instead of aggregating
  const { data: result, error } = await supabase
    .from('listings_unified')  // or 'listings_unified_materialized'
    .select('*')
    .order('created_at', { ascending: false })
    .limit(1000)
  
  data = result || []
} else {
  // For specific categories, still query individual tables
  const tableName = getTableName(activeCategory)
  // ... existing code
}
```

## Materialized View Refresh

If you chose the materialized view, you need to refresh it periodically.

### Manual Refresh

```sql
SELECT refresh_listings_unified();
```

Or:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY listings_unified_materialized;
```

### Automatic Refresh (Recommended)

Set up a cron job in Supabase:

1. Go to Database → Extensions
2. Enable `pg_cron` extension
3. Schedule a refresh:

```sql
-- Refresh every hour
SELECT cron.schedule(
  'refresh-listings-unified',
  '0 * * * *',  -- Every hour at minute 0
  'SELECT refresh_listings_unified()'
);

-- Or refresh every 15 minutes
SELECT cron.schedule(
  'refresh-listings-unified',
  '*/15 * * * *',
  'SELECT refresh_listings_unified()'
);
```

### View Refresh Schedule

```sql
-- View all scheduled jobs
SELECT * FROM cron.job;

-- Remove a scheduled job
SELECT cron.unschedule('refresh-listings-unified');
```

## View Structure

The unified view includes all columns from the listing tables plus:

- **`source_category`**: Identifies which table the row came from
  - Values: `'listings'`, `'expired_listings'`, `'fsbo_leads'`, `'frbo_leads'`, `'imports'`, `'trash'`, `'foreclosure_listings'`, `'probate_leads'`

## Query Examples

### Get All Listings

```sql
SELECT * FROM listings_unified 
ORDER BY created_at DESC 
LIMIT 100;
```

### Filter by Category

```sql
SELECT * FROM listings_unified 
WHERE source_category = 'fsbo_leads'
ORDER BY created_at DESC;
```

### Count by Category

```sql
SELECT source_category, COUNT(*) as count 
FROM listings_unified 
GROUP BY source_category;
```

### Search Across All Categories

```sql
SELECT * FROM listings_unified 
WHERE city = 'Chicago' 
  AND state = 'IL'
  AND list_price BETWEEN 100000 AND 500000
ORDER BY list_price ASC;
```

## Important Notes

1. **Writes Still Go to Individual Tables**: The view is read-only. You still insert/update/delete in the individual category tables (listings, fsbo_leads, etc.).

2. **Probate Leads Transformation**: The `probate_leads` table has a different schema, so it's transformed to match the unified structure. Some fields may be NULL for probate leads.

3. **Performance**: 
   - Regular view: Slightly slower but always current
   - Materialized view: Much faster but needs refresh

4. **RLS Policies**: The view inherits RLS policies from the underlying tables. Make sure your RLS policies allow access to all the source tables.

## Migration Path

If you want to completely replace the `listings` table with a view:

⚠️ **Warning**: This is a breaking change and requires careful migration.

1. **Backup existing `listings` data** (if any)
2. **Move existing `listings` data** to a new table (e.g., `listings_legacy`)
3. **Drop the `listings` table**
4. **Create a view named `listings`** that unions all tables
5. **Update foreign key constraints** (they won't work with views)
6. **Update application code** to write to appropriate category tables

**Recommendation**: Keep the `listings` table as-is and use `listings_unified` view for reads. This is safer and maintains backward compatibility.

## Troubleshooting

### View Returns No Data

- Check that source tables have data
- Verify RLS policies allow access
- Check for schema mismatches

### Materialized View is Stale

- Refresh manually: `SELECT refresh_listings_unified()`
- Check cron job status if using automatic refresh
- Verify the refresh function has proper permissions

### Performance Issues

- For regular view: Consider switching to materialized view
- For materialized view: Add more indexes or refresh more frequently
- Check query execution plans

## Support

If you encounter issues:
1. Check Supabase logs for errors
2. Verify all source tables exist and have compatible schemas
3. Test queries directly in SQL Editor
4. Check RLS policies on source tables


