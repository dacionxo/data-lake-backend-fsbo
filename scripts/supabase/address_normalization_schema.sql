-- ============================================================================
-- Address Normalization Schema
-- ============================================================================
-- This schema normalizes repeated address/contact columns across lead tables.
--
-- APPROACH: Helper views that map street/city/state/zip_code consistently
-- for analytics, rather than changing table structure (which would break
-- existing code). This allows gradual migration.
--
-- Future enhancement: Could migrate to ADDRESS composite type if needed.
-- ============================================================================

-- ============================================================================
-- ADDRESS COMPOSITE TYPE (Optional - for future use)
-- ============================================================================
-- Define a composite type for addresses
-- Note: Not used in tables yet, but available for migration

CREATE TYPE address_type AS (
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  country TEXT
);

-- ============================================================================
-- HELPER VIEWS FOR CONSISTENT ADDRESS MAPPING
-- ============================================================================

-- Unified Address View for Listings
-- Maps all lead tables to consistent address structure for analytics
CREATE OR REPLACE VIEW address_view AS
SELECT 
  'listings' AS source_table,
  listing_id AS listing_id,
  street,
  unit,
  city,
  state,
  zip_code,
  lat,
  lng,
  created_at
FROM listings
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL

UNION ALL

SELECT 
  'fsbo_leads' AS source_table,
  listing_id,
  street,
  unit,
  city,
  state,
  zip_code,
  lat,
  lng,
  created_at
FROM fsbo_leads
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL

UNION ALL

SELECT 
  'expired_listings' AS source_table,
  listing_id,
  street,
  unit,
  city,
  state,
  zip_code,
  lat,
  lng,
  created_at
FROM expired_listings
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL

UNION ALL

SELECT 
  'frbo_leads' AS source_table,
  listing_id,
  street,
  unit,
  city,
  state,
  zip_code,
  lat,
  lng,
  created_at
FROM frbo_leads
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL

UNION ALL

SELECT 
  'foreclosure_listings' AS source_table,
  listing_id,
  street,
  unit,
  city,
  state,
  zip_code,
  lat,
  lng,
  created_at
FROM foreclosure_listings
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL

UNION ALL

SELECT 
  'imports' AS source_table,
  listing_id,
  street,
  unit,
  city,
  state,
  zip_code,
  lat,
  lng,
  created_at
FROM imports
WHERE street IS NOT NULL OR city IS NOT NULL OR state IS NOT NULL;

-- Address normalization view with formatted address
CREATE OR REPLACE VIEW address_normalized AS
SELECT 
  source_table,
  listing_id,
  street,
  unit,
  city,
  state,
  zip_code,
  lat,
  lng,
  -- Formatted full address
  TRIM(
    COALESCE(street, '') || 
    CASE WHEN unit IS NOT NULL THEN ' ' || unit ELSE '' END || 
    CASE WHEN city IS NOT NULL THEN ', ' || city ELSE '' END ||
    CASE WHEN state IS NOT NULL THEN ', ' || state ELSE '' END ||
    CASE WHEN zip_code IS NOT NULL THEN ' ' || zip_code ELSE '' END
  ) AS formatted_address,
  -- Normalized city/state for matching
  UPPER(TRIM(COALESCE(city, ''))) AS city_normalized,
  UPPER(TRIM(COALESCE(state, ''))) AS state_normalized,
  -- Geographic key for grouping
  UPPER(TRIM(COALESCE(city, '')) || ', ' || TRIM(COALESCE(state, ''))) AS city_state_key,
  created_at
FROM address_view;

-- ============================================================================
-- CONTACT NORMALIZATION VIEWS
-- ============================================================================

-- Unified Contact View for Listings
-- Maps contact information (name, email, phone) across all lead tables
CREATE OR REPLACE VIEW contact_view AS
SELECT 
  'listings' AS source_table,
  listing_id,
  agent_name AS contact_name,
  agent_email AS contact_email,
  agent_phone AS contact_phone,
  agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3,
  listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM listings
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL

UNION ALL

SELECT 
  'fsbo_leads' AS source_table,
  listing_id,
  agent_name AS contact_name,
  agent_email AS contact_email,
  agent_phone AS contact_phone,
  agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3,
  listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM fsbo_leads
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL

UNION ALL

SELECT 
  'expired_listings' AS source_table,
  listing_id,
  agent_name AS contact_name,
  agent_email AS contact_email,
  agent_phone AS contact_phone,
  agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3,
  listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM expired_listings
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL

UNION ALL

SELECT 
  'frbo_leads' AS source_table,
  listing_id,
  agent_name AS contact_name,
  agent_email AS contact_email,
  agent_phone AS contact_phone,
  agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3,
  listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM frbo_leads
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL

UNION ALL

SELECT 
  'foreclosure_listings' AS source_table,
  listing_id,
  agent_name AS contact_name,
  agent_email AS contact_email,
  agent_phone AS contact_phone,
  agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3,
  listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM foreclosure_listings
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL

UNION ALL

SELECT 
  'imports' AS source_table,
  listing_id,
  agent_name AS contact_name,
  agent_email AS contact_email,
  agent_phone AS contact_phone,
  agent_phone_2 AS contact_phone_2,
  listing_agent_phone_2 AS contact_phone_3,
  listing_agent_phone_5 AS contact_phone_4,
  created_at
FROM imports
WHERE agent_name IS NOT NULL OR agent_email IS NOT NULL OR agent_phone IS NOT NULL;

-- Contact normalized view with primary contact method
CREATE OR REPLACE VIEW contact_normalized AS
SELECT 
  source_table,
  listing_id,
  contact_name,
  contact_email,
  contact_phone,
  contact_phone_2,
  contact_phone_3,
  contact_phone_4,
  -- Primary contact method (prefer email, then phone)
  COALESCE(contact_email, contact_phone, contact_phone_2) AS primary_contact,
  -- All contact methods as array
  ARRAY_REMOVE(ARRAY[
    contact_email,
    contact_phone,
    contact_phone_2,
    contact_phone_3,
    contact_phone_4
  ], NULL) AS all_contact_methods,
  -- Has contact info flag
  (contact_email IS NOT NULL OR contact_phone IS NOT NULL) AS has_contact_info,
  created_at
FROM contact_view;

-- ============================================================================
-- ANALYTICS VIEWS
-- ============================================================================

-- Geographic distribution view
CREATE OR REPLACE VIEW geographic_distribution AS
SELECT 
  city_normalized AS city,
  state_normalized AS state,
  city_state_key,
  COUNT(*) AS lead_count,
  COUNT(DISTINCT source_table) AS table_count,
  MIN(created_at) AS first_seen,
  MAX(created_at) AS last_seen
FROM address_normalized
WHERE city_normalized != '' AND state_normalized != ''
GROUP BY city_normalized, state_normalized, city_state_key
ORDER BY lead_count DESC;

-- ============================================================================
-- INDEXES FOR VIEW PERFORMANCE
-- ============================================================================

-- Note: Views use indexes on underlying tables, but we can add indexes
-- on commonly queried columns in the source tables

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON VIEW address_view IS 'Unified view of addresses across all lead tables for analytics';
COMMENT ON VIEW address_normalized IS 'Normalized addresses with formatted strings and geographic keys';
COMMENT ON VIEW contact_view IS 'Unified view of contact information across all lead tables';
COMMENT ON VIEW contact_normalized IS 'Normalized contacts with primary contact method and arrays';
COMMENT ON VIEW geographic_distribution IS 'Geographic distribution of leads by city/state';
COMMENT ON TYPE address_type IS 'Composite type for normalized addresses (future use)';

