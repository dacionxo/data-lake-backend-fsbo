-- ============================================================================
-- SMS System Schema for LeadMap
-- GoHighLevel-class SMS functionality with Twilio Conversations API
-- ============================================================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS sms_events CASCADE;
DROP TABLE IF EXISTS sms_campaign_enrollments CASCADE;
DROP TABLE IF EXISTS sms_campaign_steps CASCADE;
DROP TABLE IF EXISTS sms_campaigns CASCADE;
DROP TABLE IF EXISTS sms_messages CASCADE;
DROP TABLE IF EXISTS sms_conversations CASCADE;

-- Drop existing types
DROP TYPE IF EXISTS sms_event_type CASCADE;
DROP TYPE IF EXISTS sms_enrollment_status CASCADE;
DROP TYPE IF EXISTS sms_campaign_status CASCADE;
DROP TYPE IF EXISTS sms_campaign_type CASCADE;
DROP TYPE IF EXISTS sms_message_status CASCADE;
DROP TYPE IF EXISTS sms_direction CASCADE;

-- ============================================================================
-- 1) SMS CONVERSATIONS
-- ============================================================================
-- Tracks conversation threads between users and leads via SMS

CREATE TABLE sms_conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id UUID,
  
  -- Twilio identifiers
  twilio_conversation_sid TEXT UNIQUE NOT NULL,
  lead_phone TEXT NOT NULL,           -- E.164 format: +1XXXXXXXXXX
  twilio_proxy_number TEXT NOT NULL,  -- Your Twilio SMS number
  
  -- Status tracking
  status TEXT NOT NULL DEFAULT 'active', -- active | closed | archived
  
  -- Message timestamps
  last_message_at TIMESTAMPTZ,
  last_inbound_at TIMESTAMPTZ,
  last_outbound_at TIMESTAMPTZ,
  
  -- UI helpers
  unread_count INTEGER NOT NULL DEFAULT 0,
  
  -- Extensibility
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_sms_conversations_user_id ON sms_conversations(user_id);
CREATE INDEX idx_sms_conversations_listing_id ON sms_conversations(listing_id);
CREATE INDEX idx_sms_conversations_twilio_sid ON sms_conversations(twilio_conversation_sid);
CREATE INDEX idx_sms_conversations_lead_phone ON sms_conversations(lead_phone);
CREATE INDEX idx_sms_conversations_status ON sms_conversations(status);
CREATE INDEX idx_sms_conversations_last_message_at ON sms_conversations(last_message_at DESC);

-- ============================================================================
-- 2) SMS MESSAGES
-- ============================================================================
-- Individual SMS messages within conversations

CREATE TYPE sms_direction AS ENUM ('inbound', 'outbound');

CREATE TYPE sms_message_status AS ENUM (
  'queued',
  'sent',
  'delivered',
  'read',
  'undelivered',
  'failed'
);

CREATE TABLE sms_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID NOT NULL REFERENCES sms_conversations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Who sent (for outbound)
  
  -- Message details
  direction sms_direction NOT NULL,
  body TEXT NOT NULL,
  media_urls TEXT[] DEFAULT '{}',
  
  -- Twilio identifiers
  twilio_message_sid TEXT UNIQUE,
  channel_message_sid TEXT, -- e.g. SMxx for SMS channel
  
  -- Status tracking
  status sms_message_status NOT NULL DEFAULT 'queued',
  error_code TEXT,
  error_message TEXT,
  
  -- Timestamps
  sent_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,
  
  -- Raw Twilio data for debugging
  raw_payload JSONB,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_sms_messages_conversation_id ON sms_messages(conversation_id);
CREATE INDEX idx_sms_messages_twilio_message_sid ON sms_messages(twilio_message_sid);
CREATE INDEX idx_sms_messages_created_at ON sms_messages(created_at);
CREATE INDEX idx_sms_messages_direction ON sms_messages(direction);
CREATE INDEX idx_sms_messages_status ON sms_messages(status);

