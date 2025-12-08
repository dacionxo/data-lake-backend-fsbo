-- ============================================================================
-- Calendar System Schema for LeadMap
-- ============================================================================
-- This schema adds comprehensive calendar scheduling functionality including:
-- - Calendar events (calls, visits, content posts, etc.)
-- - External calendar connections (Google, Outlook, iCloud)
-- - Two-way sync with external calendars
-- - Reminders and notifications
-- - Free/busy availability checking
-- - Automated follow-ups
-- ============================================================================

-- Calendar Connections Table
-- Stores OAuth connections to external calendars (Google, Outlook, iCloud)
CREATE TABLE IF NOT EXISTS calendar_connections (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('google', 'outlook', 'icloud')),
  provider_account_id TEXT NOT NULL, -- External account ID
  email TEXT NOT NULL, -- Calendar email address
  access_token TEXT NOT NULL, -- Encrypted access token
  refresh_token TEXT, -- Encrypted refresh token
  token_expires_at TIMESTAMPTZ,
  calendar_id TEXT, -- Primary calendar ID from provider
  calendar_name TEXT, -- Display name of calendar
  sync_enabled BOOLEAN DEFAULT TRUE,
  last_sync_at TIMESTAMPTZ,
  sync_token TEXT, -- For incremental sync (Google Calendar)
  webhook_id TEXT, -- Webhook subscription ID for push notifications
  webhook_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, provider, email)
);

-- Calendar Events Table
-- Stores all calendar events (calls, visits, content posts, etc.)
CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  event_type TEXT NOT NULL CHECK (event_type IN ('call', 'visit', 'showing', 'content', 'meeting', 'follow_up', 'other')),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  timezone TEXT DEFAULT 'UTC',
  all_day BOOLEAN DEFAULT FALSE,
  location TEXT,
  conferencing_link TEXT, -- Google Meet, Zoom, etc.
  conferencing_provider TEXT, -- 'google_meet', 'zoom', 'teams', etc.
  
  -- Recurrence support (RRULE)
  recurrence_rule TEXT, -- iCalendar RRULE string
  recurrence_end_date TIMESTAMPTZ,
  
  -- Related entities (leads, properties, contacts, deals)
  related_type TEXT, -- 'contact', 'deal', 'listing', 'property', 'lead'
  related_id TEXT, -- ID of the related entity
  
  -- External calendar sync
  external_event_id TEXT, -- Event ID in external calendar (Google/Outlook)
  external_calendar_id TEXT, -- Calendar ID where event is synced
  sync_status TEXT DEFAULT 'pending' CHECK (sync_status IN ('pending', 'synced', 'failed', 'deleted')),
  last_synced_at TIMESTAMPTZ,
  
  -- Attendees
  attendees JSONB DEFAULT '[]'::jsonb, -- Array of {email, name, status, organizer}
  organizer_email TEXT,
  organizer_name TEXT,
  
  -- Status and metadata
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled', 'no_show')),
  color TEXT, -- Event color for UI
  notes TEXT,
  tags TEXT[],
  
  -- Reminders
  reminder_minutes INTEGER[], -- Array of minutes before event (e.g., [15, 1440] for 15min and 1 day)
  reminder_sent BOOLEAN DEFAULT FALSE,
  
  -- Follow-up automation
  follow_up_enabled BOOLEAN DEFAULT FALSE,
  follow_up_delay_hours INTEGER, -- Hours after event end to trigger follow-up
  follow_up_triggered BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT valid_time_range CHECK (end_time > start_time)
);

