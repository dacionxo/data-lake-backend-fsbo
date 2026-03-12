-- ============================================================================
-- fsbo_leads table schema (canonical — matches Supabase production)
-- ============================================================================
-- This file is the single source of truth for the fsbo_leads table structure.
-- Keep in sync with Supabase Dashboard > Table Editor > fsbo_leads.
-- ============================================================================

CREATE TABLE public.fsbo_leads (
  listing_id text NOT NULL,
  property_url text NOT NULL,
  permalink text NULL,
  scrape_date date NULL,
  last_scraped_at timestamp with time zone NULL DEFAULT now(),
  active boolean NULL DEFAULT true,
  street text NULL,
  unit text NULL,
  city text NULL,
  state text NULL,
  zip_code text NULL,
  beds integer NULL,
  full_baths numeric(4, 2) NULL,
  half_baths integer NULL,
  sqft integer NULL,
  year_built integer NULL,
  list_price bigint NULL,
  list_price_min bigint NULL,
  list_price_max bigint NULL,
  status text NULL DEFAULT 'fsbo'::text,
  mls text NULL,
  agent_name text NULL,
  agent_email text NULL,
  agent_phone text NULL,
  agent_phone_2 text NULL,
  listing_agent_phone_2 text NULL,
  listing_agent_phone_5 text NULL,
  text text NULL,
  last_sale_price text NULL,
  last_sale_date date NULL,
  photos text NULL,
  photos_json jsonb NULL,
  other jsonb NULL,
  price_per_sqft numeric NULL,
  listing_source_name text NULL,
  listing_source_id text NULL,
  monthly_payment_estimate text NULL,
  ai_investment_score numeric NULL,
  time_listed timestamp with time zone NULL,
  fsbo_source text NULL,
  owner_contact_method text NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  user_id uuid NULL,
  owner_id uuid NULL,
  tags text[] NULL,
  lists text[] NULL,
  pipeline_status text NULL DEFAULT 'new'::text,
  lat numeric(10, 8) NULL,
  lng numeric(11, 8) NULL,
  living_area text NULL,
  year_built_pagination text NULL,
  bedrooms text NULL,
  bathrooms text NULL,
  property_type text NULL,
  construction_type text NULL,
  building_style text NULL,
  effective_year_built text NULL,
  number_of_units text NULL,
  number_of_buildings text NULL,
  number_of_commercial_units text NULL,
  stories text NULL,
  garage text NULL,
  garage_area text NULL,
  heating_type text NULL,
  heating_gas text NULL,
  air_conditioning text NULL,
  basement text NULL,
  deck text NULL,
  interior_walls text NULL,
  exterior_walls text NULL,
  exterior_features text NULL,
  fireplaces text NULL,
  flooring_cover text NULL,
  driveway text NULL,
  pool text NULL,
  patio text NULL,
  porch text NULL,
  roof text NULL,
  roof_type text NULL,
  sewer text NULL,
  topography text NULL,
  water text NULL,
  apn text NULL,
  lot_size text NULL,
  legal_name text NULL,
  legal_description text NULL,
  subdivision_name text NULL,
  property_class text NULL,
  county_name text NULL,
  association_fee text NULL,
  elementary_school_district text NULL,
  high_school_district text NULL,
  zoning text NULL,
  property_condition text NULL,
  flood_zone text NULL,
  tax_year text NULL,
  tax_amount text NULL,
  assessment_year text NULL,
  total_assessed_value text NULL,
  assessed_improvement_value text NULL,
  total_market_value text NULL,
  amenities text NULL,
  universal_property_id text NULL,
  middle_school_district text NULL,
  CONSTRAINT fsbo_leads_pkey PRIMARY KEY (listing_id),
  CONSTRAINT fsbo_leads_property_url_key UNIQUE (property_url),
  CONSTRAINT fsbo_leads_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users (id) ON DELETE SET NULL,
  CONSTRAINT fsbo_leads_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users (id) ON DELETE SET NULL,
  CONSTRAINT fsbo_listing_id_check CHECK (COALESCE(listing_id, ''::text) <> ''::text)
) TABLESPACE pg_default;

-- Indexes (match Supabase)
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_user_id ON public.fsbo_leads USING btree (user_id) TABLESPACE pg_default
WHERE (user_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_city ON public.fsbo_leads USING btree (city) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state ON public.fsbo_leads USING btree (state) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_status ON public.fsbo_leads USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_created_at ON public.fsbo_leads USING btree (created_at) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_fsbo_source ON public.fsbo_leads USING btree (fsbo_source) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_city ON public.fsbo_leads USING btree (state, city) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_status ON public.fsbo_leads USING btree (state, status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_created_at ON public.fsbo_leads USING btree (state, created_at DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_status_active ON public.fsbo_leads USING btree (status, active) TABLESPACE pg_default
WHERE (active = true);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_price ON public.fsbo_leads USING btree (state, list_price) TABLESPACE pg_default
WHERE (list_price IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_pipeline_status ON public.fsbo_leads USING btree (pipeline_status, created_at DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_user_status ON public.fsbo_leads USING btree (user_id, status) TABLESPACE pg_default
WHERE (user_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_city_state_status ON public.fsbo_leads USING btree (city, state, status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_pipeline_status_created ON public.fsbo_leads USING btree (pipeline_status, created_at DESC) TABLESPACE pg_default
WHERE (pipeline_status IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_price_range ON public.fsbo_leads USING btree (list_price) TABLESPACE pg_default
WHERE (list_price IS NOT NULL AND list_price > 0);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_text_search ON public.fsbo_leads USING gin (to_tsvector('english'::regconfig, COALESCE(text, ''::text))) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_covering_state_city ON public.fsbo_leads USING btree (
  state,
  city,
  listing_id,
  property_url,
  list_price,
  status,
  created_at
) TABLESPACE pg_default
WHERE (active = true);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state_status_created ON public.fsbo_leads USING btree (
  state,
  status,
  date_trunc('day'::text, (created_at AT TIME ZONE 'UTC'::text))
) TABLESPACE pg_default;

-- Trigger for updated_at
CREATE TRIGGER update_fsbo_leads_updated_at
  BEFORE UPDATE ON public.fsbo_leads
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
