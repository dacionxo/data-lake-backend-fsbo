-- ============================================================================
-- Campaign Options Schema Enhancement
-- ============================================================================
-- Adds options/settings fields to campaigns table for the Options tab
-- ============================================================================

-- Add campaign options fields
ALTER TABLE campaigns
  -- Stop on reply (campaign-level override)
  ADD COLUMN IF NOT EXISTS stop_on_reply BOOLEAN DEFAULT TRUE;

ALTER TABLE campaigns
  -- Tracking options
  ADD COLUMN IF NOT EXISTS open_tracking_enabled BOOLEAN DEFAULT TRUE;

ALTER TABLE campaigns
  ADD COLUMN IF NOT EXISTS link_tracking_enabled BOOLEAN DEFAULT TRUE;

ALTER TABLE campaigns
  -- Delivery optimization
  ADD COLUMN IF NOT EXISTS text_only_mode BOOLEAN DEFAULT FALSE;

ALTER TABLE campaigns
  ADD COLUMN IF NOT EXISTS first_email_text_only BOOLEAN DEFAULT FALSE;

-- Daily limit is already in schema as daily_cap
-- Mailbox selection is already in schema as mailbox_id

-- Create index for filtering
CREATE INDEX IF NOT EXISTS idx_campaigns_options ON campaigns(stop_on_reply, open_tracking_enabled, link_tracking_enabled);

-- ============================================================================
-- Comments for documentation
-- ============================================================================
COMMENT ON COLUMN campaigns.stop_on_reply IS 'Stop sending emails to a lead if a response has been received (campaign-level setting)';
COMMENT ON COLUMN campaigns.open_tracking_enabled IS 'Track email opens using tracking pixel';
COMMENT ON COLUMN campaigns.link_tracking_enabled IS 'Track link clicks by wrapping URLs';
COMMENT ON COLUMN campaigns.text_only_mode IS 'Send all emails as text-only (no HTML)';
COMMENT ON COLUMN campaigns.first_email_text_only IS 'Send first email as text-only (pro feature)';

