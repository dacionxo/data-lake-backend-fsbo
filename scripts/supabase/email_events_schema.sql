-- ============================================================================
-- Unified Email Events Schema
-- ============================================================================
-- Comprehensive email tracking, analytics & logging system
-- Tracks all email events: sent, delivered, opened, clicked, replied, bounced, complaint
-- ============================================================================

-- ============================================================================
-- UNIFIED EMAIL_EVENTS TABLE
-- ============================================================================
-- Single table for all email events (replaces/enhances email_opens, email_clicks)
CREATE TABLE IF NOT EXISTS email_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID REFERENCES mailboxes(id) ON DELETE SET NULL,
  
  -- Event identification
  event_type TEXT NOT NULL CHECK (event_type IN (
    'sent',           -- Email was sent (queued/sending -> sent)
    'delivered',      -- Email was delivered (from provider webhook)
    'opened',         -- Email was opened (tracking pixel)
    'clicked',        -- Link in email was clicked
    'replied',        -- Recipient replied to email
    'bounced',        -- Email bounced (hard or soft)
    'complaint',      -- Spam complaint filed
    'failed',         -- Email failed to send
    'deferred',       -- Email delivery deferred
    'dropped'         -- Email was dropped by provider
  )),
  
  -- Email references (can link to emails table or email_threads/email_messages)
  email_id UUID REFERENCES emails(id) ON DELETE CASCADE,
  email_message_id UUID REFERENCES email_messages(id) ON DELETE CASCADE,
  
  -- Campaign references
  campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
  campaign_recipient_id UUID REFERENCES campaign_recipients(id) ON DELETE SET NULL,
  campaign_step_id UUID REFERENCES campaign_steps(id) ON DELETE SET NULL,
  
  -- Recipient information
  recipient_email TEXT NOT NULL, -- Normalized email address
  contact_id UUID, -- Link to contacts table if matched
  
  -- Event metadata
  event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  provider_message_id TEXT, -- Provider's message ID (for delivered/bounced events)
  
  -- Event-specific data
  metadata JSONB DEFAULT '{}'::jsonb, -- Flexible storage for event-specific data
  -- Examples:
  -- opened: { user_agent, ip_address, device_type, location }
  -- clicked: { url, user_agent, ip_address }
  -- bounced: { bounce_type: 'hard'|'soft', reason, diagnostic_code }
  -- complaint: { feedback_type, feedback_date }
  -- failed: { error_message, error_code }
  
  -- IP and user agent tracking
  ip_address TEXT,
  user_agent TEXT,
  
  -- For click events: the URL that was clicked
  clicked_url TEXT,
  
  -- For bounce events: bounce classification
  bounce_type TEXT CHECK (bounce_type IN ('hard', 'soft', 'transient', 'permanent')),
  bounce_reason TEXT,
  bounce_subtype TEXT, -- e.g., '550', '554', '421'
  
  -- For reply events: reference to the reply message
  reply_message_id UUID,
  
  -- For complaint events: complaint details
  complaint_type TEXT, -- 'spam', 'abuse', etc.
  complaint_feedback TEXT,
  
  -- Deduplication
  event_hash TEXT, -- Hash of event to prevent duplicates
  -- Format: MD5(event_type || email_id || recipient_email || event_timestamp::date)
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_email_events_user_id ON email_events(user_id);
CREATE INDEX IF NOT EXISTS idx_email_events_mailbox_id ON email_events(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_email_events_email_id ON email_events(email_id);
CREATE INDEX IF NOT EXISTS idx_email_events_email_message_id ON email_events(email_message_id);
CREATE INDEX IF NOT EXISTS idx_email_events_campaign_id ON email_events(campaign_id);
CREATE INDEX IF NOT EXISTS idx_email_events_campaign_recipient_id ON email_events(campaign_recipient_id);
CREATE INDEX IF NOT EXISTS idx_email_events_recipient_email ON email_events(recipient_email);
CREATE INDEX IF NOT EXISTS idx_email_events_contact_id ON email_events(contact_id);
CREATE INDEX IF NOT EXISTS idx_email_events_event_type ON email_events(event_type);
CREATE INDEX IF NOT EXISTS idx_email_events_event_timestamp ON email_events(event_timestamp);
CREATE INDEX IF NOT EXISTS idx_email_events_event_hash ON email_events(event_hash);
CREATE INDEX IF NOT EXISTS idx_email_events_provider_message_id ON email_events(provider_message_id);

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_email_events_user_timestamp ON email_events(user_id, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_email_events_mailbox_type_timestamp ON email_events(mailbox_id, event_type, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_email_events_campaign_type_timestamp ON email_events(campaign_id, event_type, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_email_events_recipient_type_timestamp ON email_events(recipient_email, event_type, event_timestamp DESC);

-- ============================================================================
-- PER-RECIPIENT ENGAGEMENT PROFILE VIEW
-- ============================================================================
-- Aggregated view showing engagement metrics per recipient email
CREATE OR REPLACE VIEW recipient_engagement_profiles AS
SELECT 
  user_id,
  recipient_email,
  contact_id,
  -- Counts
  COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'sent') as total_emails_sent,
  COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'delivered') as total_emails_delivered,
  COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'opened') as total_emails_opened,
  COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'clicked') as total_emails_clicked,
  COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'replied') as total_emails_replied,
  COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'bounced') as total_emails_bounced,
  COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'complaint') as total_complaints,
  -- Open/click counts (not unique emails)
  COUNT(*) FILTER (WHERE event_type = 'opened') as total_opens,
  COUNT(*) FILTER (WHERE event_type = 'clicked') as total_clicks,
  -- Rates
  CASE 
    WHEN COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'delivered') > 0
    THEN (COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'opened')::DECIMAL / 
          COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'delivered') * 100)
    ELSE 0 
  END as open_rate,
  CASE 
    WHEN COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'delivered') > 0
    THEN (COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'clicked')::DECIMAL / 
          COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'delivered') * 100)
    ELSE 0 
  END as click_rate,
  CASE 
    WHEN COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'delivered') > 0
    THEN (COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'replied')::DECIMAL / 
          COUNT(DISTINCT email_id) FILTER (WHERE event_type = 'delivered') * 100)
    ELSE 0 
  END as reply_rate,
  -- Timestamps
  MIN(event_timestamp) FILTER (WHERE event_type = 'sent') as first_contact_at,
  MAX(event_timestamp) FILTER (WHERE event_type = 'sent') as last_contact_at,
  MIN(event_timestamp) FILTER (WHERE event_type = 'opened') as first_opened_at,
  MAX(event_timestamp) FILTER (WHERE event_type = 'opened') as last_opened_at,
  MIN(event_timestamp) FILTER (WHERE event_type = 'clicked') as first_clicked_at,
  MAX(event_timestamp) FILTER (WHERE event_type = 'clicked') as last_clicked_at,
  MIN(event_timestamp) FILTER (WHERE event_type = 'replied') as first_replied_at,
  MAX(event_timestamp) FILTER (WHERE event_type = 'replied') as last_replied_at
