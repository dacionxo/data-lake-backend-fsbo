-- ============================================================================
-- LeadMap - Separate Tables for Each Lead Category
-- ============================================================================
-- This schema creates dedicated tables for each lead category to ensure
-- complete separation and prevent cross-contamination between categories.
-- 
-- INSTRUCTIONS:
-- 1. Go to your Supabase Dashboard
-- 2. Navigate to SQL Editor
-- 3. Click "New Query"
-- 4. Copy and paste this entire file
-- 5. Click "Run" (or press Ctrl+Enter)
-- 6. Wait for "Success" message
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CREATE SEPARATE TABLES FOR EACH LEAD CATEGORY
-- ============================================================================

-- ============================================================================
-- 1. EXPIRED LISTINGS TABLE
-- ============================================================================
-- Stores listings that have expired, been sold, or are off-market
CREATE TABLE IF NOT EXISTS expired_listings (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT FALSE, -- Expired listings are not active
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
  status TEXT, -- 'expired', 'sold', 'off market', etc.
  mls TEXT,
  agent_name TEXT,
  agent_email TEXT,
  agent_phone TEXT,
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT, -- Description
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
  expired_date TIMESTAMPTZ, -- When the listing expired
  sold_date TIMESTAMPTZ, -- When the listing was sold (if applicable)
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

-- ============================================================================
-- 2. FSBO LEADS TABLE (For Sale By Owner)
-- ============================================================================
-- Stores FSBO (For Sale By Owner) property leads
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
  agent_name TEXT, -- Owner name for FSBO
  agent_email TEXT, -- Owner email for FSBO
  agent_phone TEXT, -- Owner phone for FSBO
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT, -- Description
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
  fsbo_source TEXT, -- Where the FSBO listing was found (e.g., 'craigslist', 'facebook', 'zillow')
  owner_contact_method TEXT, -- Preferred contact method
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

-- ============================================================================
-- 3. FRBO LEADS TABLE (For Rent By Owner)
-- ============================================================================
-- Stores FRBO (For Rent By Owner) property leads
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
  list_price BIGINT, -- Monthly rent price
  list_price_min BIGINT,
  list_price_max BIGINT,
  status TEXT DEFAULT 'frbo',
  mls TEXT,
  agent_name TEXT, -- Owner name for FRBO
  agent_email TEXT, -- Owner email for FRBO
  agent_phone TEXT, -- Owner phone for FRBO
  agent_phone_2 TEXT,
  listing_agent_phone_2 TEXT,
  listing_agent_phone_5 TEXT,
  text TEXT, -- Description
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
  frbo_source TEXT, -- Where the FRBO listing was found
  lease_term TEXT, -- 'month-to-month', '12 months', etc.
  available_date DATE, -- When the property becomes available
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

-- ============================================================================
-- 4. IMPORTS TABLE
-- ============================================================================
-- Stores imported leads from CSV, API, or other external sources
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
  text TEXT, -- Description
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
  import_source TEXT NOT NULL, -- 'csv', 'api', 'manual', etc.
  import_batch_id TEXT, -- Group imports by batch
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

-- ============================================================================
-- 5. TRASH TABLE
-- ============================================================================
-- Stores leads that have been marked as trash/not useful
CREATE TABLE IF NOT EXISTS trash (
  listing_id TEXT PRIMARY KEY,
  property_url TEXT NOT NULL UNIQUE,
  permalink TEXT,
  scrape_date DATE,
  last_scraped_at TIMESTAMPTZ DEFAULT NOW(),
  active BOOLEAN DEFAULT FALSE, -- Trash leads are not active
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
  text TEXT, -- Description
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
  trash_reason TEXT, -- Why this lead was marked as trash
  trashed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  trashed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  original_category TEXT, -- What category this was in before being trashed
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

-- ============================================================================
-- 6. FORECLOSURE LISTINGS TABLE
-- ============================================================================
-- Stores foreclosure property listings
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
  list_price BIGINT, -- Foreclosure sale price
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
  text TEXT, -- Description
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
  foreclosure_type TEXT, -- 'pre-foreclosure', 'auction', 'bank-owned', etc.
  auction_date DATE, -- If applicable
  default_amount BIGINT, -- Amount in default
  lender_name TEXT, -- Name of the lender
  case_number TEXT, -- Foreclosure case number
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

-- ============================================================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Expired Listings Indexes
CREATE INDEX IF NOT EXISTS idx_expired_listings_city ON expired_listings(city);
CREATE INDEX IF NOT EXISTS idx_expired_listings_state ON expired_listings(state);
CREATE INDEX IF NOT EXISTS idx_expired_listings_status ON expired_listings(status);
CREATE INDEX IF NOT EXISTS idx_expired_listings_created_at ON expired_listings(created_at);
CREATE INDEX IF NOT EXISTS idx_expired_listings_expired_date ON expired_listings(expired_date);

-- FSBO Leads Indexes
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_city ON fsbo_leads(city);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_state ON fsbo_leads(state);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_status ON fsbo_leads(status);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_created_at ON fsbo_leads(created_at);
CREATE INDEX IF NOT EXISTS idx_fsbo_leads_fsbo_source ON fsbo_leads(fsbo_source);

-- FRBO Leads Indexes
CREATE INDEX IF NOT EXISTS idx_frbo_leads_city ON frbo_leads(city);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_state ON frbo_leads(state);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_status ON frbo_leads(status);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_created_at ON frbo_leads(created_at);
CREATE INDEX IF NOT EXISTS idx_frbo_leads_available_date ON frbo_leads(available_date);

-- Imports Indexes
CREATE INDEX IF NOT EXISTS idx_imports_city ON imports(city);
CREATE INDEX IF NOT EXISTS idx_imports_state ON imports(state);
CREATE INDEX IF NOT EXISTS idx_imports_import_source ON imports(import_source);
CREATE INDEX IF NOT EXISTS idx_imports_import_batch_id ON imports(import_batch_id);
CREATE INDEX IF NOT EXISTS idx_imports_created_at ON imports(created_at);

-- Trash Indexes
CREATE INDEX IF NOT EXISTS idx_trash_city ON trash(city);
CREATE INDEX IF NOT EXISTS idx_trash_state ON trash(state);
CREATE INDEX IF NOT EXISTS idx_trash_trashed_at ON trash(trashed_at);
CREATE INDEX IF NOT EXISTS idx_trash_original_category ON trash(original_category);

-- Foreclosure Listings Indexes
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_city ON foreclosure_listings(city);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_state ON foreclosure_listings(state);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_foreclosure_type ON foreclosure_listings(foreclosure_type);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_auction_date ON foreclosure_listings(auction_date);
CREATE INDEX IF NOT EXISTS idx_foreclosure_listings_created_at ON foreclosure_listings(created_at);

-- ============================================================================
-- CREATE UPDATED_AT TRIGGER FUNCTION (if not exists)
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CREATE TRIGGERS FOR UPDATED_AT
-- ============================================================================
CREATE TRIGGER update_expired_listings_updated_at
  BEFORE UPDATE ON expired_listings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_fsbo_leads_updated_at
  BEFORE UPDATE ON fsbo_leads
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_frbo_leads_updated_at
  BEFORE UPDATE ON frbo_leads
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_imports_updated_at
  BEFORE UPDATE ON imports
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trash_updated_at
  BEFORE UPDATE ON trash
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_foreclosure_listings_updated_at
  BEFORE UPDATE ON foreclosure_listings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
-- Enable RLS on all tables
ALTER TABLE expired_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fsbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE frbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE trash ENABLE ROW LEVEL SECURITY;
ALTER TABLE foreclosure_listings ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read all leads (adjust as needed for your security model)
CREATE POLICY "Users can read expired_listings" ON expired_listings
  FOR SELECT USING (true);

CREATE POLICY "Users can read fsbo_leads" ON fsbo_leads
  FOR SELECT USING (true);

CREATE POLICY "Users can read frbo_leads" ON frbo_leads
  FOR SELECT USING (true);

CREATE POLICY "Users can read imports" ON imports
  FOR SELECT USING (true);

CREATE POLICY "Users can read trash" ON trash
  FOR SELECT USING (true);

CREATE POLICY "Users can read foreclosure_listings" ON foreclosure_listings
  FOR SELECT USING (true);

-- Policy: Authenticated users can insert/update/delete (adjust as needed)
CREATE POLICY "Users can insert expired_listings" ON expired_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update expired_listings" ON expired_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert fsbo_leads" ON fsbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update fsbo_leads" ON fsbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert frbo_leads" ON frbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update frbo_leads" ON frbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert imports" ON imports
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update imports" ON imports
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert trash" ON trash
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update trash" ON trash
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert foreclosure_listings" ON foreclosure_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update foreclosure_listings" ON foreclosure_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE 'Successfully created all lead category tables!';
  RAISE NOTICE 'Tables created:';
  RAISE NOTICE '  - expired_listings';
  RAISE NOTICE '  - fsbo_leads';
  RAISE NOTICE '  - frbo_leads';
  RAISE NOTICE '  - imports';
  RAISE NOTICE '  - trash';
  RAISE NOTICE '  - foreclosure_listings';
  RAISE NOTICE '';
  RAISE NOTICE 'All tables are now ready to use with proper indexes and RLS policies.';
END $$;


