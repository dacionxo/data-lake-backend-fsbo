-- ============================================================================
-- Read-Optimized Views Schema
-- ============================================================================
-- This schema creates read-optimized views for LeadMap-main UI screens,
-- joining normalized tables for optimal query performance.
--
-- VIEWS:
-- - prospect_enrich_view: Prospect & Enrich page view
-- - dashboard_summary_view: Dashboard summary data
-- - lead_detail_view: Detailed lead information
-- ============================================================================

-- ============================================================================
-- PROSPECT ENRICH VIEW
-- ============================================================================
-- Optimized view for "Prospect & Enrich" UI page
-- Joins listings with enrichment data and CRM state
CREATE OR REPLACE VIEW prospect_enrich_view AS
SELECT 
  -- Listing identification
  l.listing_id,
  l.property_url,
  l.permalink,
  
  -- Address information
  l.street,
  l.unit,
  l.city,
  l.state,
  l.zip_code,
  l.lat,
  l.lng,
  
  -- Property details
  l.beds,
  l.full_baths,
  l.half_baths,
  l.sqft,
  l.year_built,
  l.list_price,
  l.price_per_sqft,
  
  -- Status and metadata
  l.status,
  l.active,
  l.pipeline_status,
  l.scrape_date,
  l.last_scraped_at,
  l.created_at,
  l.updated_at,
  
  -- Contact information
  l.agent_name AS contact_name,
  l.agent_email AS contact_email,
  l.agent_phone AS contact_phone,
  
  -- Enrichment data (from staging if available)
  fsbo_raw.enriched AS is_enriched,
  fsbo_raw.enriched_at,
  fsbo_raw.validated AS is_validated,
  
  -- CRM state (user-specific, aggregated)
  (
    SELECT COUNT(*) 
    FROM contacts c 
    WHERE c.source_id = l.listing_id 
      AND c.deleted_at IS NULL
  ) AS contact_count,
  
  (
    SELECT COUNT(*) 
    FROM deals d 
    WHERE d.source_id = l.listing_id 
      AND d.deleted_at IS NULL
  ) AS deal_count,
  
  (
    SELECT COUNT(*) 
    FROM tasks t 
    WHERE t.related_type = 'listing' 
      AND t.related_id = l.listing_id
      AND t.deleted_at IS NULL
  ) AS task_count,
  
  -- List membership (if any lists contain this listing)
  (
    SELECT array_agg(DISTINCT li.list_id::TEXT)
    FROM list_items li
    INNER JOIN lists lst ON li.list_id = lst.id
    WHERE li.item_type = 'listing' 
      AND li.item_id = l.listing_id
      AND li.deleted_at IS NULL
      AND lst.deleted_at IS NULL
  ) AS list_ids,
  
  -- Source information
  l.listing_source_name,
  l.listing_source_id,
  l.user_id AS scraped_by_user_id,
  
  -- Additional metadata
  l.photos_json,
  l.other AS metadata,
  l.tags,
  l.ai_investment_score
  
FROM listings l
LEFT JOIN fsbo_raw ON l.listing_id = fsbo_raw.listing_id
WHERE l.active = TRUE;

-- ============================================================================
-- LEAD DETAIL VIEW
-- ============================================================================
-- Comprehensive view for lead detail pages
CREATE OR REPLACE VIEW lead_detail_view AS
SELECT 
  -- Unified listing data (works across all lead tables)
  listing_id,
  'listings' AS source_table,
  property_url,
  street,
  city,
  state,
  zip_code,
  list_price,
  status,
  pipeline_status,
  agent_name,
  agent_email,
  agent_phone,
  created_at,
  user_id,
  lat,
  lng
FROM listings

UNION ALL

SELECT 
  listing_id,
  'fsbo_leads' AS source_table,
  property_url,
  street,
  city,
  state,
  zip_code,
  list_price,
  status,
  pipeline_status,
  agent_name,
  agent_email,
  agent_phone,
  created_at,
  user_id,
  lat,
  lng
FROM fsbo_leads

UNION ALL

SELECT 
  listing_id,
  'expired_listings' AS source_table,
  property_url,
  street,
  city,
  state,
  zip_code,
  list_price,
  status,
  pipeline_status,
  agent_name,
  agent_email,
  agent_phone,
  created_at,
  user_id,
  lat,
  lng
FROM expired_listings

UNION ALL

SELECT 
  listing_id,
  'frbo_leads' AS source_table,
  property_url,
  street,
  city,
  state,
  zip_code,
  list_price,
  status,
  pipeline_status,
  agent_name,
  agent_email,
  agent_phone,
  created_at,
  user_id,
  lat,
  lng
