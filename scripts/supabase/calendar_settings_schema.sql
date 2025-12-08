-- ============================================================================
-- Calendar Settings Schema - Google Calendar Style
-- ============================================================================
-- This extends the calendar schema with comprehensive settings matching
-- Google Calendar's feature set
-- ============================================================================

-- User Calendar Settings (Global/General Settings)
CREATE TABLE IF NOT EXISTS user_calendar_settings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  
  -- General Settings
  default_timezone TEXT DEFAULT 'America/New_York',
  default_event_duration_minutes INTEGER DEFAULT 30,
  default_event_visibility TEXT DEFAULT 'private' CHECK (default_event_visibility IN ('public', 'private', 'confidential')),
  default_calendar_color TEXT DEFAULT '#3b82f6',
  language TEXT DEFAULT 'en',
  appearance TEXT DEFAULT 'system' CHECK (appearance IN ('light', 'dark', 'system')),
  
  -- Event Defaults
  default_reminders JSONB DEFAULT '[{"minutes": 15, "method": "email"}]'::jsonb,
  default_conferencing_provider TEXT, -- 'google_meet', 'zoom', 'teams', null
  default_guest_permissions JSONB DEFAULT '{
    "can_modify": false,
    "can_see_guest_list": true,
    "can_invite_others": false
  }'::jsonb,
  
  -- Visual & UX Options
  show_declined_events BOOLEAN DEFAULT false,
  default_view TEXT DEFAULT 'month' CHECK (default_view IN ('month', 'week', 'day', 'agenda')),
  show_weekends BOOLEAN DEFAULT true,
  view_density TEXT DEFAULT 'comfortable' CHECK (view_density IN ('comfortable', 'compact')),
  color_code_by_event_type BOOLEAN DEFAULT true,
  
  -- Notification Preferences (Global)
  notifications_email BOOLEAN DEFAULT true,
  notifications_in_app BOOLEAN DEFAULT true,
  notifications_sms BOOLEAN DEFAULT false,
  notification_sound_enabled BOOLEAN DEFAULT true,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Calendar-Specific Settings (Per-Calendar)
CREATE TABLE IF NOT EXISTS calendar_settings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  calendar_id UUID REFERENCES calendar_connections(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  -- Calendar Identity
  name TEXT NOT NULL,
  description TEXT,
  color TEXT DEFAULT '#3b82f6',
  timezone TEXT, -- Override user default if set
  
  -- Default Event Settings for this Calendar
  default_duration_minutes INTEGER,
  default_reminders JSONB,
  default_visibility TEXT CHECK (default_visibility IN ('public', 'private', 'confidential')),
  
  -- Notifications (Per-Calendar Overrides)
  notifications JSONB DEFAULT '{
    "email": true,
    "in_app": true,
    "sms": false,
    "popup": true,
    "all_day_events": true
  }'::jsonb,
  
  -- Sharing & Permissions
  share_permissions JSONB DEFAULT '{
    "owner": true,
    "editors": [],
    "viewers": [],
    "public_access": false
  }'::jsonb,
  
  -- Working Hours (Per-Calendar)
  working_hours JSONB DEFAULT '{
    "monday": {"enabled": true, "ranges": [{"start": "09:00", "end": "17:00"}]},
    "tuesday": {"enabled": true, "ranges": [{"start": "09:00", "end": "17:00"}]},
    "wednesday": {"enabled": true, "ranges": [{"start": "09:00", "end": "17:00"}]},
    "thursday": {"enabled": true, "ranges": [{"start": "09:00", "end": "17:00"}]},
    "friday": {"enabled": true, "ranges": [{"start": "09:00", "end": "17:00"}]},
    "saturday": {"enabled": false, "ranges": []},
    "sunday": {"enabled": false, "ranges": []}
  }'::jsonb,
  
  -- Free/Busy Access
  freebusy_visible BOOLEAN DEFAULT true,
  
  -- Visual Options
  show_declined_events BOOLEAN DEFAULT false,
  is_visible BOOLEAN DEFAULT true,
  is_selected BOOLEAN DEFAULT true,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(user_id, calendar_id)
);

