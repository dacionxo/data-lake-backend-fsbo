# Schema Update Summary

## Updated Schema Structure

The listings table has been completely restructured to match the Redfin scraper output format.

### New Listings Table Structure

**Primary Key**: `listing_id` (TEXT) - Redfin listing ID or URL slug
**Required Fields**: 
- `listing_id` (TEXT, PRIMARY KEY)
- `property_url` (TEXT, UNIQUE)

**Key Changes**:
- Changed from `id` (UUID) to `listing_id` (TEXT)
- Changed from `address` to `street` and `unit` (separate fields)
- Changed from `zip` to `zip_code`
- Changed from `price` to `list_price`, `list_price_min`, `list_price_max` (BIGINT)
- Removed: `price_drop_percent`, `days_on_market`, `owner_name`, `owner_email`, `owner_phone`, `expired`, `expired_at`, `enrichment_source`, `enrichment_confidence`, `geo_source`, `radius_km`
- Added: `beds`, `full_baths`, `half_baths`, `sqft`, `year_built`, `status`, `mls`, `agent_name`, `agent_email`, `agent_phone`, `photos`, `photos_json` (JSONB), `other` (JSONB), `price_per_sqft`, `listing_source_name`, `listing_source_id`, `monthly_payment_estimate`, `ai_investment_score`, `time_listed`, `scrape_date`, `last_scraped_at`, `permalink`

### New Tables

1. **price_history** - Tracks price changes over time
2. **status_history** - Tracks status changes over time

### Files Updated

1. ✅ `supabase/complete_schema.sql` - Updated table structure, indexes, triggers, RLS policies
2. ✅ `app/api/admin/upload-csv/route.ts` - Updated to handle new CSV format
3. ⏳ `app/dashboard/leads/page.tsx` - Needs update to new schema
4. ⏳ `components/AdminPanel.tsx` - Needs CSV instructions update
5. ⏳ `app/dashboard/components/DashboardContent.tsx` - Needs schema update
6. ⏳ Other components referencing old schema

### CSV Format

**Required columns**:
- `listing_id` - Unique identifier (or will be generated from property_url)
- `property_url` - Full URL to the property listing

**Optional columns**:
- `street`, `unit`, `city`, `state`, `zip_code`
- `list_price`, `list_price_min`, `list_price_max`
- `beds`, `full_baths`, `half_baths`, `sqft`, `year_built`
- `status`, `mls`
- `agent_name`, `agent_email`, `agent_phone`
- `photos`, `photos_json` (JSON string)
- `other` (JSON string)
- `price_per_sqft`, `listing_source_name`, `listing_source_id`
- `monthly_payment_estimate`, `ai_investment_score`
- `time_listed`, `scrape_date`, `permalink`
- `active` (boolean)

