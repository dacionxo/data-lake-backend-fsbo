-- ============================================================================
-- Create Unified Listings View
-- ============================================================================
-- This view creates a compiled/aggregated view of all listing tables
-- so that the 'listings' table can be queried as a union of all categories.
-- 
-- The view includes:
-- - listings (base table)
-- - expired_listings
-- - fsbo_leads
-- - frbo_leads
-- - imports
-- - trash
-- - foreclosure_listings
-- - probate_leads (with transformation to match schema)
--
-- Each row includes a 'source_category' field to identify its origin.
-- ============================================================================

-- Drop existing view if it exists
DROP VIEW IF EXISTS listings_unified CASCADE;

-- Create the unified view
CREATE VIEW listings_unified AS
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
  'expired_listings' AS source_category
FROM expired_listings

UNION ALL

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
  'fsbo_leads' AS source_category
FROM fsbo_leads

UNION ALL

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
  'frbo_leads' AS source_category
FROM frbo_leads

UNION ALL

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
  'imports' AS source_category
FROM imports

UNION ALL

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
  'trash' AS source_category
FROM trash

UNION ALL

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
  'foreclosure_listings' AS source_category
FROM foreclosure_listings

UNION ALL

-- Probate leads have a different schema, so we need to transform them
SELECT 
  id::TEXT AS listing_id,  -- Convert UUID to TEXT
  NULL AS property_url,     -- Probate doesn't have property_url
  NULL AS permalink,
  NULL AS scrape_date,
  created_at AS last_scraped_at,
  TRUE AS active,
  address AS street,         -- Probate uses 'address' instead of 'street'
  NULL AS unit,
  city,
  state,
  zip AS zip_code,          -- Probate uses 'zip' instead of 'zip_code'
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
  decedent_name AS agent_name,  -- Use decedent_name as agent_name
  NULL AS agent_email,
  NULL AS agent_phone,
  NULL AS agent_phone_2,
  NULL AS listing_agent_phone_2,
  NULL AS listing_agent_phone_5,
  notes AS text,            -- Use notes as text/description
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
  NULL AS user_id,          -- Probate doesn't have user_id
  NULL AS owner_id,
  NULL AS tags,
  NULL AS lists,
  NULL AS pipeline_status,
  latitude AS lat,          -- Probate uses 'latitude' instead of 'lat'
  longitude AS lng,          -- Probate uses 'longitude' instead of 'lng'
  'probate_leads' AS source_category
FROM probate_leads;

-- ============================================================================
-- Grant Permissions
-- ============================================================================
-- Grant SELECT permission to authenticated users
GRANT SELECT ON listings_unified TO authenticated;

-- ============================================================================
-- Create Indexes (if needed for performance)
-- ============================================================================
-- Note: Views don't support indexes directly, but you can create indexes
-- on the underlying tables for better performance

-- ============================================================================
-- Usage Examples
-- ============================================================================
-- Query all listings from all categories:
-- SELECT * FROM listings_unified ORDER BY created_at DESC;
--
-- Query listings from a specific category:
-- SELECT * FROM listings_unified WHERE source_category = 'fsbo_leads';
--
-- Count listings by category:
-- SELECT source_category, COUNT(*) FROM listings_unified GROUP BY source_category;
--
-- ============================================================================
-- Verification
-- ============================================================================
SELECT 'Listings unified view created successfully!' as status;
SELECT COUNT(*) as total_listings FROM listings_unified;
SELECT source_category, COUNT(*) as count FROM listings_unified GROUP BY source_category;


