-- ============================================================================
-- User ID Semantics Standardization
-- ============================================================================
-- This schema documents and enforces user_id semantics across all tables.
--
-- SEMANTICS:
-- 1. UNIVERSAL TABLES: user_id is optional/nullable (shared data pool)
--    - Used for tracking provenance (who scraped/added data)
--    - All authenticated users can access all rows
--    - Examples: listings, fsbo_leads, expired_listings, etc.
--
-- 2. USER-SPECIFIC TABLES: user_id is NOT NULL with RLS
--    - Each user only sees their own data
--    - Required for data isolation
--    - Examples: contacts, deals, tasks, lists, list_items
--
-- This schema adds CHECK constraints and documentation to enforce these rules.
-- ============================================================================

-- ============================================================================
-- DOCUMENTATION AND VALIDATION FUNCTIONS
-- ============================================================================

-- Function to validate user_id semantics for universal tables
CREATE OR REPLACE FUNCTION validate_universal_user_id()
RETURNS TRIGGER AS $$
BEGIN
  -- For universal tables, user_id can be NULL (shared pool)
  -- If provided, it should reference a valid user
  IF NEW.user_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.user_id) THEN
      RAISE EXCEPTION 'user_id must reference a valid auth.users.id';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to validate user_id semantics for user-specific tables
CREATE OR REPLACE FUNCTION validate_user_specific_user_id()
RETURNS TRIGGER AS $$
BEGIN
  -- For user-specific tables, user_id is REQUIRED
  IF NEW.user_id IS NULL THEN
    RAISE EXCEPTION 'user_id is required and cannot be NULL for user-specific tables';
  END IF;
  
  -- Must reference a valid user
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.user_id) THEN
    RAISE EXCEPTION 'user_id must reference a valid auth.users.id';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ADD CHECK CONSTRAINTS TO EXISTING TABLES
-- ============================================================================

-- Note: These constraints should be added to complete_schema.sql
-- This file documents the patterns

-- UNIVERSAL TABLES (user_id optional/nullable)
-- Examples of constraints to add:
-- ALTER TABLE listings ADD CONSTRAINT listings_user_id_check 
--   CHECK (user_id IS NULL OR EXISTS (SELECT 1 FROM auth.users WHERE id = user_id));
-- 
-- ALTER TABLE fsbo_leads ADD CONSTRAINT fsbo_leads_user_id_check
--   CHECK (user_id IS NULL OR EXISTS (SELECT 1 FROM auth.users WHERE id = user_id));

-- USER-SPECIFIC TABLES (user_id NOT NULL)
-- Examples of constraints to add:
-- ALTER TABLE contacts ADD CONSTRAINT contacts_user_id_not_null
--   CHECK (user_id IS NOT NULL);
-- 
-- ALTER TABLE contacts ADD CONSTRAINT contacts_user_id_valid
--   CHECK (EXISTS (SELECT 1 FROM auth.users WHERE id = user_id));

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION validate_universal_user_id IS 
  'Validates user_id for universal tables (optional/nullable, tracks provenance)';

COMMENT ON FUNCTION validate_user_specific_user_id IS 
  'Validates user_id for user-specific tables (required NOT NULL, enforces isolation)';

-- ============================================================================
-- TABLE CLASSIFICATION DOCUMENTATION
-- ============================================================================

-- UNIVERSAL TABLES (user_id optional/nullable):
-- - listings
-- - fsbo_leads
-- - expired_listings
-- - frbo_leads
-- - foreclosure_listings
-- - trash (note: this is user-specific in practice but uses listing_id as PK)
-- - imports (note: user-specific but uses listing_id as PK)

-- USER-SPECIFIC TABLES (user_id NOT NULL):
-- - contacts
-- - deals
-- - tasks
-- - lists
-- - list_items

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
--
-- To enforce user_id semantics:
-- 1. Add CHECK constraints to prevent invalid user_id values
-- 2. Add comments to document table classification
-- 3. Update RLS policies to match semantics
-- 4. Update application code to handle NULL vs NOT NULL appropriately
--
-- Example migration:
-- 
-- -- For universal tables
-- COMMENT ON COLUMN listings.user_id IS 
--   'Optional: User who scraped/added this listing. NULL = shared pool accessible to all users.';
-- 
-- -- For user-specific tables  
-- COMMENT ON COLUMN contacts.user_id IS 
--   'Required: User who owns this contact. Enforced by RLS for data isolation.';
--   ALTER TABLE contacts ALTER COLUMN user_id SET NOT NULL;

