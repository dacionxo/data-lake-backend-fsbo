-- ============================================================================
-- Add Calendar Onboarding Flag
-- ============================================================================
-- Adds a flag to track if the user has completed calendar onboarding
-- ============================================================================

-- Add onboarding_complete column to user_calendar_settings
ALTER TABLE user_calendar_settings
ADD COLUMN IF NOT EXISTS calendar_onboarding_complete BOOLEAN DEFAULT FALSE;

-- Add comment
COMMENT ON COLUMN user_calendar_settings.calendar_onboarding_complete IS 
  'Flag to track if user has completed calendar onboarding. Set to true when user clicks "Connect calendar" button.';

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_calendar_settings_onboarding 
  ON user_calendar_settings(user_id, calendar_onboarding_complete) 
  WHERE calendar_onboarding_complete = FALSE;

