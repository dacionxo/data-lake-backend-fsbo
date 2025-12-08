-- ============================================================================
-- Deals Module Schema Updates
-- ============================================================================
-- This file adds enhancements to the deals table and creates supporting tables
-- for the full deals pipeline functionality

-- Add property_id/listing_id to deals table for better property linking
ALTER TABLE deals 
ADD COLUMN IF NOT EXISTS listing_id TEXT,
ADD COLUMN IF NOT EXISTS pipeline_id UUID,
ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS assigned_to UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create index for listing_id
CREATE INDEX IF NOT EXISTS idx_deals_listing_id ON deals(listing_id);
CREATE INDEX IF NOT EXISTS idx_deals_pipeline_id ON deals(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_deals_owner_id ON deals(owner_id);
CREATE INDEX IF NOT EXISTS idx_deals_assigned_to ON deals(assigned_to);

-- Deal Pipelines Table
-- Stores custom pipelines for different deal types or markets
CREATE TABLE IF NOT EXISTS deal_pipelines (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  stages TEXT[] NOT NULL, -- Array of stage names in order
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

CREATE INDEX IF NOT EXISTS idx_deal_pipelines_user_id ON deal_pipelines(user_id);

-- Deal Activities Table
-- Stores activity log for deals (emails, calls, notes, status changes, etc.)
CREATE TABLE IF NOT EXISTS deal_activities (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  deal_id UUID REFERENCES deals(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  activity_type TEXT NOT NULL CHECK (activity_type IN (
    'note', 
    'email', 
    'call', 
    'sms', 
    'meeting', 
    'task_created', 
    'task_completed', 
    'stage_changed', 
    'value_changed', 
    'contact_added', 
    'document_uploaded',
    'status_changed'
  )),
  title TEXT NOT NULL,
  description TEXT,
  metadata JSONB, -- Store additional data (email content, call duration, etc.)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deal_activities_deal_id ON deal_activities(deal_id);
CREATE INDEX IF NOT EXISTS idx_deal_activities_user_id ON deal_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_deal_activities_created_at ON deal_activities(created_at DESC);

-- Deal Contacts Table (Many-to-Many relationship)
-- Links multiple contacts to a deal (seller, buyer, broker, etc.)
CREATE TABLE IF NOT EXISTS deal_contacts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  deal_id UUID REFERENCES deals(id) ON DELETE CASCADE NOT NULL,
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE NOT NULL,
  role TEXT, -- 'seller', 'buyer', 'broker', 'agent', 'contractor', etc.
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(deal_id, contact_id)
);

CREATE INDEX IF NOT EXISTS idx_deal_contacts_deal_id ON deal_contacts(deal_id);
CREATE INDEX IF NOT EXISTS idx_deal_contacts_contact_id ON deal_contacts(contact_id);

-- Deal Watchers Table
-- Users who are watching/following a deal
CREATE TABLE IF NOT EXISTS deal_watchers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  deal_id UUID REFERENCES deals(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(deal_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_deal_watchers_deal_id ON deal_watchers(deal_id);
CREATE INDEX IF NOT EXISTS idx_deal_watchers_user_id ON deal_watchers(user_id);

-- Deal Documents Table
-- Stores documents attached to deals
CREATE TABLE IF NOT EXISTS deal_documents (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  deal_id UUID REFERENCES deals(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT,
  file_size BIGINT,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deal_documents_deal_id ON deal_documents(deal_id);

-- Add updated_at trigger for deal_pipelines
CREATE TRIGGER update_deal_pipelines_updated_at BEFORE UPDATE ON deal_pipelines
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default pipeline for existing users (will be created per user on first use)
-- Note: This is handled in the application code, not here

