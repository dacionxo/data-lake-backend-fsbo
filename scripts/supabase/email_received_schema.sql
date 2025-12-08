-- ============================================================================
-- Received Emails Schema Extension
-- ============================================================================
-- Extends the emails table to support received/incoming emails for Unibox
-- ============================================================================

-- Add columns to emails table for received emails
ALTER TABLE emails ADD COLUMN IF NOT EXISTS direction TEXT CHECK (direction IN ('sent', 'received')) DEFAULT 'sent';
ALTER TABLE emails ADD COLUMN IF NOT EXISTS from_email TEXT;
ALTER TABLE emails ADD COLUMN IF NOT EXISTS from_name TEXT;
ALTER TABLE emails ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ;
ALTER TABLE emails ADD COLUMN IF NOT EXISTS thread_id TEXT; -- For grouping conversation threads
ALTER TABLE emails ADD COLUMN IF NOT EXISTS in_reply_to TEXT; -- Message ID this is replying to
ALTER TABLE emails ADD COLUMN IF NOT EXISTS raw_message_id TEXT; -- Provider's message ID (Gmail/Outlook)
ALTER TABLE emails ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE emails ADD COLUMN IF NOT EXISTS is_starred BOOLEAN DEFAULT FALSE;
ALTER TABLE emails ADD COLUMN IF NOT EXISTS labels TEXT[]; -- Array of labels/folders

-- Create index for received emails lookup
CREATE INDEX IF NOT EXISTS idx_emails_direction ON emails(direction);
CREATE INDEX IF NOT EXISTS idx_emails_received_at ON emails(received_at);
CREATE INDEX IF NOT EXISTS idx_emails_thread_id ON emails(thread_id);
CREATE INDEX IF NOT EXISTS idx_emails_is_read ON emails(is_read);

-- Update existing emails to be marked as 'sent' direction
UPDATE emails SET direction = 'sent' WHERE direction IS NULL;

-- Update status constraint to allow 'received' (if needed, otherwise sent emails keep their status)
-- Note: The status column constraint doesn't need to change as received emails can still have status='sent' (from sender's perspective)

