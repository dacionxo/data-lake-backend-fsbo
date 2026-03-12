-- ============================================================================
-- LeadMap Complete Database Schema (FULL VERSION WITH FIXES)
-- ============================================================================
-- This is the complete schema for LeadMap including all tables, indexes,
-- triggers, RLS policies (with fixes), and sample data.
-- 
-- MULTI-USER ARCHITECTURE:
-- This schema is designed to support multiple users with a hybrid data model:
-- - Universal shared data (listings) accessible to all users
-- - User-specific data (imports, trash, CRM data) isolated per user
-- 
-- Key Features:
-- - Universal Tables: listings (shared property data pool for all users)
-- - User-Specific Tables: imports, trash, tasks, contacts, deals, lists, list_items
-- - Category Tables: expired_listings, fsbo_leads, frbo_leads, foreclosure_listings (user-specific)
-- - RLS policies ensure proper data access control
-- - Indexes on user_id columns ensure optimal query performance
-- - CASCADE deletes ensure data cleanup when users are deleted
-- 
-- DATA ARCHITECTURE:
-- 
-- DATA LAKE ZONES:
-- This schema organizes data into three processing zones:
-- 
-- RAW ZONE (raw_* tables):
-- - raw_redfin_responses: Raw API responses from Redfin scraping
-- - raw_csv_imports: Raw CSV file imports before processing
-- - raw_apollo_imports: Raw Apollo.io API responses
-- - Purpose: Store unprocessed data from external sources
-- 
-- STAGING ZONE (staging/* tables):
-- - fsbo_raw: Normalized FSBO data extracted from raw responses
-- - import_staging: Normalized data from CSV/API imports
-- - Purpose: Partially processed, normalized data ready for enrichment/validation
-- 
-- CURATED ZONE (production tables):
-- - listings: Fully processed and validated property listings
-- - fsbo_leads: Enriched and validated FSBO leads
-- - expired_listings, frbo_leads, foreclosure_listings: Curated category data
-- - contacts, deals, tasks, lists, list_items: Curated CRM data
-- - imports: User-specific imported leads (final processed state)
-- - trash: User-specific soft-deleted items
-- - Purpose: Production-ready, validated data for application use
-- 
-- See: data_lake_zones_schema.sql for zone table definitions
-- See: data_lake_ingestion_schema.sql for pipeline tracking
-- 
-- UNIVERSAL TABLES (All Users Can Access):
-- - listings: Shared property data pool for "Prospect & Enrich" page
--   * user_id is optional/nullable (listings can be scraped by any user)
--   * All authenticated users can view all listings
-- 
-- - expired_listings, fsbo_leads, frbo_leads, foreclosure_listings: Category tables (universal)
--   * user_id is optional/nullable (category data is shared across all users)
--   * All authenticated users can view all category data
-- 
-- USER-SPECIFIC TABLES (Isolated Per User - Connected via auth.users email/password):
-- - imports: All imported leads go here (CSV, API, manual imports)
--   * user_id is required and references auth.users(id) - users only see their own imports
--   * This is where imported leads are stored (NOT in listings table)
--   * Connected to user's email/password authentication via auth.users
-- 
-- - trash: Recycling bin for soft-deleted leads
--   * user_id is required and references auth.users(id) - users only see their own trash
--   * Functions as a step before permanent deletion
--   * Users can restore items or permanently delete them
--   * Connected to user's email/password authentication via auth.users
-- 
-- - tasks, contacts, deals, lists, list_items: CRM data (user-specific)
--   * user_id is required and references auth.users(id)
--   * Connected to user's email/password authentication via auth.users
-- 
-- SHARED TABLES (with admin controls):
-- - email_templates (admins can manage, users can view)
-- - probate_leads (admins can manage, users can view)
-- - email_captures (public inserts, admin management)
-- 
-- INSTRUCTIONS:
-- 1. Go to your Supabase Dashboard
-- 2. Navigate to SQL Editor
-- 3. Click "New Query"
-- 4. Copy and paste this entire file
-- 5. Click "Run" (or press Ctrl+Enter)
-- 6. Wait for "Success" message
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- DROP EXISTING OBJECTS (Clean Slate)
-- ============================================================================
DROP TABLE IF EXISTS list_items CASCADE;
DROP TABLE IF EXISTS lists CASCADE;
DROP VIEW IF EXISTS list_counts CASCADE;
DROP VIEW IF EXISTS list_items_with_metadata CASCADE;
DROP FUNCTION IF EXISTS get_list_items_paginated(UUID, INTEGER, INTEGER, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_list_items_count(UUID, TEXT) CASCADE;
DROP TABLE IF EXISTS deals CASCADE;
DROP TABLE IF EXISTS contacts CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS email_captures CASCADE;
DROP TABLE IF EXISTS email_templates CASCADE;
DROP TABLE IF EXISTS probate_leads CASCADE;
DROP TABLE IF EXISTS price_history CASCADE;
DROP TABLE IF EXISTS status_history CASCADE;
-- Drop lead category tables
DROP TABLE IF EXISTS expired_listings CASCADE;
DROP TABLE IF EXISTS fsbo_leads CASCADE;
DROP TABLE IF EXISTS frbo_leads CASCADE;
DROP TABLE IF EXISTS imports CASCADE;
DROP TABLE IF EXISTS trash CASCADE;
DROP TABLE IF EXISTS foreclosure_listings CASCADE;
DROP TABLE IF EXISTS listings CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_lists_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_lists_updated_at_on_list_items_change() CASCADE;
DROP FUNCTION IF EXISTS update_last_scraped_at() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
-- Note: Triggers on list_items are automatically dropped when the table is dropped with CASCADE
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Drop data lake zone and ingestion tables if they exist
DROP TABLE IF EXISTS zone_transitions CASCADE;
DROP TABLE IF EXISTS import_staging CASCADE;
DROP TABLE IF EXISTS fsbo_raw CASCADE;
DROP TABLE IF EXISTS raw_apollo_imports CASCADE;
DROP TABLE IF EXISTS raw_csv_imports CASCADE;
DROP TABLE IF EXISTS raw_redfin_responses CASCADE;
DROP TABLE IF EXISTS pipeline_run_events CASCADE;
DROP TABLE IF EXISTS pipeline_runs CASCADE;
DROP TABLE IF EXISTS pipelines CASCADE;
DROP FUNCTION IF EXISTS update_pipeline_run_completion() CASCADE;
DROP FUNCTION IF EXISTS get_pipeline_run_summary(UUID) CASCADE;
DROP TRIGGER IF EXISTS trigger_update_pipeline_run_completion ON pipeline_runs CASCADE;

-- ============================================================================
-- DATA LAKE INGESTION METADATA SCHEMA
-- ============================================================================
-- This section defines tables for tracking all data pipelines, runs, and events.
-- These tables must be created before zone tables since zone tables reference pipeline_runs.
-- See: data_lake_ingestion_schema.sql for detailed documentation

-- Pipelines Table: Defines all data ingestion pipelines in the system
CREATE TABLE IF NOT EXISTS pipelines (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  pipeline_type TEXT NOT NULL CHECK (pipeline_type IN (
    'scraper', 'enrichment', 'geocoding', 'import', 'transformation', 'validation', 'sync'
  )),
  source_zone TEXT NOT NULL CHECK (source_zone IN ('raw', 'staging', 'curated', 'external')),
  target_zone TEXT NOT NULL CHECK (target_zone IN ('raw', 'staging', 'curated')),
  source_tables TEXT[],
  target_tables TEXT[],
  config JSONB,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_cron TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_pipelines_type ON pipelines(pipeline_type);
CREATE INDEX IF NOT EXISTS idx_pipelines_enabled ON pipelines(enabled);
CREATE INDEX IF NOT EXISTS idx_pipelines_target_zone ON pipelines(target_zone);

-- Pipeline Runs Table: Tracks individual executions of pipelines
CREATE TABLE IF NOT EXISTS pipeline_runs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pipeline_id UUID NOT NULL REFERENCES pipelines(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN (
    'queued', 'running', 'completed', 'failed', 'cancelled', 'timeout'
  )),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  records_processed INTEGER DEFAULT 0,
  records_succeeded INTEGER DEFAULT 0,
  records_failed INTEGER DEFAULT 0,
  error_message TEXT,
  error_stack TEXT,
  metadata JSONB,
  triggered_by TEXT,
  triggered_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_pipeline_id ON pipeline_runs(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_status ON pipeline_runs(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started_at ON pipeline_runs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_pipeline_status ON pipeline_runs(pipeline_id, status);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_triggered_by_user ON pipeline_runs(triggered_by_user_id);

-- Pipeline Run Events Table: Tracks granular events within pipeline runs
CREATE TABLE IF NOT EXISTS pipeline_run_events (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pipeline_run_id UUID NOT NULL REFERENCES pipeline_runs(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN (
    'start', 'progress', 'milestone', 'warning', 'error', 'checkpoint', 'complete', 'fail', 'cancel'
  )),
  event_level TEXT NOT NULL DEFAULT 'info' CHECK (event_level IN ('debug', 'info', 'warning', 'error', 'critical')),
  message TEXT NOT NULL,
  details JSONB,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_run_id ON pipeline_run_events(pipeline_run_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_type ON pipeline_run_events(event_type);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_level ON pipeline_run_events(event_level);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_occurred_at ON pipeline_run_events(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_run_type ON pipeline_run_events(pipeline_run_id, event_type);

-- Function to update pipeline_runs.completed_at and duration_seconds
CREATE OR REPLACE FUNCTION update_pipeline_run_completion()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('completed', 'failed', 'cancelled', 'timeout') AND NEW.completed_at IS NULL THEN
    NEW.completed_at = NOW();
    NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.completed_at - NEW.started_at))::INTEGER;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically set completed_at and duration_seconds
CREATE TRIGGER trigger_update_pipeline_run_completion
  BEFORE UPDATE ON pipeline_runs
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION update_pipeline_run_completion();

-- Function to get pipeline run summary
CREATE OR REPLACE FUNCTION get_pipeline_run_summary(p_run_id UUID)
RETURNS TABLE (
  run_id UUID,
  pipeline_name TEXT,
  status TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER,
  records_processed INTEGER,
  records_succeeded INTEGER,
  records_failed INTEGER,
  event_count INTEGER,
  error_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pr.id,
    p.name,
    pr.status,
    pr.started_at,
    pr.completed_at,
    pr.duration_seconds,
    pr.records_processed,
    pr.records_succeeded,
    pr.records_failed,
    COUNT(pre.id)::INTEGER as event_count,
    COUNT(CASE WHEN pre.event_level IN ('error', 'critical') THEN 1 END)::INTEGER as error_count
  FROM pipeline_runs pr
  JOIN pipelines p ON pr.pipeline_id = p.id
  LEFT JOIN pipeline_run_events pre ON pr.id = pre.pipeline_run_id
  WHERE pr.id = p_run_id
  GROUP BY pr.id, p.name, pr.status, pr.started_at, pr.completed_at, 
           pr.duration_seconds, pr.records_processed, pr.records_succeeded, pr.records_failed;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DATA LAKE ZONES SCHEMA
-- ============================================================================
-- This section introduces explicit data-lake "zones" to organize data by
-- processing stage: raw, staging, and curated.
-- See: data_lake_zones_schema.sql for detailed documentation

-- RAW ZONE TABLES: Store raw, unprocessed data from external sources

-- Raw Redfin Responses Table
CREATE TABLE IF NOT EXISTS raw_redfin_responses (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  response_data JSONB NOT NULL,
  url TEXT NOT NULL,
  status_code INTEGER,
  response_headers JSONB,
  scraped_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  processed BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_redfin_responses_scraped_at ON raw_redfin_responses(scraped_at DESC);
CREATE INDEX IF NOT EXISTS idx_raw_redfin_responses_processed ON raw_redfin_responses(processed);
CREATE INDEX IF NOT EXISTS idx_raw_redfin_responses_pipeline_run ON raw_redfin_responses(pipeline_run_id);

-- Raw CSV Imports Table
CREATE TABLE IF NOT EXISTS raw_csv_imports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  filename TEXT NOT NULL,
  file_size_bytes INTEGER,
  row_count INTEGER,
  raw_data JSONB NOT NULL,
  column_mapping JSONB,
  imported_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  processed BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_csv_imports_imported_by ON raw_csv_imports(imported_by);
CREATE INDEX IF NOT EXISTS idx_raw_csv_imports_processed ON raw_csv_imports(processed);
CREATE INDEX IF NOT EXISTS idx_raw_csv_imports_pipeline_run ON raw_csv_imports(pipeline_run_id);

-- Raw Apollo Imports Table
CREATE TABLE IF NOT EXISTS raw_apollo_imports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  list_id TEXT,
  response_data JSONB NOT NULL,
  imported_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  processed BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_apollo_imports_imported_by ON raw_apollo_imports(imported_by);
CREATE INDEX IF NOT EXISTS idx_raw_apollo_imports_processed ON raw_apollo_imports(processed);
CREATE INDEX IF NOT EXISTS idx_raw_apollo_imports_pipeline_run ON raw_apollo_imports(pipeline_run_id);

-- STAGING ZONE TABLES: Store normalized and partially processed data

-- FSBO Raw Table (Staging)
CREATE TABLE IF NOT EXISTS fsbo_raw (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  listing_id TEXT,
  property_url TEXT,
  raw_response_id UUID REFERENCES raw_redfin_responses(id) ON DELETE SET NULL,
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  status TEXT,
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  raw_data JSONB,
  normalized BOOLEAN NOT NULL DEFAULT FALSE,
  normalized_at TIMESTAMPTZ,
  enriched BOOLEAN NOT NULL DEFAULT FALSE,
  enriched_at TIMESTAMPTZ,
  validated BOOLEAN NOT NULL DEFAULT FALSE,
  validated_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_fsbo_raw_listing_id ON fsbo_raw(listing_id);
CREATE INDEX IF NOT EXISTS idx_fsbo_raw_normalized ON fsbo_raw(normalized);
CREATE INDEX IF NOT EXISTS idx_fsbo_raw_enriched ON fsbo_raw(enriched);
CREATE INDEX IF NOT EXISTS idx_fsbo_raw_pipeline_run ON fsbo_raw(pipeline_run_id);
CREATE INDEX IF NOT EXISTS idx_fsbo_raw_city_state ON fsbo_raw(city, state);

-- Import Staging Table
CREATE TABLE IF NOT EXISTS import_staging (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  raw_import_id UUID,
  import_type TEXT NOT NULL CHECK (import_type IN ('csv', 'apollo', 'manual', 'api')),
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  first_name TEXT,
  last_name TEXT,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  company TEXT,
  job_title TEXT,
  normalized_data JSONB NOT NULL,
  raw_data JSONB,
  validated BOOLEAN NOT NULL DEFAULT FALSE,
  validated_at TIMESTAMPTZ,
  enriched BOOLEAN NOT NULL DEFAULT FALSE,
  enriched_at TIMESTAMPTZ,
  moved_to_curated BOOLEAN NOT NULL DEFAULT FALSE,
  moved_at TIMESTAMPTZ,
  error_message TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_import_staging_import_type ON import_staging(import_type);
CREATE INDEX IF NOT EXISTS idx_import_staging_validated ON import_staging(validated);
CREATE INDEX IF NOT EXISTS idx_import_staging_user_id ON import_staging(user_id);
CREATE INDEX IF NOT EXISTS idx_import_staging_pipeline_run ON import_staging(pipeline_run_id);

-- Zone Transitions Table: Track when data moves between zones
CREATE TABLE IF NOT EXISTS zone_transitions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  source_zone TEXT NOT NULL CHECK (source_zone IN ('raw', 'staging', 'curated')),
  target_zone TEXT NOT NULL CHECK (target_zone IN ('raw', 'staging', 'curated')),
  source_table TEXT NOT NULL,
  target_table TEXT NOT NULL,
  source_record_id UUID NOT NULL,
  target_record_id UUID NOT NULL,
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  transitioned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  transitioned_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_zone_transitions_source ON zone_transitions(source_zone, source_table, source_record_id);
CREATE INDEX IF NOT EXISTS idx_zone_transitions_target ON zone_transitions(target_zone, target_table, target_record_id);
CREATE INDEX IF NOT EXISTS idx_zone_transitions_pipeline_run ON zone_transitions(pipeline_run_id);

-- ============================================================================
-- CREATE TABLES (CURATED ZONE - Existing Production Tables)
-- ============================================================================

-- Users Table
-- Stores user profile information, subscription status, and Stripe integration
CREATE TABLE users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  -- Note: Consider migrating to user_role lookup table (see enum_lookup_tables_schema.sql)
  trial_end TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  is_subscribed BOOLEAN NOT NULL DEFAULT FALSE,
  plan_tier TEXT NOT NULL DEFAULT 'free' CHECK (plan_tier IN ('free', 'starter', 'pro')),
  -- Note: Consider migrating to plan_tier lookup table (see enum_lookup_tables_schema.sql)
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  dashboard_config JSONB,
  has_real_data BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Listings Table
-- Stores general property leads (for "All Prospects" view)
-- NOTE: Listings are UNIVERSALLY accessible to all users (shared data pool)
-- This table contains scraped/aggregated property data that all users can view
CREATE TABLE listings (
  listing_id TEXT PRIMARY KEY,        -- use Redfin listing id or URL slug
  property_url TEXT NOT NULL UNIQUE,  -- full URL for reference
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT,
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,                          -- Description
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,              -- comma-separated or JSON in photos_json
  photos_json JSONB,        -- optional structured photo list
  other JSONB,              -- any extra fields
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT listing_id_url_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Price History Table
-- Tracks price changes over time
CREATE TABLE price_history (
  id BIGSERIAL PRIMARY KEY,
  listing_id TEXT REFERENCES listings(listing_id) ON DELETE CASCADE,
  old_price BIGINT,
  new_price BIGINT NOT NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Status History Table
-- Tracks status changes over time
CREATE TABLE status_history (
  id BIGSERIAL PRIMARY KEY,
  listing_id TEXT REFERENCES listings(listing_id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email Templates Table
-- Stores reusable email templates for lead outreach
CREATE TABLE email_templates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL, -- 'follow_up', 'initial_contact', 'expired_listing', 'probate', 'general'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Probate Leads Table
-- Stores probate property leads from court filings
CREATE TABLE probate_leads (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  case_number TEXT NOT NULL UNIQUE,
  decedent_name TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  zip TEXT NOT NULL,
  filing_date DATE,
  source TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Email Captures Table
-- Stores email addresses captured from click forms (lead generation)
CREATE TABLE email_captures (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  source TEXT, -- e.g., 'landing_page', 'popup', 'footer_form'
  referrer TEXT, -- URL where the form was submitted from
  user_agent TEXT, -- Browser/client information
  ip_address TEXT, -- IP address (for analytics, consider privacy regulations)
  metadata JSONB, -- Additional flexible data (form fields, UTM parameters, etc.)
  subscribed BOOLEAN DEFAULT TRUE, -- Whether user opted in for emails
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- LEAD CATEGORY TABLES (Separate tables for each category)
-- ============================================================================

-- Expired Listings Table
-- Stores listings that have expired, been sold, or are off-market
-- NOTE: Expired listings are UNIVERSALLY accessible (shared data pool)
CREATE TABLE expired_listings (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT FALSE, -- Expired listings are not active
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT, -- 'expired', 'sold', 'off market', etc.
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  expired_date TIMESTAMPTZ,
  sold_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'lost',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT expired_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- FSBO Leads Table (For Sale By Owner)
-- NOTE: FSBO leads are UNIVERSALLY accessible (shared data pool)
-- Schema matches Supabase production; canonical definition: scripts/supabase/fsbo_leads_schema.sql
CREATE TABLE fsbo_leads (
  listing_id TEXT NOT NULL,
  property_url TEXT NOT NULL,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths NUMERIC(4, 2),
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'fsbo',
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price TEXT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  fsbo_source TEXT,
  owner_contact_method TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  living_area TEXT,
  year_built_pagination TEXT,
  bedrooms TEXT,
  bathrooms TEXT,
  property_type TEXT,
  construction_type TEXT,
  building_style TEXT,
  effective_year_built TEXT,
  number_of_units TEXT,
  number_of_buildings TEXT,
  number_of_commercial_units TEXT,
  stories TEXT,
  garage TEXT,
  garage_area TEXT,
  heating_type TEXT,
  heating_gas TEXT,
  air_conditioning TEXT,
  basement TEXT,
  deck TEXT,
  interior_walls TEXT,
  exterior_walls TEXT,
  exterior_features TEXT,
  fireplaces TEXT,
  flooring_cover TEXT,
  driveway TEXT,
  pool TEXT,
  patio TEXT,
  porch TEXT,
  roof TEXT,
  roof_type TEXT,
  sewer TEXT,
  topography TEXT,
  water TEXT,
  apn TEXT,
  lot_size TEXT,
  legal_name TEXT,
  legal_description TEXT,
  subdivision_name TEXT,
  property_class TEXT,
  county_name TEXT,
  association_fee TEXT,
  elementary_school_district TEXT,
  high_school_district TEXT,
  zoning TEXT,
  property_condition TEXT,
  flood_zone TEXT,
  tax_year TEXT,
  tax_amount TEXT,
  assessment_year TEXT,
  total_assessed_value TEXT,
  assessed_improvement_value TEXT,
  total_market_value TEXT,
  amenities TEXT,
  universal_property_id TEXT,
  middle_school_district TEXT,
  CONSTRAINT fsbo_leads_pkey PRIMARY KEY (listing_id),
  CONSTRAINT fsbo_leads_property_url_key UNIQUE (property_url),
  CONSTRAINT fsbo_leads_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT fsbo_leads_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL,
  CONSTRAINT fsbo_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- FRBO Leads Table (For Rent By Owner)
-- NOTE: FRBO leads are UNIVERSALLY accessible (shared data pool)
CREATE TABLE frbo_leads (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT, -- Monthly rent price
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'frbo',
  mls TEXT,
  agent_name TEXT, -- Owner name for FRBO
  agent_email TEXT, -- Owner email for FRBO
  agent_phone TEXT, -- Owner phone for FRBO
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  frbo_source TEXT,
  lease_term TEXT,
  available_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT frbo_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Imports Table
-- Stores imported leads from CSV, API, or other external sources
-- NOTE: Imports are USER-SPECIFIC - each user only sees their own imported leads
-- All imported leads automatically go to this table (not the listings table)
-- Connected to user's email/password authentication via auth.users(id)
CREATE TABLE imports (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT,
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  import_source TEXT NOT NULL DEFAULT 'csv', -- 'csv', 'api', 'manual', etc.
  import_batch_id TEXT,
  import_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT imports_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Trash Table
-- Stores leads that have been marked as trash/not useful
-- NOTE: Trash is USER-SPECIFIC and functions as a recycling bin (soft delete)
-- Leads are moved to trash before actual deletion, allowing recovery
-- Users can restore items from trash or permanently delete them
-- Connected to user's email/password authentication via auth.users(id)
CREATE TABLE trash (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT FALSE, -- Trash leads are not active
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'trash',
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  trash_reason TEXT,
  trashed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  trashed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  original_category TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'lost',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT trash_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Foreclosure Listings Table
-- NOTE: Foreclosure listings are UNIVERSALLY accessible (shared data pool)
CREATE TABLE foreclosure_listings (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT, -- Foreclosure sale price
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'foreclosure',
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  foreclosure_type TEXT,
  auction_date DATE,
  default_amount BIGINT,
  lender_name TEXT,
  case_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT foreclosure_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- ============================================================================
-- CRM TABLES
-- ============================================================================

-- Tasks Table
-- Stores user tasks and to-dos
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE tasks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  -- SEMANTICS: User-specific table - user_id is REQUIRED NOT NULL (enforced by RLS for data isolation)
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  due_date TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  related_type TEXT, -- 'contact', 'deal', 'listing', 'campaign', etc.
  related_id TEXT, -- ID of the related entity
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Contacts Table
-- Stores CRM contacts (property owners, leads, etc.)
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE contacts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  -- SEMANTICS: User-specific table - user_id is REQUIRED NOT NULL (enforced by RLS for data isolation)
  first_name TEXT,
  last_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  company TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  source TEXT, -- 'listing', 'probate', 'geo', 'manual', 'form', etc.
  source_id TEXT, -- ID of the source (e.g., listing_id)
  notes TEXT,
  tags TEXT[], -- Array of tags
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'qualified', 'nurturing', 'not_interested')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deals Table
-- Stores sales deals/opportunities
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE deals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  -- SEMANTICS: User-specific table - user_id is REQUIRED NOT NULL (enforced by RLS for data isolation)
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  value NUMERIC(12, 2), -- Deal value in dollars
  stage TEXT NOT NULL DEFAULT 'new' CHECK (stage IN ('new', 'contacted', 'qualified', 'proposal', 'negotiation', 'closed_won', 'closed_lost')),
  probability INTEGER DEFAULT 0 CHECK (probability >= 0 AND probability <= 100),
  expected_close_date TIMESTAMPTZ,
  closed_date TIMESTAMPTZ,
  source TEXT,
  source_id TEXT, -- ID of the source (e.g., listing_id)
  notes TEXT,
  tags TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Lists Table
-- Stores user-created lists for organizing contacts and properties
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE lists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('people', 'properties')),
  description TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  -- SEMANTICS: User-specific table - user_id is REQUIRED NOT NULL (enforced by RLS for data isolation)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- List Items Table
-- Stores the relationship between lists and items (contacts/properties/listings)
CREATE TABLE list_items (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  list_id UUID REFERENCES lists(id) ON DELETE CASCADE NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('contact', 'company', 'listing')),
  item_id TEXT NOT NULL, -- Can reference different tables based on item_type
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(list_id, item_type, item_id)
);

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

-- Listings indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_listings_user_id ON listings(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_listings_city ON listings(city);
CREATE INDEX idx_listings_state ON listings(state);
CREATE INDEX idx_listings_active ON listings(active);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_list_price ON listings(list_price);
CREATE INDEX idx_listings_created_at ON listings(created_at);
CREATE INDEX idx_listings_last_scraped_at ON listings(last_scraped_at);

-- Price history indexes
CREATE INDEX idx_price_history_listing ON price_history(listing_id, changed_at DESC);

-- Status history indexes
CREATE INDEX idx_status_history_listing ON status_history(listing_id, changed_at DESC);

-- Email templates indexes
CREATE INDEX idx_email_templates_category ON email_templates(category);
CREATE INDEX idx_email_templates_created_by ON email_templates(created_by);

-- Probate leads indexes
CREATE INDEX idx_probate_leads_case_number ON probate_leads(case_number);
CREATE INDEX idx_probate_leads_state ON probate_leads(state);
CREATE INDEX idx_probate_leads_city ON probate_leads(city);
CREATE INDEX idx_probate_leads_filing_date ON probate_leads(filing_date);

-- Email captures indexes
CREATE INDEX idx_email_captures_email ON email_captures(email);
CREATE INDEX idx_email_captures_created_at ON email_captures(created_at);
CREATE INDEX idx_email_captures_source ON email_captures(source);
CREATE INDEX idx_email_captures_subscribed ON email_captures(subscribed);

-- CRM indexes
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_related ON tasks(related_type, related_id);

CREATE INDEX idx_contacts_user_id ON contacts(user_id);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_status ON contacts(status);
CREATE INDEX idx_contacts_source ON contacts(source, source_id);

CREATE INDEX idx_deals_user_id ON deals(user_id);
CREATE INDEX idx_deals_contact_id ON deals(contact_id);
CREATE INDEX idx_deals_stage ON deals(stage);
CREATE INDEX idx_deals_source ON deals(source, source_id);

-- Lead Category Tables Indexes
-- Expired Listings indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_expired_listings_user_id ON expired_listings(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_expired_listings_city ON expired_listings(city);
CREATE INDEX idx_expired_listings_state ON expired_listings(state);
CREATE INDEX idx_expired_listings_status ON expired_listings(status);
CREATE INDEX idx_expired_listings_created_at ON expired_listings(created_at);
CREATE INDEX idx_expired_listings_expired_date ON expired_listings(expired_date);

-- FSBO Leads indexes (match Supabase; see fsbo_leads_schema.sql)
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_user_id ON fsbo_leads(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_city ON fsbo_leads(city);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state ON fsbo_leads(state);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_status ON fsbo_leads(status);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_created_at ON fsbo_leads(created_at);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_fsbo_source ON fsbo_leads(fsbo_source);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_city ON fsbo_leads(state, city);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_status ON fsbo_leads(state, status);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_created_at ON fsbo_leads(state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_status_active ON fsbo_leads(status, active) WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_price ON fsbo_leads(state, list_price) WHERE list_price IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_pipeline_status ON fsbo_leads(pipeline_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_user_status ON fsbo_leads(user_id, status) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_city_state_status ON fsbo_leads(city, state, status);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_pipeline_status_created ON fsbo_leads(pipeline_status, created_at DESC) WHERE pipeline_status IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_price_range ON fsbo_leads(list_price) WHERE list_price IS NOT NULL AND list_price > 0;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_text_search ON fsbo_leads USING gin(to_tsvector('english', COALESCE(text, '')));
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_covering_state_city ON fsbo_leads(state, city, listing_id, property_url, list_price, status, created_at) WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_status_created ON fsbo_leads(state, status, date_trunc('day', (created_at AT TIME ZONE 'UTC')));

-- FRBO Leads indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_frbo_leads_user_id ON frbo_leads(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_frbo_leads_city ON frbo_leads(city);
CREATE INDEX idx_frbo_leads_state ON frbo_leads(state);
CREATE INDEX idx_frbo_leads_status ON frbo_leads(status);
CREATE INDEX idx_frbo_leads_created_at ON frbo_leads(created_at);
CREATE INDEX idx_frbo_leads_available_date ON frbo_leads(available_date);

-- Imports indexes
CREATE INDEX idx_imports_user_id ON imports(user_id);
CREATE INDEX idx_imports_city ON imports(city);
CREATE INDEX idx_imports_state ON imports(state);
CREATE INDEX idx_imports_import_source ON imports(import_source);
CREATE INDEX idx_imports_import_batch_id ON imports(import_batch_id);
CREATE INDEX idx_imports_created_at ON imports(created_at);

-- Trash indexes
CREATE INDEX idx_trash_user_id ON trash(user_id);
CREATE INDEX idx_trash_city ON trash(city);
CREATE INDEX idx_trash_state ON trash(state);
CREATE INDEX idx_trash_trashed_at ON trash(trashed_at);
CREATE INDEX idx_trash_original_category ON trash(original_category);

-- Foreclosure Listings indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_foreclosure_listings_user_id ON foreclosure_listings(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_foreclosure_listings_city ON foreclosure_listings(city);
CREATE INDEX idx_foreclosure_listings_state ON foreclosure_listings(state);
CREATE INDEX idx_foreclosure_listings_foreclosure_type ON foreclosure_listings(foreclosure_type);
CREATE INDEX idx_foreclosure_listings_auction_date ON foreclosure_listings(auction_date);
CREATE INDEX idx_foreclosure_listings_created_at ON foreclosure_listings(created_at);

-- Lists indexes
CREATE INDEX idx_lists_user_id ON lists(user_id);
CREATE INDEX idx_lists_type ON lists(type);
CREATE INDEX idx_lists_updated_at ON lists(updated_at DESC);
CREATE INDEX idx_lists_id_user_id ON lists(id, user_id); -- Composite index for efficient list fetching with user check

-- List items indexes for pagination
CREATE INDEX idx_list_items_list_id ON list_items(list_id);
CREATE INDEX idx_list_items_item ON list_items(item_type, item_id);
CREATE INDEX idx_list_items_list_id_created_at ON list_items(list_id, created_at DESC); -- For pagination by creation date
CREATE INDEX idx_list_items_list_id_item_type ON list_items(list_id, item_type); -- For filtering by item type

-- ============================================================================
-- CREATE FUNCTIONS
-- ============================================================================

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Function to handle new user creation (auto-create profile)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, trial_end, is_subscribed, plan_tier)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email::text, 'User'),
    'user',
    NOW() + INTERVAL '7 days',
    false,
    'free'
  )
  ON CONFLICT (id) DO NOTHING; -- Don't error if profile already exists
  RETURN NEW;
END;
$$;

-- ============================================================================
-- CREATE TRIGGERS
-- ============================================================================

CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_listings_updated_at 
  BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  
-- Trigger to update last_scraped_at when listing is updated
CREATE OR REPLACE FUNCTION update_last_scraped_at()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.last_scraped_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_listings_last_scraped_at 
  BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_last_scraped_at();

-- Function to update lists updated_at timestamp
CREATE OR REPLACE FUNCTION update_lists_updated_at()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update lists.updated_at when list_items change
-- This ensures the parent list's updated_at is automatically updated
-- whenever list_items are inserted, updated, or deleted
CREATE OR REPLACE FUNCTION update_lists_updated_at_on_list_items_change()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update the parent list's updated_at timestamp
  IF TG_OP = 'DELETE' THEN
    -- For DELETE, use OLD.list_id
    UPDATE lists 
    SET updated_at = NOW() 
    WHERE id = OLD.list_id;
    RETURN OLD;
  ELSE
    -- For INSERT or UPDATE, use NEW.list_id
    UPDATE lists 
    SET updated_at = NOW() 
    WHERE id = NEW.list_id;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_email_templates_updated_at 
  BEFORE UPDATE ON email_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_probate_leads_updated_at 
  BEFORE UPDATE ON probate_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_captures_updated_at 
  BEFORE UPDATE ON email_captures
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CRM table triggers
CREATE TRIGGER update_tasks_updated_at 
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at 
  BEFORE UPDATE ON contacts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deals_updated_at 
  BEFORE UPDATE ON deals
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Lead Category Tables Triggers
CREATE TRIGGER update_expired_listings_updated_at
  BEFORE UPDATE ON expired_listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_fsbo_leads_updated_at
  BEFORE UPDATE ON fsbo_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_frbo_leads_updated_at
  BEFORE UPDATE ON frbo_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_imports_updated_at
  BEFORE UPDATE ON imports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trash_updated_at
  BEFORE UPDATE ON trash
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_foreclosure_listings_updated_at
  BEFORE UPDATE ON foreclosure_listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Lists table trigger
CREATE TRIGGER update_lists_updated_at
  BEFORE UPDATE ON lists
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at();

-- List items triggers - automatically update parent list's updated_at
-- when list_items are inserted, updated, or deleted
CREATE TRIGGER update_lists_on_list_items_insert
  AFTER INSERT ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

CREATE TRIGGER update_lists_on_list_items_update
  AFTER UPDATE ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

CREATE TRIGGER update_lists_on_list_items_delete
  AFTER DELETE ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

-- Auto-create user profile trigger (runs when auth user is created)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE probate_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_captures ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
-- Enable RLS on lead category tables
ALTER TABLE expired_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fsbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE frbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE trash ENABLE ROW LEVEL SECURITY;
ALTER TABLE foreclosure_listings ENABLE ROW LEVEL SECURITY;

-- Enable RLS on data lake zone and ingestion tables
ALTER TABLE pipelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_run_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_redfin_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_csv_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_apollo_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE fsbo_raw ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_staging ENABLE ROW LEVEL SECURITY;
ALTER TABLE zone_transitions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES - USERS TABLE (FIXED)
-- ============================================================================

-- Allow users to view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT 
  USING (auth.uid() = id);

-- Allow users to insert their own profile (when id matches their auth.uid())
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- RLS POLICIES - LISTINGS TABLE
-- ============================================================================
-- Listings are UNIVERSALLY accessible - all authenticated users can view all listings
-- This allows the "Prospect & Enrich" page to show a shared pool of property data

CREATE POLICY "All authenticated users can view listings" ON listings
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert listings" ON listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update listings" ON listings
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete listings" ON listings
  FOR DELETE USING (auth.role() = 'authenticated');

-- Price history policies
CREATE POLICY "Allow authenticated users to view price history" ON price_history
  FOR SELECT USING (auth.role() = 'authenticated');

-- Status history policies
CREATE POLICY "Allow authenticated users to view status history" ON status_history
  FOR SELECT USING (auth.role() = 'authenticated');

-- ============================================================================
-- RLS POLICIES - EMAIL TEMPLATES TABLE
-- ============================================================================

CREATE POLICY "Authenticated users can view templates" ON email_templates
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can insert templates" ON email_templates
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update templates" ON email_templates
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete templates" ON email_templates
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- RLS POLICIES - PROBATE LEADS TABLE
-- ============================================================================

CREATE POLICY "Authenticated users can view probate leads" ON probate_leads
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage probate leads" ON probate_leads
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- RLS POLICIES - EMAIL CAPTURES TABLE
-- ============================================================================

-- Allow public inserts (for form submissions) but restrict viewing to admins
CREATE POLICY "Allow public email capture inserts" ON email_captures
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view email captures" ON email_captures
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update email captures" ON email_captures
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete email captures" ON email_captures
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- RLS POLICIES - CRM TABLES
-- ============================================================================

-- Tasks RLS Policies
CREATE POLICY "Users can view their own tasks" ON tasks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tasks" ON tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tasks" ON tasks
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tasks" ON tasks
  FOR DELETE USING (auth.uid() = user_id);

-- Contacts RLS Policies
CREATE POLICY "Users can view their own contacts" ON contacts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own contacts" ON contacts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own contacts" ON contacts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own contacts" ON contacts
  FOR DELETE USING (auth.uid() = user_id);

-- Deals RLS Policies
CREATE POLICY "Users can view their own deals" ON deals
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own deals" ON deals
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own deals" ON deals
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own deals" ON deals
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- RLS POLICIES - LEAD CATEGORY TABLES
-- ============================================================================
-- Category tables are UNIVERSALLY accessible - all authenticated users can view all category data
-- This allows the "Prospect & Enrich" page to show shared pools of property data

-- Expired Listings Policies
CREATE POLICY "All authenticated users can view expired_listings" ON expired_listings
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert expired_listings" ON expired_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update expired_listings" ON expired_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete expired_listings" ON expired_listings
  FOR DELETE USING (auth.role() = 'authenticated');

-- FSBO Leads Policies
CREATE POLICY "All authenticated users can view fsbo_leads" ON fsbo_leads
  FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can insert fsbo_leads" ON fsbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can update fsbo_leads" ON fsbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can delete fsbo_leads" ON fsbo_leads
  FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- FRBO Leads Policies
CREATE POLICY "All authenticated users can view frbo_leads" ON frbo_leads
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert frbo_leads" ON frbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update frbo_leads" ON frbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete frbo_leads" ON frbo_leads
  FOR DELETE USING (auth.role() = 'authenticated');

-- Imports Policies
-- Imports are USER-SPECIFIC - users can only see/manage their own imported leads
CREATE POLICY "Users can view their own imports" ON imports
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own imports" ON imports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own imports" ON imports
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own imports" ON imports
  FOR DELETE USING (auth.uid() = user_id);

-- Trash Policies
-- Trash is USER-SPECIFIC and functions as a recycling bin (soft delete)
-- Users can only see/manage their own trashed leads
CREATE POLICY "Users can view their own trash" ON trash
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own trash" ON trash
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own trash" ON trash
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own trash" ON trash
  FOR DELETE USING (auth.uid() = user_id);

-- Foreclosure Listings Policies
CREATE POLICY "All authenticated users can view foreclosure_listings" ON foreclosure_listings
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert foreclosure_listings" ON foreclosure_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update foreclosure_listings" ON foreclosure_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete foreclosure_listings" ON foreclosure_listings
  FOR DELETE USING (auth.role() = 'authenticated');

-- Lists RLS Policies
ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own lists"
  ON lists FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own lists"
  ON lists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own lists"
  ON lists FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own lists"
  ON lists FOR DELETE
  USING (auth.uid() = user_id);

-- List Items RLS Policies
CREATE POLICY "Users can view items in their lists"
  ON list_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can add items to their lists"
  ON list_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete items from their lists"
  ON list_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

-- ============================================================================
-- CREATE VIEWS
-- ============================================================================

-- View to get list counts
CREATE OR REPLACE VIEW list_counts AS
SELECT 
  l.id,
  l.name,
  l.type,
  l.user_id,
  COUNT(li.id) as count
FROM lists l
LEFT JOIN list_items li ON l.id = li.list_id
GROUP BY l.id, l.name, l.type, l.user_id;

-- View for paginated list items with metadata
-- This view provides list items with their list information for efficient pagination queries
CREATE OR REPLACE VIEW list_items_with_metadata AS
SELECT 
  li.id,
  li.list_id,
  li.item_type,
  li.item_id,
  li.created_at,
  l.name as list_name,
  l.type as list_type,
  l.user_id,
  l.created_at as list_created_at,
  l.updated_at as list_updated_at
FROM list_items li
INNER JOIN lists l ON li.list_id = l.id;

-- Function to get paginated list items
-- Usage: SELECT * FROM get_list_items_paginated('list_id_here', 0, 50);
CREATE OR REPLACE FUNCTION get_list_items_paginated(
  p_list_id UUID,
  p_offset INTEGER DEFAULT 0,
  p_limit INTEGER DEFAULT 50,
  p_item_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  list_id UUID,
  item_type TEXT,
  item_id TEXT,
  created_at TIMESTAMPTZ,
  list_name TEXT,
  list_type TEXT,
  user_id UUID
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    li.id,
    li.list_id,
    li.item_type,
    li.item_id,
    li.created_at,
    l.name as list_name,
    l.type as list_type,
    l.user_id
  FROM list_items li
  INNER JOIN lists l ON li.list_id = l.id
  WHERE li.list_id = p_list_id
    AND (p_item_type IS NULL OR li.item_type = p_item_type)
  ORDER BY li.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Function to get total count of items in a list (for pagination metadata)
CREATE OR REPLACE FUNCTION get_list_items_count(
  p_list_id UUID,
  p_item_type TEXT DEFAULT NULL
)
RETURNS INTEGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM list_items
  WHERE list_id = p_list_id
    AND (p_item_type IS NULL OR item_type = p_item_type);
  
  RETURN v_count;
END;
$$;

-- ============================================================================
-- UNIFIED LISTINGS VIEW
-- ============================================================================
-- This view creates a compiled/aggregated view of all listing tables
-- so that queries can access all categories through a single unified interface.
-- Each row includes a 'source_category' field to identify its origin table.

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
  longitude AS lng,         -- Probate uses 'longitude' instead of 'lng'
  'probate_leads' AS source_category
FROM probate_leads;

-- ============================================================================
-- RLS POLICIES - DATA LAKE ZONES AND INGESTION TABLES
-- ============================================================================

-- Policies for pipelines table
CREATE POLICY "Users can view pipelines"
  ON pipelines FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Admins can manage pipelines"
  ON pipelines FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Policies for pipeline_runs table
CREATE POLICY "Users can view pipeline runs"
  ON pipeline_runs FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create pipeline runs"
  ON pipeline_runs FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Users can update pipeline runs"
  ON pipeline_runs FOR UPDATE
  TO authenticated
  USING (
    triggered_by_user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Policies for pipeline_run_events table
CREATE POLICY "Users can view pipeline run events"
  ON pipeline_run_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM pipeline_runs pr
      WHERE pr.id = pipeline_run_events.pipeline_run_id
    )
  );

CREATE POLICY "Service role can insert pipeline run events"
  ON pipeline_run_events FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Policies for raw zone tables
CREATE POLICY "Authenticated users can view raw redfin responses"
  ON raw_redfin_responses FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can view raw csv imports"
  ON raw_csv_imports FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can view raw apollo imports"
  ON raw_apollo_imports FOR SELECT
  TO authenticated
  USING (true);

-- Policies for staging zone tables
CREATE POLICY "Authenticated users can view fsbo_raw"
  ON fsbo_raw FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view their own import staging"
  ON import_staging FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can manage their own import staging"
  ON import_staging FOR ALL
  TO authenticated
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Policies for zone_transitions
CREATE POLICY "Authenticated users can view zone transitions"
  ON zone_transitions FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions for lists tables
GRANT ALL ON lists TO authenticated;
GRANT ALL ON list_items TO authenticated;
GRANT SELECT ON list_counts TO authenticated;
GRANT SELECT ON list_items_with_metadata TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_items_paginated(UUID, INTEGER, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_items_count(UUID, TEXT) TO authenticated;

-- Grant permissions for unified listings view
GRANT SELECT ON listings_unified TO authenticated;

-- ============================================================================
-- INITIAL PIPELINE DEFINITIONS
-- ============================================================================

-- Insert default pipeline definitions for data lake ingestion
INSERT INTO pipelines (name, description, pipeline_type, source_zone, target_zone, source_tables, target_tables, enabled)
VALUES
  ('redfin_fsbo_scraper', 'Redfin FSBO listing scraper', 'scraper', 'external', 'raw', ARRAY[]::TEXT[], ARRAY['raw_redfin_responses'], TRUE),
  ('fsbo_enrichment', 'FSBO lead enrichment (skip tracing, contact info)', 'enrichment', 'raw', 'staging', ARRAY['raw_redfin_responses'], ARRAY['fsbo_raw'], TRUE),
  ('geocoding_backfill', 'Backfill geocoding for addresses', 'geocoding', 'staging', 'curated', ARRAY['fsbo_raw', 'listings'], ARRAY['fsbo_leads', 'listings'], TRUE),
  ('csv_import', 'CSV file import pipeline', 'import', 'external', 'raw', ARRAY[]::TEXT[], ARRAY['raw_csv_imports'], TRUE),
  ('apollo_import', 'Apollo.io list import', 'import', 'external', 'raw', ARRAY[]::TEXT[], ARRAY['raw_apollo_imports'], TRUE)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- Note: Sample listing data is not included because listings require a user_id.
-- Users should create listings through the application after signing up.
-- This ensures proper user association and data isolation.

-- Insert default email templates (shared/admin-managed, no user_id required)
INSERT INTO email_templates (title, body, category) VALUES
(
  'Initial FSBO Contact',
  'Hello {{owner_name}},

I noticed you have {{address}} listed for sale by owner. I''m a local real estate professional specializing in properties in {{city}}, {{state}}.

I''ve helped many sellers in your area get the best price for their home while minimizing stress. Would you be open to a brief conversation about your goals?

I''m available at your convenience.

Best regards,
{{agent_name}}',
  'initial_contact'
),
(
  'Expired Listing Follow-up',
  'Hi {{owner_name}},

I see that {{address}} is no longer on the market. I know that can be frustrating after all the effort you''ve put in.

If you''re still interested in selling, I''d love to help. I specialize in properties that have been on and off the market, and I have strategies that often yield better results.

Would you like to chat about what might work for your situation?

Thank you,
{{agent_name}}',
  'expired_listing'
),
(
  'Probate Property Assistance',
  'Dear {{owner_name}},

I understand you''re handling matters for {{decedent_name}}''s estate, including the property at {{address}}.

Selling a probate property can involve unique challenges. I have experience with probate transactions in {{city}}, {{state}} and can guide you through the process.

If you''re considering selling the property, I''d be happy to discuss how I can help make this as smooth as possible.

Sincerely,
{{agent_name}}',
  'probate'
);

-- ============================================================================
-- USER SYNC FUNCTIONALITY
-- ============================================================================

-- Create missing user records for any existing auth users
INSERT INTO public.users (id, email, name, role, trial_end, is_subscribed, plan_tier)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'name', 'User') as name,
  'user' as role,
  NOW() + INTERVAL '7 days' as trial_end,
  false as is_subscribed,
  'free' as plan_tier
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify the setup
SELECT 'Database setup complete!' as status;
SELECT COUNT(*) as total_listings FROM listings;
SELECT COUNT(*) as total_email_templates FROM email_templates;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as auth_users FROM auth.users;
SELECT COUNT(*) as total_email_captures FROM email_captures;
SELECT COUNT(*) as total_tasks FROM tasks;
SELECT COUNT(*) as total_contacts FROM contacts;
SELECT COUNT(*) as total_deals FROM deals;
-- Verify lead category tables
SELECT COUNT(*) as total_expired_listings FROM expired_listings;
SELECT COUNT(*) as total_fsbo_leads FROM fsbo_leads;
SELECT COUNT(*) as total_frbo_leads FROM frbo_leads;
SELECT COUNT(*) as total_imports FROM imports;
SELECT COUNT(*) as total_trash FROM trash;
SELECT COUNT(*) as total_foreclosure_listings FROM foreclosure_listings;
SELECT COUNT(*) as total_lists FROM lists;
SELECT COUNT(*) as total_list_items FROM list_items;
SELECT COUNT(*) as total_unified_listings FROM listings_unified;
SELECT source_category, COUNT(*) as count FROM listings_unified GROUP BY source_category;
SELECT 'All systems ready! Lead category tables and lists integrated successfully!' as final_status;

-- ============================================================================
-- SCHEMA ENHANCEMENTS - ADDRESS/CONTACT NORMALIZATION
-- ============================================================================
-- Helper views for consistent address/contact mapping across all lead tables
-- See: address_normalization_schema.sql

-- ADDRESS COMPOSITE TYPE (Optional - for future use)
CREATE TYPE IF NOT EXISTS address_type AS (
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  country TEXT
);

-- Unified Address View for Listings
CREATE OR REPLACE VIEW address_view AS
SELECT 
  'listings' AS source_table,
  listing_id AS listing_id,
  street, unit, city, state, zip_code, lat, lng, created_at
FROM listings
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL
UNION ALL
SELECT 
  'fsbo_leads' AS source_table,
  listing_id, street, unit, city, state, zip_code, lat, lng, created_at
FROM fsbo_leads
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL
UNION ALL
SELECT 
  'expired_listings' AS source_table,
  listing_id, street, unit, city, state, zip_code, lat, lng, created_at
FROM expired_listings
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL
UNION ALL
SELECT 
  'frbo_leads' AS source_table,
  listing_id, street, unit, city, state, zip_code, lat, lng, created_at
FROM frbo_leads
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL
UNION ALL
SELECT 
  'foreclosure_listings' AS source_table,
  listing_id, street, unit, city, state, zip_code, lat, lng, created_at
FROM foreclosure_listings
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL
UNION ALL
SELECT 
  'imports' AS source_table,
  listing_id, street, unit, city, state, zip_code, lat, lng, created_at
FROM imports
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL;

-- Address normalization view with formatted address
CREATE OR REPLACE VIEW address_normalized AS
SELECT 
  source_table, listing_id, street, unit, city, state, zip_code, lat, lng,
  TRIM(COALESCE(street, '') || 
    CASE WHEN unit IS NOT NULL THEN ' ' || unit ELSE '' END || 
    CASE WHEN city IS NOT NULL THEN ', ' || city ELSE '' END ||
    CASE WHEN state IS NOT NULL THEN ', ' || state ELSE '' END ||
    CASE WHEN zip_code IS NOT NULL THEN ' ' || zip_code ELSE '' END
  ) AS formatted_address,
  UPPER(TRIM(COALESCE(city, ''))) AS city_normalized,
  UPPER(TRIM(COALESCE(state, ''))) AS state_normalized,
  UPPER(TRIM(COALESCE(city, '')) || ', ' || TRIM(COALESCE(state, ''))) AS city_state_key,
  created_at
FROM address_view;

-- Unified Contact View
CREATE OR REPLACE VIEW contact_view AS
SELECT 
  'listings' AS source_table, listing_id,
  agent_name AS contact_name, agent_email AS contact_email,
  agent_phone AS contact_phone, agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3, listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM listings
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL
UNION ALL
SELECT 
  'fsbo_leads' AS source_table, listing_id,
  agent_name AS contact_name, agent_email AS contact_email,
  agent_phone AS contact_phone, agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3, listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM fsbo_leads
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL
UNION ALL
SELECT 
  'expired_listings' AS source_table, listing_id,
  agent_name AS contact_name, agent_email AS contact_email,
  agent_phone AS contact_phone, agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3, listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM expired_listings
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL
UNION ALL
SELECT 
  'frbo_leads' AS source_table, listing_id,
  agent_name AS contact_name, agent_email AS contact_email,
  agent_phone AS contact_phone, agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3, listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM frbo_leads
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL
UNION ALL
SELECT 
  'foreclosure_listings' AS source_table, listing_id,
  agent_name AS contact_name, agent_email AS contact_email,
  agent_phone AS contact_phone, agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3, listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM foreclosure_listings
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL
UNION ALL
SELECT 
  'imports' AS source_table, listing_id,
  agent_name AS contact_name, agent_email AS contact_email,
  agent_phone AS contact_phone, agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3, listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM imports
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL;

-- Contact normalized view
CREATE OR REPLACE VIEW contact_normalized AS
SELECT 
  source_table, listing_id, contact_name, contact_email,
  contact_phone, contact_phone_2, contact_phone_3, contact_phone_4,
  COALESCE(contact_email, contact_phone, contact_phone_2) AS primary_contact,
  ARRAY_REMOVE(ARRAY[contact_email, contact_phone, contact_phone_2, contact_phone_3, contact_phone_4], NULL) AS all_contact_methods,
  (contact_email IS NOT NULL OR contact_phone IS NOT NULL) AS has_contact_info,
  created_at
FROM contact_view;

-- Geographic distribution view
CREATE OR REPLACE VIEW geographic_distribution AS
SELECT 
  city_normalized AS city, state_normalized AS state, city_state_key,
  COUNT(*) AS lead_count, COUNT(DISTINCT source_table) AS table_count,
  MIN(created_at) AS first_seen, MAX(created_at) AS last_seen
FROM address_normalized
WHERE city_normalized != '' AND state_normalized != ''
GROUP BY city_normalized, state_normalized, city_state_key
ORDER BY lead_count DESC;

COMMENT ON VIEW address_view IS 'Unified view of addresses across all lead tables for analytics';
COMMENT ON VIEW address_normalized IS 'Normalized addresses with formatted strings and geographic keys';
COMMENT ON VIEW contact_view IS 'Unified view of contact information across all lead tables';
COMMENT ON VIEW contact_normalized IS 'Normalized contacts with primary contact method and arrays';
COMMENT ON VIEW geographic_distribution IS 'Geographic distribution of leads by city/state';
COMMENT ON TYPE address_type IS 'Composite type for normalized addresses (future use)';

-- ============================================================================
-- SCHEMA ENHANCEMENTS - ENUM LOOKUP TABLES
-- ============================================================================
-- Lookup tables for enums currently encoded as TEXT + CHECK constraints
-- See: enum_lookup_tables_schema.sql

-- Lead Status Lookup Table
CREATE TABLE IF NOT EXISTS lead_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  category TEXT,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Pipeline Status Lookup Table
CREATE TABLE IF NOT EXISTS pipeline_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- User Role Lookup Table
CREATE TABLE IF NOT EXISTS user_role (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  permissions JSONB,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Plan Tier Lookup Table
CREATE TABLE IF NOT EXISTS plan_tier (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  monthly_price NUMERIC(10, 2),
  features JSONB,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Contact Status Lookup Table
CREATE TABLE IF NOT EXISTS contact_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  category TEXT,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deal Stage Lookup Table
CREATE TABLE IF NOT EXISTS deal_stage (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  category TEXT,
  probability_default INTEGER DEFAULT 0,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task Status Lookup Table
CREATE TABLE IF NOT EXISTS task_status (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  is_complete BOOLEAN NOT NULL DEFAULT FALSE,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Task Priority Lookup Table
CREATE TABLE IF NOT EXISTS task_priority (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  priority_level INTEGER NOT NULL,
  color_code TEXT,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- List Type Lookup Table
CREATE TABLE IF NOT EXISTS list_type (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- List Item Type Lookup Table
CREATE TABLE IF NOT EXISTS list_item_type (
  id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  description TEXT,
  display_order INTEGER DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_lead_status_code ON lead_status(code);
CREATE INDEX IF NOT EXISTS idx_pipeline_status_code ON pipeline_status(code);
CREATE INDEX IF NOT EXISTS idx_user_role_code ON user_role(code);
CREATE INDEX IF NOT EXISTS idx_plan_tier_code ON plan_tier(code);
CREATE INDEX IF NOT EXISTS idx_contact_status_code ON contact_status(code);
CREATE INDEX IF NOT EXISTS idx_deal_stage_code ON deal_stage(code);
CREATE INDEX IF NOT EXISTS idx_task_status_code ON task_status(code);
CREATE INDEX IF NOT EXISTS idx_task_priority_code ON task_priority(code);

-- Initial Enum Values
INSERT INTO lead_status (code, label, description, category, display_order) VALUES
  ('fsbo', 'FSBO', 'For Sale By Owner', 'category', 1),
  ('frbo', 'FRBO', 'For Rent By Owner', 'category', 2),
  ('expired', 'Expired', 'Listing has expired', 'listing', 3),
  ('active', 'Active', 'Active listing', 'listing', 4),
  ('sold', 'Sold', 'Property has been sold', 'listing', 5),
  ('pending', 'Pending', 'Sale is pending', 'listing', 6),
  ('foreclosure', 'Foreclosure', 'Foreclosure listing', 'category', 7)
ON CONFLICT (code) DO NOTHING;

INSERT INTO pipeline_status (code, label, description, is_terminal, display_order) VALUES
  ('queued', 'Queued', 'Pipeline run is queued', FALSE, 1),
  ('running', 'Running', 'Pipeline run is currently executing', FALSE, 2),
  ('completed', 'Completed', 'Pipeline run completed successfully', TRUE, 3),
  ('failed', 'Failed', 'Pipeline run failed', TRUE, 4),
  ('cancelled', 'Cancelled', 'Pipeline run was cancelled', TRUE, 5),
  ('timeout', 'Timeout', 'Pipeline run timed out', TRUE, 6)
ON CONFLICT (code) DO NOTHING;

INSERT INTO user_role (code, label, description, display_order) VALUES
  ('user', 'User', 'Standard user account', 1),
  ('admin', 'Admin', 'Administrator account with full access', 2)
ON CONFLICT (code) DO NOTHING;

INSERT INTO plan_tier (code, label, description, monthly_price, display_order) VALUES
  ('free', 'Free', 'Free tier with basic features', 0.00, 1),
  ('starter', 'Starter', 'Starter tier with enhanced features', 29.99, 2),
  ('pro', 'Pro', 'Professional tier with all features', 99.99, 3)
ON CONFLICT (code) DO NOTHING;

INSERT INTO contact_status (code, label, description, category, display_order) VALUES
  ('new', 'New', 'Newly added contact', 'active', 1),
  ('contacted', 'Contacted', 'Contact has been reached', 'active', 2),
  ('qualified', 'Qualified', 'Contact is qualified', 'active', 3),
  ('nurturing', 'Nurturing', 'Contact in nurturing phase', 'active', 4),
  ('not_interested', 'Not Interested', 'Contact is not interested', 'inactive', 5)
ON CONFLICT (code) DO NOTHING;

INSERT INTO deal_stage (code, label, description, category, probability_default, display_order) VALUES
  ('new', 'New', 'New deal opportunity', 'open', 10, 1),
  ('contacted', 'Contacted', 'Initial contact made', 'open', 20, 2),
  ('qualified', 'Qualified', 'Deal is qualified', 'open', 40, 3),
  ('proposal', 'Proposal', 'Proposal sent', 'open', 60, 4),
  ('negotiation', 'Negotiation', 'In negotiation', 'open', 80, 5),
  ('closed_won', 'Closed Won', 'Deal won', 'won', 100, 6),
  ('closed_lost', 'Closed Lost', 'Deal lost', 'lost', 0, 7)
ON CONFLICT (code) DO NOTHING;

INSERT INTO task_status (code, label, description, is_complete, display_order) VALUES
  ('pending', 'Pending', 'Task is pending', FALSE, 1),
  ('in_progress', 'In Progress', 'Task is in progress', FALSE, 2),
  ('completed', 'Completed', 'Task is completed', TRUE, 3),
  ('cancelled', 'Cancelled', 'Task was cancelled', TRUE, 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO task_priority (code, label, description, priority_level, color_code, display_order) VALUES
  ('low', 'Low', 'Low priority task', 1, '#gray', 1),
  ('medium', 'Medium', 'Medium priority task', 2, '#blue', 2),
  ('high', 'High', 'High priority task', 3, '#orange', 3),
  ('urgent', 'Urgent', 'Urgent priority task', 4, '#red', 4)
ON CONFLICT (code) DO NOTHING;

INSERT INTO list_type (code, label, description, display_order) VALUES
  ('people', 'People', 'List of people/contacts', 1),
  ('properties', 'Properties', 'List of properties', 2)
ON CONFLICT (code) DO NOTHING;

INSERT INTO list_item_type (code, label, description, display_order) VALUES
  ('contact', 'Contact', 'Contact item', 1),
  ('company', 'Company', 'Company item', 2),
  ('listing', 'Listing', 'Property listing item', 3)
ON CONFLICT (code) DO NOTHING;

-- Helper function
CREATE OR REPLACE FUNCTION validate_enum_value(p_enum_table TEXT, p_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  EXECUTE format('SELECT EXISTS(SELECT 1 FROM %I WHERE code = $1 AND active = TRUE)', p_enum_table)
  INTO v_exists USING p_code;
  RETURN v_exists;
END;
$$ LANGUAGE plpgsql STABLE;

-- RLS Policies for lookup tables (all authenticated users can view, only admins can modify)
ALTER TABLE lead_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_role ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan_tier ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_stage ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_priority ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_type ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_item_type ENABLE ROW LEVEL SECURITY;

-- View policies (all authenticated users)
DO $$ BEGIN
  CREATE POLICY "Users can view lead_status" ON lead_status FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view pipeline_status" ON pipeline_status FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view user_role" ON user_role FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view plan_tier" ON plan_tier FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view contact_status" ON contact_status FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view deal_stage" ON deal_stage FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view task_status" ON task_status FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view task_priority" ON task_priority FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view list_type" ON list_type FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Users can view list_item_type" ON list_item_type FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Admin manage policies
DO $$ BEGIN
  CREATE POLICY "Admins can manage lead_status" ON lead_status FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage pipeline_status" ON pipeline_status FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage user_role" ON user_role FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage plan_tier" ON plan_tier FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage contact_status" ON contact_status FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage deal_stage" ON deal_stage FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage task_status" ON task_status FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage task_priority" ON task_priority FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage list_type" ON list_type FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage list_item_type" ON list_item_type FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- SCHEMA ENHANCEMENTS - USER ID SEMANTICS STANDARDIZATION
-- ============================================================================
-- See: user_id_semantics_schema.sql

CREATE OR REPLACE FUNCTION validate_universal_user_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.user_id) THEN
      RAISE EXCEPTION 'user_id must reference a valid auth.users.id';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_user_specific_user_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required and cannot be NULL for user-specific tables';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.user_id) THEN
    RAISE EXCEPTION 'user_id must reference a valid auth.users.id';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_universal_user_id IS 
  'Validates user_id for universal tables (optional/nullable, tracks provenance)';
COMMENT ON FUNCTION validate_user_specific_user_id IS 
  'Validates user_id for user-specific tables (required NOT NULL, enforces isolation)';
COMMENT ON FUNCTION validate_enum_value IS 'Validates that an enum code exists and is active in a lookup table';
COMMENT ON TABLE lead_status IS 'Lookup table for lead/listing status values';
COMMENT ON TABLE pipeline_status IS 'Lookup table for pipeline run status values';
COMMENT ON TABLE user_role IS 'Lookup table for user roles';
COMMENT ON TABLE plan_tier IS 'Lookup table for subscription plan tiers';
COMMENT ON TABLE contact_status IS 'Lookup table for contact status values';
COMMENT ON TABLE deal_stage IS 'Lookup table for deal pipeline stages';
COMMENT ON TABLE task_status IS 'Lookup table for task status values';
COMMENT ON TABLE task_priority IS 'Lookup table for task priority levels';
COMMENT ON TABLE list_type IS 'Lookup table for list types';
COMMENT ON TABLE list_item_type IS 'Lookup table for list item types';

-- ============================================================================
-- SCHEMA ENHANCEMENTS - SOFT DELETE SUPPORT FOR CRM TABLES
-- ============================================================================
-- See: soft_delete_schema.sql

-- Add deleted_at columns to CRM tables
ALTER TABLE contacts 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE deals 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE lists 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE list_items 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Indexes for soft delete queries
CREATE INDEX IF NOT EXISTS idx_contacts_deleted_at ON contacts(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_user_deleted ON contacts(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_deleted_at ON deals(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_user_deleted ON deals(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON tasks(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_user_deleted ON tasks(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lists_deleted_at ON lists(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lists_user_deleted ON lists(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_list_items_deleted_at ON list_items(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_list_items_list_deleted ON list_items(list_id, deleted_at) WHERE deleted_at IS NULL;

-- Soft delete helper functions
CREATE OR REPLACE FUNCTION soft_delete_contact(p_contact_id UUID, p_deleted_by UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE contacts SET deleted_at = NOW(), deleted_by = p_deleted_by, updated_at = NOW()
  WHERE id = p_contact_id AND user_id = p_deleted_by;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION restore_contact(p_contact_id UUID, p_restored_by UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE contacts SET deleted_at = NULL, deleted_by = NULL, updated_at = NOW()
  WHERE id = p_contact_id AND user_id = p_restored_by;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Active views (excludes deleted records)
CREATE OR REPLACE VIEW contacts_active AS SELECT * FROM contacts WHERE deleted_at IS NULL;
CREATE OR REPLACE VIEW deals_active AS SELECT * FROM deals WHERE deleted_at IS NULL;
CREATE OR REPLACE VIEW tasks_active AS SELECT * FROM tasks WHERE deleted_at IS NULL;
CREATE OR REPLACE VIEW lists_active AS SELECT * FROM lists WHERE deleted_at IS NULL;
CREATE OR REPLACE VIEW list_items_active AS SELECT * FROM list_items WHERE deleted_at IS NULL;

COMMENT ON COLUMN contacts.deleted_at IS 'Timestamp when contact was soft-deleted. NULL = active record.';
COMMENT ON COLUMN contacts.deleted_by IS 'User who soft-deleted this contact.';
COMMENT ON COLUMN deals.deleted_at IS 'Timestamp when deal was soft-deleted. NULL = active record.';
COMMENT ON COLUMN tasks.deleted_at IS 'Timestamp when task was soft-deleted. NULL = active record.';
COMMENT ON COLUMN lists.deleted_at IS 'Timestamp when list was soft-deleted. NULL = active record.';
COMMENT ON COLUMN list_items.deleted_at IS 'Timestamp when list item was soft-deleted. NULL = active record.';

-- ============================================================================
-- SCHEMA ENHANCEMENTS - INDEX OPTIMIZATION
-- ============================================================================
-- See: index_optimization_schema.sql

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_listings_state_city ON listings(state, city);
CREATE INDEX IF NOT EXISTS idx_listings_state_status ON listings(state, status);
CREATE INDEX IF NOT EXISTS idx_listings_state_created_at ON listings(state, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_status_active ON listings(status, active) WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS idx_listings_state_price ON listings(state, list_price) WHERE list_price IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_pipeline_status_active ON listings(pipeline_status, active) WHERE active = TRUE;
CREATE INDEX IF NOT EXISTS idx_listings_user_status ON listings(user_id, status) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_city_state_status ON listings(city, state, status);

-- Price range indexes
CREATE INDEX IF NOT EXISTS idx_listings_price_range ON listings(list_price) WHERE list_price IS NOT NULL AND list_price > 0;

-- CRM table indexes
CREATE INDEX IF NOT EXISTS idx_tasks_user_status_due ON tasks(user_id, status, due_date) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_user_priority ON tasks(user_id, priority, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_user_status ON contacts(user_id, status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_user_created_at ON contacts(user_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_user_stage ON deals(user_id, stage) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_user_stage_value ON deals(user_id, stage, value DESC) WHERE deleted_at IS NULL;

-- Full text search indexes
CREATE INDEX IF NOT EXISTS idx_listings_text_search ON listings USING gin(to_tsvector('english', COALESCE(text, '')));

-- ============================================================================
-- SCHEMA ENHANCEMENTS - READ-OPTIMIZED VIEWS
-- ============================================================================
-- See: read_optimized_views_schema.sql

-- Prospect Enrich View for "Prospect & Enrich" UI
CREATE OR REPLACE VIEW prospect_enrich_view AS
SELECT 
  l.listing_id, l.property_url, l.permalink,
  l.street, l.unit, l.city, l.state, l.zip_code, l.lat, l.lng,
  l.beds, l.full_baths, l.half_baths, l.sqft, l.year_built, l.list_price, l.price_per_sqft,
  l.status, l.active, l.pipeline_status, l.scrape_date, l.last_scraped_at,
  l.created_at, l.updated_at,
  l.agent_name AS contact_name, l.agent_email AS contact_email, l.agent_phone AS contact_phone,
  fsbo_raw.enriched AS is_enriched, fsbo_raw.enriched_at, fsbo_raw.validated AS is_validated,
  (SELECT COUNT(*) FROM contacts c WHERE c.source_id = l.listing_id AND c.deleted_at IS NULL) AS contact_count,
  (SELECT COUNT(*) FROM deals d WHERE d.source_id = l.listing_id AND d.deleted_at IS NULL) AS deal_count,
  (SELECT COUNT(*) FROM tasks t WHERE t.related_type = 'listing' AND t.related_id = l.listing_id AND t.deleted_at IS NULL) AS task_count,
  (SELECT array_agg(DISTINCT li.list_id::TEXT) FROM list_items li
   INNER JOIN lists lst ON li.list_id = lst.id
   WHERE li.item_type = 'listing' AND li.item_id = l.listing_id
   AND li.deleted_at IS NULL AND lst.deleted_at IS NULL) AS list_ids,
  l.listing_source_name, l.listing_source_id, l.user_id AS scraped_by_user_id,
  l.photos_json, l.other AS metadata, l.tags, l.ai_investment_score
FROM listings l
LEFT JOIN fsbo_raw ON l.listing_id = fsbo_raw.listing_id
WHERE l.active = TRUE;

COMMENT ON VIEW prospect_enrich_view IS 
  'Optimized view for Prospect & Enrich UI page - joins listings with enrichment and CRM state';

-- ============================================================================
-- SCHEMA ENHANCEMENTS - DASHBOARD AGGREGATIONS
-- ============================================================================
-- See: dashboard_aggregations_schema.sql

-- Lead Counts by Category (Materialized View)
CREATE MATERIALIZED VIEW IF NOT EXISTS lead_counts_by_category AS
SELECT 
  'fsbo_leads' AS category, status, state, city,
  COUNT(*) AS lead_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_count,
  AVG(list_price) AS avg_price, MIN(list_price) AS min_price, MAX(list_price) AS max_price,
  MIN(created_at) AS first_seen, MAX(created_at) AS last_seen
FROM fsbo_leads
GROUP BY status, state, city
UNION ALL
SELECT 
  'expired_listings' AS category, status, state, city,
  COUNT(*) AS lead_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_count,
  AVG(list_price) AS avg_price, MIN(list_price) AS min_price, MAX(list_price) AS max_price,
  MIN(created_at) AS first_seen, MAX(created_at) AS last_seen
FROM expired_listings
GROUP BY status, state, city;

CREATE INDEX IF NOT EXISTS idx_lead_counts_category_status ON lead_counts_by_category(category, status);
CREATE INDEX IF NOT EXISTS idx_lead_counts_state_city ON lead_counts_by_category(state, city);

-- Status Funnel View
CREATE MATERIALIZED VIEW IF NOT EXISTS status_funnel AS
SELECT 
  pipeline_status, COUNT(*) AS total_count,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_count,
  AVG(list_price) AS avg_price,
  MIN(created_at) AS oldest_lead, MAX(created_at) AS newest_lead
FROM (
  SELECT pipeline_status, active, list_price, created_at FROM listings
  UNION ALL SELECT pipeline_status, active, list_price, created_at FROM fsbo_leads
) AS all_leads
WHERE pipeline_status IS NOT NULL
GROUP BY pipeline_status;

CREATE INDEX IF NOT EXISTS idx_status_funnel_status ON status_funnel(pipeline_status);

-- Refresh function
CREATE OR REPLACE FUNCTION refresh_dashboard_aggregations()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY lead_counts_by_category;
  REFRESH MATERIALIZED VIEW CONCURRENTLY status_funnel;
END;
$$ LANGUAGE plpgsql;

COMMENT ON MATERIALIZED VIEW lead_counts_by_category IS 
  'Aggregated lead counts by category, status, and location for dashboard analytics';
COMMENT ON MATERIALIZED VIEW status_funnel IS 
  'Pipeline status funnel showing progression through processing stages';

-- ============================================================================
-- SCHEMA ENHANCEMENTS - SCHEMA VERSIONING
-- ============================================================================
-- See: schema_versioning_schema.sql

CREATE TABLE IF NOT EXISTS schema_versions (
  id SERIAL PRIMARY KEY,
  version TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  migration_file TEXT,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  applied_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  checksum TEXT,
  rollback_sql TEXT,
  metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_schema_versions_version ON schema_versions(version);
CREATE INDEX IF NOT EXISTS idx_schema_versions_applied_at ON schema_versions(applied_at DESC);

CREATE OR REPLACE FUNCTION get_current_schema_version()
RETURNS TEXT AS $$
DECLARE
  v_version TEXT;
BEGIN
  SELECT version INTO v_version FROM schema_versions ORDER BY applied_at DESC LIMIT 1;
  RETURN COALESCE(v_version, '0.0.0');
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION check_schema_version(p_expected_version TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_current_version TEXT;
BEGIN
  v_current_version := get_current_schema_version();
  RETURN v_current_version = p_expected_version;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION require_schema_version(p_expected_version TEXT)
RETURNS VOID AS $$
DECLARE
  v_current_version TEXT;
BEGIN
  v_current_version := get_current_schema_version();
  IF v_current_version != p_expected_version THEN
    RAISE EXCEPTION 'Schema version mismatch: expected %, got %', p_expected_version, v_current_version;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION record_schema_migration(
  p_version TEXT, p_description TEXT, p_migration_file TEXT DEFAULT NULL,
  p_checksum TEXT DEFAULT NULL, p_rollback_sql TEXT DEFAULT NULL, p_metadata JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO schema_versions (version, description, migration_file, applied_by, checksum, rollback_sql, metadata)
  VALUES (p_version, p_description, p_migration_file, auth.uid(), p_checksum, p_rollback_sql, p_metadata);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert initial schema version
INSERT INTO schema_versions (version, description, migration_file)
VALUES ('2.0.0', 'Complete schema with all enhancements: address normalization, enum lookups, soft deletes, indexes, views, aggregations, versioning', 'complete_schema.sql')
ON CONFLICT (version) DO NOTHING;

ALTER TABLE schema_versions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Users can view schema versions" ON schema_versions FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Admins can manage schema versions" ON schema_versions FOR ALL TO authenticated
  USING (auth.role() = 'service_role' OR (
    EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users')
    AND EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  ));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMENT ON TABLE schema_versions IS 
  'Tracks database schema versions to ensure Data-Lake-Backend and LeadMap-main stay in sync';
COMMENT ON FUNCTION get_current_schema_version IS 'Returns the current schema version string';
COMMENT ON FUNCTION require_schema_version IS 'Raises an error if schema version does not match expected';

-- ============================================================================
-- SCALABILITY OPTIMIZATIONS FOR 500 CONCURRENT USERS
-- ============================================================================
-- See: scalability_optimizations.sql and docs/SCALABILITY_500_USERS.md
-- 
-- KEY OPTIMIZATIONS INCLUDED:
-- 1. Enhanced RLS policies with soft-delete filtering (in soft_delete_schema.sql)
-- 2. Composite indexes for high-frequency query patterns (in index_optimization_schema.sql)
-- 3. Pagination optimization indexes (below)
-- 4. Materialized views for dashboard performance (in dashboard_aggregations_schema.sql)
-- 
-- CRITICAL FOR 500 USERS:
-- - All user-specific queries MUST filter by deleted_at IS NULL
-- - Use materialized views for dashboard aggregations
-- - Implement pagination on all list queries
-- - Use connection pooling (transaction pool, 100-200 connections)
-- - Schedule materialized view refreshes every 15 minutes
--
-- Apply scalability_optimizations.sql after this schema for production deployment
-- That file is fully independent and can be run standalone
-- ============================================================================

-- Additional pagination indexes for 500-user load
CREATE INDEX IF NOT EXISTS idx_contacts_user_created_at_pagination 
  ON contacts(user_id, created_at DESC, id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_deals_user_created_at_pagination 
  ON deals(user_id, created_at DESC, id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_user_created_at_pagination 
  ON tasks(user_id, created_at DESC, id) 
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_listings_created_at_pagination 
  ON listings(created_at DESC, listing_id) 
  WHERE active = TRUE;

-- Optimized dashboard summary function for single-user queries
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

COMMENT ON FUNCTION get_user_dashboard_summary IS 
  'Optimized dashboard summary for single user. Use instead of multiple queries. Critical for 500-user performance.';

-- ============================================================================
-- SCHEMA ENHANCEMENTS - FSBO UPSERT IDEMPOTENT SUPPORT
-- ============================================================================
-- Ensure idempotent upserts using listing_id + property_url

-- Function for idempotent FSBO upsert
CREATE OR REPLACE FUNCTION upsert_fsbo_lead(p_listing_data JSONB)
RETURNS UUID AS $$
DECLARE
  v_listing_id TEXT;
  v_property_url TEXT;
  v_result UUID;
BEGIN
  v_listing_id := p_listing_data->>'listing_id';
  v_property_url := p_listing_data->>'property_url';
  
  IF v_listing_id IS NULL OR v_property_url IS NULL THEN
    RAISE EXCEPTION 'listing_id and property_url are required';
  END IF;
  
  INSERT INTO fsbo_leads (
    listing_id, property_url, permalink, scrape_date, last_scraped_at,
    active, street, unit, city, state, zip_code, beds, full_baths, half_baths,
    sqft, year_built, list_price, status, mls, agent_name, agent_email,
    agent_phone, text, fsbo_source, pipeline_status, lat, lng
  ) VALUES (
    v_listing_id,
    v_property_url,
    p_listing_data->>'permalink',
    (p_listing_data->>'scrape_date')::DATE,
    COALESCE((p_listing_data->>'last_scraped_at')::TIMESTAMPTZ, NOW()),
    COALESCE((p_listing_data->>'active')::BOOLEAN, TRUE),
    p_listing_data->>'street',
    p_listing_data->>'unit',
    p_listing_data->>'city',
    p_listing_data->>'state',
    p_listing_data->>'zip_code',
    (p_listing_data->>'beds')::INTEGER,
    (p_listing_data->>'full_baths')::NUMERIC(4,2),
    (p_listing_data->>'half_baths')::INTEGER,
    (p_listing_data->>'sqft')::INTEGER,
    (p_listing_data->>'year_built')::INTEGER,
    (p_listing_data->>'list_price')::BIGINT,
    COALESCE(p_listing_data->>'status', 'fsbo'),
    p_listing_data->>'mls',
    p_listing_data->>'agent_name',
    p_listing_data->>'agent_email',
    p_listing_data->>'agent_phone',
    p_listing_data->>'text',
    p_listing_data->>'fsbo_source',
    COALESCE(p_listing_data->>'pipeline_status', 'new'),
    (p_listing_data->>'lat')::NUMERIC,
    (p_listing_data->>'lng')::NUMERIC
  )
  ON CONFLICT (listing_id) DO UPDATE SET
    property_url = EXCLUDED.property_url,
    last_scraped_at = EXCLUDED.last_scraped_at,
    active = EXCLUDED.active,
    street = EXCLUDED.street,
    city = EXCLUDED.city,
    state = EXCLUDED.state,
    zip_code = EXCLUDED.zip_code,
    list_price = EXCLUDED.list_price,
    status = EXCLUDED.status,
    agent_name = EXCLUDED.agent_name,
    agent_email = EXCLUDED.agent_email,
    agent_phone = EXCLUDED.agent_phone,
    text = EXCLUDED.text,
    fsbo_source = EXCLUDED.fsbo_source,
    updated_at = NOW()
  RETURNING listing_id::TEXT INTO v_result;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION upsert_fsbo_lead IS 'Idempotent upsert for FSBO leads using listing_id as conflict resolution';

-- ============================================================================
-- SCHEMA ENHANCEMENTS - SOURCE HEALTH VIEW
-- ============================================================================
-- View summarizing per-source metrics for admin dashboard

CREATE OR REPLACE VIEW source_health_summary AS
SELECT 
  'fsbo_leads' AS source_type,
  fsbo_source AS source_name,
  COUNT(*) AS total_leads,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_leads,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_leads,
  COUNT(CASE WHEN scrape_date >= CURRENT_DATE - INTERVAL '1 day' THEN 1 END) AS leads_last_24h,
  COUNT(CASE WHEN scrape_date >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END) AS leads_last_7d,
  COUNT(CASE WHEN scrape_date >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) AS leads_last_30d,
  COUNT(DISTINCT state) AS states_covered,
  COUNT(DISTINCT city) AS cities_covered,
  AVG(list_price) AS avg_list_price,
  MIN(scrape_date) AS first_seen,
  MAX(scrape_date) AS last_seen,
  MAX(last_scraped_at) AS most_recent_scrape,
  COUNT(CASE WHEN agent_email IS NOT NULL OR agent_phone IS NOT NULL THEN 1 END) AS leads_with_contact_info,
  COUNT(CASE WHEN lat IS NOT NULL AND lng IS NOT NULL THEN 1 END) AS geocoded_count,
  0 AS leads_with_raw_data
FROM fsbo_leads
WHERE fsbo_source IS NOT NULL
GROUP BY fsbo_source

UNION ALL

SELECT 
  'expired_listings' AS source_type,
  'redfin' AS source_name,
  COUNT(*) AS total_leads,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_leads,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_leads,
  COUNT(CASE WHEN scrape_date >= CURRENT_DATE - INTERVAL '1 day' THEN 1 END) AS leads_last_24h,
  COUNT(CASE WHEN scrape_date >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END) AS leads_last_7d,
  COUNT(CASE WHEN scrape_date >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) AS leads_last_30d,
  COUNT(DISTINCT state) AS states_covered,
  COUNT(DISTINCT city) AS cities_covered,
  AVG(list_price) AS avg_list_price,
  MIN(scrape_date) AS first_seen,
  MAX(scrape_date) AS last_seen,
  MAX(last_scraped_at) AS most_recent_scrape,
  COUNT(CASE WHEN agent_email IS NOT NULL OR agent_phone IS NOT NULL THEN 1 END) AS leads_with_contact_info,
  COUNT(CASE WHEN lat IS NOT NULL AND lng IS NOT NULL THEN 1 END) AS geocoded_count,
  0 AS leads_with_raw_data
FROM expired_listings
GROUP BY 1, 2

UNION ALL

SELECT 
  'imports' AS source_type,
  import_source AS source_name,
  COUNT(*) AS total_leads,
  COUNT(CASE WHEN active = TRUE THEN 1 END) AS active_leads,
  COUNT(CASE WHEN active = FALSE THEN 1 END) AS inactive_leads,
  COUNT(CASE WHEN created_at >= NOW() - INTERVAL '1 day' THEN 1 END) AS leads_last_24h,
  COUNT(CASE WHEN created_at >= NOW() - INTERVAL '7 days' THEN 1 END) AS leads_last_7d,
  COUNT(CASE WHEN created_at >= NOW() - INTERVAL '30 days' THEN 1 END) AS leads_last_30d,
  COUNT(DISTINCT state) AS states_covered,
  COUNT(DISTINCT city) AS cities_covered,
  AVG(list_price) AS avg_list_price,
  MIN(created_at::DATE) AS first_seen,
  MAX(created_at::DATE) AS last_seen,
  MAX(created_at) AS most_recent_scrape,
  COUNT(CASE WHEN agent_email IS NOT NULL OR agent_phone IS NOT NULL THEN 1 END) AS leads_with_contact_info,
  COUNT(CASE WHEN lat IS NOT NULL AND lng IS NOT NULL THEN 1 END) AS geocoded_count,
  0 AS leads_with_raw_data
FROM imports
WHERE import_source IS NOT NULL
GROUP BY import_source;

COMMENT ON VIEW source_health_summary IS 
  'Per-source health metrics for admin dashboard - summarizes FSBO, expired, and import sources';

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

