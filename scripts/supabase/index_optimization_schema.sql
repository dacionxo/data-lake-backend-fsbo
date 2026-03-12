-- ============================================================================
-- Index Optimization Schema
-- ============================================================================
-- This schema reviews and extends indexes on high-volume lead queries used
-- by LeadMap-main for optimal performance.
--
-- INDEX STRATEGY:
-- - Composite indexes for common filter combinations
-- - Partial indexes for common WHERE clauses
-- - Covering indexes for frequently queried columns
-- - Indexes on foreign keys and join columns
-- ============================================================================

-- ============================================================================
-- COMPOSITE INDEXES FOR COMMON QUERY PATTERNS
-- ============================================================================

-- Listings: Common filter combinations
CREATE INDEX IF NOT EXISTS idx_listings_state_city ON listings(state, city);
CREATE INDEX IF NOT EXISTS idx_listings_state_status ON listings(state, status);
CREATE INDEX IF NOT EXISTS idx_listings_state_created_at ON listings(state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_status_active ON listings(status, active) WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS idx_listings_state_price ON listings(state, list_price) WHERE list_price IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_pipeline_status_active ON listings(pipeline_status, active) WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS idx_listings_user_status ON listings(user_id, status) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_city_state_status ON listings(city, state, status);

-- FSBO Leads: Common filter combinations
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_city ON fsbo_leads(state, city);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_status ON fsbo_leads(state, status);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_created_at ON fsbo_leads(state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_status_active ON fsbo_leads(status, active) WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_price ON fsbo_leads(state, list_price) WHERE list_price IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_pipeline_status ON fsbo_leads(pipeline_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_user_status ON fsbo_leads(user_id, status) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_city_state_status ON fsbo_leads(city, state, status);

-- Expired Listings: Common filter combinations
CREATE INDEX IF NOT EXISTS idx_expired_listings_state_city ON expired_listings(state, city);
CREATE INDEX IF NOT EXISTS idx_expired_listings_state_status ON expired_listings(state, status);
CREATE INDEX IF NOT EXISTS idx_expired_listings_state_created_at ON expired_listings(state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_expired_listings_expired_date_state ON expired_listings(expired_date, state) WHERE expired_date IS NOT NULL;

-- FRBO Leads: Common filter combinations
CREATE INDEX IF NOT EXISTS idx_frbo_leads_state_city ON frbo_leads(state, city);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_state_status ON frbo_leads(state, status);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_state_created_at ON frbo_leads(state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_available_date_state ON frbo_leads(available_date, state) WHERE available_date IS NOT NULL;

-- Foreclosure Listings: Common filter combinations
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_state_city ON foreclosure_listings(state, city);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_state_created_at ON foreclosure_listings(state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_auction_date_state ON foreclosure_listings(auction_date, state) WHERE auction_date IS NOT NULL;

-- Imports: User-specific queries
CREATE INDEX IF NOT EXISTS idx_imports_user_created_at ON imports(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_imports_user_status ON imports(user_id, status);
CREATE INDEX IF NOT EXISTS idx_imports_user_city_state ON imports(user_id, city, state);

-- ============================================================================
-- PIPELINE STATUS INDEXES
-- ============================================================================

-- Listings with pipeline status
CREATE INDEX IF NOT EXISTS idx_listings_pipeline_status_created ON listings(pipeline_status, created_at DESC) WHERE pipeline_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_pipeline_status_created ON fsbo_leads(pipeline_status, created_at DESC) WHERE pipeline_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_expired_listings_pipeline_status ON expired_listings(pipeline_status) WHERE pipeline_status IS NOT NULL;

-- ============================================================================
-- PRICE RANGE INDEXES
-- ============================================================================

-- For price filtering queries
CREATE INDEX IF NOT EXISTS idx_listings_price_range ON listings(list_price) WHERE list_price IS NOT NULL AND list_price > 0;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_price_range ON fsbo_leads(list_price) WHERE list_price IS NOT NULL AND list_price > 0;
CREATE INDEX IF NOT EXISTS idx_frbo_leads_price_range ON frbo_leads(list_price) WHERE list_price IS NOT NULL AND list_price > 0;

-- ============================================================================
-- CRM TABLE INDEXES
-- ============================================================================

-- Tasks: Common query patterns
CREATE INDEX IF NOT EXISTS idx_tasks_user_status_due ON tasks(user_id, status, due_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_user_priority ON tasks(user_id, priority, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_user_completed ON tasks(user_id, status, completed_at DESC) WHERE deleted_at IS NULL AND status = 'completed';

-- Contacts: Common query patterns
CREATE INDEX IF NOT EXISTS idx_contacts_user_status ON contacts(user_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_user_created_at ON contacts(user_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_user_email ON contacts(user_id, email) WHERE deleted_at IS NULL AND email IS NOT NULL;

-- Deals: Common query patterns
CREATE INDEX IF NOT EXISTS idx_deals_user_stage ON deals(user_id, stage) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_user_stage_value ON deals(user_id, stage, value DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_user_expected_close ON deals(user_id, expected_close_date) WHERE deleted_at IS NULL AND expected_close_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_deals_stage_probability ON deals(stage, probability) WHERE deleted_at IS NULL;

-- Lists: Common query patterns
CREATE INDEX IF NOT EXISTS idx_lists_user_type ON lists(user_id, type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lists_user_updated_at ON lists(user_id, updated_at DESC) WHERE deleted_at IS NULL;

-- List Items: Common query patterns
CREATE INDEX IF NOT EXISTS idx_list_items_list_type ON list_items(list_id, item_type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_list_items_type_id ON list_items(item_type, item_id) WHERE deleted_at IS NULL;

-- ============================================================================
-- FULL TEXT SEARCH INDEXES
-- ============================================================================

-- For text search on descriptions and notes
CREATE INDEX IF NOT EXISTS idx_listings_text_search ON listings USING gin(to_tsvector('english', COALESCE(text, '')));
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_text_search ON fsbo_leads USING gin(to_tsvector('english', COALESCE(text, '')));
CREATE INDEX IF NOT EXISTS idx_contacts_text_search ON contacts USING gin(to_tsvector('english', COALESCE(notes, '') || ' ' || COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')));
CREATE INDEX IF NOT EXISTS idx_deals_text_search ON deals USING gin(to_tsvector('english', COALESCE(description, '') || ' ' || COALESCE(notes, '')));

-- ============================================================================
-- COVERING INDEXES (Include frequently selected columns)
-- ============================================================================

-- Listings: Covering index for common SELECT queries
CREATE INDEX IF NOT EXISTS idx_listings_covering_state_city 
ON listings(state, city, listing_id, property_url, list_price, status, created_at)
WHERE active = TRUE;

-- FSBO Leads: Covering index
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_covering_state_city
ON fsbo_leads(state, city, listing_id, property_url, list_price, status, created_at)
WHERE active = TRUE;

-- ============================================================================
-- ANALYTICS INDEXES
-- ============================================================================

-- For dashboard aggregation queries
CREATE INDEX IF NOT EXISTS idx_listings_state_status_created ON listings(state, status, date_trunc('day', (created_at AT TIME ZONE 'UTC')));
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_status_created ON fsbo_leads(state, status, date_trunc('day', (created_at AT TIME ZONE 'UTC')));
CREATE INDEX IF NOT EXISTS idx_deals_user_stage_closed ON deals(user_id, stage, closed_date) WHERE deleted_at IS NULL AND closed_date IS NOT NULL;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON INDEX idx_listings_state_city IS 'Optimized for filtering by state and city (common LeadMap-main query)';
COMMENT ON INDEX idx_listings_state_status IS 'Optimized for filtering by state and status';
COMMENT ON INDEX idx_listings_pipeline_status_active IS 'Optimized for pipeline status queries on active listings';
COMMENT ON INDEX idx_fsbo_leads_state_city IS 'Optimized for FSBO filtering by state and city';
COMMENT ON INDEX idx_tasks_user_status_due IS 'Optimized for task queries by user, status, and due date';
COMMENT ON INDEX idx_deals_user_stage_value IS 'Optimized for deal queries by user, stage, and value';