-- ============================================================================
-- 3) SMS CAMPAIGNS
-- ============================================================================
-- Drip sequences or broadcast campaigns

CREATE TYPE sms_campaign_type AS ENUM ('drip', 'broadcast');

CREATE TYPE sms_campaign_status AS ENUM (
  'draft',
  'running',
  'paused',
  'completed',
  'archived'
);

CREATE TABLE sms_campaigns (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Campaign details
  name TEXT NOT NULL,
  description TEXT,
  type sms_campaign_type NOT NULL DEFAULT 'drip',
  status sms_campaign_status NOT NULL DEFAULT 'draft',
  
  -- Targeting (who gets enrolled)
  segment_filters JSONB NOT NULL DEFAULT '{}'::JSONB,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sms_campaigns_user_id ON sms_campaigns(user_id);
CREATE INDEX idx_sms_campaigns_status ON sms_campaigns(status);
CREATE INDEX idx_sms_campaigns_type ON sms_campaigns(type);

-- ============================================================================
-- 4) SMS CAMPAIGN STEPS
-- ============================================================================
-- Multi-step sequences for drip campaigns

CREATE TABLE sms_campaign_steps (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES sms_campaigns(id) ON DELETE CASCADE,
  
  -- Step configuration
  step_order INTEGER NOT NULL,
  delay_minutes INTEGER NOT NULL DEFAULT 0, -- Relative to previous step
  
  -- Message content
  template_body TEXT NOT NULL,
  
  -- Behavior
  stop_on_reply BOOLEAN NOT NULL DEFAULT TRUE,
  
  -- Quiet hours (optional, e.g., "21:00" to "08:00")
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  
  -- Extensibility
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  
  UNIQUE(campaign_id, step_order)
);

CREATE INDEX idx_sms_campaign_steps_campaign_id ON sms_campaign_steps(campaign_id);
CREATE INDEX idx_sms_campaign_steps_step_order ON sms_campaign_steps(campaign_id, step_order);

-- ============================================================================
-- 5) SMS CAMPAIGN ENROLLMENTS
-- ============================================================================
-- Tracks which leads are enrolled in which campaigns

CREATE TYPE sms_enrollment_status AS ENUM (
  'pending',
  'active',
  'completed',
  'cancelled',
  'bounced',
  'unsubscribed'
);

CREATE TABLE sms_campaign_enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  campaign_id UUID NOT NULL REFERENCES sms_campaigns(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES sms_conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id UUID,
  
  -- Enrollment state
  status sms_enrollment_status NOT NULL DEFAULT 'pending',
  current_step_order INTEGER NOT NULL DEFAULT 0,
  
  -- Scheduling
  next_run_at TIMESTAMPTZ,
  last_step_sent_at TIMESTAMPTZ,
  last_inbound_at TIMESTAMPTZ,
  
  -- Opt-out tracking
  unsubscribed BOOLEAN NOT NULL DEFAULT FALSE,
  
  -- Extensibility
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Prevent duplicate enrollments
  UNIQUE(campaign_id, conversation_id)
);

CREATE INDEX idx_sms_campaign_enrollments_campaign_id ON sms_campaign_enrollments(campaign_id);
CREATE INDEX idx_sms_campaign_enrollments_conversation_id ON sms_campaign_enrollments(conversation_id);
CREATE INDEX idx_sms_campaign_enrollments_next_run_at ON sms_campaign_enrollments(next_run_at) WHERE status = 'active';
CREATE INDEX idx_sms_campaign_enrollments_status ON sms_campaign_enrollments(status);

-- ============================================================================
-- 6) SMS EVENTS (Analytics & Audit Log)
-- ============================================================================

CREATE TYPE sms_event_type AS ENUM (
  'message_sent',
  'message_delivered',
  'message_failed',
  'reply_received',
  'conversation_started',
  'conversation_closed',
  'campaign_started',
  'campaign_step_sent',
  'campaign_completed',
  'unsubscribed'
);

