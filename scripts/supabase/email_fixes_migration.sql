-- ============================================================================
-- Email System Fixes Migration (Transaction-Safe Version)
-- ============================================================================
-- This migration fixes various issues identified in the email system:
-- 1. Adds unique constraint on provider_message_id to prevent duplicate emails
-- 2. Adds unique constraint on raw_message_id for received emails
-- 
-- This version uses regular CREATE INDEX (NOT CONCURRENTLY) so it can
-- run inside a transaction block (which Supabase SQL editor does automatically).
-- 
-- For production with large tables (>1000 rows), use the concurrent version
-- instead: email_fixes_migration_concurrent.sql
-- ============================================================================

-- Add unique index on provider_message_id (for sent emails from providers)
-- This prevents duplicate emails from webhook retries or duplicate sends
CREATE UNIQUE INDEX IF NOT EXISTS idx_emails_provider_message_id_unique 
ON emails (provider_message_id) 
WHERE provider_message_id IS NOT NULL;

COMMENT ON INDEX idx_emails_provider_message_id_unique IS 
'Unique constraint on provider_message_id to prevent duplicate emails from provider webhooks';

-- Add unique index on raw_message_id (for received emails)
-- This prevents duplicate emails from duplicate webhook notifications
CREATE UNIQUE INDEX IF NOT EXISTS idx_emails_raw_message_id_unique 
ON emails (raw_message_id) 
WHERE raw_message_id IS NOT NULL;

COMMENT ON INDEX idx_emails_raw_message_id_unique IS 
'Unique constraint on raw_message_id to prevent duplicate received emails from webhook retries';

-- Add unique index on email_messages.provider_message_id to prevent duplicates
-- Only creates if email_messages table exists (for Unibox)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'email_messages'
  ) THEN
    CREATE UNIQUE INDEX IF NOT EXISTS idx_email_messages_provider_message_id_unique 
    ON email_messages (provider_message_id, mailbox_id) 
    WHERE provider_message_id IS NOT NULL;
    
    COMMENT ON INDEX idx_email_messages_provider_message_id_unique IS 
    'Unique constraint on provider_message_id per mailbox to prevent duplicate messages in Unibox';
  END IF;
END $$;

-- Add indexes on emails.direction for better query performance
CREATE INDEX IF NOT EXISTS idx_emails_direction ON emails(direction);
CREATE INDEX IF NOT EXISTS idx_emails_direction_mailbox ON emails(direction, mailbox_id);
CREATE INDEX IF NOT EXISTS idx_emails_direction_user ON emails(direction, user_id);

-- Add comment documenting the migration
COMMENT ON TABLE emails IS 
'Email log table. Stores both sent and received emails. 
Direction: "sent" for outbound emails, "received" for inbound emails.
Unique constraints on provider_message_id and raw_message_id prevent duplicates.';
