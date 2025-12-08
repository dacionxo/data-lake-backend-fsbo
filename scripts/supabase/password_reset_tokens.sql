-- ============================================================================
-- Password Reset Tokens Table
-- ============================================================================
-- This table stores hashed password reset tokens for secure password recovery
-- 
-- Security Features:
-- - Tokens are hashed before storage (never store raw tokens)
-- - Tokens expire after 15 minutes
-- - One-time use (deleted after successful reset)
-- - Old tokens are automatically cleaned up
-- ============================================================================

-- Create password_reset_tokens table
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_user_token UNIQUE(user_id, token_hash)
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_user_id ON password_reset_tokens(user_id);

-- Create index on expires_at for cleanup queries
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires_at ON password_reset_tokens(expires_at);

-- Create index on created_at for cleanup queries
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_created_at ON password_reset_tokens(created_at);

-- Enable RLS (Row Level Security)
ALTER TABLE password_reset_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Only service role can access (API routes use service role key)
-- This ensures tokens are only accessible server-side
CREATE POLICY "Service role can manage password reset tokens"
  ON password_reset_tokens
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Function to clean up expired tokens (optional, can be called periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_password_reset_tokens()
RETURNS void AS $$
BEGIN
  DELETE FROM password_reset_tokens
  WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Optional: Create a scheduled job to clean up expired tokens
-- This can be set up in Supabase Dashboard > Database > Cron Jobs
-- Example cron expression: '0 * * * *' (runs every hour)

