-- ============================================================================
-- Unibox Email System Schema
-- ============================================================================
-- Comprehensive email threading, messaging, and CRM integration schema
-- Supports Gmail, Outlook, and IMAP providers with real-time sync
-- ============================================================================

-- Update mailboxes table to include sync fields
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS sync_state TEXT DEFAULT 'idle' CHECK (sync_state IN ('idle','initial_sync','running','error'));
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS last_error TEXT;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS watch_expiration TIMESTAMPTZ;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS watch_history_id TEXT;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS provider_thread_id TEXT;

-- Add IMAP/SMTP fields if not exists
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS imap_host TEXT;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS imap_port INTEGER;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS imap_username TEXT;
ALTER TABLE mailboxes ADD COLUMN IF NOT EXISTS imap_password TEXT;

-- Update provider constraint to include imap_smtp
ALTER TABLE mailboxes DROP CONSTRAINT IF EXISTS mailboxes_provider_check;
ALTER TABLE mailboxes ADD CONSTRAINT mailboxes_provider_check 
  CHECK (provider IN ('gmail','outlook','smtp','imap_smtp'));

-- Email Threads Table
-- Groups related messages into conversations
CREATE TABLE IF NOT EXISTS email_threads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  
  -- Provider threading
  provider_thread_id TEXT,  -- Gmail threadId, Outlook conversationId, IMAP custom
  
  subject TEXT,
  last_message_at TIMESTAMPTZ,
  last_inbound_at TIMESTAMPTZ,
  last_outbound_at TIMESTAMPTZ,
  
  -- CRM links
  contact_id UUID,          -- References contacts table
  listing_id TEXT,          -- References listings table
  campaign_id UUID,         -- References campaigns table
  campaign_recipient_id UUID, -- References campaign_recipients table
  
  status TEXT NOT NULL CHECK (
    status IN ('open','needs_reply','waiting','closed','ignored')
  ) DEFAULT 'open',
  
  unread BOOLEAN DEFAULT TRUE,
  archived BOOLEAN DEFAULT FALSE,
  starred BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, mailbox_id, provider_thread_id)
);

-- Email Messages Table
-- Individual email messages within threads
CREATE TABLE IF NOT EXISTS email_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  thread_id UUID NOT NULL REFERENCES email_threads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  
  direction TEXT NOT NULL CHECK (direction IN ('inbound','outbound')),
  provider_message_id TEXT NOT NULL,  -- Gmail message.id, Graph id, IMAP UID
  
  subject TEXT,
  snippet TEXT,  -- Short preview text
  
  body_plain TEXT,
  body_html TEXT,
  
  in_reply_to TEXT,  -- Message-ID this is replying to
  "references" TEXT,   -- Space-separated Message-IDs
  
  sent_at TIMESTAMPTZ,
  received_at TIMESTAMPTZ,
  
  raw_headers JSONB,  -- Full email headers as JSON
  
  spam_flag BOOLEAN DEFAULT FALSE,
  read BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Unique constraint to prevent duplicates
  UNIQUE(mailbox_id, provider_message_id)
);

-- Email Participants Table
-- Tracks from/to/cc/bcc participants for each message
CREATE TABLE IF NOT EXISTS email_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID NOT NULL REFERENCES email_messages(id) ON DELETE CASCADE,
  
  type TEXT NOT NULL CHECK (type IN ('from','to','cc','bcc')),
  email TEXT NOT NULL,
  name TEXT,
  
  contact_id UUID,  -- Link to contacts table if matched
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email Attachments Table
-- Stores attachment metadata
CREATE TABLE IF NOT EXISTS email_attachments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  message_id UUID NOT NULL REFERENCES email_messages(id) ON DELETE CASCADE,
  
  filename TEXT NOT NULL,
  mime_type TEXT,
  size_bytes INTEGER,
  
  storage_path TEXT,  -- Supabase storage path / S3 URL
  
  provider_attachment_id TEXT,  -- Provider-specific attachment ID
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email Forwarding Rules Table
-- Auto-forwarding rules for Instantly-style routing
CREATE TABLE IF NOT EXISTS email_forwarding_rules (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  
  name TEXT NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  
  -- JSON predicates: match on from/to/subject/body/campaign etc.
  -- Example: { "type": "reply_to_campaign", "campaign_id": "..." }
  conditions JSONB,
  
  -- Where to forward
  forward_to_email TEXT NOT NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email Labels Table (optional, for Gmail labels / Outlook folders)
CREATE TABLE IF NOT EXISTS email_labels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  
  name TEXT NOT NULL,
  color TEXT,  -- Hex color for UI display
  provider_label_id TEXT,  -- Provider-specific label ID
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(user_id, mailbox_id, provider_label_id)
);

