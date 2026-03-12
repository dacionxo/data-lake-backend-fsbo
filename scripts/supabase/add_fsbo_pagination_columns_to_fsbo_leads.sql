-- ============================================================================
-- Add FSBO Pagination columns to fsbo_leads
-- ============================================================================
-- Adds all fsbo_pagination detail columns to public.fsbo_leads so one table
-- holds both lead and property-details data. Safe to run multiple times
-- (adds only if column does not exist).
--
-- Note: fsbo_leads already has year_built (integer) and beds/full_baths; we add
-- year_built_pagination (text from details section), bedrooms (text), bathrooms (text).
-- ============================================================================

DO $$
DECLARE
  col RECORD;
  -- All columns are TEXT NULL (nullable). Add any missing property-detail columns.
  cols TEXT[] := ARRAY[
    'living_area', 'year_built_pagination', 'bedrooms', 'bathrooms',
    'property_type', 'construction_type', 'building_style', 'effective_year_built',
    'number_of_units', 'number_of_buildings', 'number_of_commercial_units',
    'stories', 'garage', 'garage_area', 'heating_type', 'heating_gas',
    'air_conditioning', 'basement', 'deck', 'interior_walls', 'exterior_walls', 'exterior_features',
    'fireplaces', 'flooring_cover', 'driveway', 'pool', 'patio', 'porch',
    'roof', 'roof_type', 'sewer', 'topography', 'water', 'apn', 'lot_size',
    'legal_name', 'legal_description', 'subdivision_name', 'property_class', 'county_name',
    'association_fee', 'elementary_school_district', 'middle_school_district', 'high_school_district',
    'zoning', 'property_condition', 'flood_zone', 'tax_year', 'tax_amount', 'assessment_year',
    'total_assessed_value', 'assessed_improvement_value', 'total_market_value',
    'amenities', 'universal_property_id'
  ];
  c TEXT;
BEGIN
  FOREACH c IN ARRAY cols
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'fsbo_leads' AND column_name = c
    ) THEN
      EXECUTE format('ALTER TABLE public.fsbo_leads ADD COLUMN %I TEXT NULL', c);
      RAISE NOTICE 'Added column fsbo_leads.%', c;
    END IF;
  END LOOP;
END $$;
