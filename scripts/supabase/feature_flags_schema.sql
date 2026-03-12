-- ============================================================================
-- Feature Flags Schema
-- ============================================================================
-- This schema creates a feature flags system that can be consumed by both
-- Python jobs (Data-Lake-Backend) and Next.js API routes (LeadMap-main).
--
-- Purpose:
-- - Toggle new pipelines on/off without code changes
-- - Control schema behaviors and feature rollouts
-- - A/B testing and gradual feature releases
-- - Environment-specific configuration overrides
--
-- Usage:
-- - Python jobs: Query feature_flags table via Supabase client
-- - Next.js API: Query feature_flags table via Supabase client
-- - Both can cache flags and refresh periodically
-- ============================================================================

-- Ensure uuid extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- FEATURE FLAGS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS feature_flags (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  flag_key TEXT NOT NULL UNIQUE, -- e.g., 'enable_fsbo_enrichment', 'enable_new_schema_v2'
  flag_value BOOLEAN NOT NULL DEFAULT FALSE,
  description TEXT, -- Human-readable description of what this flag controls
  category TEXT, -- 'pipeline', 'schema', 'ui', 'feature', etc.
  
  -- Environment targeting
  environment TEXT NOT NULL DEFAULT 'production' CHECK (environment IN ('development', 'staging', 'production')),
  
  -- Targeting (optional)
  target_users UUID[], -- Specific user IDs (empty = all users)
  target_roles TEXT[], -- Specific roles (empty = all roles)
  
  -- Rollout configuration
  rollout_percentage INTEGER DEFAULT 100 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
  
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Constraints
  CONSTRAINT flag_key_format CHECK (flag_key ~ '^[a-z0-9_]+$') -- lowercase, numbers, underscores only
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON feature_flags(flag_key);
CREATE INDEX IF NOT EXISTS idx_feature_flags_category ON feature_flags(category);
CREATE INDEX IF NOT EXISTS idx_feature_flags_environment ON feature_flags(environment);
CREATE INDEX IF NOT EXISTS idx_feature_flags_enabled ON feature_flags(flag_value) WHERE flag_value = TRUE;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to check if a feature flag is enabled
-- Takes into account environment, rollout percentage, and user targeting
CREATE OR REPLACE FUNCTION is_feature_enabled(
  p_flag_key TEXT,
  p_user_id UUID DEFAULT NULL,
  p_user_role TEXT DEFAULT NULL,
  p_environment TEXT DEFAULT 'production'
)
RETURNS BOOLEAN AS $$
DECLARE
  v_flag RECORD;
  v_user_hash INTEGER;
  v_rollout_hash INTEGER;
BEGIN
  -- Get the feature flag
  SELECT * INTO v_flag
  FROM feature_flags
  WHERE flag_key = p_flag_key
    AND environment = p_environment;
  
  -- Flag doesn't exist = disabled by default
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Flag is explicitly disabled
  IF NOT v_flag.flag_value THEN
    RETURN FALSE;
  END IF;
  
  -- Check user targeting
  IF array_length(v_flag.target_users, 1) > 0 THEN
    IF p_user_id IS NULL OR NOT (p_user_id = ANY(v_flag.target_users)) THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- Check role targeting
  IF array_length(v_flag.target_roles, 1) > 0 THEN
    IF p_user_role IS NULL OR NOT (p_user_role = ANY(v_flag.target_roles)) THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- Check rollout percentage (deterministic based on user_id)
  IF v_flag.rollout_percentage < 100 AND p_user_id IS NOT NULL THEN
    -- Deterministic hash based on user_id and flag_key
    v_user_hash := abs(hashtext(p_user_id::TEXT || p_flag_key));
    v_rollout_hash := v_user_hash % 100;
    IF v_rollout_hash >= v_flag.rollout_percentage THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- All checks passed
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get all enabled flags for an environment
CREATE OR REPLACE FUNCTION get_enabled_features(
  p_environment TEXT DEFAULT 'production',
  p_user_id UUID DEFAULT NULL,
  p_user_role TEXT DEFAULT NULL
)
RETURNS TABLE (flag_key TEXT, flag_value BOOLEAN, category TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ff.flag_key,
    is_feature_enabled(ff.flag_key, p_user_id, p_user_role, p_environment) as flag_value,
    ff.category
  FROM feature_flags ff
  WHERE ff.environment = p_environment
    AND is_feature_enabled(ff.flag_key, p_user_id, p_user_role, p_environment) = TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_feature_flags_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_feature_flags_updated_at
  BEFORE UPDATE ON feature_flags
  FOR EACH ROW
  EXECUTE FUNCTION update_feature_flags_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view feature flags (needed for client-side checks)
CREATE POLICY "Users can view feature flags"
  ON feature_flags FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert/update/delete feature flags
CREATE POLICY "Admins can manage feature flags"
  ON feature_flags FOR ALL
  TO authenticated
  USING (
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

-- ============================================================================
-- INITIAL FEATURE FLAGS
-- ============================================================================

-- Insert default feature flags
INSERT INTO feature_flags (flag_key, flag_value, description, category, environment)
VALUES
  ('enable_fsbo_enrichment', TRUE, 'Enable FSBO lead enrichment pipeline', 'pipeline', 'production'),
  ('enable_geocoding_backfill', TRUE, 'Enable geocoding backfill pipeline', 'pipeline', 'production'),
  ('enable_ip_rotation', TRUE, 'Enable AWS IP rotation for scraping', 'pipeline', 'production'),
  ('enable_skip_tracing', TRUE, 'Enable skip tracing in enrichment', 'pipeline', 'production'),
  ('enable_new_schema_v2', FALSE, 'Enable new schema version 2 features', 'schema', 'production'),
  ('enable_batch_processing', TRUE, 'Enable batch processing for pipelines', 'pipeline', 'production'),
  ('enable_error_retry', TRUE, 'Enable automatic error retry in pipelines', 'pipeline', 'production'),
  ('enable_debug_logging', FALSE, 'Enable debug-level logging', 'logging', 'production')
ON CONFLICT (flag_key) DO NOTHING;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE feature_flags IS 'Feature flags for toggling pipelines and behaviors across Data-Lake-Backend and LeadMap-main';
COMMENT ON FUNCTION is_feature_enabled IS 'Check if a feature flag is enabled for a given user/role/environment';
COMMENT ON FUNCTION get_enabled_features IS 'Get all enabled feature flags for an environment';