FROM email_events
GROUP BY user_id, recipient_email, contact_id;

-- ============================================================================
-- EMAIL FAILURE LOGS TABLE
-- ============================================================================
-- Dedicated table for tracking email failures with alerting support
CREATE TABLE IF NOT EXISTS email_failure_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID REFERENCES mailboxes(id) ON DELETE SET NULL,
  email_id UUID REFERENCES emails(id) ON DELETE CASCADE,
  
  -- Failure details
  failure_type TEXT NOT NULL CHECK (failure_type IN (
    'send_failed',        -- Failed to send email
    'provider_error',     -- Provider API error
    'rate_limit_exceeded', -- Rate limit hit
    'authentication_error', -- Auth token expired/invalid
    'webhook_error',      -- Webhook processing failed
    'cron_job_failed',    -- Cron job execution failed
    'database_error',     -- Database operation failed
    'unknown_error'       -- Other errors
  )),
  
  error_message TEXT NOT NULL,
  error_code TEXT,
  error_stack TEXT,
  
  -- Context
  context JSONB DEFAULT '{}'::jsonb, -- Additional context (request data, config, etc.)
  
  -- Alerting
  alert_sent BOOLEAN DEFAULT FALSE,
  alert_sent_at TIMESTAMPTZ,
  
  -- Resolution
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolution_notes TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_failure_logs_user_id ON email_failure_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_email_failure_logs_mailbox_id ON email_failure_logs(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_email_failure_logs_email_id ON email_failure_logs(email_id);
CREATE INDEX IF NOT EXISTS idx_email_failure_logs_failure_type ON email_failure_logs(failure_type);
CREATE INDEX IF NOT EXISTS idx_email_failure_logs_alert_sent ON email_failure_logs(alert_sent);
CREATE INDEX IF NOT EXISTS idx_email_failure_logs_resolved ON email_failure_logs(resolved);
CREATE INDEX IF NOT EXISTS idx_email_failure_logs_created_at ON email_failure_logs(created_at DESC);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to generate event hash for deduplication
CREATE OR REPLACE FUNCTION generate_event_hash(
  p_event_type TEXT,
  p_email_id UUID,
  p_recipient_email TEXT,
  p_event_date DATE DEFAULT CURRENT_DATE
)
RETURNS TEXT AS $$
BEGIN
  RETURN MD5(
    COALESCE(p_event_type, '') || '||' ||
    COALESCE(p_email_id::TEXT, '') || '||' ||
    LOWER(COALESCE(p_recipient_email, '')) || '||' ||
    p_event_date::TEXT
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to record email event with deduplication
CREATE OR REPLACE FUNCTION record_email_event(
  p_user_id UUID,
  p_event_type TEXT,
  p_recipient_email TEXT,
  p_email_id UUID DEFAULT NULL,
  p_email_message_id UUID DEFAULT NULL,
  p_mailbox_id UUID DEFAULT NULL,
  p_campaign_id UUID DEFAULT NULL,
  p_campaign_recipient_id UUID DEFAULT NULL,
  p_campaign_step_id UUID DEFAULT NULL,
  p_contact_id UUID DEFAULT NULL,
  p_event_timestamp TIMESTAMPTZ DEFAULT NOW(),
  p_provider_message_id TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'::jsonb,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL,
  p_clicked_url TEXT DEFAULT NULL,
  p_bounce_type TEXT DEFAULT NULL,
  p_bounce_reason TEXT DEFAULT NULL,
  p_bounce_subtype TEXT DEFAULT NULL,
  p_reply_message_id UUID DEFAULT NULL,
  p_complaint_type TEXT DEFAULT NULL,
  p_complaint_feedback TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_event_id UUID;
  v_event_hash TEXT;
  v_existing_id UUID;
BEGIN
  -- Generate deduplication hash
  v_event_hash := generate_event_hash(
    p_event_type,
    p_email_id,
    p_recipient_email,
    p_event_timestamp::DATE
  );
  
  -- Check for duplicate (same event type, email, recipient, on same day)
  -- For opens/clicks, allow multiple events per day
  IF p_event_type NOT IN ('opened', 'clicked') THEN
    SELECT id INTO v_existing_id
    FROM email_events
    WHERE event_hash = v_event_hash
      AND event_type = p_event_type
    LIMIT 1;
    
    IF v_existing_id IS NOT NULL THEN
      -- Update existing event
      UPDATE email_events
      SET 
        event_timestamp = p_event_timestamp,
        metadata = p_metadata,
        ip_address = COALESCE(p_ip_address, ip_address),
        user_agent = COALESCE(p_user_agent, user_agent),
        clicked_url = COALESCE(p_clicked_url, clicked_url),
        bounce_type = COALESCE(p_bounce_type, bounce_type),
        bounce_reason = COALESCE(p_bounce_reason, bounce_reason),
        bounce_subtype = COALESCE(p_bounce_subtype, bounce_subtype),
        reply_message_id = COALESCE(p_reply_message_id, reply_message_id),
        complaint_type = COALESCE(p_complaint_type, complaint_type),
        complaint_feedback = COALESCE(p_complaint_feedback, complaint_feedback)
      WHERE id = v_existing_id;
      
      RETURN v_existing_id;
    END IF;
  END IF;
  
  -- Insert new event
  INSERT INTO email_events (
    user_id,
    mailbox_id,
    event_type,
    email_id,
    email_message_id,
    campaign_id,
    campaign_recipient_id,
    campaign_step_id,
    recipient_email,
    contact_id,
    event_timestamp,
    provider_message_id,
    metadata,
    ip_address,
    user_agent,
    clicked_url,
    bounce_type,
    bounce_reason,
    bounce_subtype,
    reply_message_id,
    complaint_type,
    complaint_feedback,
    event_hash
  )
  VALUES (
    p_user_id,
    p_mailbox_id,
    p_event_type,
    p_email_id,
    p_email_message_id,
    p_campaign_id,
    p_campaign_recipient_id,
    p_campaign_step_id,
    LOWER(p_recipient_email),
    p_contact_id,
    p_event_timestamp,
    p_provider_message_id,
    p_metadata,
    p_ip_address,
    p_user_agent,
    p_clicked_url,
    p_bounce_type,
    p_bounce_reason,
    p_bounce_subtype,
    p_reply_message_id,
    p_complaint_type,
    p_complaint_feedback,
    v_event_hash
  )
  RETURNING id INTO v_event_id;
  
  RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get recipient engagement summary
CREATE OR REPLACE FUNCTION get_recipient_engagement(
  p_user_id UUID,
  p_recipient_email TEXT
)
RETURNS TABLE (
  total_emails_sent BIGINT,
  total_emails_delivered BIGINT,
  total_emails_opened BIGINT,
  total_emails_clicked BIGINT,
  total_emails_replied BIGINT,
  total_opens BIGINT,
  total_clicks BIGINT,
  open_rate DECIMAL,
  click_rate DECIMAL,
  reply_rate DECIMAL,
  first_contact_at TIMESTAMPTZ,
  last_contact_at TIMESTAMPTZ,
  last_opened_at TIMESTAMPTZ,
  last_clicked_at TIMESTAMPTZ,
  last_replied_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT * FROM recipient_engagement_profiles
  WHERE user_id = p_user_id
    AND recipient_email = LOWER(p_recipient_email);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- MIGRATION FROM OLD TABLES (BACKWARDS COMPATIBLE)
-- ============================================================================
-- Migrate existing email_opens to email_events
INSERT INTO email_events (
  user_id,
  mailbox_id,
  event_type,
  email_id,
  campaign_recipient_id,
  campaign_id,
  recipient_email,
  event_timestamp,
  ip_address,
  user_agent,
  metadata,
  event_hash
)
SELECT DISTINCT ON (eo.id)
  COALESCE(e.user_id, c.user_id) as user_id,
  COALESCE(e.mailbox_id, c.mailbox_id) as mailbox_id,
  'opened' as event_type,
  eo.email_id,
  eo.campaign_recipient_id,
  eo.campaign_id,
  COALESCE(e.to_email, cr.email, 'unknown') as recipient_email,
  eo.opened_at as event_timestamp,
  eo.ip_address,
  eo.user_agent,
  jsonb_build_object('source', 'migration') as metadata,
  generate_event_hash('opened', eo.email_id, COALESCE(e.to_email, cr.email, 'unknown'), eo.opened_at::DATE)
FROM email_opens eo
LEFT JOIN emails e ON e.id = eo.email_id
LEFT JOIN campaign_recipients cr ON cr.id = eo.campaign_recipient_id
LEFT JOIN campaigns c ON c.id = eo.campaign_id
WHERE NOT EXISTS (
  SELECT 1 FROM email_events ee
  WHERE ee.event_type = 'opened'
    AND ee.email_id = eo.email_id
    AND ee.campaign_recipient_id = eo.campaign_recipient_id
    AND ee.event_timestamp::DATE = eo.opened_at::DATE
)
ON CONFLICT DO NOTHING;

-- Migrate existing email_clicks to email_events
INSERT INTO email_events (
  user_id,
  mailbox_id,
  event_type,
  email_id,
  campaign_recipient_id,
  campaign_id,
  recipient_email,
  event_timestamp,
  ip_address,
  user_agent,
  clicked_url,
  metadata,
  event_hash
)
SELECT DISTINCT ON (ec.id)
  COALESCE(e.user_id, c.user_id) as user_id,
  COALESCE(e.mailbox_id, c.mailbox_id) as mailbox_id,
  'clicked' as event_type,
  ec.email_id,
  ec.campaign_recipient_id,
  ec.campaign_id,
  COALESCE(e.to_email, cr.email, 'unknown') as recipient_email,
  ec.clicked_at as event_timestamp,
  ec.ip_address,
  ec.user_agent,
  ec.clicked_url,
  jsonb_build_object('source', 'migration') as metadata,
  generate_event_hash('clicked', ec.email_id, COALESCE(e.to_email, cr.email, 'unknown'), ec.clicked_at::DATE)
FROM email_clicks ec
LEFT JOIN emails e ON e.id = ec.email_id
LEFT JOIN campaign_recipients cr ON cr.id = ec.campaign_recipient_id
LEFT JOIN campaigns c ON c.id = ec.campaign_id
WHERE NOT EXISTS (
  SELECT 1 FROM email_events ee
  WHERE ee.event_type = 'clicked'
    AND ee.email_id = ec.email_id
    AND ee.campaign_recipient_id = ec.campaign_recipient_id
    AND ee.clicked_url = ec.clicked_url
    AND ee.event_timestamp::DATE = ec.clicked_at::DATE
)
ON CONFLICT DO NOTHING;

