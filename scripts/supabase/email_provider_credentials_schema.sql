-- ============================================================================
-- Email Provider Credentials Schema
-- ============================================================================
-- Stores per-user/provider email credentials with encryption and rotation support
-- ============================================================================

-- Provider Credentials Table (multitenant)
CREATE TABLE IF NOT EXISTS email_provider_credentials (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- Provider identification
  provider_type TEXT NOT NULL CHECK (provider_type IN ('resend', 'sendgrid', 'mailgun', 'ses', 'smtp', 'generic')),
  provider_name TEXT, -- User-friendly name for this credential set
  
  -- Encrypted credentials (use encryption functions)
  encrypted_api_key TEXT, -- Encrypted API key/access key
  encrypted_secret_key TEXT, -- Encrypted secret key (for SES, SMTP password)
  encrypted_password TEXT, -- For SMTP passwords
  
  -- Configuration
  region TEXT, -- For AWS SES
  domain TEXT, -- For Mailgun
  host TEXT, -- For SMTP
  port INTEGER, -- For SMTP
  username TEXT, -- For SMTP
  from_email TEXT,
  
  -- Rotation tracking
  last_rotated_at TIMESTAMPTZ,
  rotation_schedule_days INTEGER DEFAULT 90, -- Rotate every 90 days by default
  next_rotation_due_at TIMESTAMPTZ,
  
  -- Status
  active BOOLEAN DEFAULT TRUE,
  verified BOOLEAN DEFAULT FALSE, -- Whether credentials have been verified
  last_verified_at TIMESTAMPTZ,
  
  -- Metadata
  sandbox_mode BOOLEAN DEFAULT FALSE,
  tracking_domain TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- One credential set per user per provider type
  UNIQUE(user_id, provider_type, provider_name)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_email_provider_credentials_user_id ON email_provider_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_email_provider_credentials_provider_type ON email_provider_credentials(provider_type);
CREATE INDEX IF NOT EXISTS idx_email_provider_credentials_active ON email_provider_credentials(active);
CREATE INDEX IF NOT EXISTS idx_email_provider_credentials_next_rotation ON email_provider_credentials(next_rotation_due_at) WHERE active = TRUE;

-- Provider Health Checks Table (extends existing mailbox_health_checks)
-- Tracks health of provider credentials
CREATE TABLE IF NOT EXISTS provider_health_checks (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  credential_id UUID REFERENCES email_provider_credentials(id) ON DELETE CASCADE NOT NULL,
  
  -- Health status
  healthy BOOLEAN DEFAULT TRUE,
  status TEXT NOT NULL CHECK (status IN ('healthy', 'degraded', 'unhealthy', 'disconnected')) DEFAULT 'healthy',
  
  -- Check details
  last_checked_at TIMESTAMPTZ DEFAULT NOW(),
  last_successful_check_at TIMESTAMPTZ,
  error_message TEXT,
  
  -- Provider-specific metrics
  response_time_ms INTEGER,
  rate_limit_remaining INTEGER, -- Remaining API calls/quota
  quota_used_percent DECIMAL(5,2), -- Percentage of quota used
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(credential_id)
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_provider_health_checks_credential_id ON provider_health_checks(credential_id);
CREATE INDEX IF NOT EXISTS idx_provider_health_checks_status ON provider_health_checks(status);

-- Function to check for credentials needing rotation
CREATE OR REPLACE FUNCTION check_credentials_rotation()
RETURNS TABLE (
  credential_id UUID,
  user_id UUID,
  provider_type TEXT,
  days_until_rotation INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    epc.id,
    epc.user_id,
    epc.provider_type,
    EXTRACT(DAY FROM (epc.next_rotation_due_at - NOW()))::INTEGER
  FROM email_provider_credentials epc
  WHERE epc.active = TRUE
    AND epc.next_rotation_due_at IS NOT NULL
    AND epc.next_rotation_due_at <= NOW() + INTERVAL '7 days' -- Due in next 7 days
  ORDER BY epc.next_rotation_due_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to mark credentials as rotated
CREATE OR REPLACE FUNCTION mark_credentials_rotated(
  p_credential_id UUID,
  p_new_rotation_due_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_rotation_schedule INTEGER;
BEGIN
  -- Get rotation schedule
  SELECT rotation_schedule_days INTO v_rotation_schedule
  FROM email_provider_credentials
  WHERE id = p_credential_id;
  
  -- Update rotation dates
  UPDATE email_provider_credentials
  SET 
    last_rotated_at = NOW(),
    next_rotation_due_at = COALESCE(
      p_new_rotation_due_at,
      NOW() + (v_rotation_schedule || ' days')::INTERVAL
    ),
    updated_at = NOW()
  WHERE id = p_credential_id;
END;
$$ LANGUAGE plpgsql;



