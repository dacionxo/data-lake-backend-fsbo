-- ============================================================================
-- Add end_at field to campaigns table
-- ============================================================================
-- This allows campaigns to have an end date after which they stop sending

ALTER TABLE campaigns 
  ADD COLUMN IF NOT EXISTS end_at TIMESTAMPTZ;

-- Add index for performance when querying active campaigns
CREATE INDEX IF NOT EXISTS idx_campaigns_end_at ON campaigns(end_at) WHERE end_at IS NOT NULL;

-- Add comment
COMMENT ON COLUMN campaigns.end_at IS 'End date/time for the campaign. Campaign will stop sending after this date. NULL means no end date.';

