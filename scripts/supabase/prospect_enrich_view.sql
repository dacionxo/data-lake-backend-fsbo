-- ============================================================================
-- Prospect Enrich View (Detailed Implementation)
-- ============================================================================
-- This view is optimized for the "Prospect & Enrich" UI page in LeadMap-main.
-- It joins listings with enrichment data and CRM state for efficient queries.
--
-- See also: read_optimized_views_schema.sql
-- ============================================================================

-- Drop existing view if it exists
DROP VIEW IF EXISTS prospect_enrich_view CASCADE;

-- Create optimized view
CREATE VIEW prospect_enrich_view AS
SELECT 
  -- Core listing identification
  l.listing_id,
  l.property_url,
  l.permalink,
  l.scrape_date,
  l.last_scraped_at,
  l.active,
  
  -- Address (normalized)
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
  l.list_price_min,
  l.list_price_max,
  l.price_per_sqft,
  l.last_sale_price,
  l.last_sale_date,
  
  -- Status and pipeline
  l.status,
  l.pipeline_status,
  l.mls,
  
  -- Contact information (normalized)
  l.agent_name AS contact_name,
  l.agent_email AS contact_email,
  l.agent_phone AS contact_phone,
  l.agent_phone_2 AS contact_phone_2,
  
  -- Enrichment status (from staging zone)
  CASE 
    WHEN fsbo_raw.id IS NOT NULL THEN TRUE 
    ELSE FALSE 
  END AS has_staging_data,
  
  fsbo_raw.normalized AS is_normalized,
  fsbo_raw.normalized_at,
  fsbo_raw.enriched AS is_enriched,
  fsbo_raw.enriched_at,
  fsbo_raw.validated AS is_validated,
  fsbo_raw.validated_at,
  
  -- CRM engagement (user-specific, aggregated)
  COALESCE(crm_stats.contact_count, 0) AS contact_count,
  COALESCE(crm_stats.deal_count, 0) AS deal_count,
  COALESCE(crm_stats.task_count, 0) AS task_count,
  COALESCE(crm_stats.list_count, 0) AS list_count,
  
  -- List membership
  crm_stats.list_ids,
  
  -- Source and provenance
  l.listing_source_name,
  l.listing_source_id,
  l.user_id AS scraped_by_user_id,
  
  -- Additional data
  l.photos_json,
  l.other AS metadata,
  l.tags,
  l.lists,
  l.ai_investment_score,
  l.monthly_payment_estimate,
  l.text AS description,
  
  -- Timestamps
  l.created_at,
  l.updated_at,
  
  -- Computed fields
  CASE 
    WHEN l.agent_email IS NOT NULL OR l.agent_phone IS NOT NULL THEN TRUE 
    ELSE FALSE 
  END AS has_contact_info,
  
  CASE 
    WHEN l.lat IS NOT NULL AND l.lng IS NOT NULL THEN TRUE 
    ELSE FALSE 
  END AS is_geocoded,
  
  -- Age in days
  EXTRACT(DAY FROM (NOW() - l.created_at))::INTEGER AS age_days,
  
  -- Days on market (if available)
  CASE 
    WHEN l.time_listed IS NOT NULL THEN 
      EXTRACT(DAY FROM (NOW() - l.time_listed))::INTEGER
    ELSE NULL
  END AS days_on_market

FROM listings l
LEFT JOIN fsbo_raw ON l.listing_id = fsbo_raw.listing_id
LEFT JOIN LATERAL (
  SELECT 
    COUNT(DISTINCT c.id) AS contact_count,
    COUNT(DISTINCT d.id) AS deal_count,
    COUNT(DISTINCT t.id) AS task_count,
    COUNT(DISTINCT lst.id) AS list_count,
    array_agg(DISTINCT li.list_id::TEXT) FILTER (WHERE li.list_id IS NOT NULL) AS list_ids
  FROM contacts c
  FULL OUTER JOIN deals d ON d.source_id = l.listing_id AND d.deleted_at IS NULL
  FULL OUTER JOIN tasks t ON t.related_type = 'listing' AND t.related_id = l.listing_id AND t.deleted_at IS NULL
  FULL OUTER JOIN list_items li ON li.item_type = 'listing' AND li.item_id = l.listing_id AND li.deleted_at IS NULL
  FULL OUTER JOIN lists lst ON li.list_id = lst.id AND lst.deleted_at IS NULL
  WHERE c.source_id = l.listing_id 
    AND c.deleted_at IS NULL
) AS crm_stats ON TRUE
WHERE l.active = TRUE;

-- Indexes for view performance (on underlying tables)
-- These should be created by index_optimization_schema.sql

-- Comments
COMMENT ON VIEW prospect_enrich_view IS 
  'Optimized view for Prospect & Enrich UI page - combines listings, enrichment status, and CRM engagement data';

-- Grant permissions
GRANT SELECT ON prospect_enrich_view TO authenticated;

