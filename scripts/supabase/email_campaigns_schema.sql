-- ============================================================================
-- Email Campaigns System - Complete Database Schema
-- ============================================================================
-- Full implementation matching Instantly/Apollo architecture
-- ============================================================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS campaign_recipients CASCADE;
DROP TABLE IF EXISTS campaign_steps CASCADE;
DROP TABLE IF EXISTS campaigns CASCADE;

-- Note: mailboxes and emails tables should already exist from email_mailboxes_schema.sql
-- We'll add additional columns to emails table if needed

-- ============================================================================
-- CAMPAIGNS TABLE
-- ============================================================================
CREATE TABLE campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  
  name TEXT NOT NULL,
  description TEXT,
  
  status TEXT NOT NULL CHECK (status IN ('draft', 'scheduled', 'running', 'paused', 'completed', 'cancelled')) DEFAULT 'draft',
  
  send_strategy TEXT NOT NULL CHECK (send_strategy IN ('single', 'sequence')) DEFAULT 'single',
  start_at TIMESTAMPTZ,
  timezone TEXT DEFAULT 'UTC',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- CAMPAIGN_STEPS TABLE
-- ============================================================================
-- For multi-step drips: initial email + follow-ups
CREATE TABLE campaign_steps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  
  step_number INTEGER NOT NULL,        -- 1, 2, 3...
  delay_hours INTEGER NOT NULL,        -- hours after previous step or start_at
  
  template_id UUID REFERENCES email_templates(id),
  
  subject TEXT NOT NULL,
  html TEXT NOT NULL,
  
  stop_on_reply BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(campaign_id, step_number)
);

-- ============================================================================
-- CAMPAIGN_RECIPIENTS TABLE
-- ============================================================================
-- Who gets what: contacts, leads, listing owners, etc.
CREATE TABLE campaign_recipients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  
  -- Link to existing CRM / listing:
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  listing_id TEXT REFERENCES listings(listing_id) ON DELETE SET NULL,
  
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  
  status TEXT NOT NULL CHECK (
    status IN ('pending', 'queued', 'in_progress', 'completed', 'bounced', 'unsubscribed', 'failed')
  ) DEFAULT 'pending',
  
  last_step_sent INTEGER,    -- step_number
  last_sent_at TIMESTAMPTZ,
  replied BOOLEAN DEFAULT FALSE,
  bounced BOOLEAN DEFAULT FALSE,
  unsubscribed BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- UPDATE EMAILS TABLE
-- ============================================================================
-- Add campaign-related columns to existing emails table
ALTER TABLE emails 
  ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS campaign_step_id UUID REFERENCES campaign_steps(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS campaign_recipient_id UUID REFERENCES campaign_recipients(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS last_error TEXT;

-- Update status check constraint to include 'cancelled'
ALTER TABLE emails DROP CONSTRAINT IF EXISTS emails_status_check;
ALTER TABLE emails ADD CONSTRAINT emails_status_check 
  CHECK (status IN ('queued', 'sending', 'sent', 'failed', 'cancelled'));

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_campaigns_user_id ON campaigns(user_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_mailbox_id ON campaigns(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_start_at ON campaigns(start_at);

CREATE INDEX IF NOT EXISTS idx_campaign_steps_campaign_id ON campaign_steps(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_steps_step_number ON campaign_steps(campaign_id, step_number);

CREATE INDEX IF NOT EXISTS idx_campaign_recipients_campaign_id ON campaign_recipients(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_status ON campaign_recipients(status);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_email ON campaign_recipients(email);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_contact_id ON campaign_recipients(contact_id);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_listing_id ON campaign_recipients(listing_id);

CREATE INDEX IF NOT EXISTS idx_emails_campaign_id ON emails(campaign_id);
CREATE INDEX IF NOT EXISTS idx_emails_campaign_step_id ON emails(campaign_step_id);
CREATE INDEX IF NOT EXISTS idx_emails_campaign_recipient_id ON emails(campaign_recipient_id);

-- ============================================================================
-- RLS POLICIES
-- ============================================================================
ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE campaign_recipients ENABLE ROW LEVEL SECURITY;

-- Campaigns policies
DROP POLICY IF EXISTS "Users can view their own campaigns" ON campaigns;
CREATE POLICY "Users can view their own campaigns"
  ON campaigns FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own campaigns" ON campaigns;
CREATE POLICY "Users can insert their own campaigns"
  ON campaigns FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own campaigns" ON campaigns;
CREATE POLICY "Users can update their own campaigns"
  ON campaigns FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own campaigns" ON campaigns;
CREATE POLICY "Users can delete their own campaigns"
  ON campaigns FOR DELETE
  USING (auth.uid() = user_id);

-- Campaign steps policies
DROP POLICY IF EXISTS "Users can view their own campaign steps" ON campaign_steps;
CREATE POLICY "Users can view their own campaign steps"
  ON campaign_steps FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_steps.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert their own campaign steps" ON campaign_steps;
CREATE POLICY "Users can insert their own campaign steps"
  ON campaign_steps FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_steps.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update their own campaign steps" ON campaign_steps;
CREATE POLICY "Users can update their own campaign steps"
  ON campaign_steps FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_steps.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete their own campaign steps" ON campaign_steps;
CREATE POLICY "Users can delete their own campaign steps"
  ON campaign_steps FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_steps.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

-- Campaign recipients policies
DROP POLICY IF EXISTS "Users can view their own campaign recipients" ON campaign_recipients;
CREATE POLICY "Users can view their own campaign recipients"
  ON campaign_recipients FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_recipients.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert their own campaign recipients" ON campaign_recipients;
CREATE POLICY "Users can insert their own campaign recipients"
  ON campaign_recipients FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_recipients.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can update their own campaign recipients" ON campaign_recipients;
CREATE POLICY "Users can update their own campaign recipients"
  ON campaign_recipients FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_recipients.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can delete their own campaign recipients" ON campaign_recipients;
CREATE POLICY "Users can delete their own campaign recipients"
  ON campaign_recipients FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM campaigns
      WHERE campaigns.id = campaign_recipients.campaign_id
      AND campaigns.user_id = auth.uid()
    )
  );

-- ============================================================================
-- TRIGGERS
-- ============================================================================
-- Trigger for campaigns updated_at
DROP TRIGGER IF EXISTS update_campaigns_updated_at ON campaigns;
CREATE TRIGGER update_campaigns_updated_at
  BEFORE UPDATE ON campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Trigger for campaign_recipients updated_at
DROP TRIGGER IF EXISTS update_campaign_recipients_updated_at ON campaign_recipients;
CREATE TRIGGER update_campaign_recipients_updated_at
  BEFORE UPDATE ON campaign_recipients
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