CREATE TABLE sms_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  event_type sms_event_type NOT NULL,
  
  -- Foreign keys
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  listing_id UUID,
  conversation_id UUID REFERENCES sms_conversations(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES sms_campaigns(id) ON DELETE SET NULL,
  message_id UUID REFERENCES sms_messages(id) ON DELETE SET NULL,
  
  -- Event data
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  details JSONB NOT NULL DEFAULT '{}'::JSONB
);

CREATE INDEX idx_sms_events_user_id_occurred_at ON sms_events(user_id, occurred_at DESC);
CREATE INDEX idx_sms_events_campaign_id_occurred_at ON sms_events(campaign_id, occurred_at DESC);
CREATE INDEX idx_sms_events_event_type_occurred_at ON sms_events(event_type, occurred_at DESC);
CREATE INDEX idx_sms_events_conversation_id ON sms_events(conversation_id);

-- ============================================================================
-- ANALYTICS VIEWS
-- ============================================================================

-- Campaign Performance View
CREATE OR REPLACE VIEW sms_campaign_performance AS
SELECT
  c.id AS campaign_id,
  c.name,
  c.type,
  c.status,
  COUNT(DISTINCT e.conversation_id) FILTER (WHERE e.event_type = 'campaign_started') AS conversations_started,
  COUNT(e.id) FILTER (WHERE e.event_type = 'campaign_step_sent') AS total_messages_sent,
  COUNT(e.id) FILTER (WHERE e.event_type = 'reply_received') AS total_replies,
  COUNT(e.id) FILTER (WHERE e.event_type = 'unsubscribed') AS total_unsubscribes,
  ROUND(
    (COUNT(e.id) FILTER (WHERE e.event_type = 'reply_received')::DECIMAL /
    NULLIF(COUNT(e.id) FILTER (WHERE e.event_type = 'campaign_step_sent'), 0)) * 100,
    2
  ) AS reply_rate_percent,
  ROUND(
    (COUNT(e.id) FILTER (WHERE e.event_type = 'unsubscribed')::DECIMAL /
    NULLIF(COUNT(e.id) FILTER (WHERE e.event_type = 'campaign_step_sent'), 0)) * 100,
    2
  ) AS opt_out_rate_percent
FROM sms_campaigns c
LEFT JOIN sms_events e ON e.campaign_id = c.id
GROUP BY c.id;

-- User Daily Metrics View
CREATE OR REPLACE VIEW sms_user_daily_metrics AS
SELECT
  u.id AS user_id,
  u.email,
  DATE(e.occurred_at) AS day,
  COUNT(e.id) FILTER (WHERE e.event_type = 'message_sent') AS messages_sent,
  COUNT(e.id) FILTER (WHERE e.event_type = 'reply_received') AS replies,
  COUNT(e.id) FILTER (WHERE e.event_type = 'unsubscribed') AS unsubscribes
FROM auth.users u
JOIN sms_events e ON e.user_id = u.id
GROUP BY u.id, u.email, DATE(e.occurred_at)
ORDER BY day DESC;

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE sms_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_campaign_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_campaign_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_events ENABLE ROW LEVEL SECURITY;

-- sms_conversations policies
CREATE POLICY "Users can view their own conversations" ON sms_conversations
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own conversations" ON sms_conversations
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own conversations" ON sms_conversations
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own conversations" ON sms_conversations
  FOR DELETE USING (auth.uid() = user_id);

-- sms_messages policies
CREATE POLICY "Users can view messages in their conversations" ON sms_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM sms_conversations
      WHERE sms_conversations.id = sms_messages.conversation_id
      AND sms_conversations.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert messages in their conversations" ON sms_messages
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM sms_conversations
      WHERE sms_conversations.id = sms_messages.conversation_id
      AND sms_conversations.user_id = auth.uid()
    )
  );

