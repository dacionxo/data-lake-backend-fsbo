-- ============================================================================
-- Add Calendar Type Column
-- ============================================================================
-- Adds a column to track whether user is using native calendar or external calendar integration
-- ============================================================================

-- Add calendar_type column to user_calendar_settings
ALTER TABLE user_calendar_settings
ADD COLUMN IF NOT EXISTS calendar_type TEXT DEFAULT NULL CHECK (calendar_type IN ('native', 'google', 'microsoft365', 'outlook', 'exchange'));

-- Add comment
COMMENT ON COLUMN user_calendar_settings.calendar_type IS 
  'Type of calendar being used: native (FullCalendar), google, microsoft365, outlook, or exchange. NULL means onboarding not completed.';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_calendar_settings_calendar_type 
  ON user_calendar_settings(user_id, calendar_type);

