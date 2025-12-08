-- ============================================================================
-- Email System Fixes Migration (CONCURRENTLY Version for Production)
-- ============================================================================
-- This migration uses CREATE INDEX CONCURRENTLY which does NOT lock tables
-- but CANNOT run inside a transaction block.
-- 
-- USE THIS VERSION if:
-- - You have a large emails table (>1000 rows)
-- - You want to avoid locking the table during index creation
-- - You can run SQL statements outside of transactions
--
-- INSTRUCTIONS:
-- 1. Run this file directly in Supabase SQL editor (don't wrap in BEGIN/COMMIT)
-- 2. Or run each CREATE INDEX CONCURRENTLY statement separately
-- 3. These statements can take several minutes on large tables
-- ============================================================================

-- Add unique index on provider_message_id (for sent emails from providers)
-- This prevents duplicate emails from webhook retries or duplicate sends
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_emails_provider_message_id_unique 
ON emails (provider_message_id) 
WHERE provider_message_id IS NOT NULL;

COMMENT ON INDEX idx_emails_provider_message_id_unique IS 
'Unique constraint on provider_message_id to prevent duplicate emails from provider webhooks';

-- Add unique index on raw_message_id (for received emails)
-- This prevents duplicate emails from duplicate webhook notifications
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_emails_raw_message_id_unique 
ON emails (raw_message_id) 
WHERE raw_message_id IS NOT NULL;

COMMENT ON INDEX idx_emails_raw_message_id_unique IS 
'Unique constraint on raw_message_id to prevent duplicate received emails from webhook retries';

-- Add unique index on email_messages.provider_message_id to prevent duplicates
-- Only run if email_messages table exists (for Unibox)
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_email_messages_provider_message_id_unique 
ON email_messages (provider_message_id, mailbox_id) 
WHERE provider_message_id IS NOT NULL;

COMMENT ON INDEX idx_email_messages_provider_message_id_unique IS 
'Unique constraint on provider_message_id per mailbox to prevent duplicate messages in Unibox';

-- Regular indexes (these can run in transactions, no CONCURRENTLY needed)
CREATE INDEX IF NOT EXISTS idx_emails_direction ON emails(direction);
CREATE INDEX IF NOT EXISTS idx_emails_direction_mailbox ON emails(direction, mailbox_id);
CREATE INDEX IF NOT EXISTS idx_emails_direction_user ON emails(direction, user_id);

-- Add comment documenting the migration
COMMENT ON TABLE emails IS 
'Email log table. Stores both sent and received emails. 
Direction: "sent" for outbound emails, "received" for inbound emails.
Unique constraints on provider_message_id and raw_message_id prevent duplicates.';

