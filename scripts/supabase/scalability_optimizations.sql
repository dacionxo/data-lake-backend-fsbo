-- ============================================================================
-- Scalability Optimizations for 500 Concurrent Users
-- ============================================================================
-- This schema adds performance optimizations to ensure the system scales
-- efficiently with 500 concurrent users on the front end.
--
-- INDEPENDENT SCHEMA: This file can be run standalone or after complete_schema.sql
-- All operations check for table existence and handle missing objects gracefully
--
-- KEY OPTIMIZATIONS:
-- 1. Enhanced RLS policies with soft-delete filtering
-- 2. Composite indexes for common query patterns
-- 3. Query optimization for high-frequency operations
-- 4. Connection pooling recommendations (documented in comments)
-- 5. Materialized view refresh strategies
-- 6. Pagination support indexes
-- ============================================================================

-- Ensure uuid extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ENHANCED RLS POLICIES WITH SOFT-DELETE FILTERING
-- ============================================================================
-- Update RLS policies to automatically filter soft-deleted records
-- This is critical for performance with 500 users querying simultaneously

-- Contacts policies with soft-delete filtering
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'contacts') THEN
    -- Drop old policies if they exist
    DROP POLICY IF EXISTS "Users can view their own contacts" ON contacts;
    DROP POLICY IF EXISTS "Users can update their own contacts" ON contacts;
    DROP POLICY IF EXISTS "Users can delete their own contacts" ON contacts;
    DROP POLICY IF EXISTS "Users can view their own active contacts" ON contacts;
    DROP POLICY IF EXISTS "Users can update their own active contacts" ON contacts;
    
    -- Create enhanced policies with soft-delete filtering
    CREATE POLICY "Users can view their own active contacts" ON contacts
      FOR SELECT 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can update their own active contacts" ON contacts
      FOR UPDATE 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can delete their own contacts" ON contacts
      FOR DELETE 
      USING (user_id = auth.uid());
  END IF;
END $$;

-- Deals policies with soft-delete filtering
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'deals') THEN
    DROP POLICY IF EXISTS "Users can view their own deals" ON deals;
    DROP POLICY IF EXISTS "Users can update their own deals" ON deals;
    DROP POLICY IF EXISTS "Users can delete their own deals" ON deals;
    DROP POLICY IF EXISTS "Users can view their own active deals" ON deals;
    DROP POLICY IF EXISTS "Users can update their own active deals" ON deals;
    
    CREATE POLICY "Users can view their own active deals" ON deals
      FOR SELECT 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can update their own active deals" ON deals
      FOR UPDATE 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can delete their own deals" ON deals
      FOR DELETE 
      USING (user_id = auth.uid());
  END IF;
END $$;

-- Tasks policies with soft-delete filtering
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'tasks') THEN
    DROP POLICY IF EXISTS "Users can view their own tasks" ON tasks;
    DROP POLICY IF EXISTS "Users can update their own tasks" ON tasks;
    DROP POLICY IF EXISTS "Users can delete their own tasks" ON tasks;
    DROP POLICY IF EXISTS "Users can view their own active tasks" ON tasks;
    DROP POLICY IF EXISTS "Users can update their own active tasks" ON tasks;
    
    CREATE POLICY "Users can view their own active tasks" ON tasks
      FOR SELECT 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can update their own active tasks" ON tasks
      FOR UPDATE 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can delete their own tasks" ON tasks
      FOR DELETE 
      USING (user_id = auth.uid());
  END IF;
END $$;

-- Lists policies with soft-delete filtering
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'lists') THEN
    DROP POLICY IF EXISTS "Users can view their own lists" ON lists;
    DROP POLICY IF EXISTS "Users can update their own lists" ON lists;
    DROP POLICY IF EXISTS "Users can delete their own lists" ON lists;
    DROP POLICY IF EXISTS "Users can view their own active lists" ON lists;
    DROP POLICY IF EXISTS "Users can update their own active lists" ON lists;
    
    CREATE POLICY "Users can view their own active lists" ON lists
      FOR SELECT 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can update their own active lists" ON lists
      FOR UPDATE 
      USING (user_id = auth.uid() AND deleted_at IS NULL);
    
    CREATE POLICY "Users can delete their own lists" ON lists
      FOR DELETE 
      USING (user_id = auth.uid());
  END IF;
