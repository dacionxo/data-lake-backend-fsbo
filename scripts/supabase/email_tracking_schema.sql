-- ============================================================================
-- Email Tracking Schema
-- ============================================================================
-- Tracks email opens and clicks for analytics
-- ============================================================================

-- Email Opens Table
CREATE TABLE IF NOT EXISTS email_opens (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  email_id UUID REFERENCES emails(id) ON DELETE CASCADE,
  campaign_recipient_id UUID REFERENCES campaign_recipients(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
  
  opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Email Clicks Table
CREATE TABLE IF NOT EXISTS email_clicks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  email_id UUID REFERENCES emails(id) ON DELETE CASCADE,
  campaign_recipient_id UUID REFERENCES campaign_recipients(id) ON DELETE CASCADE,
  campaign_id UUID REFERENCES campaigns(id) ON DELETE CASCADE,
  
  clicked_url TEXT NOT NULL,
  clicked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_email_opens_email_id ON email_opens(email_id);
CREATE INDEX IF NOT EXISTS idx_email_opens_campaign_recipient_id ON email_opens(campaign_recipient_id);
CREATE INDEX IF NOT EXISTS idx_email_opens_campaign_id ON email_opens(campaign_id);
CREATE INDEX IF NOT EXISTS idx_email_opens_opened_at ON email_opens(opened_at);

CREATE INDEX IF NOT EXISTS idx_email_clicks_email_id ON email_clicks(email_id);
CREATE INDEX IF NOT EXISTS idx_email_clicks_campaign_recipient_id ON email_clicks(campaign_recipient_id);
CREATE INDEX IF NOT EXISTS idx_email_clicks_campaign_id ON email_clicks(campaign_id);
CREATE INDEX IF NOT EXISTS idx_email_clicks_clicked_at ON email_clicks(clicked_at);



