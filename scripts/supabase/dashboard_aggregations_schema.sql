-- ============================================================================
-- Dashboard Aggregation Schema
-- ============================================================================
-- This schema creates aggregation tables and materialized views for
-- dashboard analytics in LeadMap-main.
--
-- AGGREGATIONS:
-- - Lead counts by category and status
-- - Status funnels (pipeline progression)
-- - Per-market statistics
-- - User activity summaries
-- ============================================================================

-- ============================================================================
-- MATERIALIZED VIEWS FOR DASHBOARDS
-- ============================================================================

-- Lead Counts by Category
-- Aggregates lead counts grouped by category (FSBO, expired, etc.) and status
CREATE MATERIALIZED VIEW IF NOT EXISTS lead_counts_by_category AS
SELECT 
  'fsbo_leads' AS category,
  status,
  state,
  city,
  COUNT(*) AS lead_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_count,
  AVG(list_price) AS avg_price,
  MIN(list_price) AS min_price,
  MAX(list_price) AS max_price,
  MIN(created_at) AS first_seen,
  MAX(created_at) AS last_seen
FROM fsbo_leads
GROUP BY status, state, city

UNION ALL

SELECT 
  'expired_listings' AS category,
  status,
  state,
  city,
  COUNT(*) AS lead_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_count,
  AVG(list_price) AS avg_price,
  MIN(list_price) AS min_price,
  MAX(list_price) AS max_price,
  MIN(created_at) AS first_seen,
  MAX(created_at) AS last_seen
FROM expired_listings
GROUP BY status, state, city

UNION ALL

SELECT 
  'frbo_leads' AS category,
  status,
  state,
  city,
  COUNT(*) AS lead_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_count,
  AVG(list_price) AS avg_price,
  MIN(list_price) AS min_price,
  MAX(list_price) AS max_price,
  MIN(created_at) AS first_seen,
  MAX(created_at) AS last_seen
FROM frbo_leads
GROUP BY status, state, city

UNION ALL

SELECT 
  'foreclosure_listings' AS category,
  status,
  state,
  city,
  COUNT(*) AS lead_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_count,
  AVG(list_price) AS avg_price,
  MIN(list_price) AS min_price,
  MAX(list_price) AS max_price,
  MIN(created_at) AS first_seen,
  MAX(created_at) AS last_seen
FROM foreclosure_listings
GROUP BY status, state, city;

-- Indexes for materialized view
CREATE INDEX IF NOT EXISTS idx_lead_counts_category_status ON lead_counts_by_category(category, status);
CREATE INDEX IF NOT EXISTS idx_lead_counts_state_city ON lead_counts_by_category(state, city);
CREATE INDEX IF NOT EXISTS idx_lead_counts_category_state ON lead_counts_by_category(category, state);

-- Status Funnel View
-- Shows progression through pipeline statuses
CREATE MATERIALIZED VIEW IF NOT EXISTS status_funnel AS
SELECT 
  pipeline_status,
  COUNT(*) AS total_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  COUNT(CASE WHEN status = 'fsbo' THEN 1 END) AS fsbo_count,
  COUNT(CASE WHEN status = 'expired' THEN 1 END) AS expired_count,
  COUNT(CASE WHEN status = 'frbo' THEN 1 END) AS frbo_count,
  AVG(list_price) AS avg_price,
  MIN(created_at) AS oldest_lead,
  MAX(created_at) AS newest_lead
FROM (
  SELECT pipeline_status, active, status, list_price, created_at FROM listings
  UNION ALL
  SELECT pipeline_status, active, status, list_price, created_at FROM fsbo_leads
  UNION ALL
  SELECT pipeline_status, active, status, list_price, created_at FROM expired_listings
  UNION ALL
  SELECT pipeline_status, active, status, list_price, created_at FROM frbo_leads
  UNION ALL
  SELECT pipeline_status, active, status, list_price, created_at FROM foreclosure_listings
) AS all_leads
WHERE pipeline_status IS NOT NULL
GROUP BY pipeline_status
ORDER BY 
  CASE pipeline_status
    WHEN 'new' THEN 1
    WHEN 'normalized' THEN 2
    WHEN 'enriched' THEN 3
    WHEN 'validated' THEN 4
    WHEN 'ready' THEN 5
    ELSE 6
  END;

