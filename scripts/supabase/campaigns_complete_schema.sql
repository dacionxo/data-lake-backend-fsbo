-- ============================================================================
-- Complete Campaigns & Sequences Schema
-- ============================================================================
-- Full implementation with all features: throttling, warmup, state machine, etc.
-- ============================================================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS campaign_reports CASCADE;
DROP TABLE IF EXISTS campaign_recipients CASCADE;
DROP TABLE IF EXISTS campaign_steps CASCADE;
DROP TABLE IF EXISTS campaigns CASCADE;

-- ============================================================================
-- CAMPAIGNS TABLE (Enhanced)
-- ============================================================================
CREATE TABLE campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mailbox_id UUID NOT NULL REFERENCES mailboxes(id) ON DELETE CASCADE,
  
  -- Basic info
  name TEXT NOT NULL,
  description TEXT,
  
  -- State machine
  status TEXT NOT NULL CHECK (status IN ('draft', 'scheduled', 'running', 'paused', 'completed', 'cancelled')) DEFAULT 'draft',
  
  -- Strategy
  send_strategy TEXT NOT NULL CHECK (send_strategy IN ('single', 'sequence')) DEFAULT 'single',
  
  -- Scheduling
  start_at TIMESTAMPTZ,
  timezone TEXT DEFAULT 'UTC',
  send_window_start TIME DEFAULT '09:00:00', -- e.g., 9 AM
  send_window_end TIME DEFAULT '17:00:00',   -- e.g., 5 PM
  send_days_of_week INTEGER[] DEFAULT ARRAY[1,2,3,4,5], -- Monday-Friday (1=Monday)
  
  -- Throttling & caps
  daily_cap INTEGER, -- Max emails per day for this campaign
  hourly_cap INTEGER, -- Max emails per hour for this campaign
  total_cap INTEGER, -- Max total emails for this campaign
  
  -- Warmup/ramp-up
  warmup_enabled BOOLEAN DEFAULT FALSE,
  warmup_schedule JSONB, -- { "day_1": 10, "day_2": 20, "day_3": 50, ... }
  current_warmup_day INTEGER DEFAULT 0,
  
  -- Segment/filtering
  segment_criteria JSONB, -- Filter criteria for recipients
  recipient_list_ids UUID[], -- Array of list IDs
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  paused_at TIMESTAMPTZ,
  resumed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

-- ============================================================================
-- CAMPAIGN_STEPS TABLE (Enhanced)
-- ============================================================================
CREATE TABLE campaign_steps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  
  step_number INTEGER NOT NULL, -- 1, 2, 3...
  delay_hours INTEGER NOT NULL DEFAULT 0, -- Hours after previous step or start_at
  delay_days INTEGER DEFAULT 0, -- Days (alternative to hours)
  
  -- Email content
  template_id UUID REFERENCES email_templates(id),
  subject TEXT NOT NULL,
  html TEXT NOT NULL,
  plain_text TEXT, -- Optional plain text version
  
  -- Behavior
  stop_on_reply BOOLEAN DEFAULT TRUE,
  stop_on_bounce BOOLEAN DEFAULT TRUE,
  stop_on_unsubscribe BOOLEAN DEFAULT TRUE,
  
  -- Scheduling
  send_at TIMESTAMPTZ, -- Specific send time (overrides delay)
  send_window_start TIME, -- Override campaign send window
  send_window_end TIME,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(campaign_id, step_number)
);

-- ============================================================================
-- CAMPAIGN_RECIPIENTS TABLE (Enhanced)
-- ============================================================================
CREATE TABLE campaign_recipients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  
  -- Link to existing CRM / listing
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  listing_id TEXT REFERENCES listings(listing_id) ON DELETE SET NULL,
  
  -- Recipient info
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  company TEXT,
  metadata JSONB, -- Additional custom fields
  
  -- State tracking
  status TEXT NOT NULL CHECK (
    status IN ('pending', 'queued', 'in_progress', 'completed', 'stopped', 'bounced', 'unsubscribed', 'failed')
  ) DEFAULT 'pending',
  
  -- Sequence tracking
  current_step_number INTEGER DEFAULT 0, -- Which step they're on
  last_step_sent INTEGER, -- Last step number that was sent
  last_sent_at TIMESTAMPTZ,
  next_send_at TIMESTAMPTZ, -- When to send next step
  
  -- Reply detection
  replied BOOLEAN DEFAULT FALSE,
  replied_at TIMESTAMPTZ,
  reply_message_id TEXT, -- Message ID of the reply
  
  -- Bounce/unsubscribe tracking
  bounced BOOLEAN DEFAULT FALSE,
  bounced_at TIMESTAMPTZ,
  unsubscribed BOOLEAN DEFAULT FALSE,
  unsubscribed_at TIMESTAMPTZ,
  
  -- Error tracking
  error_count INTEGER DEFAULT 0,
  last_error TEXT,
  
  -- Dedupe tracking
  enrolled_at TIMESTAMPTZ DEFAULT NOW(),
  dedupe_hash TEXT, -- Hash of (email, campaign_type) for deduplication
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Prevent duplicate enrollments
  UNIQUE(campaign_id, email)
);

