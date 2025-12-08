-- ============================================================================
-- List Import Schema Documentation
-- ============================================================================
-- This file documents the schema requirements for importing CSV files into lists
-- The import functionality uses the existing list_memberships table
-- ============================================================================

-- ============================================================================
-- EXISTING TABLES USED
-- ============================================================================

-- 1. lists table
--    - id (UUID, PRIMARY KEY)
--    - user_id (UUID, REFERENCES auth.users)
--    - name (TEXT)
--    - type (TEXT, CHECK: 'people' | 'properties')
--    - created_at (TIMESTAMPTZ)
--    - updated_at (TIMESTAMPTZ)

-- 2. list_memberships table
--    - id (UUID, PRIMARY KEY)
--    - list_id (UUID, REFERENCES lists(id))
--    - item_type (TEXT, CHECK: 'listing' | 'contact' | 'company')
--    - item_id (TEXT) - References listing_id, contact.id, or company.id
--    - created_at (TIMESTAMPTZ)
--    - UNIQUE(list_id, item_type, item_id)

-- 3. listings table (for properties lists)
--    - listing_id (TEXT, PRIMARY KEY)
--    - property_url (TEXT)
--    - street, city, state, zip_code (TEXT)
--    - list_price, beds, full_baths, sqft (NUMERIC)
--    - status (TEXT)
--    - agent_name, agent_email, agent_phone (TEXT)
--    - year_built (INTEGER)
--    - last_sale_price (BIGINT)
--    - active (BOOLEAN)
--    - user_id (UUID)
--    - listing_source_name (TEXT)

-- 4. contacts table (for people lists)
--    - id (UUID, PRIMARY KEY)
--    - user_id (UUID, REFERENCES auth.users)
--    - first_name, last_name (TEXT)
--    - email (TEXT)
--    - phone (TEXT)
--    - company (TEXT)
--    - job_title (TEXT)
--    - address, city, state, zip_code (TEXT)
--    - created_at (TIMESTAMPTZ)

-- ============================================================================
-- CSV IMPORT REQUIREMENTS
-- ============================================================================

-- FOR PROPERTIES LISTS (list.type = 'properties'):
-- 
-- Required Columns (at least one):
--   - listing_id OR property_url
--
-- Optional Columns (will be mapped if present):
--   - street, city, state, zip_code
--   - list_price, beds, full_baths, sqft
--   - status, mls
--   - agent_name, agent_email, agent_phone
--   - year_built, last_sale_price, last_sale_date
--   - photos, photos_json
--   - other (JSON)
--   - price_per_sqft
--   - monthly_payment_estimate
--   - ai_investment_score
--   - time_listed
--   - lat, lng
--
-- Behavior:
--   1. If listing_id exists in database, uses existing listing
--   2. If property_url exists in database, finds listing by property_url
--   3. If neither exists, creates new listing with data from CSV
--   4. Adds listing to list_memberships with item_type='listing'
--   5. Duplicate memberships are ignored (unique constraint)

-- FOR PEOPLE LISTS (list.type = 'people'):
--
-- Required Columns (at least one):
--   - email OR phone
--
-- Optional Columns (will be mapped if present):
--   - first_name, last_name (or 'name' which will be split)
--   - company, job_title
--   - address (or street), city, state, zip_code
--
-- Behavior:
--   1. If email exists in contacts table, uses existing contact
--   2. If phone exists in contacts table, uses existing contact
--   3. If neither exists, creates new contact with data from CSV
--   4. Adds contact to list_memberships with item_type='contact'
--   5. Duplicate memberships are ignored (unique constraint)

-- ============================================================================
-- IMPORT PROCESS FLOW
-- ============================================================================

-- 1. User uploads CSV file via /api/lists/import-csv
-- 2. API validates:
--    - User is authenticated
--    - List exists and belongs to user
--    - CSV has required columns based on list type
-- 3. For each CSV row:
--    - Find or create the item (listing/contact)
--    - Add to list_memberships
--    - Handle duplicates gracefully
-- 4. Return summary:
--    - Number of items added
--    - Any errors encountered

-- ============================================================================
-- EXAMPLE CSV FORMATS
-- ============================================================================

-- Properties List CSV Example:
-- listing_id,property_url,street,city,state,zip_code,list_price,beds,full_baths,sqft,status,agent_name,agent_email
-- ABC123,https://example.com/property/123,123 Main St,San Francisco,CA,94102,850000,3,2,1500,Active,John Doe,john@example.com
-- DEF456,https://example.com/property/456,456 Oak Ave,Los Angeles,CA,90001,650000,2,1,1200,Active,Jane Smith,jane@example.com

-- People List CSV Example:
-- email,first_name,last_name,phone,company,job_title,city,state
-- john@example.com,John,Doe,555-1234,Acme Corp,Sales Manager,San Francisco,CA
-- jane@example.com,Jane,Smith,555-5678,Tech Inc,Developer,Los Angeles,CA

-- ============================================================================
-- NOTES
-- ============================================================================

-- - The import API automatically creates listings/contacts if they don't exist
-- - Duplicate list memberships are handled by the unique constraint
-- - All imports are associated with the authenticated user
-- - The list.updated_at timestamp is automatically updated via trigger
-- - CSV parsing uses csv-parse library with headers: true
-- - Empty rows are skipped automatically
-- - All text fields are trimmed of whitespace

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- The existing RLS policies ensure:
-- - Users can only import into their own lists
-- - Users can only create listings/contacts for themselves
-- - Users can only add memberships to their own lists

-- ============================================================================

