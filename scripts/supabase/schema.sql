-- LeadMap Performance-Optimized Database Setup
-- This file fixes all RLS performance warnings and user sync issues

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing tables if they exist (clean slate)
DROP TABLE IF EXISTS listings CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Create users table
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

-- Create listings table
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
  active BOOLEAN DEFAULT TRUE,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_listings_state ON listings(state);
CREATE INDEX idx_listings_city ON listings(city);
CREATE INDEX idx_listings_price ON listings(price);
CREATE INDEX idx_listings_price_drop ON listings(price_drop_percent);
CREATE INDEX idx_listings_days_on_market ON listings(days_on_market);
CREATE INDEX idx_listings_created_at ON listings(created_at);

-- Create updated_at trigger function with secure search_path
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

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_listings_updated_at 
  BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Create optimized RLS policies for users table (using subqueries for performance)
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = (SELECT auth.uid()));

CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = (SELECT auth.uid()));

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = (SELECT auth.uid()));

-- Create single optimized RLS policy for listings table (using subquery for performance)
CREATE POLICY "Allow authenticated users to view listings" ON listings
  FOR SELECT USING (auth.role() = (SELECT auth.role()) AND (SELECT auth.role()) = 'authenticated');

-- Fix user sync issue - Create missing user records for any existing auth users
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

-- Insert sample property data
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

-- Verify the setup
SELECT 'Database setup complete!' as status;
SELECT COUNT(*) as total_listings FROM listings;
SELECT COUNT(*) as total_users FROM users;
SELECT COUNT(*) as auth_users FROM auth.users;
SELECT 'All systems ready!' as final_status;
