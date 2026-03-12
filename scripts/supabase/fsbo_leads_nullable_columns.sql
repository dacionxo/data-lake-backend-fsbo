-- ============================================================================
-- Ensure fsbo_leads property-detail columns allow NULL
-- ============================================================================
-- Run this on Supabase if any of these columns were created as NOT NULL.
-- Safe to run multiple times (no-op if column is already nullable).
-- ============================================================================

DO $$
DECLARE
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
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'fsbo_leads' AND column_name = c
        AND is_nullable = 'NO'
    ) THEN
      EXECUTE format('ALTER TABLE public.fsbo_leads ALTER COLUMN %I DROP NOT NULL', c);
      RAISE NOTICE 'fsbo_leads.% is now nullable', c;
    END IF;
  END LOOP;
END $$;