FROM frbo_leads

UNION ALL

SELECT 
  listing_id,
  'foreclosure_listings' AS source_table,
  property_url,
  street,
  city,
  state,
  zip_code,
  list_price,
  status,
  pipeline_status,
  agent_name,
  agent_email,
  agent_phone,
  created_at,
  user_id,
  lat,
  lng
FROM foreclosure_listings;

-- ============================================================================
-- USER DASHBOARD VIEW
-- ============================================================================
-- Summary view for user dashboard
CREATE OR REPLACE VIEW user_dashboard_view AS
SELECT 
  u.id AS user_id,
  u.email,
  u.name,
  
  -- Lead counts
  (
    SELECT COUNT(*) 
    FROM listings l 
    WHERE l.active = TRUE
  ) AS total_listings,
  
  (
    SELECT COUNT(*) 
    FROM fsbo_leads f 
    WHERE f.active = TRUE
  ) AS total_fsbo_leads,
  
  -- User-specific CRM counts
  (
    SELECT COUNT(*) 
    FROM contacts c 
    WHERE c.user_id = u.id 
      AND c.deleted_at IS NULL
  ) AS my_contacts,
  
  (
    SELECT COUNT(*) 
    FROM deals d 
    WHERE d.user_id = u.id 
      AND d.deleted_at IS NULL
      AND d.stage NOT IN ('closed_won', 'closed_lost')
  ) AS active_deals,
  
  (
    SELECT COUNT(*) 
    FROM deals d 
    WHERE d.user_id = u.id 
      AND d.deleted_at IS NULL
      AND d.stage = 'closed_won'
  ) AS won_deals,
  
  (
    SELECT COUNT(*) 
    FROM tasks t 
    WHERE t.user_id = u.id 
      AND t.deleted_at IS NULL
      AND t.status NOT IN ('completed', 'cancelled')
  ) AS active_tasks,
  
  (
    SELECT COUNT(*) 
    FROM lists l 
    WHERE l.user_id = u.id 
      AND l.deleted_at IS NULL
  ) AS my_lists,
  
  -- Recent activity
  (
    SELECT MAX(created_at) 
    FROM contacts c 
    WHERE c.user_id = u.id
  ) AS last_contact_created,
  
  (
    SELECT MAX(created_at) 
    FROM deals d 
    WHERE d.user_id = u.id
  ) AS last_deal_created

FROM users u;

-- ============================================================================
-- LISTING WITH ENRICHMENT VIEW
-- ============================================================================
-- View showing listings with enrichment status
CREATE OR REPLACE VIEW listing_enrichment_view AS
SELECT 
  l.listing_id,
  l.property_url,
  l.city,
  l.state,
  l.list_price,
  l.status,
  l.pipeline_status,
  l.created_at,
  
  -- Enrichment status
  CASE 
    WHEN fsbo_raw.id IS NOT NULL THEN TRUE 
    ELSE FALSE 
  END AS has_staging_data,
  
  fsbo_raw.normalized AS is_normalized,
  fsbo_raw.enriched AS is_enriched,
  fsbo_raw.validated AS is_validated,
  fsbo_raw.enriched_at,
  
  -- Contact info availability
  CASE 
    WHEN l.agent_email IS NOT NULL OR l.agent_phone IS NOT NULL THEN TRUE 
    ELSE FALSE 
  END AS has_contact_info,
  
  -- Geocoding status
  CASE 
    WHEN l.lat IS NOT NULL AND l.lng IS NOT NULL THEN TRUE 
    ELSE FALSE 
  END AS is_geocoded

FROM listings l
LEFT JOIN fsbo_raw ON l.listing_id = fsbo_raw.listing_id
WHERE l.active = TRUE;

-- ============================================================================
-- INDEXES FOR VIEW PERFORMANCE
-- ============================================================================

-- Views use indexes on underlying tables, but we ensure key indexes exist
-- These should already be created by index_optimization_schema.sql

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON VIEW prospect_enrich_view IS 
  'Optimized view for Prospect & Enrich UI page - joins listings with enrichment and CRM state';

COMMENT ON VIEW lead_detail_view IS 
  'Unified view of all lead types for detail pages';

COMMENT ON VIEW user_dashboard_view IS 
  'Summary statistics for user dashboard';

COMMENT ON VIEW listing_enrichment_view IS 
  'Listings with enrichment status for pipeline monitoring';