-- ============================================================================
-- CAMPAIGN_REPORTS TABLE
-- ============================================================================
-- Aggregated stats per campaign
CREATE TABLE campaign_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES campaigns(id) ON DELETE CASCADE,
  
  -- Date for daily reports
  report_date DATE NOT NULL,
  
  -- Aggregated stats
  total_recipients INTEGER DEFAULT 0,
  emails_sent INTEGER DEFAULT 0,
  emails_delivered INTEGER DEFAULT 0,
  emails_opened INTEGER DEFAULT 0,
  emails_clicked INTEGER DEFAULT 0,
  emails_replied INTEGER DEFAULT 0,
  emails_bounced INTEGER DEFAULT 0,
  emails_unsubscribed INTEGER DEFAULT 0,
  emails_failed INTEGER DEFAULT 0,
  
  -- Rates (calculated)
  delivery_rate DECIMAL(5,2), -- delivered / sent
  open_rate DECIMAL(5,2), -- opened / delivered
  click_rate DECIMAL(5,2), -- clicked / delivered
  reply_rate DECIMAL(5,2), -- replied / delivered
  bounce_rate DECIMAL(5,2), -- bounced / sent
  unsubscribe_rate DECIMAL(5,2), -- unsubscribed / delivered
  
  -- Performance metrics
  avg_time_to_open_minutes INTEGER, -- Average time from send to open
  avg_time_to_click_minutes INTEGER, -- Average time from send to click
  avg_time_to_reply_minutes INTEGER, -- Average time from send to reply
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(campaign_id, report_date)
);

