-- ============================================================================
-- LeadMap Complete Database Schema (FULL VERSION WITH FIXES)
-- ============================================================================
-- This is the complete schema for LeadMap including all tables, indexes,
-- triggers, RLS policies (with fixes), and sample data.
-- 
-- MULTI-USER ARCHITECTURE:
-- This schema is designed to support multiple users with a hybrid data model:
-- - Universal shared data (listings) accessible to all users
-- - User-specific data (imports, trash, CRM data) isolated per user
-- 
-- Key Features:
-- - Universal Tables: listings (shared property data pool for all users)
-- - User-Specific Tables: imports, trash, tasks, contacts, deals, lists, list_items
-- - Category Tables: expired_listings, fsbo_leads, frbo_leads, foreclosure_listings (user-specific)
-- - RLS policies ensure proper data access control
-- - Indexes on user_id columns ensure optimal query performance
-- - CASCADE deletes ensure data cleanup when users are deleted
-- 
-- DATA ARCHITECTURE:
-- 
-- UNIVERSAL TABLES (All Users Can Access):
-- - listings: Shared property data pool for "Prospect & Enrich" page
--   * user_id is optional/nullable (listings can be scraped by any user)
--   * All authenticated users can view all listings
-- 
-- - expired_listings, fsbo_leads, frbo_leads, foreclosure_listings: Category tables (universal)
--   * user_id is optional/nullable (category data is shared across all users)
--   * All authenticated users can view all category data
-- 
-- USER-SPECIFIC TABLES (Isolated Per User - Connected via auth.users email/password):
-- - imports: All imported leads go here (CSV, API, manual imports)
--   * user_id is required and references auth.users(id) - users only see their own imports
--   * This is where imported leads are stored (NOT in listings table)
--   * Connected to user's email/password authentication via auth.users
-- 
-- - trash: Recycling bin for soft-deleted leads
--   * user_id is required and references auth.users(id) - users only see their own trash
--   * Functions as a step before permanent deletion
--   * Users can restore items or permanently delete them
--   * Connected to user's email/password authentication via auth.users
-- 
-- - tasks, contacts, deals, lists, list_items: CRM data (user-specific)
--   * user_id is required and references auth.users(id)
--   * Connected to user's email/password authentication via auth.users
-- 
-- SHARED TABLES (with admin controls):
-- - email_templates (admins can manage, users can view)
-- - probate_leads (admins can manage, users can view)
-- - email_captures (public inserts, admin management)
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
-- DROP EXISTING OBJECTS (Clean Slate)
-- ============================================================================
DROP TABLE IF EXISTS list_items CASCADE;
DROP TABLE IF EXISTS lists CASCADE;
DROP VIEW IF EXISTS list_counts CASCADE;
DROP VIEW IF EXISTS list_items_with_metadata CASCADE;
DROP FUNCTION IF EXISTS get_list_items_paginated(UUID, INTEGER, INTEGER, TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_list_items_count(UUID, TEXT) CASCADE;
DROP TABLE IF EXISTS deals CASCADE;
DROP TABLE IF EXISTS contacts CASCADE;
DROP TABLE IF EXISTS tasks CASCADE;
DROP TABLE IF EXISTS email_captures CASCADE;
DROP TABLE IF EXISTS email_templates CASCADE;
DROP TABLE IF EXISTS probate_leads CASCADE;
DROP TABLE IF EXISTS price_history CASCADE;
DROP TABLE IF EXISTS status_history CASCADE;
-- Drop lead category tables
DROP TABLE IF EXISTS expired_listings CASCADE;
DROP TABLE IF EXISTS fsbo_leads CASCADE;
DROP TABLE IF EXISTS frbo_leads CASCADE;
DROP TABLE IF EXISTS imports CASCADE;
DROP TABLE IF EXISTS trash CASCADE;
DROP TABLE IF EXISTS foreclosure_listings CASCADE;
DROP TABLE IF EXISTS listings CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS update_lists_updated_at() CASCADE;
DROP FUNCTION IF EXISTS update_lists_updated_at_on_list_items_change() CASCADE;
DROP FUNCTION IF EXISTS update_last_scraped_at() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
-- Note: Triggers on list_items are automatically dropped when the table is dropped with CASCADE
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

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
  dashboard_config JSONB,
  has_real_data BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Listings Table
-- Stores general property leads (for "All Prospects" view)
-- NOTE: Listings are UNIVERSALLY accessible to all users (shared data pool)
-- This table contains scraped/aggregated property data that all users can view
CREATE TABLE listings (
  listing_id TEXT PRIMARY KEY,        -- use Redfin listing id or URL slug
  property_url TEXT NOT NULL UNIQUE,  -- full URL for reference
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
  text TEXT,                          -- Description
  last_sale_price BIGINT,
  last_sale_date DATE,
  photos TEXT,              -- comma-separated or JSON in photos_json
  photos_json JSONB,        -- optional structured photo list
  other JSONB,              -- any extra fields
  price_per_sqft NUMERIC,
  listing_source_name TEXT,
  listing_source_id TEXT,
  monthly_payment_estimate TEXT,
  ai_investment_score NUMERIC,
  time_listed TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT listing_id_url_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Price History Table
-- Tracks price changes over time
CREATE TABLE price_history (
  id BIGSERIAL PRIMARY KEY,
  listing_id TEXT REFERENCES listings(listing_id) ON DELETE CASCADE,
  old_price BIGINT,
  new_price BIGINT NOT NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Status History Table
-- Tracks status changes over time
CREATE TABLE status_history (
  id BIGSERIAL PRIMARY KEY,
  listing_id TEXT REFERENCES listings(listing_id) ON DELETE CASCADE,
  old_status TEXT,
  new_status TEXT NOT NULL,
  changed_at TIMESTAMPTZ DEFAULT NOW()
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
-- LEAD CATEGORY TABLES (Separate tables for each category)
-- ============================================================================

-- Expired Listings Table
-- Stores listings that have expired, been sold, or are off-market
-- NOTE: Expired listings are UNIVERSALLY accessible (shared data pool)
CREATE TABLE expired_listings (
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
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'lost',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT expired_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- FSBO Leads Table (For Sale By Owner)
-- NOTE: FSBO leads are UNIVERSALLY accessible (shared data pool)
CREATE TABLE fsbo_leads (
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
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT fsbo_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- FRBO Leads Table (For Rent By Owner)
-- NOTE: FRBO leads are UNIVERSALLY accessible (shared data pool)
CREATE TABLE frbo_leads (
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
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT frbo_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Imports Table
-- Stores imported leads from CSV, API, or other external sources
-- NOTE: Imports are USER-SPECIFIC - each user only sees their own imported leads
-- All imported leads automatically go to this table (not the listings table)
-- Connected to user's email/password authentication via auth.users(id)
CREATE TABLE imports (
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
  import_source TEXT NOT NULL DEFAULT 'csv', -- 'csv', 'api', 'manual', etc.
  import_batch_id TEXT,
  import_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT imports_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Trash Table
-- Stores leads that have been marked as trash/not useful
-- NOTE: Trash is USER-SPECIFIC and functions as a recycling bin (soft delete)
-- Leads are moved to trash before actual deletion, allowing recovery
-- Users can restore items from trash or permanently delete them
-- Connected to user's email/password authentication via auth.users(id)
CREATE TABLE trash (
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
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'lost',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT trash_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- Foreclosure Listings Table
-- NOTE: Foreclosure listings are UNIVERSALLY accessible (shared data pool)
CREATE TABLE foreclosure_listings (
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
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Optional: User who scraped/added this listing (nullable for universal access)
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Property owner (if known)
  tags TEXT[],
  lists TEXT[],
  pipeline_status TEXT DEFAULT 'new',
  lat NUMERIC(10, 8),
  lng NUMERIC(11, 8),
  CONSTRAINT foreclosure_listing_id_check CHECK (COALESCE(listing_id,'') <> '')
);

-- ============================================================================
-- CRM TABLES
-- ============================================================================

-- Tasks Table
-- Stores user tasks and to-dos
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE tasks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  due_date TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  related_type TEXT, -- 'contact', 'deal', 'listing', 'campaign', etc.
  related_id TEXT, -- ID of the related entity
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Contacts Table
-- Stores CRM contacts (property owners, leads, etc.)
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE contacts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  first_name TEXT,
  last_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  company TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  source TEXT, -- 'listing', 'probate', 'geo', 'manual', 'form', etc.
  source_id TEXT, -- ID of the source (e.g., listing_id)
  notes TEXT,
  tags TEXT[], -- Array of tags
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'qualified', 'nurturing', 'not_interested')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deals Table
-- Stores sales deals/opportunities
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE deals (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  value NUMERIC(12, 2), -- Deal value in dollars
  stage TEXT NOT NULL DEFAULT 'new' CHECK (stage IN ('new', 'contacted', 'qualified', 'proposal', 'negotiation', 'closed_won', 'closed_lost')),
  probability INTEGER DEFAULT 0 CHECK (probability >= 0 AND probability <= 100),
  expected_close_date TIMESTAMPTZ,
  closed_date TIMESTAMPTZ,
  source TEXT,
  source_id TEXT, -- ID of the source (e.g., listing_id)
  notes TEXT,
  tags TEXT[],
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Lists Table
-- Stores user-created lists for organizing contacts and properties
-- NOTE: User-specific table - connected to user's email/password via auth.users(id)
CREATE TABLE lists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('people', 'properties')),
  description TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL, -- References auth.users (email/password authentication)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- List Items Table
-- Stores the relationship between lists and items (contacts/properties/listings)
CREATE TABLE list_items (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  list_id UUID REFERENCES lists(id) ON DELETE CASCADE NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('contact', 'company', 'listing')),
  item_id TEXT NOT NULL, -- Can reference different tables based on item_type
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(list_id, item_type, item_id)
);

-- ============================================================================
-- CREATE INDEXES
-- ============================================================================

-- Listings indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_listings_user_id ON listings(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_listings_city ON listings(city);
CREATE INDEX idx_listings_state ON listings(state);
CREATE INDEX idx_listings_active ON listings(active);
CREATE INDEX idx_listings_status ON listings(status);
CREATE INDEX idx_listings_list_price ON listings(list_price);
CREATE INDEX idx_listings_created_at ON listings(created_at);
CREATE INDEX idx_listings_last_scraped_at ON listings(last_scraped_at);

-- Price history indexes
CREATE INDEX idx_price_history_listing ON price_history(listing_id, changed_at DESC);

-- Status history indexes
CREATE INDEX idx_status_history_listing ON status_history(listing_id, changed_at DESC);

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

-- CRM indexes
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_related ON tasks(related_type, related_id);

CREATE INDEX idx_contacts_user_id ON contacts(user_id);
CREATE INDEX idx_contacts_email ON contacts(email);
CREATE INDEX idx_contacts_status ON contacts(status);
CREATE INDEX idx_contacts_source ON contacts(source, source_id);

CREATE INDEX idx_deals_user_id ON deals(user_id);
CREATE INDEX idx_deals_contact_id ON deals(contact_id);
CREATE INDEX idx_deals_stage ON deals(stage);
CREATE INDEX idx_deals_source ON deals(source, source_id);

-- Lead Category Tables Indexes
-- Expired Listings indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_expired_listings_user_id ON expired_listings(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_expired_listings_city ON expired_listings(city);
CREATE INDEX idx_expired_listings_state ON expired_listings(state);
CREATE INDEX idx_expired_listings_status ON expired_listings(status);
CREATE INDEX idx_expired_listings_created_at ON expired_listings(created_at);
CREATE INDEX idx_expired_listings_expired_date ON expired_listings(expired_date);

-- FSBO Leads indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_fsbo_leads_user_id ON fsbo_leads(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_fsbo_leads_city ON fsbo_leads(city);
CREATE INDEX idx_fsbo_leads_state ON fsbo_leads(state);
CREATE INDEX idx_fsbo_leads_status ON fsbo_leads(status);
CREATE INDEX idx_fsbo_leads_created_at ON fsbo_leads(created_at);
CREATE INDEX idx_fsbo_leads_fsbo_source ON fsbo_leads(fsbo_source);

-- FRBO Leads indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_frbo_leads_user_id ON frbo_leads(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_frbo_leads_city ON frbo_leads(city);
CREATE INDEX idx_frbo_leads_state ON frbo_leads(state);
CREATE INDEX idx_frbo_leads_status ON frbo_leads(status);
CREATE INDEX idx_frbo_leads_created_at ON frbo_leads(created_at);
CREATE INDEX idx_frbo_leads_available_date ON frbo_leads(available_date);

-- Imports indexes
CREATE INDEX idx_imports_user_id ON imports(user_id);
CREATE INDEX idx_imports_city ON imports(city);
CREATE INDEX idx_imports_state ON imports(state);
CREATE INDEX idx_imports_import_source ON imports(import_source);
CREATE INDEX idx_imports_import_batch_id ON imports(import_batch_id);
CREATE INDEX idx_imports_created_at ON imports(created_at);

-- Trash indexes
CREATE INDEX idx_trash_user_id ON trash(user_id);
CREATE INDEX idx_trash_city ON trash(city);
CREATE INDEX idx_trash_state ON trash(state);
CREATE INDEX idx_trash_trashed_at ON trash(trashed_at);
CREATE INDEX idx_trash_original_category ON trash(original_category);

-- Foreclosure Listings indexes (user_id is optional/nullable for universal access)
CREATE INDEX idx_foreclosure_listings_user_id ON foreclosure_listings(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX idx_foreclosure_listings_city ON foreclosure_listings(city);
CREATE INDEX idx_foreclosure_listings_state ON foreclosure_listings(state);
CREATE INDEX idx_foreclosure_listings_foreclosure_type ON foreclosure_listings(foreclosure_type);
CREATE INDEX idx_foreclosure_listings_auction_date ON foreclosure_listings(auction_date);
CREATE INDEX idx_foreclosure_listings_created_at ON foreclosure_listings(created_at);

-- Lists indexes
CREATE INDEX idx_lists_user_id ON lists(user_id);
CREATE INDEX idx_lists_type ON lists(type);
CREATE INDEX idx_lists_updated_at ON lists(updated_at DESC);
CREATE INDEX idx_lists_id_user_id ON lists(id, user_id); -- Composite index for efficient list fetching with user check

-- List items indexes for pagination
CREATE INDEX idx_list_items_list_id ON list_items(list_id);
CREATE INDEX idx_list_items_item ON list_items(item_type, item_id);
CREATE INDEX idx_list_items_list_id_created_at ON list_items(list_id, created_at DESC); -- For pagination by creation date
CREATE INDEX idx_list_items_list_id_item_type ON list_items(list_id, item_type); -- For filtering by item type

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

-- Function to handle new user creation (auto-create profile)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, trial_end, is_subscribed, plan_tier)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email::text, 'User'),
    'user',
    NOW() + INTERVAL '7 days',
    false,
    'free'
  )
  ON CONFLICT (id) DO NOTHING; -- Don't error if profile already exists
  RETURN NEW;
END;
$$;

-- ============================================================================
-- CREATE TRIGGERS
-- ============================================================================

CREATE TRIGGER update_users_updated_at 
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_listings_updated_at 
  BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  
-- Trigger to update last_scraped_at when listing is updated
CREATE OR REPLACE FUNCTION update_last_scraped_at()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.last_scraped_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_listings_last_scraped_at 
  BEFORE UPDATE ON listings
  FOR EACH ROW EXECUTE FUNCTION update_last_scraped_at();

-- Function to update lists updated_at timestamp
CREATE OR REPLACE FUNCTION update_lists_updated_at()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update lists.updated_at when list_items change
-- This ensures the parent list's updated_at is automatically updated
-- whenever list_items are inserted, updated, or deleted
CREATE OR REPLACE FUNCTION update_lists_updated_at_on_list_items_change()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update the parent list's updated_at timestamp
  IF TG_OP = 'DELETE' THEN
    -- For DELETE, use OLD.list_id
    UPDATE lists 
    SET updated_at = NOW() 
    WHERE id = OLD.list_id;
    RETURN OLD;
  ELSE
    -- For INSERT or UPDATE, use NEW.list_id
    UPDATE lists 
    SET updated_at = NOW() 
    WHERE id = NEW.list_id;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_email_templates_updated_at 
  BEFORE UPDATE ON email_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_probate_leads_updated_at 
  BEFORE UPDATE ON probate_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_captures_updated_at 
  BEFORE UPDATE ON email_captures
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- CRM table triggers
CREATE TRIGGER update_tasks_updated_at 
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at 
  BEFORE UPDATE ON contacts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_deals_updated_at 
  BEFORE UPDATE ON deals
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Lead Category Tables Triggers
CREATE TRIGGER update_expired_listings_updated_at
  BEFORE UPDATE ON expired_listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_fsbo_leads_updated_at
  BEFORE UPDATE ON fsbo_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_frbo_leads_updated_at
  BEFORE UPDATE ON frbo_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_imports_updated_at
  BEFORE UPDATE ON imports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trash_updated_at
  BEFORE UPDATE ON trash
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_foreclosure_listings_updated_at
  BEFORE UPDATE ON foreclosure_listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Lists table trigger
CREATE TRIGGER update_lists_updated_at
  BEFORE UPDATE ON lists
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at();

-- List items triggers - automatically update parent list's updated_at
-- when list_items are inserted, updated, or deleted
CREATE TRIGGER update_lists_on_list_items_insert
  AFTER INSERT ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

CREATE TRIGGER update_lists_on_list_items_update
  AFTER UPDATE ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

CREATE TRIGGER update_lists_on_list_items_delete
  AFTER DELETE ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

-- Auto-create user profile trigger (runs when auth user is created)
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE probate_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_captures ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
-- Enable RLS on lead category tables
ALTER TABLE expired_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE fsbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE frbo_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE trash ENABLE ROW LEVEL SECURITY;
ALTER TABLE foreclosure_listings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES - USERS TABLE (FIXED)
-- ============================================================================

-- Allow users to view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT 
  USING (auth.uid() = id);

-- Allow users to insert their own profile (when id matches their auth.uid())
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- RLS POLICIES - LISTINGS TABLE
-- ============================================================================
-- Listings are UNIVERSALLY accessible - all authenticated users can view all listings
-- This allows the "Prospect & Enrich" page to show a shared pool of property data

CREATE POLICY "All authenticated users can view listings" ON listings
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert listings" ON listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update listings" ON listings
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete listings" ON listings
  FOR DELETE USING (auth.role() = 'authenticated');

-- Price history policies
CREATE POLICY "Allow authenticated users to view price history" ON price_history
  FOR SELECT USING (auth.role() = 'authenticated');

-- Status history policies
CREATE POLICY "Allow authenticated users to view status history" ON status_history
  FOR SELECT USING (auth.role() = 'authenticated');

-- ============================================================================
-- RLS POLICIES - EMAIL TEMPLATES TABLE
-- ============================================================================

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

-- ============================================================================
-- RLS POLICIES - PROBATE LEADS TABLE
-- ============================================================================

CREATE POLICY "Authenticated users can view probate leads" ON probate_leads
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage probate leads" ON probate_leads
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ============================================================================
-- RLS POLICIES - EMAIL CAPTURES TABLE
-- ============================================================================

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
-- RLS POLICIES - CRM TABLES
-- ============================================================================

-- Tasks RLS Policies
CREATE POLICY "Users can view their own tasks" ON tasks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own tasks" ON tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tasks" ON tasks
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tasks" ON tasks
  FOR DELETE USING (auth.uid() = user_id);

-- Contacts RLS Policies
CREATE POLICY "Users can view their own contacts" ON contacts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own contacts" ON contacts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own contacts" ON contacts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own contacts" ON contacts
  FOR DELETE USING (auth.uid() = user_id);

-- Deals RLS Policies
CREATE POLICY "Users can view their own deals" ON deals
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own deals" ON deals
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own deals" ON deals
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own deals" ON deals
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- RLS POLICIES - LEAD CATEGORY TABLES
-- ============================================================================
-- Category tables are UNIVERSALLY accessible - all authenticated users can view all category data
-- This allows the "Prospect & Enrich" page to show shared pools of property data

-- Expired Listings Policies
CREATE POLICY "All authenticated users can view expired_listings" ON expired_listings
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert expired_listings" ON expired_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update expired_listings" ON expired_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete expired_listings" ON expired_listings
  FOR DELETE USING (auth.role() = 'authenticated');

-- FSBO Leads Policies
CREATE POLICY "All authenticated users can view fsbo_leads" ON fsbo_leads
  FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can insert fsbo_leads" ON fsbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can update fsbo_leads" ON fsbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can delete fsbo_leads" ON fsbo_leads
  FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- FRBO Leads Policies
CREATE POLICY "All authenticated users can view frbo_leads" ON frbo_leads
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert frbo_leads" ON frbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update frbo_leads" ON frbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete frbo_leads" ON frbo_leads
  FOR DELETE USING (auth.role() = 'authenticated');

-- Imports Policies
-- Imports are USER-SPECIFIC - users can only see/manage their own imported leads
CREATE POLICY "Users can view their own imports" ON imports
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own imports" ON imports
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own imports" ON imports
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own imports" ON imports
  FOR DELETE USING (auth.uid() = user_id);

-- Trash Policies
-- Trash is USER-SPECIFIC and functions as a recycling bin (soft delete)
-- Users can only see/manage their own trashed leads
CREATE POLICY "Users can view their own trash" ON trash
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own trash" ON trash
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own trash" ON trash
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own trash" ON trash
  FOR DELETE USING (auth.uid() = user_id);

-- Foreclosure Listings Policies
CREATE POLICY "All authenticated users can view foreclosure_listings" ON foreclosure_listings
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert foreclosure_listings" ON foreclosure_listings
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update foreclosure_listings" ON foreclosure_listings
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete foreclosure_listings" ON foreclosure_listings
  FOR DELETE USING (auth.role() = 'authenticated');

-- Lists RLS Policies
ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own lists"
  ON lists FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own lists"
  ON lists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own lists"
  ON lists FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own lists"
  ON lists FOR DELETE
  USING (auth.uid() = user_id);

-- List Items RLS Policies
CREATE POLICY "Users can view items in their lists"
  ON list_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can add items to their lists"
  ON list_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete items from their lists"
  ON list_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

-- ============================================================================
-- CREATE VIEWS
-- ============================================================================

-- View to get list counts
CREATE OR REPLACE VIEW list_counts AS
SELECT 
  l.id,
  l.name,
  l.type,
  l.user_id,
  COUNT(li.id) as count
FROM lists l
LEFT JOIN list_items li ON l.id = li.list_id
GROUP BY l.id, l.name, l.type, l.user_id;

-- View for paginated list items with metadata
-- This view provides list items with their list information for efficient pagination queries
CREATE OR REPLACE VIEW list_items_with_metadata AS
SELECT 
  li.id,
  li.list_id,
  li.item_type,
  li.item_id,
  li.created_at,
  l.name as list_name,
  l.type as list_type,
  l.user_id,
  l.created_at as list_created_at,
  l.updated_at as list_updated_at
FROM list_items li
INNER JOIN lists l ON li.list_id = l.id;

-- Function to get paginated list items
-- Usage: SELECT * FROM get_list_items_paginated('list_id_here', 0, 50);
CREATE OR REPLACE FUNCTION get_list_items_paginated(
  p_list_id UUID,
  p_offset INTEGER DEFAULT 0,
  p_limit INTEGER DEFAULT 50,
  p_item_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  list_id UUID,
  item_type TEXT,
  item_id TEXT,
  created_at TIMESTAMPTZ,
  list_name TEXT,
  list_type TEXT,
  user_id UUID
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    li.id,
    li.list_id,
    li.item_type,
    li.item_id,
    li.created_at,
    l.name as list_name,
    l.type as list_type,
    l.user_id
  FROM list_items li
  INNER JOIN lists l ON li.list_id = l.id
  WHERE li.list_id = p_list_id
    AND (p_item_type IS NULL OR li.item_type = p_item_type)
  ORDER BY li.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Function to get total count of items in a list (for pagination metadata)
CREATE OR REPLACE FUNCTION get_list_items_count(
  p_list_id UUID,
  p_item_type TEXT DEFAULT NULL
)
RETURNS INTEGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM list_items
  WHERE list_id = p_list_id
    AND (p_item_type IS NULL OR item_type = p_item_type);
  
  RETURN v_count;
END;
$$;

-- ============================================================================
-- UNIFIED LISTINGS VIEW
-- ============================================================================
-- This view creates a compiled/aggregated view of all listing tables
-- so that queries can access all categories through a single unified interface.
-- Each row includes a 'source_category' field to identify its origin table.

-- Drop existing view if it exists
DROP VIEW IF EXISTS listings_unified CASCADE;

-- Create the unified view
CREATE VIEW listings_unified AS
SELECT 
  listing_id,
  property_url,
  permalink,
  scrape_date,
  last_scraped_at,
  active,
  street,
  unit,
  city,
  state,
  zip_code,
  beds,
  full_baths,
  half_baths,
  sqft,
  year_built,
  list_price,
  list_price_min,
  list_price_max,
  status,
  mls,
  agent_name,
  agent_email,
  agent_phone,
  agent_phone_2,
  listing_agent_phone_2,
  listing_agent_phone_5,
  text,
  last_sale_price,
  last_sale_date,
  photos,
  photos_json,
  other,
  price_per_sqft,
  listing_source_name,
  listing_source_id,
  monthly_payment_estimate,
  ai_investment_score,
  time_listed,
  created_at,
  updated_at,
  user_id,
  owner_id,
  tags,
  lists,
  pipeline_status,
  lat,
  lng,
  'listings' AS source_category
FROM listings

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'expired_listings' AS source_category
FROM expired_listings

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'fsbo_leads' AS source_category
FROM fsbo_leads

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'frbo_leads' AS source_category
FROM frbo_leads

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'imports' AS source_category
FROM imports

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'trash' AS source_category
FROM trash

UNION ALL

SELECT 
  listing_id, property_url, permalink, scrape_date, last_scraped_at, active,
  street, unit, city, state, zip_code, beds, full_baths, half_baths, sqft,
  year_built, list_price, list_price_min, list_price_max, status, mls,
  agent_name, agent_email, agent_phone, agent_phone_2, listing_agent_phone_2,
  listing_agent_phone_5, text, last_sale_price, last_sale_date, photos,
  photos_json, other, price_per_sqft, listing_source_name, listing_source_id,
  monthly_payment_estimate, ai_investment_score, time_listed, created_at,
  updated_at, user_id, owner_id, tags, lists, pipeline_status, lat, lng,
  'foreclosure_listings' AS source_category
FROM foreclosure_listings

UNION ALL

-- Probate leads have a different schema, so we need to transform them
SELECT 
  id::TEXT AS listing_id,  -- Convert UUID to TEXT
  NULL AS property_url,     -- Probate doesn't have property_url
  NULL AS permalink,
  NULL AS scrape_date,
  created_at AS last_scraped_at,
  TRUE AS active,
  address AS street,         -- Probate uses 'address' instead of 'street'
  NULL AS unit,
  city,
  state,
  zip AS zip_code,          -- Probate uses 'zip' instead of 'zip_code'
  NULL AS beds,
  NULL AS full_baths,
  NULL AS half_baths,
  NULL AS sqft,
  NULL AS year_built,
  NULL AS list_price,
  NULL AS list_price_min,
  NULL AS list_price_max,
  'probate' AS status,
  NULL AS mls,
  decedent_name AS agent_name,  -- Use decedent_name as agent_name
  NULL AS agent_email,
  NULL AS agent_phone,
  NULL AS agent_phone_2,
  NULL AS listing_agent_phone_2,
  NULL AS listing_agent_phone_5,
  notes AS text,            -- Use notes as text/description
  NULL AS last_sale_price,
  NULL AS last_sale_date,
  NULL AS photos,
  NULL AS photos_json,
  jsonb_build_object(
    'case_number', case_number,
    'filing_date', filing_date,
    'source', source
  ) AS other,
  NULL AS price_per_sqft,
  NULL AS listing_source_name,
  NULL AS listing_source_id,
  NULL AS monthly_payment_estimate,
  NULL AS ai_investment_score,
  NULL AS time_listed,
  created_at,
  updated_at,
  NULL AS user_id,          -- Probate doesn't have user_id
  NULL AS owner_id,
  NULL AS tags,
  NULL AS lists,
  NULL AS pipeline_status,
  latitude AS lat,          -- Probate uses 'latitude' instead of 'lat'
  longitude AS lng,         -- Probate uses 'longitude' instead of 'lng'
  'probate_leads' AS source_category
FROM probate_leads;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions for lists tables
GRANT ALL ON lists TO authenticated;
GRANT ALL ON list_items TO authenticated;
GRANT SELECT ON list_counts TO authenticated;
GRANT SELECT ON list_items_with_metadata TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_items_paginated(UUID, INTEGER, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_items_count(UUID, TEXT) TO authenticated;

-- Grant permissions for unified listings view
GRANT SELECT ON listings_unified TO authenticated;

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- Note: Sample listing data is not included because listings require a user_id.
-- Users should create listings through the application after signing up.
-- This ensures proper user association and data isolation.

-- Insert default email templates (shared/admin-managed, no user_id required)
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
WHERE pu.id IS NULL
ON CONFLICT (id) DO NOTHING;

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
SELECT COUNT(*) as total_tasks FROM tasks;
SELECT COUNT(*) as total_contacts FROM contacts;
SELECT COUNT(*) as total_deals FROM deals;
-- Verify lead category tables
SELECT COUNT(*) as total_expired_listings FROM expired_listings;
SELECT COUNT(*) as total_fsbo_leads FROM fsbo_leads;
SELECT COUNT(*) as total_frbo_leads FROM frbo_leads;
SELECT COUNT(*) as total_imports FROM imports;
SELECT COUNT(*) as total_trash FROM trash;
SELECT COUNT(*) as total_foreclosure_listings FROM foreclosure_listings;
SELECT COUNT(*) as total_lists FROM lists;
SELECT COUNT(*) as total_list_items FROM list_items;
SELECT COUNT(*) as total_unified_listings FROM listings_unified;
SELECT source_category, COUNT(*) as count FROM listings_unified GROUP BY source_category;
SELECT 'All systems ready! Lead category tables and lists integrated successfully!' as final_status;

-- ============================================================================
-- END OF SCHEMA
-- =================================================A===========================