-- Thread-Label junction table (many-to-many)
CREATE TABLE IF NOT EXISTS email_thread_labels (
  thread_id UUID NOT NULL REFERENCES email_threads(id) ON DELETE CASCADE,
  label_id UUID NOT NULL REFERENCES email_labels(id) ON DELETE CASCADE,
  
  PRIMARY KEY (thread_id, label_id)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_email_threads_user_id ON email_threads(user_id);
CREATE INDEX IF NOT EXISTS idx_email_threads_mailbox_id ON email_threads(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_email_threads_provider_thread_id ON email_threads(provider_thread_id);
CREATE INDEX IF NOT EXISTS idx_email_threads_status ON email_threads(status);
CREATE INDEX IF NOT EXISTS idx_email_threads_unread ON email_threads(unread);
CREATE INDEX IF NOT EXISTS idx_email_threads_last_message_at ON email_threads(last_message_at);
CREATE INDEX IF NOT EXISTS idx_email_threads_contact_id ON email_threads(contact_id);
CREATE INDEX IF NOT EXISTS idx_email_threads_listing_id ON email_threads(listing_id);
CREATE INDEX IF NOT EXISTS idx_email_threads_campaign_id ON email_threads(campaign_id);

CREATE INDEX IF NOT EXISTS idx_email_messages_thread_id ON email_messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_email_messages_user_id ON email_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_email_messages_mailbox_id ON email_messages(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_email_messages_provider_message_id ON email_messages(provider_message_id);
CREATE INDEX IF NOT EXISTS idx_email_messages_direction ON email_messages(direction);
CREATE INDEX IF NOT EXISTS idx_email_messages_received_at ON email_messages(received_at);
CREATE INDEX IF NOT EXISTS idx_email_messages_sent_at ON email_messages(sent_at);
CREATE INDEX IF NOT EXISTS idx_email_messages_in_reply_to ON email_messages(in_reply_to);

CREATE INDEX IF NOT EXISTS idx_email_participants_message_id ON email_participants(message_id);
CREATE INDEX IF NOT EXISTS idx_email_participants_email ON email_participants(email);
CREATE INDEX IF NOT EXISTS idx_email_participants_contact_id ON email_participants(contact_id);

CREATE INDEX IF NOT EXISTS idx_email_attachments_message_id ON email_attachments(message_id);

CREATE INDEX IF NOT EXISTS idx_email_forwarding_rules_user_id ON email_forwarding_rules(user_id);
CREATE INDEX IF NOT EXISTS idx_email_forwarding_rules_mailbox_id ON email_forwarding_rules(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_email_forwarding_rules_active ON email_forwarding_rules(active);

-- Full-text search indexes (PostgreSQL)
CREATE INDEX IF NOT EXISTS idx_email_threads_subject_search ON email_threads USING gin(to_tsvector('english', coalesce(subject, '')));
CREATE INDEX IF NOT EXISTS idx_email_messages_body_search ON email_messages USING gin(to_tsvector('english', coalesce(body_plain, '')));

-- RLS Policies
ALTER TABLE email_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_forwarding_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_labels ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_thread_labels ENABLE ROW LEVEL SECURITY;

-- Email Threads policies
DROP POLICY IF EXISTS "Users can view their own email threads" ON email_threads;
CREATE POLICY "Users can view their own email threads"
  ON email_threads FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own email threads" ON email_threads;
CREATE POLICY "Users can insert their own email threads"
  ON email_threads FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own email threads" ON email_threads;
CREATE POLICY "Users can update their own email threads"
  ON email_threads FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own email threads" ON email_threads;
CREATE POLICY "Users can delete their own email threads"
  ON email_threads FOR DELETE
  USING (auth.uid() = user_id);

-- Email Messages policies
DROP POLICY IF EXISTS "Users can view their own email messages" ON email_messages;
CREATE POLICY "Users can view their own email messages"
  ON email_messages FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own email messages" ON email_messages;
CREATE POLICY "Users can insert their own email messages"
  ON email_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own email messages" ON email_messages;
CREATE POLICY "Users can update their own email messages"
  ON email_messages FOR UPDATE
  USING (auth.uid() = user_id);

-- Email Participants policies
DROP POLICY IF EXISTS "Users can view email participants for their messages" ON email_participants;
CREATE POLICY "Users can view email participants for their messages"
  ON email_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM email_messages
      WHERE email_messages.id = email_participants.message_id
      AND email_messages.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert email participants for their messages" ON email_participants;
CREATE POLICY "Users can insert email participants for their messages"
  ON email_participants FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM email_messages
      WHERE email_messages.id = email_participants.message_id
      AND email_messages.user_id = auth.uid()
    )
  );

-- Email Attachments policies
DROP POLICY IF EXISTS "Users can view attachments for their messages" ON email_attachments;
CREATE POLICY "Users can view attachments for their messages"
  ON email_attachments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM email_messages
      WHERE email_messages.id = email_attachments.message_id
      AND email_messages.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert attachments for their messages" ON email_attachments;
CREATE POLICY "Users can insert attachments for their messages"
  ON email_attachments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM email_messages
      WHERE email_messages.id = email_attachments.message_id
      AND email_messages.user_id = auth.uid()
    )
  );