-- ============================================================================
-- UPDATE EMAILS TABLE
-- ============================================================================
ALTER TABLE emails 
  ADD COLUMN IF NOT EXISTS campaign_id UUID REFERENCES campaigns(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS campaign_step_id UUID REFERENCES campaign_steps(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS campaign_recipient_id UUID REFERENCES campaign_recipients(id) ON DELETE SET NULL;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_campaigns_user_id ON campaigns(user_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_mailbox_id ON campaigns(mailbox_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns(status);
CREATE INDEX IF NOT EXISTS idx_campaigns_start_at ON campaigns(start_at);
CREATE INDEX IF NOT EXISTS idx_campaigns_warmup ON campaigns(warmup_enabled, current_warmup_day);

CREATE INDEX IF NOT EXISTS idx_campaign_steps_campaign_id ON campaign_steps(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_steps_step_number ON campaign_steps(campaign_id, step_number);
CREATE INDEX IF NOT EXISTS idx_campaign_steps_send_at ON campaign_steps(send_at);

CREATE INDEX IF NOT EXISTS idx_campaign_recipients_campaign_id ON campaign_recipients(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_status ON campaign_recipients(status);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_email ON campaign_recipients(email);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_next_send_at ON campaign_recipients(next_send_at) WHERE status IN ('pending', 'queued', 'in_progress');
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_dedupe_hash ON campaign_recipients(dedupe_hash);
CREATE INDEX IF NOT EXISTS idx_campaign_recipients_replied ON campaign_recipients(replied) WHERE replied = TRUE;

CREATE INDEX IF NOT EXISTS idx_campaign_reports_campaign_id ON campaign_reports(campaign_id);
CREATE INDEX IF NOT EXISTS idx_campaign_reports_date ON campaign_reports(report_date);

CREATE INDEX IF NOT EXISTS idx_emails_campaign_id ON emails(campaign_id);
CREATE INDEX IF NOT EXISTS idx_emails_campaign_step_id ON emails(campaign_step_id);
CREATE INDEX IF NOT EXISTS idx_emails_campaign_recipient_id ON emails(campaign_recipient_id);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to check for duplicate enrollments
CREATE OR REPLACE FUNCTION check_campaign_dedupe(
  p_campaign_id UUID,
  p_email TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  SELECT EXISTS(
    SELECT 1 FROM campaign_recipients
    WHERE campaign_id = p_campaign_id
      AND email = LOWER(p_email)
      AND status NOT IN ('failed', 'cancelled')
  ) INTO v_exists;
  
  RETURN NOT v_exists; -- Returns TRUE if NOT duplicate
END;
$$ LANGUAGE plpgsql;

-- Function to update campaign report
CREATE OR REPLACE FUNCTION update_campaign_report(
  p_campaign_id UUID,
  p_report_date DATE DEFAULT CURRENT_DATE
)
RETURNS void AS $$
DECLARE
  v_stats RECORD;
BEGIN
  -- Calculate stats for the day
  SELECT 
    COUNT(DISTINCT cr.id) as total_recipients,
    COUNT(DISTINCT e.id) FILTER (WHERE e.status = 'sent') as emails_sent,
    COUNT(DISTINCT e.id) FILTER (WHERE e.status = 'sent' AND e.sent_at IS NOT NULL) as emails_delivered,
    COUNT(DISTINCT e.id) FILTER (WHERE e.opened_at IS NOT NULL) as emails_opened,
    COUNT(DISTINCT e.id) FILTER (WHERE e.clicked_at IS NOT NULL) as emails_clicked,
    COUNT(DISTINCT cr.id) FILTER (WHERE cr.replied = TRUE) as emails_replied,
    COUNT(DISTINCT cr.id) FILTER (WHERE cr.bounced = TRUE) as emails_bounced,
    COUNT(DISTINCT cr.id) FILTER (WHERE cr.unsubscribed = TRUE) as emails_unsubscribed,
    COUNT(DISTINCT e.id) FILTER (WHERE e.status = 'failed') as emails_failed
  INTO v_stats
  FROM campaign_recipients cr
  LEFT JOIN emails e ON e.campaign_recipient_id = cr.id
  WHERE cr.campaign_id = p_campaign_id
    AND DATE(COALESCE(e.sent_at, cr.created_at)) = p_report_date;

  -- Upsert report
  INSERT INTO campaign_reports (
    campaign_id,
    report_date,
    total_recipients,
    emails_sent,
    emails_delivered,
    emails_opened,
    emails_clicked,
    emails_replied,
    emails_bounced,
    emails_unsubscribed,
    emails_failed,
    delivery_rate,
    open_rate,
    click_rate,
    reply_rate,
    bounce_rate,
    unsubscribe_rate
  )
  VALUES (
    p_campaign_id,
    p_report_date,
    COALESCE(v_stats.total_recipients, 0),
    COALESCE(v_stats.emails_sent, 0),
    COALESCE(v_stats.emails_delivered, 0),
    COALESCE(v_stats.emails_opened, 0),
    COALESCE(v_stats.emails_clicked, 0),
    COALESCE(v_stats.emails_replied, 0),
    COALESCE(v_stats.emails_bounced, 0),
    COALESCE(v_stats.emails_unsubscribed, 0),
    COALESCE(v_stats.emails_failed, 0),
    CASE WHEN v_stats.emails_sent > 0 
      THEN (v_stats.emails_delivered::DECIMAL / v_stats.emails_sent * 100) 
      ELSE 0 END,
    CASE WHEN v_stats.emails_delivered > 0 
      THEN (v_stats.emails_opened::DECIMAL / v_stats.emails_delivered * 100) 
      ELSE 0 END,
    CASE WHEN v_stats.emails_delivered > 0 
      THEN (v_stats.emails_clicked::DECIMAL / v_stats.emails_delivered * 100) 
      ELSE 0 END,
    CASE WHEN v_stats.emails_delivered > 0 
      THEN (v_stats.emails_replied::DECIMAL / v_stats.emails_delivered * 100) 
      ELSE 0 END,
    CASE WHEN v_stats.emails_sent > 0 
      THEN (v_stats.emails_bounced::DECIMAL / v_stats.emails_sent * 100) 
      ELSE 0 END,
    CASE WHEN v_stats.emails_delivered > 0 
      THEN (v_stats.emails_unsubscribed::DECIMAL / v_stats.emails_delivered * 100) 
      ELSE 0 END
  )
  ON CONFLICT (campaign_id, report_date) 
  DO UPDATE SET
    total_recipients = EXCLUDED.total_recipients,
    emails_sent = EXCLUDED.emails_sent,
    emails_delivered = EXCLUDED.emails_delivered,
    emails_opened = EXCLUDED.emails_opened,
    emails_clicked = EXCLUDED.emails_clicked,
    emails_replied = EXCLUDED.emails_replied,
    emails_bounced = EXCLUDED.emails_bounced,
    emails_unsubscribed = EXCLUDED.emails_unsubscribed,
    emails_failed = EXCLUDED.emails_failed,
    delivery_rate = EXCLUDED.delivery_rate,
    open_rate = EXCLUDED.open_rate,
    click_rate = EXCLUDED.click_rate,
    reply_rate = EXCLUDED.reply_rate,
    bounce_rate = EXCLUDED.bounce_rate,
    unsubscribe_rate = EXCLUDED.unsubscribe_rate,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to check warmup limits
CREATE OR REPLACE FUNCTION get_warmup_limit(
  p_campaign_id UUID
)
RETURNS INTEGER AS $$
DECLARE
  v_campaign RECORD;
  v_limit INTEGER;
BEGIN
  SELECT warmup_enabled, current_warmup_day, warmup_schedule
  INTO v_campaign
  FROM campaigns
  WHERE id = p_campaign_id;

  IF NOT v_campaign.warmup_enabled THEN
    RETURN NULL; -- No limit
  END IF;

  -- Get limit for current warmup day
  IF v_campaign.warmup_schedule IS NOT NULL THEN
    v_limit := (v_campaign.warmup_schedule->>('day_' || v_campaign.current_warmup_day))::INTEGER;
  END IF;

  RETURN COALESCE(v_limit, 0);
END;
$$ LANGUAGE plpgsql;

