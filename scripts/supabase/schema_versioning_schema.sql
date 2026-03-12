-- ============================================================================
-- Schema Versioning Mechanism
-- ============================================================================
-- This schema creates a versioning system to track database schema versions
-- and ensure both Data-Lake-Backend and LeadMap-main target the same version.
--
-- USAGE:
-- - Track all schema migrations
-- - Enforce schema version checks in CI/CD
-- - Prevent deployment mismatches between repos
-- ============================================================================

-- Ensure uuid extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- SCHEMA VERSIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_versions (
  id SERIAL PRIMARY KEY,
  version TEXT NOT NULL UNIQUE, -- e.g., '1.0.0', '2.1.3'
  description TEXT NOT NULL,
  migration_file TEXT, -- Name of migration file if applicable
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  applied_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  checksum TEXT, -- SHA256 checksum of migration SQL (optional)
  rollback_sql TEXT, -- SQL to rollback this migration (optional)
  metadata JSONB -- Additional metadata (git commit, PR number, etc.)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_schema_versions_version ON schema_versions(version);
CREATE INDEX IF NOT EXISTS idx_schema_versions_applied_at ON schema_versions(applied_at DESC);

-- ============================================================================
-- SCHEMA MIGRATIONS TABLE (Supabase CLI compatible)
-- ============================================================================

-- Create schema if it doesn't exist (must be created before creating table in it)
CREATE SCHEMA IF NOT EXISTS supabase_migrations;

-- This table is compatible with Supabase CLI migrations
CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations (
  version TEXT NOT NULL PRIMARY KEY,
  statements TEXT[], -- Array of SQL statements
  name TEXT
);

-- ============================================================================
-- CURRENT SCHEMA VERSION FUNCTION
-- ============================================================================

-- Function to get current schema version
CREATE OR REPLACE FUNCTION get_current_schema_version()
RETURNS TEXT AS $$
DECLARE
  v_version TEXT;
BEGIN
  SELECT version INTO v_version
  FROM schema_versions
  ORDER BY applied_at DESC
  LIMIT 1;
  
  RETURN COALESCE(v_version, '0.0.0'); -- Default if no versions
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to check if schema version matches expected
CREATE OR REPLACE FUNCTION check_schema_version(p_expected_version TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_current_version TEXT;
BEGIN
  v_current_version := get_current_schema_version();
  RETURN v_current_version = p_expected_version;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to require specific schema version (raises error if mismatch)
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

-- ============================================================================
-- MIGRATION TRACKING FUNCTIONS
-- ============================================================================

-- Function to record a schema migration
CREATE OR REPLACE FUNCTION record_schema_migration(
  p_version TEXT,
  p_description TEXT,
  p_migration_file TEXT DEFAULT NULL,
  p_checksum TEXT DEFAULT NULL,
  p_rollback_sql TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO schema_versions (
    version,
    description,
    migration_file,
    applied_by,
    checksum,
    rollback_sql,
    metadata
  ) VALUES (
    p_version,
    p_description,
    p_migration_file,
    auth.uid(),
    p_checksum,
    p_rollback_sql,
    p_metadata
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- INITIAL SCHEMA VERSION
-- ============================================================================

-- Insert initial schema version
INSERT INTO schema_versions (version, description, migration_file)
VALUES ('1.0.0', 'Initial schema version - complete schema with all tables and features', 'complete_schema.sql')
ON CONFLICT (version) DO NOTHING;

-- ============================================================================
-- VERSION CHECK CONSTRAINTS (Optional - can be enforced in application)
-- ============================================================================

-- Example: Add version check to a critical function
-- This ensures functions fail if schema version doesn't match
-- CREATE OR REPLACE FUNCTION secure_listing_insert(...)
-- RETURNS ... AS $$
-- BEGIN
--   PERFORM require_schema_version('1.0.0'); -- Enforce version
--   -- ... rest of function
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE schema_versions ENABLE ROW LEVEL SECURITY;

-- All authenticated users can view schema versions (needed for version checks)
CREATE POLICY "Users can view schema versions"
  ON schema_versions FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert schema versions
CREATE POLICY "Admins can manage schema versions"
  ON schema_versions FOR ALL
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
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE schema_versions IS 
  'Tracks database schema versions to ensure Data-Lake-Backend and LeadMap-main stay in sync';

COMMENT ON FUNCTION get_current_schema_version IS 
  'Returns the current schema version string';

COMMENT ON FUNCTION check_schema_version IS 
  'Checks if current schema version matches expected version';

COMMENT ON FUNCTION require_schema_version IS 
  'Raises an error if schema version does not match expected (for strict version enforcement)';

COMMENT ON FUNCTION record_schema_migration IS 
  'Records a schema migration in the version tracking table';

-- ============================================================================
-- CI/CD INTEGRATION NOTES
-- ============================================================================
--
-- To enforce schema version in CI:
--
-- 1. Data-Lake-Backend CI:
--    - After running migrations, verify: SELECT require_schema_version('X.Y.Z');
--    - Fail build if version doesn't match
--
-- 2. LeadMap-main CI:
--    - Before deployment, check: SELECT check_schema_version('X.Y.Z');
--    - Fail build if version doesn't match
--
-- 3. Version Numbering:
--    - Use semantic versioning: MAJOR.MINOR.PATCH
--    - MAJOR: Breaking schema changes
--    - MINOR: New tables/columns (backwards compatible)
--    - PATCH: Indexes, views, bug fixes
--
-- Example CI check:
-- ```
-- psql $DATABASE_URL -c "SELECT require_schema_version('1.2.0');"
-- ```

