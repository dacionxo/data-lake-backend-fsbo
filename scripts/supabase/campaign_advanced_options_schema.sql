-- ============================================================================
-- Campaign Advanced Options Schema
-- ============================================================================
-- Adds advanced campaign settings for CRM, sending patterns, A/B testing,
-- provider matching, and email compliance features
-- ============================================================================

-- ============================================================================
-- CRM Features
-- ============================================================================
ALTER TABLE campaigns
  -- Campaign ownership (for team collaboration)
  -- Defaults to user_id via application logic, but can be changed for team collaboration
  ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create a trigger to set owner_id to user_id if not provided (fallback)
-- This ensures owner_id is always set even if application doesn't provide it
CREATE OR REPLACE FUNCTION set_campaign_owner_id()
RETURNS TRIGGER AS $$
BEGIN
  -- If owner_id is NULL, set it to user_id
  IF NEW.owner_id IS NULL THEN
    NEW.owner_id := NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_campaign_owner_id ON campaigns;
CREATE TRIGGER trigger_set_campaign_owner_id
  BEFORE INSERT ON campaigns
  FOR EACH ROW
  EXECUTE FUNCTION set_campaign_owner_id();

ALTER TABLE campaigns
  -- Custom tags for grouping campaigns
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT ARRAY[]::TEXT[];

-- ============================================================================
-- Sending Pattern
-- ============================================================================
ALTER TABLE campaigns
  -- Time gap between emails (minimum time in minutes)
  ADD COLUMN IF NOT EXISTS time_gap_min INTEGER DEFAULT 9;

ALTER TABLE campaigns
  -- Random additional time to add to time gap (in minutes)
  ADD COLUMN IF NOT EXISTS time_gap_random INTEGER DEFAULT 5;

ALTER TABLE campaigns
  -- Maximum new leads to add per day
  ADD COLUMN IF NOT EXISTS max_new_leads_per_day INTEGER;

ALTER TABLE campaigns
  -- Prioritize new leads over existing ones in queue
  ADD COLUMN IF NOT EXISTS prioritize_new_leads BOOLEAN DEFAULT FALSE;

-- ============================================================================
-- Auto Optimize A/B Testing
-- ============================================================================
ALTER TABLE campaigns
  -- Enable automatic winner selection for split tests
  ADD COLUMN IF NOT EXISTS auto_optimize_split_test BOOLEAN DEFAULT FALSE;

ALTER TABLE campaigns
  -- Metric to use for determining winner (open_rate, click_rate, reply_rate, conversion_rate)
  ADD COLUMN IF NOT EXISTS split_test_winning_metric TEXT DEFAULT 'open_rate' 
    CHECK (split_test_winning_metric IN ('open_rate', 'click_rate', 'reply_rate', 'conversion_rate'));

-- ============================================================================
-- Provider Matching / ESP Routing
-- ============================================================================
ALTER TABLE campaigns
  -- Enable provider matching (match sender and recipient email providers)
  ADD COLUMN IF NOT EXISTS provider_matching_enabled BOOLEAN DEFAULT FALSE;

ALTER TABLE campaigns
  -- ESP routing rules (JSONB for flexible rule configuration)
  -- Format: [{"sender_provider": "gmail", "recipient_provider": "gmail", "mailbox_id": "uuid"}, ...]
  ADD COLUMN IF NOT EXISTS esp_routing_rules JSONB DEFAULT '[]'::JSONB;

-- ============================================================================
-- Email Compliance & Safety
-- ============================================================================
ALTER TABLE campaigns
  -- Stop campaign for entire company when any lead from that company replies
  ADD COLUMN IF NOT EXISTS stop_company_on_reply BOOLEAN DEFAULT FALSE;

ALTER TABLE campaigns
  -- Stop sending emails to a lead if an automatic response is received
  ADD COLUMN IF NOT EXISTS stop_on_auto_reply BOOLEAN DEFAULT FALSE;

ALTER TABLE campaigns
  -- Insert unsubscribe link in email headers (List-Unsubscribe header)
  ADD COLUMN IF NOT EXISTS unsubscribe_link_header BOOLEAN DEFAULT TRUE;

ALTER TABLE campaigns
  -- Allow risky emails to be contacted (bypass risky email filtering)
  ADD COLUMN IF NOT EXISTS allow_risky_emails BOOLEAN DEFAULT FALSE;

-- Add stopped_reason column to campaign_recipients if it doesn't exist
ALTER TABLE campaign_recipients
  ADD COLUMN IF NOT EXISTS stopped_reason TEXT;

-- ============================================================================
-- Indexes for Performance
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_campaigns_owner_id ON campaigns(owner_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_tags ON campaigns USING GIN(tags);

-- ============================================================================
-- Comments for Documentation
-- ============================================================================
COMMENT ON COLUMN campaigns.owner_id IS 'Campaign owner/assignee for team collaboration';
COMMENT ON COLUMN campaigns.tags IS 'Custom tags for grouping and filtering campaigns';
COMMENT ON COLUMN campaigns.time_gap_min IS 'Minimum time gap between emails in minutes';
COMMENT ON COLUMN campaigns.time_gap_random IS 'Random additional time to add to time gap in minutes';
COMMENT ON COLUMN campaigns.max_new_leads_per_day IS 'Maximum number of new leads to add to campaign per day';
COMMENT ON COLUMN campaigns.prioritize_new_leads IS 'Prioritize new leads over existing ones in sending queue';
COMMENT ON COLUMN campaigns.auto_optimize_split_test IS 'Automatically select winning variant in A/B tests';
COMMENT ON COLUMN campaigns.split_test_winning_metric IS 'Metric used to determine winning variant (open_rate, click_rate, reply_rate, conversion_rate)';
COMMENT ON COLUMN campaigns.provider_matching_enabled IS 'Enable provider matching (match sender and recipient email providers)';
COMMENT ON COLUMN campaigns.esp_routing_rules IS 'JSONB array of ESP routing rules for provider-based mailbox selection';
COMMENT ON COLUMN campaigns.stop_company_on_reply IS 'Stop campaign for entire company when any lead from that company replies';
COMMENT ON COLUMN campaigns.stop_on_auto_reply IS 'Stop sending emails to a lead if an automatic response is received';
COMMENT ON COLUMN campaigns.unsubscribe_link_header IS 'Insert unsubscribe link in email headers (List-Unsubscribe header)';
COMMENT ON COLUMN campaigns.allow_risky_emails IS 'Allow risky emails to be contacted (bypass risky email filtering)';

