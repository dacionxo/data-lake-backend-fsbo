-- ============================================================================
-- LeadMap Complete Database Schema (with Email Captures)
-- ============================================================================
-- This is the complete schema for LeadMap including all tables, indexes,
-- triggers, RLS policies, and sample data.
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
-- DROP EXISTING TABLES (Clean Slate)
-- ============================================================================
DROP TABLE IF EXISTS email_captures CASCADE;
DROP TABLE IF EXISTS email_templates CASCADE;
DROP TABLE IF EXISTS probate_leads CASCADE;
DROP TABLE IF EXISTS listings CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- ============================================================================
-- CREATE TABLES
-- ============================================================================

-- Users Table
-- Stores user profile information, subscription status, and Stripe integration
CREATE TABLE users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  trial_end TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  is_subscribed BOOLEAN NOT NULL DEFAULT FALSE,
  plan_tier TEXT NOT NULL DEFAULT 'free' CHECK (plan_tier IN ('free', 'starter', 'pro')),
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Listings Table
-- Stores property leads with location, pricing, and enrichment data
CREATE TABLE listings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  zip TEXT NOT NULL,
  price INTEGER NOT NULL,
  price_drop_percent DECIMAL(5,2) NOT NULL DEFAULT 0,
  days_on_market INTEGER NOT NULL DEFAULT 0,
  url TEXT NOT NULL,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  source TEXT,
  source_url TEXT,
  owner_name TEXT,
  owner_phone TEXT,
  owner_email TEXT,
  active BOOLEAN DEFAULT TRUE,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  -- Phase 2 fields
  expired BOOLEAN DEFAULT FALSE,
  expired_at TIMESTAMPTZ,
  enrichment_source TEXT,
  enrichment_confidence FLOAT,
  geo_source TEXT,
  radius_km FLOAT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Email Templates Table
-- Stores reusable email templates for lead outreach
CREATE TABLE email_templates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL, -- 'follow_up', 'initial_contact', 'expired_listing', 'probate', 'general'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Probate Leads Table
-- Stores probate property leads from court filings
CREATE TABLE probate_leads (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  case_number TEXT NOT NULL UNIQUE,
  decedent_name TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  zip TEXT NOT NULL,
  filing_date DATE,
  source TEXT,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Email Captures Table
-- Stores email addresses captured from click forms (lead generation)
CREATE TABLE email_captures (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT,
  source TEXT, -- e.g., 'landing_page', 'popup', 'footer_form'
  referrer TEXT, -- URL where the form was submitted from
  user_agent TEXT, -- Browser/client information
  ip_address TEXT, -- IP address (for analytics, consider privacy regulations)
  metadata JSONB, -- Additional flexible data (form fields, UTM parameters, etc.)
  subscribed BOOLEAN DEFAULT TRUE, -- Whether user opted in for emails
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

-- Listings indexes
CREATE INDEX idx_listings_state ON listings(state);
CREATE INDEX idx_listings_city ON listings(city);
CREATE INDEX idx_listings_price ON listings(price);
CREATE INDEX idx_listings_price_drop ON listings(price_drop_percent);
CREATE INDEX idx_listings_days_on_market ON listings(days_on_market);
CREATE INDEX idx_listings_created_at ON listings(created_at);
CREATE INDEX idx_listings_expired ON listings(expired);
CREATE INDEX idx_listings_expired_at ON listings(expired_at);
CREATE INDEX idx_listings_enrichment_source ON listings(enrichment_source);
CREATE INDEX idx_listings_geo_source ON listings(geo_source);

-- Email templates indexes
CREATE INDEX idx_email_templates_category ON email_templates(category);
CREATE INDEX idx_email_templates_created_by ON email_templates(created_by);

-- Probate leads indexes
CREATE INDEX idx_probate_leads_case_number ON probate_leads(case_number);
CREATE INDEX idx_probate_leads_state ON probate_leads(state);
CREATE INDEX idx_probate_leads_city ON probate_leads(city);
CREATE INDEX idx_probate_leads_filing_date ON probate_leads(filing_date);

-- Email captures indexes
CREATE INDEX idx_email_captures_email ON email_captures(email);
CREATE INDEX idx_email_captures_created_at ON email_captures(created_at);
CREATE INDEX idx_email_captures_source ON email_captures(source);
CREATE INDEX idx_email_captures_subscribed ON email_captures(subscribed);

-- ============================================================================
-- CREATE FUNCTIONS
-- ============================================================================

-- Updated_at trigger function
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

-- ============================================================================
-- CREATE TRIGGERS
-- ============================================================================

CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_listings_updated_at 
  BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_templates_updated_at 
  BEFORE UPDATE ON email_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_probate_leads_updated_at 
  BEFORE UPDATE ON probate_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_captures_updated_at 
  BEFORE UPDATE ON email_captures
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE probate_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_captures ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = (SELECT auth.uid()));

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = (SELECT auth.uid()));

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = (SELECT auth.uid()));

-- Listings table policies
CREATE POLICY "Allow authenticated users to view listings" ON listings
  FOR SELECT USING (auth.role() = (SELECT auth.role()) AND (SELECT auth.role()) = 'authenticated');