-- Email Forwarding Rules policies
DROP POLICY IF EXISTS "Users can view their own forwarding rules" ON email_forwarding_rules;
CREATE POLICY "Users can view their own forwarding rules"
  ON email_forwarding_rules FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own forwarding rules" ON email_forwarding_rules;
CREATE POLICY "Users can insert their own forwarding rules"
  ON email_forwarding_rules FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own forwarding rules" ON email_forwarding_rules;
CREATE POLICY "Users can update their own forwarding rules"
  ON email_forwarding_rules FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own forwarding rules" ON email_forwarding_rules;
CREATE POLICY "Users can delete their own forwarding rules"
  ON email_forwarding_rules FOR DELETE
  USING (auth.uid() = user_id);

-- Email Labels policies
DROP POLICY IF EXISTS "Users can view their own email labels" ON email_labels;
CREATE POLICY "Users can view their own email labels"
  ON email_labels FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can manage their own email labels" ON email_labels;
CREATE POLICY "Users can manage their own email labels"
  ON email_labels FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Thread-Label junction policies
DROP POLICY IF EXISTS "Users can view thread labels for their threads" ON email_thread_labels;
CREATE POLICY "Users can view thread labels for their threads"
  ON email_thread_labels FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM email_threads
      WHERE email_threads.id = email_thread_labels.thread_id
      AND email_threads.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can manage thread labels for their threads" ON email_thread_labels;
CREATE POLICY "Users can manage thread labels for their threads"
  ON email_thread_labels FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM email_threads
      WHERE email_threads.id = email_thread_labels.thread_id
      AND email_threads.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM email_threads
      WHERE email_threads.id = email_thread_labels.thread_id
      AND email_threads.user_id = auth.uid()
    )
  );

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_email_threads_updated_at ON email_threads;
CREATE TRIGGER update_email_threads_updated_at
  BEFORE UPDATE ON email_threads
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_email_forwarding_rules_updated_at ON email_forwarding_rules;
CREATE TRIGGER update_email_forwarding_rules_updated_at
  BEFORE UPDATE ON email_forwarding_rules
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to update thread timestamps when messages are added
CREATE OR REPLACE FUNCTION update_thread_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE email_threads
  SET 
    last_message_at = GREATEST(
      COALESCE(last_message_at, NEW.received_at, NEW.sent_at),
      COALESCE(NEW.received_at, NEW.sent_at)
    ),
    last_inbound_at = CASE 
      WHEN NEW.direction = 'inbound' THEN GREATEST(
        COALESCE(last_inbound_at, NEW.received_at),
        NEW.received_at
      )
      ELSE last_inbound_at
    END,
    last_outbound_at = CASE 
      WHEN NEW.direction = 'outbound' THEN GREATEST(
        COALESCE(last_outbound_at, NEW.sent_at),
        NEW.sent_at
      )
      ELSE last_outbound_at
    END,
    unread = CASE 
      WHEN NEW.direction = 'inbound' AND NEW.read = FALSE THEN TRUE
      ELSE unread
    END,
    updated_at = NOW()
  WHERE id = NEW.thread_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update thread timestamps
DROP TRIGGER IF EXISTS update_thread_on_message_insert ON email_messages;
CREATE TRIGGER update_thread_on_message_insert
  AFTER INSERT ON email_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_thread_timestamps();