CREATE INDEX IF NOT EXISTS idx_status_funnel_status ON status_funnel(pipeline_status);

-- Per-Market Statistics
-- Aggregates statistics by market (city/state combination)
CREATE MATERIALIZED VIEW IF NOT EXISTS market_statistics AS
SELECT 
  city,
  state,
  COUNT(*) AS total_leads,
  COUNT(DISTINCT CASE WHEN source_table = 'listings' THEN listing_id END) AS listings_count,
  COUNT(DISTINCT CASE WHEN source_table = 'fsbo_leads' THEN listing_id END) AS fsbo_count,
  COUNT(DISTINCT CASE WHEN source_table = 'expired_listings' THEN listing_id END) AS expired_count,
  COUNT(DISTINCT CASE WHEN source_table = 'frbo_leads' THEN listing_id END) AS frbo_count,
  COUNT(DISTINCT CASE WHEN source_table = 'foreclosure_listings' THEN listing_id END) AS foreclosure_count,
  AVG(list_price) AS avg_price,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY list_price) AS median_price,
  MIN(list_price) AS min_price,
  MAX(list_price) AS max_price,
  AVG(sqft) AS avg_sqft,
  AVG(CASE WHEN year_built IS NOT NULL THEN year_built END) AS avg_year_built,
  COUNT(CASE WHEN lat IS NOT NULL AND lng IS NOT NULL THEN 1 END) AS geocoded_count,
  MIN(created_at) AS market_first_seen,
  MAX(created_at) AS market_last_seen
FROM (
  SELECT 'listings' AS source_table, listing_id, city, state, list_price, sqft, year_built, lat, lng, created_at FROM listings WHERE active = TRUE
  UNION ALL
  SELECT 'fsbo_leads' AS source_table, listing_id, city, state, list_price, sqft, year_built, lat, lng, created_at FROM fsbo_leads WHERE active = TRUE
  UNION ALL
  SELECT 'expired_listings' AS source_table, listing_id, city, state, list_price, sqft, year_built, lat, lng, created_at FROM expired_listings WHERE active = TRUE
  UNION ALL
  SELECT 'frbo_leads' AS source_table, listing_id, city, state, list_price, sqft, year_built, lat, lng, created_at FROM frbo_leads WHERE active = TRUE
  UNION ALL
  SELECT 'foreclosure_listings' AS source_table, listing_id, city, state, list_price, sqft, year_built, lat, lng, created_at FROM foreclosure_listings WHERE active = TRUE
) AS all_leads
WHERE city IS NOT NULL AND state IS NOT NULL
GROUP BY city, state
HAVING COUNT(*) >= 5; -- Only include markets with at least 5 leads

CREATE INDEX IF NOT EXISTS idx_market_stats_state_city ON market_statistics(state, city);
CREATE INDEX IF NOT EXISTS idx_market_stats_total_leads ON market_statistics(total_leads DESC);

-- User Activity Summary
-- Aggregates user-specific activity for dashboard
CREATE MATERIALIZED VIEW IF NOT EXISTS user_activity_summary AS
SELECT 
  u.id AS user_id,
  u.email,
  u.name,
  
  -- CRM activity
  COUNT(DISTINCT c.id) AS contacts_count,
  COUNT(DISTINCT CASE WHEN c.created_at >= NOW() - INTERVAL '30 days' THEN c.id END) AS contacts_last_30_days,
  
  COUNT(DISTINCT d.id) AS deals_count,
  COUNT(DISTINCT CASE WHEN d.stage NOT IN ('closed_won', 'closed_lost') THEN d.id END) AS active_deals_count,
  COUNT(DISTINCT CASE WHEN d.stage = 'closed_won' THEN d.id END) AS won_deals_count,
  SUM(CASE WHEN d.stage = 'closed_won' THEN d.value ELSE 0 END) AS total_revenue,
  
  COUNT(DISTINCT t.id) AS tasks_count,
  COUNT(DISTINCT CASE WHEN t.status NOT IN ('completed', 'cancelled') THEN t.id END) AS active_tasks_count,
  
  COUNT(DISTINCT l.id) AS lists_count,
  
  -- Lead engagement
  COUNT(DISTINCT li.list_id) AS engaged_listings_count,
  
  -- Recent activity
  MAX(GREATEST(
    (SELECT MAX(created_at) FROM contacts WHERE user_id = u.id),
    (SELECT MAX(created_at) FROM deals WHERE user_id = u.id),
    (SELECT MAX(created_at) FROM tasks WHERE user_id = u.id)
  )) AS last_activity_at

