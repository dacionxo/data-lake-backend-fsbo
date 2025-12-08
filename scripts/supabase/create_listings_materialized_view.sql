-- ============================================================================
-- Create Materialized View for Unified Listings
-- ============================================================================
-- This creates a materialized view that can be refreshed periodically
-- for better query performance. Use this if you need faster reads but
-- can tolerate slightly stale data.
-- ============================================================================

-- Drop existing materialized view if it exists
DROP MATERIALIZED VIEW IF EXISTS listings_unified_materialized CASCADE;

-- Create the materialized view (same structure as the regular view)
CREATE MATERIALIZED VIEW listings_unified_materialized AS
SELECT 
  listing_id,
  property_url,
  permalink,
  scrape_date,
  last_scraped_at,
  active,
  street,
  unit,
  city,
  state,
  zip_code,
  beds,
  full_baths,
  half_baths,
  sqft,
  year_built,
  list_price,
  list_price_min,
  list_price_max,
  status,
  mls,
  agent_name,
  agent_email,
  agent_phone,
  agent_phone_2,
  listing_agent_phone_2,
  listing_agent_phone_5,
  text,
  last_sale_price,
  last_sale_date,
  photos,
  photos_json,
  other,
  price_per_sqft,
  listing_source_name,
  listing_source_id,
  monthly_payment_estimate,
  ai_investment_score,
  time_listed,
  created_at,
  updated_at,
  user_id,
  owner_id,
  tags,
  lists,
  pipeline_status,
  lat,
  lng,
  'listings' AS source_category
FROM listings

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'expired_listings' AS source_category
FROM expired_listings

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'fsbo_leads' AS source_category
FROM fsbo_leads

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'frbo_leads' AS source_category
FROM frbo_leads

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'imports' AS source_category
FROM imports

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'trash' AS source_category
FROM trash

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'foreclosure_listings' AS source_category
FROM foreclosure_listings

UNION ALL

-- Probate leads transformation
SELECT 
  id::TEXT AS listing_id,
  NULL AS property_url,
  NULL AS permalink,
  NULL AS scrape_date,
  created_at AS last_scraped_at,
  TRUE AS active,
  address AS street,
  NULL AS unit,
  city,
  state,
  zip AS zip_code,
  NULL AS beds,
  NULL AS full_baths,
  NULL AS half_baths,
  NULL AS sqft,
  NULL AS year_built,
  NULL AS list_price,
  NULL AS list_price_min,
  NULL AS list_price_max,
  'probate' AS status,
  NULL AS mls,
  decedent_name AS agent_name,
  NULL AS agent_email,
  NULL AS agent_phone,
  NULL AS agent_phone_2,
  NULL AS listing_agent_phone_2,
  NULL AS listing_agent_phone_5,
  notes AS text,
  NULL AS last_sale_price,
  NULL AS last_sale_date,
  NULL AS photos,
  NULL AS photos_json,
  jsonb_build_object(
    'case_number', case_number,
    'filing_date', filing_date,
    'source', source
  ) AS other,
  NULL AS price_per_sqft,
  NULL AS listing_source_name,
  NULL AS listing_source_id,
  NULL AS monthly_payment_estimate,
  NULL AS ai_investment_score,
  NULL AS time_listed,
  created_at,
  updated_at,
  NULL AS user_id,
  NULL AS owner_id,
  NULL AS tags,
  NULL AS lists,
  NULL AS pipeline_status,
  latitude AS lat,
  longitude AS lng,
  'probate_leads' AS source_category
FROM probate_leads;

-- Create indexes on the materialized view for better performance
CREATE INDEX idx_listings_unified_materialized_listing_id ON listings_unified_materialized(listing_id);
CREATE INDEX idx_listings_unified_materialized_source_category ON listings_unified_materialized(source_category);
CREATE INDEX idx_listings_unified_materialized_created_at ON listings_unified_materialized(created_at DESC);
CREATE INDEX idx_listings_unified_materialized_city_state ON listings_unified_materialized(city, state);
CREATE INDEX idx_listings_unified_materialized_list_price ON listings_unified_materialized(list_price);

-- Grant permissions
GRANT SELECT ON listings_unified_materialized TO authenticated;

-- ============================================================================
-- Refresh Function
-- ============================================================================
-- Create a function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_listings_unified()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY listings_unified_materialized;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION refresh_listings_unified() TO authenticated;

-- ============================================================================
-- Auto-refresh Trigger (Optional)
-- ============================================================================
-- You can set up a cron job or scheduled task to refresh this view periodically
-- Example: Refresh every hour
-- SELECT cron.schedule('refresh-listings-unified', '0 * * * *', 'SELECT refresh_listings_unified()');

-- ============================================================================
-- Usage
-- ============================================================================
-- Query the materialized view:
-- SELECT * FROM listings_unified_materialized ORDER BY created_at DESC LIMIT 100;
--
-- Refresh the view manually:
-- SELECT refresh_listings_unified();
--
-- Or refresh without concurrent (faster but locks the view):
-- REFRESH MATERIALIZED VIEW listings_unified_materialized;

SELECT 'Materialized view created successfully!' as status;
SELECT COUNT(*) as total_listings FROM listings_unified_materialized;


