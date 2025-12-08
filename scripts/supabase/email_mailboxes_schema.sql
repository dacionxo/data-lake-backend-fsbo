-- Email Mailboxes Schema
-- This schema supports Gmail, Outlook, and SMTP mailboxes for email marketing

-- Mailboxes table
CREATE TABLE IF NOT EXISTS mailboxes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('gmail', 'outlook', 'smtp', 'resend', 'sendgrid', 'mailgun', 'ses', 'generic')),
  email TEXT NOT NULL,
  display_name TEXT,
  access_token TEXT,      -- encrypted / KMS (stored as plain text for now, should be encrypted in production)
  refresh_token TEXT,     -- encrypted
  token_expires_at TIMESTAMPTZ,
  smtp_host TEXT,
  smtp_port INTEGER,
  smtp_username TEXT,
  smtp_password TEXT,     -- encrypted (for app passwords)
  from_name TEXT,
  from_email TEXT,
  daily_limit INTEGER DEFAULT 200,
  hourly_limit INTEGER DEFAULT 20,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, email, provider)
);

-- Emails table (log of sends)
CREATE TABLE IF NOT EXISTS emails (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  to_email TEXT NOT NULL,
  subject TEXT NOT NULL,
  html TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('queued','sending','sent','failed')),
  provider_message_id TEXT,
  error TEXT,
  scheduled_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  opened_at TIMESTAMPTZ,
  clicked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Email campaigns table (for grouping emails)
CREATE TABLE IF NOT EXISTS email_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  sender_email TEXT,
  sender_name TEXT,
  subject TEXT,
  preview_text TEXT,
  html_content TEXT,
  reply_to TEXT,
  send_type TEXT CHECK (send_type IN ('now','schedule','batch','rss','smart')) DEFAULT 'now',
  recipient_type TEXT CHECK (recipient_type IN ('contacts','smart_list','segments')) DEFAULT 'contacts',
  recipient_ids JSONB DEFAULT '[]'::jsonb,
  track_clicks BOOLEAN DEFAULT FALSE,
  utm_tracking BOOLEAN DEFAULT FALSE,
  add_tags BOOLEAN DEFAULT FALSE,
  resend_unopened BOOLEAN DEFAULT FALSE,
  status TEXT NOT NULL CHECK (status IN ('draft','scheduled','sending','completed','paused')) DEFAULT 'draft',
  scheduled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Link emails to campaigns
ALTER TABLE emails ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES email_campaigns(id) ON DELETE SET NULL;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_mailboxes_user_id ON mailboxes(user_id);
CREATE INDEX IF NOT EXISTS idx_mailboxes_active ON mailboxes(active);
CREATE INDEX IF NOT EXISTS idx_emails_user_id ON emails(user_id);
CREATE INDEX IF NOT EXISTS idx_emails_mailbox_id ON emails(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_emails_status ON emails(status);
CREATE INDEX IF NOT EXISTS idx_emails_scheduled_at ON emails(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_emails_campaign_id ON emails(campaign_id);
CREATE INDEX IF NOT EXISTS idx_email_campaigns_user_id ON email_campaigns(user_id);

-- RLS Policies
ALTER TABLE mailboxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_campaigns ENABLE ROW LEVEL SECURITY;

-- Mailboxes policies
DROP POLICY IF EXISTS "Users can view their own mailboxes" ON mailboxes;
CREATE POLICY "Users can view their own mailboxes"
  ON mailboxes FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own mailboxes" ON mailboxes;
CREATE POLICY "Users can insert their own mailboxes"
  ON mailboxes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own mailboxes" ON mailboxes;
CREATE POLICY "Users can update their own mailboxes"
  ON mailboxes FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own mailboxes" ON mailboxes;
CREATE POLICY "Users can delete their own mailboxes"
  ON mailboxes FOR DELETE
  USING (auth.uid() = user_id);

-- Emails policies
DROP POLICY IF EXISTS "Users can view their own emails" ON emails;
CREATE POLICY "Users can view their own emails"
  ON emails FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own emails" ON emails;
CREATE POLICY "Users can insert their own emails"
  ON emails FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own emails" ON emails;
CREATE POLICY "Users can update their own emails"
  ON emails FOR UPDATE
  USING (auth.uid() = user_id);

-- Email campaigns policies
DROP POLICY IF EXISTS "Users can view their own campaigns" ON email_campaigns;
CREATE POLICY "Users can view their own campaigns"
  ON email_campaigns FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own campaigns" ON email_campaigns;
CREATE POLICY "Users can insert their own campaigns"
  ON email_campaigns FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own campaigns" ON email_campaigns;
CREATE POLICY "Users can update their own campaigns"
  ON email_campaigns FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own campaigns" ON email_campaigns;
CREATE POLICY "Users can delete their own campaigns"
  ON email_campaigns FOR DELETE
  USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_mailboxes_updated_at ON mailboxes;
CREATE TRIGGER update_mailboxes_updated_at
  BEFORE UPDATE ON mailboxes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_email_campaigns_updated_at ON email_campaigns;
CREATE TRIGGER update_email_campaigns_updated_at
  BEFORE UPDATE ON email_campaigns
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

