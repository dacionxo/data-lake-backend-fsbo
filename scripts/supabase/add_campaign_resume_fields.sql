-- ============================================================================
-- Add resume-related fields to campaigns table
-- ============================================================================
-- Ensures campaigns can be properly paused and resumed

-- Add resumed_at if it doesn't exist
ALTER TABLE campaigns 
  ADD COLUMN IF NOT EXISTS resumed_at TIMESTAMPTZ;

-- Add paused_at if it doesn't exist
ALTER TABLE campaigns 
  ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ;

-- Add index for performance when querying paused campaigns
CREATE INDEX IF NOT EXISTS idx_campaigns_paused_at ON campaigns(paused_at) WHERE paused_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_campaigns_resumed_at ON campaigns(resumed_at) WHERE resumed_at IS NOT NULL;

-- Add comments
COMMENT ON COLUMN campaigns.paused_at IS 'Timestamp when the campaign was paused';
COMMENT ON COLUMN campaigns.resumed_at IS 'Timestamp when the campaign was resumed';