-- sms_campaigns policies
CREATE POLICY "Users can view their own campaigns" ON sms_campaigns
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own campaigns" ON sms_campaigns
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own campaigns" ON sms_campaigns
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own campaigns" ON sms_campaigns
  FOR DELETE USING (auth.uid() = user_id);

-- sms_campaign_steps policies
CREATE POLICY "Users can view steps of their campaigns" ON sms_campaign_steps
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM sms_campaigns
      WHERE sms_campaigns.id = sms_campaign_steps.campaign_id
      AND sms_campaigns.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert steps for their campaigns" ON sms_campaign_steps
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM sms_campaigns
      WHERE sms_campaigns.id = sms_campaign_steps.campaign_id
      AND sms_campaigns.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update steps of their campaigns" ON sms_campaign_steps
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM sms_campaigns
      WHERE sms_campaigns.id = sms_campaign_steps.campaign_id
      AND sms_campaigns.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete steps of their campaigns" ON sms_campaign_steps
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM sms_campaigns
      WHERE sms_campaigns.id = sms_campaign_steps.campaign_id
      AND sms_campaigns.user_id = auth.uid()
    )
  );

-- sms_campaign_enrollments policies
CREATE POLICY "Users can view their enrollments" ON sms_campaign_enrollments
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their enrollments" ON sms_campaign_enrollments
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their enrollments" ON sms_campaign_enrollments
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their enrollments" ON sms_campaign_enrollments
  FOR DELETE USING (auth.uid() = user_id);

-- sms_events policies
CREATE POLICY "Users can view their events" ON sms_events
  FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM sms_conversations
      WHERE sms_conversations.id = sms_events.conversation_id
      AND sms_conversations.user_id = auth.uid()
    )
  );

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Update updated_at timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at
CREATE TRIGGER update_sms_conversations_updated_at
  BEFORE UPDATE ON sms_conversations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sms_campaigns_updated_at
  BEFORE UPDATE ON sms_campaigns
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sms_campaign_enrollments_updated_at
  BEFORE UPDATE ON sms_campaign_enrollments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ADD FOREIGN KEY CONSTRAINTS FOR LISTINGS (if table exists)
-- ============================================================================
-- These are added separately to avoid errors if listings table doesn't exist yet

DO $$
BEGIN
  -- Add foreign key constraint for sms_conversations.listing_id
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'listings') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'listings' AND column_name = 'id') THEN
      ALTER TABLE sms_conversations 
      ADD CONSTRAINT sms_conversations_listing_id_fkey 
      FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE SET NULL;
    END IF;
  END IF;

  -- Add foreign key constraint for sms_campaign_enrollments.listing_id
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'listings') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'listings' AND column_name = 'id') THEN
      ALTER TABLE sms_campaign_enrollments 
      ADD CONSTRAINT sms_campaign_enrollments_listing_id_fkey 
      FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE SET NULL;
    END IF;
  END IF;

  -- Add foreign key constraint for sms_events.listing_id
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'listings') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'listings' AND column_name = 'id') THEN
      ALTER TABLE sms_events 
      ADD CONSTRAINT sms_events_listing_id_fkey 
      FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE sms_conversations IS 'SMS conversation threads between users and leads via Twilio';
COMMENT ON TABLE sms_messages IS 'Individual SMS messages with delivery tracking';
COMMENT ON TABLE sms_campaigns IS 'SMS drip campaigns and broadcasts';
COMMENT ON TABLE sms_campaign_steps IS 'Sequential steps in drip campaigns';
COMMENT ON TABLE sms_campaign_enrollments IS 'Lead enrollments in campaigns with progression tracking';
COMMENT ON TABLE sms_events IS 'Analytics and audit log for all SMS activities';

COMMENT ON VIEW sms_campaign_performance IS 'Campaign-level analytics: reply rate, opt-out rate, etc.';
COMMENT ON VIEW sms_user_daily_metrics IS 'Per-user daily SMS activity metrics';