-- Event Templates (Default Event Types)
CREATE TABLE IF NOT EXISTS event_templates (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  name TEXT NOT NULL, -- e.g., "Property Showing", "Phone Call"
  event_type TEXT NOT NULL CHECK (event_type IN ('call', 'visit', 'showing', 'content', 'meeting', 'follow_up', 'other')),
  
  -- Template Defaults
  default_duration_minutes INTEGER DEFAULT 30,
  default_reminders JSONB DEFAULT '[{"minutes": 15, "method": "email"}]'::jsonb,
  default_location TEXT,
  default_conferencing_provider TEXT,
  default_description TEXT,
  default_color TEXT,
  
  -- Follow-up Automation
  follow_up_enabled BOOLEAN DEFAULT false,
  follow_up_delay_hours INTEGER DEFAULT 24,
  
  -- Guest Permissions
  guest_permissions JSONB DEFAULT '{
    "can_modify": false,
    "can_see_guest_list": true,
    "can_invite_others": false
  }'::jsonb,
  
  is_default BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Out of Office Rules
CREATE TABLE IF NOT EXISTS out_of_office_rules (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  
  name TEXT NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_all_day BOOLEAN DEFAULT true,
  start_time TIME,
  end_time TIME,
  
  -- Auto-decline settings
  auto_decline_meetings BOOLEAN DEFAULT true,
  decline_message TEXT,
  
  -- Recurring (optional)
  is_recurring BOOLEAN DEFAULT false,
  recurrence_rule TEXT, -- RRULE string
  
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Notification Preferences (Granular)
CREATE TABLE IF NOT EXISTS notification_preferences (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  calendar_id UUID REFERENCES calendar_connections(id) ON DELETE CASCADE,
  
  -- Event Type Specific
  event_type TEXT, -- null for all types, or specific type
  
  -- Channels
  email_enabled BOOLEAN DEFAULT true,
  in_app_enabled BOOLEAN DEFAULT true,
  sms_enabled BOOLEAN DEFAULT false,
  push_enabled BOOLEAN DEFAULT true,
  
  -- Notification Types
  new_event_notification BOOLEAN DEFAULT true,
  event_updated_notification BOOLEAN DEFAULT true,
  event_cancelled_notification BOOLEAN DEFAULT true,
  reminder_notification BOOLEAN DEFAULT true,
  invitation_notification BOOLEAN DEFAULT true,
  
  -- Timing
  reminder_minutes INTEGER[], -- Array of minutes before event
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(user_id, calendar_id, event_type)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_calendar_settings_user_id ON user_calendar_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_settings_user_id ON calendar_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_settings_calendar_id ON calendar_settings(calendar_id);
CREATE INDEX IF NOT EXISTS idx_event_templates_user_id ON event_templates(user_id);
CREATE INDEX IF NOT EXISTS idx_out_of_office_rules_user_id ON out_of_office_rules(user_id);
CREATE INDEX IF NOT EXISTS idx_out_of_office_rules_dates ON out_of_office_rules(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_notification_preferences_user_id ON notification_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_preferences_calendar_id ON notification_preferences(calendar_id);

-- Update triggers
CREATE TRIGGER update_user_calendar_settings_updated_at
  BEFORE UPDATE ON user_calendar_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

CREATE TRIGGER update_calendar_settings_updated_at
  BEFORE UPDATE ON calendar_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

CREATE TRIGGER update_event_templates_updated_at
  BEFORE UPDATE ON event_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

CREATE TRIGGER update_out_of_office_rules_updated_at
  BEFORE UPDATE ON out_of_office_rules
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

CREATE TRIGGER update_notification_preferences_updated_at
  BEFORE UPDATE ON notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

-- RLS Policies
ALTER TABLE user_calendar_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE out_of_office_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

-- User Calendar Settings Policies
CREATE POLICY "Users can view their own calendar settings"
  ON user_calendar_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own calendar settings"
  ON user_calendar_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own calendar settings"
  ON user_calendar_settings FOR UPDATE
  USING (auth.uid() = user_id);

-- Calendar Settings Policies
CREATE POLICY "Users can view their own calendar settings"
  ON calendar_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own calendar settings"
  ON calendar_settings FOR ALL
  USING (auth.uid() = user_id);

-- Event Templates Policies
CREATE POLICY "Users can view their own event templates"
  ON event_templates FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own event templates"
  ON event_templates FOR ALL
  USING (auth.uid() = user_id);

-- Out of Office Rules Policies
CREATE POLICY "Users can view their own out of office rules"
  ON out_of_office_rules FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own out of office rules"
  ON out_of_office_rules FOR ALL
  USING (auth.uid() = user_id);

-- Notification Preferences Policies
CREATE POLICY "Users can view their own notification preferences"
  ON notification_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own notification preferences"
  ON notification_preferences FOR ALL
  USING (auth.uid() = user_id);

