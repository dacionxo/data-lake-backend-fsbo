-- ============================================================================
-- Data Lake Zones Schema
-- ============================================================================
-- This schema introduces explicit data-lake "zones" to organize data by
-- processing stage: raw, staging, and curated.
-- 
-- ZONES:
-- - raw: Raw responses, CSV imports, unprocessed data from external sources
-- - staging: Normalized and partially processed data (e.g., fsbo_raw)
-- - curated: Fully processed, validated, and ready-for-use data (listings, CRM)
--
-- DEPENDENCIES:
-- - Requires: data_lake_ingestion_schema.sql (must be run first)
--   * pipeline_runs table must exist
-- - Requires: Supabase auth.users (built-in, always available)
-- - Optional: users table (for admin role checks in RLS policies)
--
-- INSTALLATION ORDER:
-- 1. Run data_lake_ingestion_schema.sql first
-- 2. Then run this file (data_lake_zones_schema.sql)
-- 3. Zone tables will reference pipeline_runs from ingestion schema
--
-- NOTE: If pipeline_runs table doesn't exist, foreign key constraints
-- will fail. Make sure to run ingestion schema first.
-- ============================================================================

-- Ensure uuid extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Check if pipeline_runs exists (optional validation)
-- This will fail with a clear error if ingestion schema wasn't run first
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'pipeline_runs'
  ) THEN
    RAISE EXCEPTION 'pipeline_runs table not found. Please run data_lake_ingestion_schema.sql first.';
  END IF;
END $$;

-- ============================================================================
-- RAW ZONE TABLES
-- ============================================================================
-- Stores raw, unprocessed data from external sources