FROM users u
LEFT JOIN contacts c ON u.id = c.user_id
LEFT JOIN deals d ON u.id = d.user_id
LEFT JOIN tasks t ON u.id = t.user_id
LEFT JOIN lists l ON u.id = l.user_id
LEFT JOIN list_items li ON l.id = li.list_id AND li.item_type = 'listing'
GROUP BY u.id, u.email, u.name;

CREATE INDEX IF NOT EXISTS idx_user_activity_user_id ON user_activity_summary(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activity_last_activity ON user_activity_summary(last_activity_at DESC);

-- ============================================================================
-- REFRESH FUNCTIONS
-- ============================================================================

-- Function to refresh all materialized views
CREATE OR REPLACE FUNCTION refresh_dashboard_aggregations()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY lead_counts_by_category;
  REFRESH MATERIALIZED VIEW CONCURRENTLY status_funnel;
  REFRESH MATERIALIZED VIEW CONCURRENTLY market_statistics;
  REFRESH MATERIALIZED VIEW CONCURRENTLY user_activity_summary;
END;
$$ LANGUAGE plpgsql;

-- Function to refresh specific aggregation
CREATE OR REPLACE FUNCTION refresh_aggregation(p_view_name TEXT)
RETURNS VOID AS $$
BEGIN
  CASE p_view_name
    WHEN 'lead_counts_by_category' THEN
      REFRESH MATERIALIZED VIEW CONCURRENTLY lead_counts_by_category;
    WHEN 'status_funnel' THEN
      REFRESH MATERIALIZED VIEW CONCURRENTLY status_funnel;
    WHEN 'market_statistics' THEN
      REFRESH MATERIALIZED VIEW CONCURRENTLY market_statistics;
    WHEN 'user_activity_summary' THEN
      REFRESH MATERIALIZED VIEW CONCURRENTLY user_activity_summary;
    ELSE
      RAISE EXCEPTION 'Unknown materialized view: %', p_view_name;
  END CASE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUTOMATED REFRESH (via cron or scheduled job)
-- ============================================================================
-- Note: Materialized views should be refreshed periodically
-- Recommend: Refresh every 5-15 minutes for dashboards
-- Can be triggered by:
-- - Supabase pg_cron extension
-- - External cron job
-- - Database trigger on data changes

-- Example pg_cron schedule (uncomment if pg_cron is enabled):
-- SELECT cron.schedule('refresh-dashboard-aggregations', '*/15 * * * *', 'SELECT refresh_dashboard_aggregations();');

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON MATERIALIZED VIEW lead_counts_by_category IS 
  'Aggregated lead counts by category, status, and location for dashboard analytics';

COMMENT ON MATERIALIZED VIEW status_funnel IS 
  'Pipeline status funnel showing progression through processing stages';

COMMENT ON MATERIALIZED VIEW market_statistics IS 
  'Per-market statistics aggregated by city/state for market analysis';

COMMENT ON MATERIALIZED VIEW user_activity_summary IS 
  'User-specific activity summary for dashboard display';

COMMENT ON FUNCTION refresh_dashboard_aggregations IS 
  'Refreshes all dashboard aggregation materialized views concurrently';

COMMENT ON FUNCTION refresh_aggregation IS 
  'Refreshes a specific dashboard aggregation materialized view';