END $$;

-- List items policies with soft-delete filtering
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'list_items') THEN
    DROP POLICY IF EXISTS "Users can view items in their lists" ON list_items;
    DROP POLICY IF EXISTS "Users can delete items from their lists" ON list_items;
    DROP POLICY IF EXISTS "Users can view active items in their lists" ON list_items;
    
    CREATE POLICY "Users can view active items in their lists" ON list_items
      FOR SELECT 
      USING (
        deleted_at IS NULL AND
        EXISTS (
          SELECT 1 FROM lists
          WHERE lists.id = list_items.list_id
          AND lists.user_id = auth.uid()
          AND lists.deleted_at IS NULL
        )
      );
    
    CREATE POLICY "Users can delete items from their lists" ON list_items
      FOR DELETE 
      USING (
        EXISTS (
          SELECT 1 FROM lists
          WHERE lists.id = list_items.list_id
          AND lists.user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- ============================================================================
-- COMPOSITE INDEXES FOR HIGH-FREQUENCY QUERY PATTERNS
-- ============================================================================
-- These indexes optimize the most common queries executed by 500 users

-- Contacts indexes
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'contacts') THEN
    -- User + Status + Created Date (common dashboard queries)
    CREATE INDEX IF NOT EXISTS idx_contacts_user_status_created_at 
      ON contacts(user_id, status, created_at DESC) 
      WHERE deleted_at IS NULL;
    
    -- User + Email lookup (duplicate checking)
    CREATE INDEX IF NOT EXISTS idx_contacts_user_email_lookup 
      ON contacts(user_id, LOWER(email)) 
      WHERE deleted_at IS NULL AND email IS NOT NULL;
    
    -- User + Phone lookup
    CREATE INDEX IF NOT EXISTS idx_contacts_user_phone_lookup 
      ON contacts(user_id, phone) 
      WHERE deleted_at IS NULL AND phone IS NOT NULL;
    
    -- Pagination index
    CREATE INDEX IF NOT EXISTS idx_contacts_user_created_at_pagination 
      ON contacts(user_id, created_at DESC, id) 
      WHERE deleted_at IS NULL;
    
    -- Date aggregation index
    CREATE INDEX IF NOT EXISTS idx_contacts_user_created_date 
      ON contacts(user_id, (created_at AT TIME ZONE 'UTC')::date) 
      WHERE deleted_at IS NULL;
    
    -- Covering index for common queries
    CREATE INDEX IF NOT EXISTS idx_contacts_covering_user_status 
      ON contacts(user_id, status, id, email, phone, created_at) 
      WHERE deleted_at IS NULL;
  END IF;
END $$;

-- Deals indexes
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'deals') THEN
    -- User + Stage + Value (pipeline views)
    CREATE INDEX IF NOT EXISTS idx_deals_user_stage_value_created 
      ON deals(user_id, stage, value DESC, created_at DESC) 
      WHERE deleted_at IS NULL;
    
    -- User + Expected Close Date (upcoming deals)
    CREATE INDEX IF NOT EXISTS idx_deals_user_close_date 
      ON deals(user_id, expected_close_date) 
      WHERE deleted_at IS NULL AND expected_close_date IS NOT NULL;
    
    -- Pagination index
    CREATE INDEX IF NOT EXISTS idx_deals_user_created_at_pagination 
      ON deals(user_id, created_at DESC, id) 
      WHERE deleted_at IS NULL;
    
    -- Date aggregation index
    CREATE INDEX IF NOT EXISTS idx_deals_user_created_date 
      ON deals(user_id, (created_at AT TIME ZONE 'UTC')::date) 
      WHERE deleted_at IS NULL;
    
    -- Covering index
    CREATE INDEX IF NOT EXISTS idx_deals_covering_user_stage 
      ON deals(user_id, stage, id, value, expected_close_date, created_at) 
      WHERE deleted_at IS NULL;
  END IF;
