-- ============================================================================
-- Email Unsubscribe and Bounce Handling Schema
-- ============================================================================

-- Unsubscribes table - tracks who unsubscribed from emails
CREATE TABLE IF NOT EXISTS email_unsubscribes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  unsubscribe_token UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
  unsubscribed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reason TEXT, -- Optional reason for unsubscribe
  source TEXT, -- 'link', 'reply', 'manual', 'bounce'
  campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, email)
);

-- Email bounces table - tracks bounced emails
CREATE TABLE IF NOT EXISTS email_bounces (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID REFERENCES mailboxes(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  provider_message_id TEXT,
  bounce_type TEXT NOT NULL CHECK (bounce_type IN ('hard', 'soft', 'complaint')),
  bounce_reason TEXT,
  bounced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  email_id UUID REFERENCES emails(id) ON DELETE SET NULL,
  campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
  campaign_recipient_id UUID REFERENCES campaign_recipients(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_email_unsubscribes_user_id ON email_unsubscribes(user_id);
CREATE INDEX IF NOT EXISTS idx_email_unsubscribes_email ON email_unsubscribes(email);
CREATE INDEX IF NOT EXISTS idx_email_unsubscribes_token ON email_unsubscribes(unsubscribe_token);
CREATE INDEX IF NOT EXISTS idx_email_bounces_user_id ON email_bounces(user_id);
CREATE INDEX IF NOT EXISTS idx_email_bounces_email ON email_bounces(email);
CREATE INDEX IF NOT EXISTS idx_email_bounces_type ON email_bounces(bounce_type);

-- RLS Policies
ALTER TABLE email_unsubscribes ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_bounces ENABLE ROW LEVEL SECURITY;

-- Unsubscribes policies
DROP POLICY IF EXISTS "Users can view their own unsubscribes" ON email_unsubscribes;
CREATE POLICY "Users can view their own unsubscribes"
  ON email_unsubscribes FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Public can unsubscribe via token" ON email_unsubscribes;
CREATE POLICY "Public can unsubscribe via token"
  ON email_unsubscribes FOR INSERT
  WITH CHECK (true); -- Allow public unsubscribes

DROP POLICY IF EXISTS "Users can insert their own unsubscribes" ON email_unsubscribes;
CREATE POLICY "Users can insert their own unsubscribes"
  ON email_unsubscribes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Bounces policies
DROP POLICY IF EXISTS "Users can view their own bounces" ON email_bounces;
CREATE POLICY "Users can view their own bounces"
  ON email_bounces FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can insert bounces" ON email_bounces;
CREATE POLICY "Service role can insert bounces"
  ON email_bounces FOR INSERT
  WITH CHECK (true); -- Service role can insert via service key

-- Function to check if email is unsubscribed
CREATE OR REPLACE FUNCTION is_email_unsubscribed(p_user_id UUID, p_email TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM email_unsubscribes
    WHERE user_id = p_user_id AND email = LOWER(p_email)
  );
$$ LANGUAGE sql STABLE;

-- Function to check if email has bounced
CREATE OR REPLACE FUNCTION has_email_bounced(p_user_id UUID, p_email TEXT)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM email_bounces
    WHERE user_id = p_user_id 
    AND email = LOWER(p_email)
    AND bounce_type = 'hard' -- Only hard bounces prevent sending
  );
$$ LANGUAGE sql STABLE;



