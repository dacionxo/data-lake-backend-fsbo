# Geocoding Implementation Guide

This guide explains how to set up and use the geocoding system for storing lat/lng coordinates in Supabase.

## Overview

The geocoding system stores coordinates in the database to make map loading instant. It consists of:

1. **Backfill Script**: One-time script to geocode existing records
2. **Edge Function**: Ongoing geocoding for new records
3. **Frontend Fallback**: Client-side geocoding only when coordinates are missing

## Setup

### 1. Environment Variables

Ensure you have these environment variables set:

```bash
# Required
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# At least one geocoding provider
NEXT_PUBLIC_MAPBOX_ACCESS_TOKEN=your_mapbox_token
# OR
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_key
```

### 2. Database Schema

Ensure your tables have `lat` and `lng` columns:

```sql
ALTER TABLE listings ADD COLUMN IF NOT EXISTS lat DOUBLE PRECISION;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS lng DOUBLE PRECISION;

-- Repeat for other tables:
-- expired_listings, fsbo_leads, frbo_leads, foreclosure_listings, imports, probate_leads, trash
```

## Usage

### One-Time Backfill

Run the backfill script to geocode all existing records:

```bash
npm run backfill-geocodes
```

Or directly:

```bash
npx tsx scripts/backfill-geocodes.ts
```

The script will:
- Find all rows with missing `lat` or `lng`
- Geocode their addresses
- Update the rows with coordinates
- Process in batches with rate limiting

### Ongoing Geocoding (Edge Function)

Deploy the Supabase Edge Function:

```bash
supabase functions deploy geocode-new-listings
```

Set up a cron job to run it periodically (e.g., every 5 minutes):

```sql
-- In Supabase SQL Editor
SELECT cron.schedule(
  'geocode-new-listings',
  '*/5 * * * *', -- Every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://your-project.supabase.co/functions/v1/geocode-new-listings',
    headers := '{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
  );
  $$
);
```

Or call it manually:

```bash
supabase functions invoke geocode-new-listings
```

## How It Works

### Frontend Behavior

1. **Fast Path (80-90% of leads)**: 
   - Leads with stored `lat/lng` → Markers appear instantly
   - No API calls needed

2. **Fallback Path (10-20% of leads)**:
   - Leads without coordinates → Client-side geocoding
   - Only geocodes a small batch (5 at a time) to avoid rate limits

### Performance Benefits

- **Instant map rendering**: Markers drop immediately for leads with coordinates
- **Reduced API calls**: Only geocode missing coordinates
- **Better UX**: No waiting for geocoding on page load
- **Cost efficient**: Batch geocoding in background vs. per-request

## Tables Supported

The system processes these tables:

- `listings`
- `expired_listings`
- `fsbo_leads`
- `frbo_leads`
- `foreclosure_listings`
- `imports`
- `probate_leads`
- `trash`

## Troubleshooting

### Script fails with "Missing environment variables"

Ensure `.env.local` has all required variables and run:
```bash
source .env.local
npm run backfill-geocodes
```

### Edge Function returns 500

Check Supabase logs:
```bash
supabase functions logs geocode-new-listings
```

### Coordinates not updating

1. Check that tables have `lat` and `lng` columns
2. Verify API keys are valid
3. Check rate limits (Mapbox: 600 req/min, Google: varies by plan)

## Best Practices

1. **Run backfill during off-peak hours** (large datasets)
2. **Monitor API usage** to avoid rate limits
3. **Geocode at import time** when possible (Option B from guide)
4. **Use Edge Function cron** for ongoing maintenance
5. **Prefer stored coordinates** in all frontend components