-- Calendar Availability Table
-- Stores user availability settings and working hours
CREATE TABLE IF NOT EXISTS calendar_availability (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  
  -- Working hours (stored as JSONB for flexibility)
  working_hours JSONB DEFAULT '{
    "monday": {"enabled": true, "start": "09:00", "end": "17:00"},
    "tuesday": {"enabled": true, "start": "09:00", "end": "17:00"},
    "wednesday": {"enabled": true, "start": "09:00", "end": "17:00"},
    "thursday": {"enabled": true, "start": "09:00", "end": "17:00"},
    "friday": {"enabled": true, "start": "09:00", "end": "17:00"},
    "saturday": {"enabled": false, "start": "09:00", "end": "17:00"},
    "sunday": {"enabled": false, "start": "09:00", "end": "17:00"}
  }'::jsonb,
  
  -- Buffer times (minutes)
  buffer_before INTEGER DEFAULT 0, -- Minutes before events
  buffer_after INTEGER DEFAULT 0, -- Minutes after events
  
  -- Timezone
  timezone TEXT DEFAULT 'America/New_York',
  
  -- Blocked dates/times
  blocked_slots JSONB DEFAULT '[]'::jsonb, -- Array of {start, end, reason}
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Calendar Reminders Table
-- Tracks sent reminders to avoid duplicates
CREATE TABLE IF NOT EXISTS calendar_reminders (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  event_id UUID REFERENCES calendar_events(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  reminder_minutes INTEGER NOT NULL, -- Minutes before event
  reminder_time TIMESTAMPTZ NOT NULL, -- When reminder should be sent
  sent_at TIMESTAMPTZ,
  sent_via TEXT, -- 'email', 'sms', 'push', 'in_app'
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'cancelled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Calendar Sync Log Table
-- Tracks sync operations for debugging and monitoring
CREATE TABLE IF NOT EXISTS calendar_sync_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  connection_id UUID REFERENCES calendar_connections(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  sync_type TEXT NOT NULL CHECK (sync_type IN ('full', 'incremental', 'webhook', 'manual')),
  direction TEXT NOT NULL CHECK (direction IN ('import', 'export', 'bidirectional')),
  events_created INTEGER DEFAULT 0,
  events_updated INTEGER DEFAULT 0,
  events_deleted INTEGER DEFAULT 0,
  status TEXT DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),
  error_message TEXT,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- Free/Busy Cache Table
-- Caches free/busy data to reduce API calls
CREATE TABLE IF NOT EXISTS calendar_freebusy_cache (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  email TEXT NOT NULL, -- Calendar email
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  busy_slots JSONB NOT NULL, -- Array of {start, end} busy periods
  cached_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  UNIQUE(user_id, email, start_time, end_time)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_calendar_events_user_id ON calendar_events(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_start_time ON calendar_events(start_time);
CREATE INDEX IF NOT EXISTS idx_calendar_events_end_time ON calendar_events(end_time);
CREATE INDEX IF NOT EXISTS idx_calendar_events_related ON calendar_events(related_type, related_id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_external_id ON calendar_events(external_event_id);
CREATE INDEX IF NOT EXISTS idx_calendar_connections_user_id ON calendar_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_connections_provider ON calendar_connections(provider);
CREATE INDEX IF NOT EXISTS idx_calendar_reminders_event_id ON calendar_reminders(event_id);
CREATE INDEX IF NOT EXISTS idx_calendar_reminders_reminder_time ON calendar_reminders(reminder_time);
CREATE INDEX IF NOT EXISTS idx_calendar_reminders_status ON calendar_reminders(status);
CREATE INDEX IF NOT EXISTS idx_calendar_sync_logs_user_id ON calendar_sync_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_calendar_freebusy_cache_user_email ON calendar_freebusy_cache(user_id, email);
CREATE INDEX IF NOT EXISTS idx_calendar_freebusy_cache_expires ON calendar_freebusy_cache(expires_at);

-- Update triggers
CREATE OR REPLACE FUNCTION update_calendar_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_calendar_connections_updated_at
  BEFORE UPDATE ON calendar_connections
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

CREATE TRIGGER update_calendar_events_updated_at
  BEFORE UPDATE ON calendar_events
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

CREATE TRIGGER update_calendar_availability_updated_at
  BEFORE UPDATE ON calendar_availability
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_updated_at();

-- RLS Policies
ALTER TABLE calendar_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_sync_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendar_freebusy_cache ENABLE ROW LEVEL SECURITY;

-- Calendar Connections Policies
CREATE POLICY "Users can view their own calendar connections"
  ON calendar_connections FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own calendar connections"
  ON calendar_connections FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own calendar connections"
  ON calendar_connections FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own calendar connections"
  ON calendar_connections FOR DELETE
  USING (auth.uid() = user_id);

-- Calendar Events Policies
CREATE POLICY "Users can view their own calendar events"
  ON calendar_events FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own calendar events"
  ON calendar_events FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own calendar events"
  ON calendar_events FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own calendar events"
  ON calendar_events FOR DELETE
  USING (auth.uid() = user_id);

-- Calendar Availability Policies
CREATE POLICY "Users can view their own availability"
  ON calendar_availability FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own availability"
  ON calendar_availability FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own availability"
  ON calendar_availability FOR UPDATE
  USING (auth.uid() = user_id);

-- Calendar Reminders Policies
CREATE POLICY "Users can view their own reminders"
  ON calendar_reminders FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reminders"
  ON calendar_reminders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reminders"
  ON calendar_reminders FOR UPDATE
  USING (auth.uid() = user_id);

-- Calendar Sync Logs Policies
CREATE POLICY "Users can view their own sync logs"
  ON calendar_sync_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sync logs"
  ON calendar_sync_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Free/Busy Cache Policies
CREATE POLICY "Users can view their own free/busy cache"
  ON calendar_freebusy_cache FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own free/busy cache"
  ON calendar_freebusy_cache FOR ALL
  USING (auth.uid() = user_id);

-- Helper function to get user's busy times for a date range
CREATE OR REPLACE FUNCTION get_user_busy_times(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ
)
RETURNS TABLE (
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  event_title TEXT,
  event_type TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ce.start_time,
    ce.end_time,
    ce.title as event_title,
    ce.event_type
  FROM calendar_events ce
  WHERE ce.user_id = p_user_id
    AND ce.status != 'cancelled'
    AND ce.start_time < p_end_time
    AND ce.end_time > p_start_time
  ORDER BY ce.start_time;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if a time slot is available
CREATE OR REPLACE FUNCTION is_time_slot_available(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_exclude_event_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  conflict_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO conflict_count
  FROM calendar_events ce
  WHERE ce.user_id = p_user_id
    AND ce.status != 'cancelled'
    AND ce.id != COALESCE(p_exclude_event_id, '00000000-0000-0000-0000-000000000000'::UUID)
    AND ce.start_time < p_end_time
    AND ce.end_time > p_start_time;
  
  RETURN conflict_count = 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

