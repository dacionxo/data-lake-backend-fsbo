-- ============================================================================
-- FSBO Pagination Table
-- ============================================================================
-- Stores detailed property attributes scraped from Redfin FSBO listing pages
-- (property details section, tax history, climate risk, etc.).
-- One row per listing; upsert key: property_url.
-- ============================================================================

CREATE TABLE IF NOT EXISTS fsbo_pagination (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  listing_id TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ,

  -- Property basics (from property details)
  living_area TEXT,
  year_built TEXT,
  bedrooms TEXT,
  bathrooms TEXT,
  property_type TEXT,
  construction_type TEXT,
  building_style TEXT,
  effective_year_built TEXT,
  number_of_units TEXT,
  stories TEXT,
  garage TEXT,
  heating_type TEXT,
  heating_gas TEXT,
  air_conditioning TEXT,
  basement TEXT,
  deck TEXT,
  interior_walls TEXT,
  exterior_walls TEXT,
  fireplaces TEXT,
  flooring_cover TEXT,
  driveway TEXT,
  pool TEXT,
  patio TEXT,
  porch TEXT,
  roof TEXT,
  sewer TEXT,
  water TEXT,

  -- Parcel / legal
  apn TEXT,
  lot_size TEXT,
  legal_name TEXT,
  legal_description TEXT,
  property_class TEXT,
  county_name TEXT,

  -- Schools & zoning
  elementary_school_district TEXT,
  middle_school_district TEXT,
  high_school_district TEXT,
  zoning TEXT,
  flood_zone TEXT,

  -- Tax & assessment
  tax_year TEXT,
  tax_amount TEXT,
  assessment_year TEXT,
  total_assessed_value TEXT,
  assessed_improvement_value TEXT,
  total_market_value TEXT,
  last_sale_price TEXT,

  amenities TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_fsbo_pagination_property_url ON fsbo_pagination(property_url);
CREATE INDEX IF NOT EXISTS idx_fsbo_pagination_listing_id ON fsbo_pagination(listing_id);
CREATE INDEX IF NOT EXISTS idx_fsbo_pagination_last_scraped_at ON fsbo_pagination(last_scraped_at DESC);

-- Trigger to refresh updated_at on row update (create function only if not present)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $fn$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$fn$;

CREATE TRIGGER update_fsbo_pagination_updated_at
  BEFORE UPDATE ON fsbo_pagination
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE fsbo_pagination IS 'Detailed FSBO listing attributes from Redfin property details (pagination/details section).';
