-- ============================================================================
-- Canonical ID Strategy
-- ============================================================================
-- This schema enforces the canonical ID strategy across all lead tables.
--
-- STRATEGY:
-- 1. listing_id (TEXT) is the canonical business ID for ALL property listings
--    - Used across: listings, fsbo_leads, expired_listings, frbo_leads,
--                   foreclosure_listings, imports, trash
--    - Format: Typically Redfin listing ID or URL slug
--    - Must be unique and non-empty
--    - NOT a UUID - this is a business identifier, not a technical ID
--
-- 2. UUIDs are used ONLY for user-specific entities
--    - Used for: contacts.id, deals.id, tasks.id, lists.id, list_items.id
--    - These are user-scoped and require technical IDs for relationships
--
-- 3. Foreign key references:
--    - Relationships to properties should use listing_id (TEXT)
--    - Relationships to user entities use UUID
--    - price_history, status_history reference listings via listing_id
--
-- ============================================================================

-- ============================================================================
-- ENFORCE CANONICAL ID CONSTRAINTS
-- ============================================================================

-- Ensure all lead tables have listing_id as PRIMARY KEY (TEXT, not UUID)
-- This is already enforced in table definitions, but we document it here

-- Listings table - listing_id is PRIMARY KEY (TEXT)
-- This is the canonical reference for all property data

-- Category tables - all use listing_id TEXT PRIMARY KEY
-- - expired_listings
-- - fsbo_leads  
-- - frbo_leads
-- - foreclosure_listings
-- - imports
-- - trash

-- ============================================================================
-- FOREIGN KEY CONSISTENCY
-- ============================================================================

-- All foreign keys to properties must reference listing_id (TEXT)
-- Example: price_history.listing_id REFERENCES listings(listing_id)

-- All foreign keys to user entities use UUID
-- Example: contacts.user_id REFERENCES auth.users(id)
-- Example: deals.contact_id REFERENCES contacts(id)  -- UUID to UUID

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

-- Function to validate listing_id format
-- Listing IDs should be non-empty strings
CREATE OR REPLACE FUNCTION validate_listing_id(listing_id_value TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  -- Must be non-empty and non-null
  IF listing_id_value IS NULL OR TRIM(listing_id_value) = '' THEN
    RETURN FALSE;
  END IF;
  
  -- Should not be a UUID (business ID, not technical ID)
  -- UUIDs are 36 characters with specific format
  IF listing_id_value ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RAISE WARNING 'listing_id should not be a UUID - it should be a business identifier (e.g., Redfin listing ID)';
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- INDEXES FOR CANONICAL ID LOOKUPS
-- ============================================================================

-- These indexes are already created in table definitions, but documented here
-- for reference:

-- All lead tables have PRIMARY KEY on listing_id (automatically indexed)
-- - listings(listing_id)
-- - fsbo_leads(listing_id)
-- - expired_listings(listing_id)
-- - frbo_leads(listing_id)
-- - foreclosure_listings(listing_id)
-- - imports(listing_id)
-- - trash(listing_id)

-- Foreign key indexes (for joins)
-- - price_history(listing_id) - already indexed
-- - status_history(listing_id) - already indexed

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON CONSTRAINT listing_id_url_check ON listings IS 
  'Ensures listing_id is non-empty. listing_id is the canonical business ID for properties (TEXT, not UUID).';

COMMENT ON CONSTRAINT fsbo_listing_id_check ON fsbo_leads IS 
  'Ensures listing_id is non-empty. listing_id is the canonical business ID (TEXT, not UUID).';

COMMENT ON CONSTRAINT expired_listing_id_check ON expired_listings IS 
  'Ensures listing_id is non-empty. listing_id is the canonical business ID (TEXT, not UUID).';

COMMENT ON CONSTRAINT frbo_listing_id_check ON frbo_leads IS 
  'Ensures listing_id is non-empty. listing_id is the canonical business ID (TEXT, not UUID).';

COMMENT ON CONSTRAINT foreclosure_listing_id_check ON foreclosure_listings IS 
  'Ensures listing_id is non-empty. listing_id is the canonical business ID (TEXT, not UUID).';

COMMENT ON CONSTRAINT imports_listing_id_check ON imports IS 
  'Ensures listing_id is non-empty. listing_id is the canonical business ID (TEXT, not UUID).';

COMMENT ON CONSTRAINT trash_listing_id_check ON trash IS 
  'Ensures listing_id is non-empty. listing_id is the canonical business ID (TEXT, not UUID).';

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
--
-- If you have existing tables with UUID primary keys for properties, migrate them:
--
-- 1. Add listing_id column (TEXT)
-- 2. Populate listing_id from property_url or generate stable ID
-- 3. Update all foreign key references
-- 4. Make listing_id PRIMARY KEY
-- 5. Drop old UUID primary key (keep as regular column if needed)
--
-- Example migration (DO NOT RUN - example only):
--
-- ALTER TABLE listings ADD COLUMN listing_id TEXT;
-- UPDATE listings SET listing_id = COALESCE(
--   regexp_replace(property_url, '^.*/([^/]+)$', '\1'),
--   'listing_' || id::TEXT
-- );
-- ALTER TABLE listings ADD CONSTRAINT listings_listing_id_check 
--   CHECK (COALESCE(listing_id, '') <> '');
-- CREATE UNIQUE INDEX idx_listings_listing_id ON listings(listing_id);
-- ALTER TABLE listings DROP CONSTRAINT listings_pkey;
-- ALTER TABLE listings ADD PRIMARY KEY (listing_id);
--
-- ============================================================================


