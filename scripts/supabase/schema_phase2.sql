-- LeadMap Phase 2 Schema Extensions
-- Run this after the base schema.sql

-- First, ensure role column exists on users table
-- Add column first (nullable)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role TEXT;

-- Update existing rows to default 'user'
UPDATE users SET role = 'user' WHERE role IS NULL;

-- Add NOT NULL constraint and default
ALTER TABLE users
  ALTER COLUMN role SET DEFAULT 'user',
  ALTER COLUMN role SET NOT NULL;

-- Add check constraint if it doesn't exist (handle errors gracefully)
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_role_check'
  ) THEN
    ALTER TABLE users 
    ADD CONSTRAINT users_role_check CHECK (role IN ('user', 'admin'));
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Constraint might already exist in different form
  RAISE NOTICE 'users_role_check constraint already exists or error: %', SQLERRM;
END $$;

-- Extend listings table with Phase 2 fields
ALTER TABLE listings
  ADD COLUMN IF NOT EXISTS expired BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS expired_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS owner_email TEXT,
  ADD COLUMN IF NOT EXISTS enrichment_source TEXT,
  ADD COLUMN IF NOT EXISTS enrichment_confidence FLOAT,
  ADD COLUMN IF NOT EXISTS geo_source TEXT,
  ADD COLUMN IF NOT EXISTS radius_km FLOAT;

-- Create indexes for new fields
CREATE INDEX IF NOT EXISTS idx_listings_expired ON listings(expired);
CREATE INDEX IF NOT EXISTS idx_listings_expired_at ON listings(expired_at);
CREATE INDEX IF NOT EXISTS idx_listings_enrichment_source ON listings(enrichment_source);
CREATE INDEX IF NOT EXISTS idx_listings_geo_source ON listings(geo_source);

-- Drop and create email_templates table
DROP TABLE IF EXISTS email_templates CASCADE;
CREATE TABLE email_templates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL, -- 'follow_up', 'initial_contact', 'expired_listing', 'probate', 'general'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Create indexes for email_templates
CREATE INDEX IF NOT EXISTS idx_email_templates_category ON email_templates(category);
CREATE INDEX IF NOT EXISTS idx_email_templates_created_by ON email_templates(created_by);

-- Create trigger for email_templates updated_at
DROP TRIGGER IF EXISTS update_email_templates_updated_at ON email_templates;
CREATE TRIGGER update_email_templates_updated_at 
  BEFORE UPDATE ON email_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS for email_templates
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for email_templates
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

-- Drop and create probate_leads table
DROP TABLE IF EXISTS probate_leads CASCADE;
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

-- Create indexes for probate_leads
CREATE INDEX IF NOT EXISTS idx_probate_leads_case_number ON probate_leads(case_number);
CREATE INDEX IF NOT EXISTS idx_probate_leads_state ON probate_leads(state);
CREATE INDEX IF NOT EXISTS idx_probate_leads_city ON probate_leads(city);
CREATE INDEX IF NOT EXISTS idx_probate_leads_filing_date ON probate_leads(filing_date);

-- Create trigger for probate_leads updated_at
DROP TRIGGER IF EXISTS update_probate_leads_updated_at ON probate_leads;
CREATE TRIGGER update_probate_leads_updated_at 
  BEFORE UPDATE ON probate_leads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS for probate_leads
ALTER TABLE probate_leads ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for probate_leads
CREATE POLICY "Authenticated users can view probate leads" ON probate_leads
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage probate leads" ON probate_leads
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Insert some default email templates
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

SELECT 'Phase 2 schema extensions applied successfully!' as status;

