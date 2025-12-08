-- ============================================================================
-- QUICK FIX: Create Lead Category Tables
-- ============================================================================
-- Run this script if you're getting "relation does not exist" errors
-- This will create all the category tables that are missing
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Expired Listings Table
CREATE TABLE IF NOT EXISTS expired_listings (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT FALSE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT,
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  expired_date TIMESTAMPTZ,
  sold_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'lost',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT expired_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- FSBO Leads Table
CREATE TABLE IF NOT EXISTS fsbo_leads (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'fsbo',
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  fsbo_source TEXT,
  owner_contact_method TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT fsbo_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- FRBO Leads Table
CREATE TABLE IF NOT EXISTS frbo_leads (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'frbo',
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  frbo_source TEXT,
  lease_term TEXT,
  available_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT frbo_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Imports Table
CREATE TABLE IF NOT EXISTS imports (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT,
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  import_source TEXT NOT NULL DEFAULT 'csv',
  import_batch_id TEXT,
  import_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT imports_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Trash Table
CREATE TABLE IF NOT EXISTS trash (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT FALSE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'trash',
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  trash_reason TEXT,
  trashed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  trashed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  original_category TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'lost',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT trash_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Foreclosure Listings Table
CREATE TABLE IF NOT EXISTS foreclosure_listings (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT TRUE,
  street TEXT,
  unit TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  beds INTEGER,
  full_baths INTEGER,
  half_baths INTEGER,
  sqft INTEGER,
  year_built INTEGER,
  list_price BIGINT,
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'foreclosure',
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT,
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,
  photos_json JSONB,
  other JSONB,
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  foreclosure_type TEXT,
  auction_date DATE,
  default_amount BIGINT,
  lender_name TEXT,
  case_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT foreclosure_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Enable RLS
ALTER TABLE expired_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fsbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE frbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE trash ENABLE ROW LEVEL SECURITY;
ALTER TABLE foreclosure_listings ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
-- Expired Listings
DROP POLICY IF EXISTS "Users can read expired_listings" ON expired_listings;
CREATE POLICY "Users can read expired_listings" ON expired_listings
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert expired_listings" ON expired_listings;
CREATE POLICY "Users can insert expired_listings" ON expired_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update expired_listings" ON expired_listings;
CREATE POLICY "Users can update expired_listings" ON expired_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

-- FSBO Leads
DROP POLICY IF EXISTS "Users can read fsbo_leads" ON fsbo_leads;
CREATE POLICY "Users can read fsbo_leads" ON fsbo_leads
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert fsbo_leads" ON fsbo_leads;
CREATE POLICY "Users can insert fsbo_leads" ON fsbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update fsbo_leads" ON fsbo_leads;
CREATE POLICY "Users can update fsbo_leads" ON fsbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated');

-- FRBO Leads
DROP POLICY IF EXISTS "Users can read frbo_leads" ON frbo_leads;
CREATE POLICY "Users can read frbo_leads" ON frbo_leads
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert frbo_leads" ON frbo_leads;
CREATE POLICY "Users can insert frbo_leads" ON frbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update frbo_leads" ON frbo_leads;
CREATE POLICY "Users can update frbo_leads" ON frbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Imports
DROP POLICY IF EXISTS "Users can read imports" ON imports;
CREATE POLICY "Users can read imports" ON imports
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert imports" ON imports;
CREATE POLICY "Users can insert imports" ON imports
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update imports" ON imports;
CREATE POLICY "Users can update imports" ON imports
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Trash
DROP POLICY IF EXISTS "Users can read trash" ON trash;
CREATE POLICY "Users can read trash" ON trash
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert trash" ON trash;
CREATE POLICY "Users can insert trash" ON trash
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update trash" ON trash;
CREATE POLICY "Users can update trash" ON trash
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Foreclosure Listings
DROP POLICY IF EXISTS "Users can read foreclosure_listings" ON foreclosure_listings;
CREATE POLICY "Users can read foreclosure_listings" ON foreclosure_listings
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert foreclosure_listings" ON foreclosure_listings;
CREATE POLICY "Users can insert foreclosure_listings" ON foreclosure_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can update foreclosure_listings" ON foreclosure_listings;
CREATE POLICY "Users can update foreclosure_listings" ON foreclosure_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Create triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_expired_listings_updated_at ON expired_listings;
CREATE TRIGGER update_expired_listings_updated_at
  BEFORE UPDATE ON expired_listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_fsbo_leads_updated_at ON fsbo_leads;
CREATE TRIGGER update_fsbo_leads_updated_at
  BEFORE UPDATE ON fsbo_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_frbo_leads_updated_at ON frbo_leads;
CREATE TRIGGER update_frbo_leads_updated_at
  BEFORE UPDATE ON frbo_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_imports_updated_at ON imports;
CREATE TRIGGER update_imports_updated_at
  BEFORE UPDATE ON imports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_trash_updated_at ON trash;
CREATE TRIGGER update_trash_updated_at
  BEFORE UPDATE ON trash
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_foreclosure_listings_updated_at ON foreclosure_listings;
CREATE TRIGGER update_foreclosure_listings_updated_at
  BEFORE UPDATE ON foreclosure_listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_expired_listings_city ON expired_listings(city);
CREATE INDEX IF NOT EXISTS idx_expired_listings_state ON expired_listings(state);
CREATE INDEX IF NOT EXISTS idx_expired_listings_status ON expired_listings(status);
CREATE INDEX IF NOT EXISTS idx_expired_listings_created_at ON expired_listings(created_at);

CREATE INDEX IF NOT EXISTS idx_fsbo_leads_city ON fsbo_leads(city);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state ON fsbo_leads(state);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_status ON fsbo_leads(status);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_created_at ON fsbo_leads(created_at);

CREATE INDEX IF NOT EXISTS idx_frbo_leads_city ON frbo_leads(city);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_state ON frbo_leads(state);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_status ON frbo_leads(status);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_created_at ON frbo_leads(created_at);

CREATE INDEX IF NOT EXISTS idx_imports_city ON imports(city);
CREATE INDEX IF NOT EXISTS idx_imports_state ON imports(state);
CREATE INDEX IF NOT EXISTS idx_imports_import_source ON imports(import_source);
CREATE INDEX IF NOT EXISTS idx_imports_created_at ON imports(created_at);

CREATE INDEX IF NOT EXISTS idx_trash_city ON trash(city);
CREATE INDEX IF NOT EXISTS idx_trash_state ON trash(state);
CREATE INDEX IF NOT EXISTS idx_trash_created_at ON trash(created_at);

CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_city ON foreclosure_listings(city);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_state ON foreclosure_listings(state);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_created_at ON foreclosure_listings(created_at);

SELECT 'Category tables created successfully!' as status;