END $$;

-- Tasks indexes
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'tasks') THEN
    -- User + Status + Due Date (task list views)
    CREATE INDEX IF NOT EXISTS idx_tasks_user_status_due_priority 
      ON tasks(user_id, status, due_date, priority, created_at DESC) 
      WHERE deleted_at IS NULL;
    
    -- User + Related Entity (tasks by contact/deal)
    CREATE INDEX IF NOT EXISTS idx_tasks_user_related 
      ON tasks(user_id, related_type, related_id) 
      WHERE deleted_at IS NULL AND related_type IS NOT NULL;
    
    -- Pagination index
    CREATE INDEX IF NOT EXISTS idx_tasks_user_created_at_pagination 
      ON tasks(user_id, created_at DESC, id) 
      WHERE deleted_at IS NULL;
  END IF;
END $$;

-- Lists indexes
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'lists') THEN
    -- User + Type + Updated (list views)
    CREATE INDEX IF NOT EXISTS idx_lists_user_type_updated 
      ON lists(user_id, type, updated_at DESC) 
      WHERE deleted_at IS NULL;
  END IF;
END $$;

-- List items indexes
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'list_items') THEN
    -- List + Type + Created (pagination)
    CREATE INDEX IF NOT EXISTS idx_list_items_list_type_created 
      ON list_items(list_id, item_type, created_at DESC) 
      WHERE deleted_at IS NULL;
  END IF;
END $$;

-- ============================================================================
-- LISTINGS QUERY OPTIMIZATIONS (Universal Access with 500 Users)
-- ============================================================================
-- Optimize queries for "Prospect & Enrich" page with many concurrent users

DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'listings') THEN
    -- Composite index for common filtering (city, state, status, price range)
    CREATE INDEX IF NOT EXISTS idx_listings_filter_composite 
      ON listings(city, state, status, active, list_price, created_at DESC) 
      WHERE active = TRUE;
    
    -- Full-text search index for description searches
    CREATE INDEX IF NOT EXISTS idx_listings_text_search_gin 
      ON listings USING gin(to_tsvector('english', COALESCE(text, '') || ' ' || COALESCE(street, '')));
    
    -- Pipeline status queries (very common)
    CREATE INDEX IF NOT EXISTS idx_listings_pipeline_status_active 
      ON listings(pipeline_status, active, created_at DESC) 
      WHERE active = TRUE AND pipeline_status IS NOT NULL;
    
    -- Pagination index
    CREATE INDEX IF NOT EXISTS idx_listings_created_at_pagination 
      ON listings(created_at DESC, listing_id) 
      WHERE active = TRUE;
    
    -- Geospatial index (if earthdistance extension available)
    BEGIN
      CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;
      CREATE INDEX IF NOT EXISTS idx_listings_geospatial 
        ON listings USING gist(
          ll_to_earth(lat::double precision, lng::double precision)
        ) 
        WHERE lat IS NOT NULL AND lng IS NOT NULL;
    EXCEPTION WHEN OTHERS THEN
      -- Extension may not be available, skip geospatial index
      NULL;
    END;
  END IF;
END $$;

-- ============================================================================
-- QUERY PERFORMANCE FUNCTIONS
-- ============================================================================
-- Optimized functions for common operations with 500 users

