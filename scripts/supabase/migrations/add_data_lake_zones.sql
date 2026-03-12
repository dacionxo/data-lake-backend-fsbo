-- ============================================================================
-- Migration: Add Data Lake Zones to Existing Schema
-- ============================================================================
-- This migration adds data-lake zones (raw, staging, curated) to the existing
-- schema without breaking existing tables.
-- 
-- IMPORTANT: Run data_lake_ingestion_schema.sql first, then data_lake_zones_schema.sql,
-- then this migration.
-- ============================================================================

-- This migration file adds zone classification comments and ensures
-- all zone tables from data_lake_zones_schema.sql are created.
-- The zone schemas should be run first.

-- Add zone classification comments to existing curated tables
COMMENT ON TABLE listings IS 'CURATED ZONE: Fully processed and validated property listings';
COMMENT ON TABLE fsbo_leads IS 'CURATED ZONE: Enriched and validated FSBO leads';
COMMENT ON TABLE expired_listings IS 'CURATED ZONE: Curated expired listings';
COMMENT ON TABLE frbo_leads IS 'CURATED ZONE: Curated FRBO leads';
COMMENT ON TABLE foreclosure_listings IS 'CURATED ZONE: Curated foreclosure listings';
COMMENT ON TABLE contacts IS 'CURATED ZONE: Curated contact data from CRM';
COMMENT ON TABLE deals IS 'CURATED ZONE: Curated deal data from CRM';
COMMENT ON TABLE tasks IS 'CURATED ZONE: Curated task data';
COMMENT ON TABLE lists IS 'CURATED ZONE: Curated list data';
COMMENT ON TABLE list_items IS 'CURATED ZONE: Curated list item data';
COMMENT ON TABLE imports IS 'CURATED ZONE: User-specific imported leads (final processed state)';
COMMENT ON TABLE trash IS 'CURATED ZONE: User-specific soft-deleted items';

-- Note: The zone tables (raw_*, staging_*) are created in data_lake_zones_schema.sql
-- This migration just ensures proper documentation of existing tables.