-- Email templates policies
CREATE POLICY "Authenticated users can view templates" ON email_templates
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can insert templates" ON email_templates
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update templates" ON email_templates
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete templates" ON email_templates
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Probate leads policies
CREATE POLICY "Authenticated users can view probate leads" ON probate_leads
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage probate leads" ON probate_leads
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Email captures policies
-- Allow public inserts (for form submissions) but restrict viewing to admins
CREATE POLICY "Allow public email capture inserts" ON email_captures
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Admins can view email captures" ON email_captures
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update email captures" ON email_captures
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can delete email captures" ON email_captures
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- Insert sample property listings
INSERT INTO listings (address, city, state, zip, price, price_drop_percent, days_on_market, url, latitude, longitude) VALUES
('123 Main St', 'Los Angeles', 'CA', '90210', 750000, 12.5, 45, 'https://example.com/property/1', 34.0522, -118.2437),
('456 Oak Ave', 'San Francisco', 'CA', '94102', 1200000, 8.2, 32, 'https://example.com/property/2', 37.7749, -122.4194),
('789 Pine St', 'Austin', 'TX', '73301', 450000, 15.8, 67, 'https://example.com/property/3', 30.2672, -97.7431),
('321 Elm St', 'Miami', 'FL', '33101', 650000, 6.5, 28, 'https://example.com/property/4', 25.7617, -80.1918),
('654 Maple Dr', 'Denver', 'CO', '80202', 380000, 9.3, 41, 'https://example.com/property/5', 39.7392, -104.9903),
('987 Cedar Ln', 'Seattle', 'WA', '98101', 850000, 11.2, 53, 'https://example.com/property/6', 47.6062, -122.3321),
('147 Birch St', 'Portland', 'OR', '97201', 520000, 7.8, 35, 'https://example.com/property/7', 45.5152, -122.6784),
('258 Spruce Ave', 'Nashville', 'TN', '37201', 320000, 13.1, 49, 'https://example.com/property/8', 36.1627, -86.7816),
('369 Willow Way', 'Phoenix', 'AZ', '85001', 280000, 5.9, 24, 'https://example.com/property/9', 33.4484, -112.0740),
('741 Poplar Pl', 'Atlanta', 'GA', '30301', 410000, 10.4, 38, 'https://example.com/property/10', 33.7490, -84.3880),
('852 Oak St', 'Chicago', 'IL', '60601', 550000, 8.7, 42, 'https://example.com/property/11', 41.8781, -87.6298),
('963 Pine Ave', 'Boston', 'MA', '02101', 680000, 11.3, 38, 'https://example.com/property/12', 42.3601, -71.0589),
('147 Maple Ln', 'Dallas', 'TX', '75201', 420000, 9.1, 35, 'https://example.com/property/13', 32.7767, -96.7970),
('258 Cedar Dr', 'Houston', 'TX', '77001', 380000, 7.4, 29, 'https://example.com/property/14', 29.7604, -95.3698),
('369 Birch Way', 'Philadelphia', 'PA', '19101', 480000, 10.8, 44, 'https://example.com/property/15', 39.9526, -75.1652);

-- Insert default email templates
INSERT INTO email_templates (title, body, category) VALUES
(
  'Initial FSBO Contact',
  'Hello {{owner_name}},

I noticed you have {{address}} listed for sale by owner. I''m a local real estate professional specializing in properties in {{city}}, {{state}}.

I''ve helped many sellers in your area get the best price for their home while minimizing stress. Would you be open to a brief conversation about your goals?

I''m available at your convenience.

Best regards,
{{agent_name}}',
  'initial_contact'
),
(
  'Expired Listing Follow-up',
  'Hi {{owner_name}},

I see that {{address}} is no longer on the market. I know that can be frustrating after all the effort you''ve put in.

If you''re still interested in selling, I''d love to help. I specialize in properties that have been on and off the market, and I have strategies that often yield better results.

Would you like to chat about what might work for your situation?

Thank you,
{{agent_name}}',
  'expired_listing'
),
(
  'Probate Property Assistance',
  'Dear {{owner_name}},

I understand you''re handling matters for {{decedent_name}}''s estate, including the property at {{address}}.

Selling a probate property can involve unique challenges. I have experience with probate transactions in {{city}}, {{state}} and can guide you through the process.

If you''re considering selling the property, I''d be happy to discuss how I can help make this as smooth as possible.

Sincerely,
{{agent_name}}',
  'probate'
);

-- ============================================================================
-- USER SYNC FUNCTIONALITY
-- ============================================================================

-- Create missing user records for any existing auth users
INSERT INTO public.users (id, email, name, role, trial_end, is_subscribed, plan_tier)
SELECT 
  au.id,
  au.email,
  COALESCE(au.raw_user_meta_data->>'name', 'User') as name,
  'user' as role,
  NOW() + INTERVAL '7 days' as trial_end,
  false as is_subscribed,
  'free' as plan_tier
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify the setup
SELECT 'Database setup complete!' as status;
SELECT COUNT(*) as total_listings FROM listings;
SELECT COUNT(*) as total_email_templates FROM email_templates;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as auth_users FROM auth.users;
SELECT COUNT(*) as total_email_captures FROM email_captures;
SELECT 'All systems ready!' as final_status;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