-- Optimized function to get user dashboard summary
CREATE OR REPLACE FUNCTION get_user_dashboard_summary(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'contacts_count', (
      SELECT COUNT(*) FROM contacts 
      WHERE user_id = p_user_id AND deleted_at IS NULL
    ),
    'active_deals_count', (
      SELECT COUNT(*) FROM deals 
      WHERE user_id = p_user_id 
      AND deleted_at IS NULL
      AND stage NOT IN ('closed_won', 'closed_lost')
    ),
    'active_tasks_count', (
      SELECT COUNT(*) FROM tasks 
      WHERE user_id = p_user_id 
      AND deleted_at IS NULL
      AND status NOT IN ('completed', 'cancelled')
    ),
    'total_listings', (
      SELECT COUNT(*) FROM listings WHERE active = TRUE
    ),
    'recent_contacts', (
      SELECT COUNT(*) FROM contacts 
      WHERE user_id = p_user_id 
      AND deleted_at IS NULL
      AND created_at >= NOW() - INTERVAL '7 days'
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- MATERIALIZED VIEW REFRESH OPTIMIZATION
-- ============================================================================
-- Schedule materialized view refreshes for 500-user load

-- Function to refresh dashboard aggregations (call via pg_cron)
CREATE OR REPLACE FUNCTION refresh_dashboard_views_for_users()
RETURNS VOID AS $$
BEGIN
  -- Refresh materialized views that support dashboards (only if they exist)
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'lead_counts_by_category') THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY lead_counts_by_category;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'status_funnel') THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY status_funnel;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'market_statistics') THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY market_statistics;
  END IF;
  
  IF EXISTS (SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'user_activity_summary') THEN
    REFRESH MATERIALIZED VIEW CONCURRENTLY user_activity_summary;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MONITORING AND ALERTS
-- ============================================================================
-- Functions to monitor performance with 500 users

CREATE OR REPLACE FUNCTION check_database_performance()
RETURNS TABLE (
  metric_name TEXT,
  metric_value NUMERIC,
  threshold NUMERIC,
  status TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    'active_connections'::TEXT,
    (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active')::NUMERIC,
    200::NUMERIC, -- Alert if > 200 active connections
    CASE 
      WHEN (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active') > 200 
      THEN 'WARNING'
      ELSE 'OK'
    END::TEXT
    
  UNION ALL
  
  SELECT 
    'slow_queries'::TEXT,
    (SELECT COUNT(*) FROM pg_stat_activity 
     WHERE state = 'active' AND query_start < NOW() - INTERVAL '30 seconds')::NUMERIC,
    10::NUMERIC, -- Alert if > 10 slow queries
    CASE 
      WHEN (SELECT COUNT(*) FROM pg_stat_activity 
            WHERE state = 'active' AND query_start < NOW() - INTERVAL '30 seconds') > 10 
      THEN 'WARNING'
      ELSE 'OK'
    END::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMMENTS AND DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION get_user_dashboard_summary IS 
  'Optimized dashboard summary for single user. Use instead of multiple queries. Critical for 500-user performance.';

COMMENT ON FUNCTION refresh_dashboard_views_for_users IS 
  'Refresh dashboard aggregations. Schedule every 5-15 minutes via pg_cron for optimal 500-user performance.';

COMMENT ON FUNCTION check_database_performance IS 
  'Monitor database performance metrics for 500-user load. Run periodically.';

-- ============================================================================
-- CONNECTION POOLING RECOMMENDATIONS (Documentation Only)
-- ============================================================================
--
-- Recommended Supabase connection pooling settings for 500 users:
-- - Transaction pool: 100-200 connections
-- - Session pool: 50-100 connections  
-- - Use Supabase connection pooler for optimal performance
-- - Connection string should use pooler.supabase.com (not db.supabase.com)
--
-- Configure in Supabase Dashboard:
-- Settings → Database → Connection Pooling
-- Mode: Transaction
-- Pool Size: 100-200 connections
--
-- LeadMap-main Configuration:
-- Use NEXT_PUBLIC_SUPABASE_URL with pooler endpoint
-- All API routes should use transaction pool mode
--
-- ============================================================================
-- END OF SCALABILITY OPTIMIZATIONS
-- ============================================================================
