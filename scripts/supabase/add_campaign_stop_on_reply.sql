-- ============================================================================
-- Add stop_on_reply field to campaigns table
-- ============================================================================
-- Allows campaigns to stop sending emails when recipients reply

-- Add stop_on_reply column if it doesn't exist
ALTER TABLE campaigns 
  ADD COLUMN IF NOT EXISTS stop_on_reply BOOLEAN DEFAULT TRUE;

-- Add comment
COMMENT ON COLUMN campaigns.stop_on_reply IS 'Stop sending emails to recipients who have replied (campaign-level setting)';