-- Raw Redfin Responses Table
-- Stores raw API responses from Redfin scraping
CREATE TABLE IF NOT EXISTS raw_redfin_responses (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  response_data JSONB NOT NULL, -- Raw JSON response from Redfin
  url TEXT NOT NULL, -- URL that was scraped
  status_code INTEGER, -- HTTP status code
  response_headers JSONB, -- Response headers
  scraped_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL, -- Link to ingestion metadata
  processed BOOLEAN NOT NULL DEFAULT FALSE, -- Whether this has been processed
  processed_at TIMESTAMPTZ, -- When it was processed
  error_message TEXT, -- Error if processing failed
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_raw_redfin_responses_scraped_at ON raw_redfin_responses(scraped_at DESC);
CREATE INDEX IF NOT EXISTS idx_raw_redfin_responses_processed ON raw_redfin_responses(processed);
CREATE INDEX IF NOT EXISTS idx_raw_redfin_responses_pipeline_run ON raw_redfin_responses(pipeline_run_id);

-- Raw CSV Imports Table
-- Stores raw CSV data imports before processing
CREATE TABLE IF NOT EXISTS raw_csv_imports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  filename TEXT NOT NULL,
  file_size_bytes INTEGER,
  row_count INTEGER,
  raw_data JSONB NOT NULL, -- Array of row objects with raw CSV data
  column_mapping JSONB, -- Column name mappings if any
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
-- Stores raw Apollo.io API responses
CREATE TABLE IF NOT EXISTS raw_apollo_imports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  list_id TEXT, -- Apollo list ID
  response_data JSONB NOT NULL, -- Raw API response
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

-- ============================================================================
-- STAGING ZONE TABLES
-- ============================================================================
-- Stores normalized and partially processed data

-- FSBO Raw Table (Staging)
-- Normalized FSBO data extracted from raw responses but not yet enriched
CREATE TABLE IF NOT EXISTS fsbo_raw (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  listing_id TEXT, -- From raw response
  property_url TEXT,
  raw_response_id UUID REFERENCES raw_redfin_responses(id) ON DELETE SET NULL, -- Link back to raw data
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  
  -- Basic property data (normalized)
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
  
  -- Raw fields (preserved from source)
  raw_data JSONB, -- Preserve original raw data for reference
  
  -- Processing status
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
-- Normalized data from CSV/API imports before moving to curated
CREATE TABLE IF NOT EXISTS import_staging (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  raw_import_id UUID, -- References raw_csv_imports or raw_apollo_imports
  import_type TEXT NOT NULL CHECK (import_type IN ('csv', 'apollo', 'manual', 'api')),
  pipeline_run_id UUID REFERENCES pipeline_runs(id) ON DELETE SET NULL,
  
  -- Normalized fields (common across import types)
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
  
  -- Structured data
  normalized_data JSONB NOT NULL, -- Fully normalized structure
  raw_data JSONB, -- Original raw data for reference
  
  -- Processing status
  validated BOOLEAN NOT NULL DEFAULT FALSE,
  validated_at TIMESTAMPTZ,
  enriched BOOLEAN NOT NULL DEFAULT FALSE,
  enriched_at TIMESTAMPTZ,
  moved_to_curated BOOLEAN NOT NULL DEFAULT FALSE,
  moved_at TIMESTAMPTZ,
  error_message TEXT,
  
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- User who imported
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_import_staging_import_type ON import_staging(import_type);
CREATE INDEX IF NOT EXISTS idx_import_staging_validated ON import_staging(validated);
CREATE INDEX IF NOT EXISTS idx_import_staging_user_id ON import_staging(user_id);
CREATE INDEX IF NOT EXISTS idx_import_staging_pipeline_run ON import_staging(pipeline_run_id);

-- ============================================================================
-- CURATED ZONE TABLES (EXISTING TABLES MAPPED)
-- ============================================================================
-- The following existing tables belong to the curated zone:
-- - listings (curated property listings)
-- - fsbo_leads (enriched FSBO leads - moved from staging)
-- - expired_listings (curated expired listings)
-- - frbo_leads (curated FRBO leads)
-- - foreclosure_listings (curated foreclosure listings)
-- - contacts (curated contact data from CRM)
-- - deals (curated deal data from CRM)
-- - tasks (curated task data)
-- - lists (curated list data)
-- - list_items (curated list item data)
-- - imports (curated import records - user-specific)
-- - trash (curated trash records - user-specific)
--
-- These tables are already defined in complete_schema.sql and should
-- remain as-is. This schema just documents their zone classification.
-- ============================================================================

-- ============================================================================
-- ZONE TRANSITION TRACKING
-- ============================================================================
-- Track when data moves between zones

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
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all zone tables
ALTER TABLE raw_redfin_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_csv_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_apollo_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE fsbo_raw ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_staging ENABLE ROW LEVEL SECURITY;
ALTER TABLE zone_transitions ENABLE ROW LEVEL SECURITY;

-- Policies for raw zone tables
-- Service role and admins can view all raw data
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
-- Authenticated users can view staging data
CREATE POLICY "Authenticated users can view fsbo_raw"
  ON fsbo_raw FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can view their own import staging"
  ON import_staging FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Users can view their own import staging, admins can view all
CREATE POLICY "Users can manage their own import staging"
  ON import_staging FOR ALL
  TO authenticated
  USING (
    user_id = auth.uid() OR
    auth.role() = 'service_role' OR
    (
      EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'users'
      )
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.role = 'admin'
      )
    )
  );

-- Policies for zone_transitions
-- Authenticated users can view transitions
CREATE POLICY "Authenticated users can view zone transitions"
  ON zone_transitions FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE raw_redfin_responses IS 'RAW ZONE: Raw API responses from Redfin scraping';
COMMENT ON TABLE raw_csv_imports IS 'RAW ZONE: Raw CSV file imports before processing';
COMMENT ON TABLE raw_apollo_imports IS 'RAW ZONE: Raw Apollo.io API responses';
COMMENT ON TABLE fsbo_raw IS 'STAGING ZONE: Normalized FSBO data extracted from raw responses';
COMMENT ON TABLE import_staging IS 'STAGING ZONE: Normalized data from CSV/API imports';
COMMENT ON TABLE zone_transitions IS 'Tracks when data moves between zones for audit and lineage';

