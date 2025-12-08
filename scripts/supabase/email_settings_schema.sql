-- ============================================================================
-- Email Settings Schema
-- ============================================================================
-- Global email settings for branding and compliance
-- ============================================================================

-- Email Settings Table (per-user or global)
CREATE TABLE IF NOT EXISTS email_settings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Branding
  from_name TEXT NOT NULL DEFAULT 'LeadMap',
  reply_to TEXT,
  default_footer_html TEXT,
  
  -- Compliance
  unsubscribe_footer_html TEXT, -- Auto-appended to campaign emails
  physical_address TEXT, -- Required for CAN-SPAM compliance
  
  -- Provider defaults (for transactional emails)
  transactional_provider TEXT CHECK (transactional_provider IN ('resend', 'sendgrid', 'mailgun', 'smtp')),
  transactional_from_email TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- One settings record per user (or NULL for global defaults)
  UNIQUE(user_id)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_email_settings_user_id ON email_settings(user_id);

-- Insert default global settings (user_id = NULL)
INSERT INTO email_settings (user_id, from_name, reply_to, default_footer_html, unsubscribe_footer_html)
VALUES (
  NULL,
  'LeadMap',
  NULL,
  '<p style="color: #666; font-size: 12px; margin-top: 20px;">© 2024 LeadMap. All rights reserved.</p>',
  '<p style="color: #666; font-size: 11px; margin-top: 20px; border-top: 1px solid #eee; padding-top: 10px;">
    You received this email because you are subscribed to our mailing list.
    <a href="{{unsubscribe_url}}" style="color: #666;">Unsubscribe</a>
  </p>'
)
ON CONFLICT (user_id) DO NOTHING;

-- Mailbox Rate Limits Table
-- Tracks per-mailbox and per-domain sending limits
CREATE TABLE IF NOT EXISTS mailbox_rate_limits (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  mailbox_id UUID REFERENCES mailboxes(id) ON DELETE CASCADE NOT NULL,
  
  -- Per-mailbox limits
  hourly_limit INTEGER DEFAULT 100,
  daily_limit INTEGER DEFAULT 1000,
  
  -- Per-domain limits (for shared domains)
  domain_hourly_limit INTEGER DEFAULT 500,
  domain_daily_limit INTEGER DEFAULT 5000,
  
  -- Current usage tracking
  current_hourly_count INTEGER DEFAULT 0,
  current_daily_count INTEGER DEFAULT 0,
  last_reset_at TIMESTAMPTZ DEFAULT NOW(),
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(mailbox_id)
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_mailbox_rate_limits_mailbox_id ON mailbox_rate_limits(mailbox_id);

-- Email Queue Table
-- For background processing of emails
CREATE TABLE IF NOT EXISTS email_queue (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  mailbox_id UUID REFERENCES mailboxes(id) ON DELETE CASCADE NOT NULL,
  
  -- Email content
  to_email TEXT NOT NULL,
  subject TEXT NOT NULL,
  html TEXT NOT NULL,
  from_name TEXT,
  from_email TEXT,
  
  -- Queue metadata
  type TEXT NOT NULL CHECK (type IN ('transactional', 'campaign')) DEFAULT 'transactional',
  priority INTEGER DEFAULT 5, -- 1-10, higher = more urgent
  status TEXT NOT NULL CHECK (status IN ('queued', 'processing', 'sent', 'failed', 'cancelled')) DEFAULT 'queued',
  
  -- Scheduling
  scheduled_at TIMESTAMPTZ,
  processed_at TIMESTAMPTZ,
  
  -- Retry logic
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  last_error TEXT,
  
  -- Campaign tracking
  campaign_id UUID,
  campaign_recipient_id UUID,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for queue processing
CREATE INDEX IF NOT EXISTS idx_email_queue_status ON email_queue(status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_email_queue_user_id ON email_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_email_queue_mailbox_id ON email_queue(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_email_queue_type ON email_queue(type);

-- Mailbox Health Checks Table
-- Tracks connection health and last check time
CREATE TABLE IF NOT EXISTS mailbox_health_checks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  mailbox_id UUID REFERENCES mailboxes(id) ON DELETE CASCADE NOT NULL,
  
  -- Health status
  healthy BOOLEAN DEFAULT TRUE,
  status TEXT NOT NULL CHECK (status IN ('healthy', 'degraded', 'unhealthy', 'disconnected')) DEFAULT 'healthy',
  
  -- Check details
  last_checked_at TIMESTAMPTZ DEFAULT NOW(),
  last_successful_check_at TIMESTAMPTZ,
  error_message TEXT,
  
  -- Connection details
  provider_response_time_ms INTEGER,
  token_valid BOOLEAN,
  smtp_connection_valid BOOLEAN,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(mailbox_id)
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_mailbox_health_checks_mailbox_id ON mailbox_health_checks(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_mailbox_health_checks_status ON mailbox_health_checks(status);

-- Function to reset hourly/daily counts
CREATE OR REPLACE FUNCTION reset_mailbox_rate_limits()
RETURNS void AS $$
BEGIN
  -- Reset hourly counts (every hour)
  UPDATE mailbox_rate_limits
  SET current_hourly_count = 0,
      last_reset_at = NOW()
  WHERE last_reset_at < NOW() - INTERVAL '1 hour';
  
  -- Reset daily counts (every day)
  UPDATE mailbox_rate_limits
  SET current_daily_count = 0
  WHERE last_reset_at < NOW() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql;

