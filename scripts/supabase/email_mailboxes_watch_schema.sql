-- ============================================================================
-- Gmail Watch Schema Extension
-- ============================================================================
-- Adds fields to mailboxes table to support Gmail Watch for push notifications
-- ============================================================================

-- Add columns for Gmail Watch
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS watch_expiration TIMESTAMPTZ;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS watch_history_id TEXT;

-- Create index for watch expiration (for renewal cron jobs)
CREATE INDEX IF NOT EXISTS idx_mailboxes_watch_expiration ON mailboxes(watch_expiration);

-- Create index for provider + watch expiration (for Gmail watch renewal)
CREATE INDEX IF NOT EXISTS idx_mailboxes_provider_watch ON mailboxes(provider, watch_expiration) 
  WHERE provider = 'gmail' AND watch_expiration IS NOT NULL;

