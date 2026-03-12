-- ============================================================================
-- Data Lake Ingestion Metadata Schema
-- ============================================================================
-- This schema adds ingestion metadata tables to track all data pipelines,
-- pipeline runs, and pipeline run events across all data ingestion jobs.
-- 
-- Purpose:
-- - Track all data ingestion pipelines (scraper, enrichment, geocoding, imports)
-- - Monitor pipeline execution and performance
-- - Enable data lineage and audit trails
-- - Support troubleshooting and debugging
--
-- DEPENDENCIES:
-- - Requires: Supabase auth.users (built-in, always available)
-- - No dependencies on other custom tables
-- - Can be installed independently or before zone schema
--
-- INSTALLATION:
-- 1. Go to Supabase Dashboard > SQL Editor
-- 2. Run this entire file
-- 3. Then run data_lake_zones_schema.sql (which depends on this)
-- ============================================================================

-- Ensure uuid extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- PIPELINES TABLE
-- ============================================================================
-- Defines all data ingestion pipelines in the system
CREATE TABLE IF NOT EXISTS pipelines (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE, -- e.g., 'redfin_fsbo_scraper', 'geocoding_backfill', 'apollo_import'
  description TEXT,
  pipeline_type TEXT NOT NULL CHECK (pipeline_type IN (
    'scraper',        -- Web scraping pipelines (Redfin, etc.)
    'enrichment',     -- Data enrichment pipelines (skip tracing, etc.)
    'geocoding',      -- Geocoding pipelines
    'import',         -- Data import pipelines (CSV, API, etc.)
    'transformation', -- Data transformation pipelines
    'validation',     -- Data validation pipelines
    'sync'            -- Data synchronization pipelines
  )),
  source_zone TEXT NOT NULL CHECK (source_zone IN ('raw', 'staging', 'curated', 'external')),
  target_zone TEXT NOT NULL CHECK (target_zone IN ('raw', 'staging', 'curated')),
  source_tables TEXT[], -- Tables this pipeline reads from
  target_tables TEXT[], -- Tables this pipeline writes to
  config JSONB, -- Pipeline-specific configuration
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  schedule_cron TEXT, -- Cron expression for scheduled pipelines (optional)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Indexes for pipelines
CREATE INDEX IF NOT EXISTS idx_pipelines_type ON pipelines(pipeline_type);
CREATE INDEX IF NOT EXISTS idx_pipelines_enabled ON pipelines(enabled);
CREATE INDEX IF NOT EXISTS idx_pipelines_target_zone ON pipelines(target_zone);

-- ============================================================================
-- PIPELINE_RUNS TABLE
-- ============================================================================
-- Tracks individual executions of pipelines
CREATE TABLE IF NOT EXISTS pipeline_runs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pipeline_id UUID NOT NULL REFERENCES pipelines(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN (
    'queued',      -- Pipeline run is queued
    'running',     -- Pipeline run is currently executing
    'completed',   -- Pipeline run completed successfully
    'failed',      -- Pipeline run failed
    'cancelled',   -- Pipeline run was cancelled
    'timeout'      -- Pipeline run timed out
  )),
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  duration_seconds INTEGER, -- Calculated duration in seconds
  records_processed INTEGER DEFAULT 0, -- Number of records processed
  records_succeeded INTEGER DEFAULT 0, -- Number of records that succeeded
  records_failed INTEGER DEFAULT 0,    -- Number of records that failed
  error_message TEXT, -- Error message if status is 'failed'
  error_stack TEXT,   -- Full error stack trace if available
  metadata JSONB,     -- Additional metadata about the run
  triggered_by TEXT,  -- 'manual', 'scheduled', 'api', 'webhook', etc.
  triggered_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for pipeline_runs
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_pipeline_id ON pipeline_runs(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_status ON pipeline_runs(status);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started_at ON pipeline_runs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_pipeline_status ON pipeline_runs(pipeline_id, status);
CREATE INDEX IF NOT EXISTS idx_pipeline_runs_triggered_by_user ON pipeline_runs(triggered_by_user_id);

-- ============================================================================
-- PIPELINE_RUN_EVENTS TABLE
-- ============================================================================
-- Tracks granular events within a pipeline run (for detailed logging and debugging)
CREATE TABLE IF NOT EXISTS pipeline_run_events (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  pipeline_run_id UUID NOT NULL REFERENCES pipeline_runs(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN (
    'start',           -- Pipeline run started
    'progress',        -- Progress update (e.g., batch processed)
    'milestone',       -- Important milestone reached
    'warning',         -- Warning occurred
    'error',           -- Error occurred (non-fatal)
    'checkpoint',      -- Checkpoint saved (for resume capability)
    'complete',        -- Pipeline run completed
    'fail',            -- Pipeline run failed
    'cancel'           -- Pipeline run cancelled
  )),
  event_level TEXT NOT NULL DEFAULT 'info' CHECK (event_level IN ('debug', 'info', 'warning', 'error', 'critical')),
  message TEXT NOT NULL,
  details JSONB, -- Additional event details (record IDs, counts, etc.)
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for pipeline_run_events
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_run_id ON pipeline_run_events(pipeline_run_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_type ON pipeline_run_events(event_type);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_level ON pipeline_run_events(event_level);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_occurred_at ON pipeline_run_events(occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_pipeline_run_events_run_type ON pipeline_run_events(pipeline_run_id, event_type);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

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
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE pipelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_run_events ENABLE ROW LEVEL SECURITY;

-- Policies for pipelines table
-- All authenticated users can view pipelines
CREATE POLICY "Users can view pipelines"
  ON pipelines FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert/update/delete pipelines
-- Note: This policy checks for admin role in users table if it exists
-- If users table doesn't exist, adjust this policy as needed
CREATE POLICY "Admins can manage pipelines"
  ON pipelines FOR ALL
  TO authenticated
  USING (
    -- If users table exists, check for admin role
    -- Otherwise, allow service role only
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

-- Policies for pipeline_runs table
-- All authenticated users can view pipeline runs
CREATE POLICY "Users can view pipeline runs"
  ON pipeline_runs FOR SELECT
  TO authenticated
  USING (true);

-- Users can create pipeline runs (for manual triggers)
CREATE POLICY "Users can create pipeline runs"
  ON pipeline_runs FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Users can update their own pipeline runs, admins can update any
CREATE POLICY "Users can update pipeline runs"
  ON pipeline_runs FOR UPDATE
  TO authenticated
  USING (
    triggered_by_user_id = auth.uid() OR
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

-- Policies for pipeline_run_events table
-- All authenticated users can view events
CREATE POLICY "Users can view pipeline run events"
  ON pipeline_run_events FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM pipeline_runs pr
      WHERE pr.id = pipeline_run_events.pipeline_run_id
    )
  );

-- Service role and pipeline runners can insert events
CREATE POLICY "Service role can insert pipeline run events"
  ON pipeline_run_events FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================================================
-- INITIAL PIPELINE DEFINITIONS
-- ============================================================================

-- Insert default pipeline definitions
INSERT INTO pipelines (name, description, pipeline_type, source_zone, target_zone, source_tables, target_tables, enabled)
VALUES
  ('redfin_fsbo_scraper', 'Redfin FSBO listing scraper', 'scraper', 'external', 'raw', ARRAY[]::TEXT[], ARRAY['raw_redfin_responses'], TRUE),
  ('fsbo_enrichment', 'FSBO lead enrichment (skip tracing, contact info)', 'enrichment', 'raw', 'staging', ARRAY['raw_redfin_responses'], ARRAY['fsbo_raw'], TRUE),
  ('geocoding_backfill', 'Backfill geocoding for addresses', 'geocoding', 'staging', 'curated', ARRAY['fsbo_raw', 'listings'], ARRAY['fsbo_leads', 'listings'], TRUE),
  ('csv_import', 'CSV file import pipeline', 'import', 'external', 'raw', ARRAY[]::TEXT[], ARRAY['raw_csv_imports'], TRUE),
  ('apollo_import', 'Apollo.io list import', 'import', 'external', 'raw', ARRAY[]::TEXT[], ARRAY['raw_apollo_imports'], TRUE)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE pipelines IS 'Defines all data ingestion pipelines in the system';
COMMENT ON TABLE pipeline_runs IS 'Tracks individual executions of pipelines';
COMMENT ON TABLE pipeline_run_events IS 'Tracks granular events within pipeline runs for logging and debugging';
COMMENT ON COLUMN pipelines.source_zone IS 'Source data zone: raw (raw data), staging (normalized), curated (validated), external (external sources)';
COMMENT ON COLUMN pipelines.target_zone IS 'Target data zone: raw (raw data), staging (normalized), curated (validated)';
COMMENT ON COLUMN pipeline_runs.triggered_by IS 'How the pipeline run was triggered: manual, scheduled, api, webhook, etc.';

