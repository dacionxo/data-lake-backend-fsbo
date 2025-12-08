-- ============================================================================
-- Calendar Time Handling Migration
-- ============================================================================
-- World-class calendar time handling:
-- 1. All times stored as UTC (TIMESTAMPTZ)
-- 2. All-day events use DATE type (no timezone conversion)
-- 3. Each event can have an optional timezone override
-- 4. Recurring events store RRULE with timezone for DST-aware expansion
-- ============================================================================

-- Add columns for proper time handling
-- event_timezone: IANA timezone identifier for per-event timezone override
-- start_date/end_date: DATE-only fields for all-day events (no TZ conversion)
-- recurrence_timezone: Timezone for recurring event expansion (DST-aware)

ALTER TABLE calendar_events 
  ADD COLUMN IF NOT EXISTS event_timezone TEXT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS start_date DATE DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS end_date DATE DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS recurrence_timezone TEXT DEFAULT NULL;

-- Add comments explaining the time handling strategy
COMMENT ON COLUMN calendar_events.start_time IS 'Event start time stored in UTC. For timed events only.';
COMMENT ON COLUMN calendar_events.end_time IS 'Event end time stored in UTC. For timed events only.';
COMMENT ON COLUMN calendar_events.timezone IS 'DEPRECATED: Use event_timezone instead. Kept for backwards compatibility.';
COMMENT ON COLUMN calendar_events.event_timezone IS 'IANA timezone (e.g., America/New_York) for this specific event. If set, times are displayed in this timezone. If NULL, user default timezone is used.';
COMMENT ON COLUMN calendar_events.start_date IS 'Start date for all-day events (DATE only, no time component). Used when all_day = true.';
COMMENT ON COLUMN calendar_events.end_date IS 'End date for all-day events (DATE only, no time component). Used when all_day = true.';
COMMENT ON COLUMN calendar_events.all_day IS 'If true, event spans whole days. Use start_date/end_date instead of start_time/end_time.';
COMMENT ON COLUMN calendar_events.recurrence_rule IS 'iCalendar RRULE string (RFC 5545). Example: FREQ=WEEKLY;BYDAY=MO,WE,FR';
COMMENT ON COLUMN calendar_events.recurrence_timezone IS 'Timezone for recurring event expansion. Ensures repeated events stay at same local time across DST. Example: America/New_York';

-- Update constraint to handle all-day events properly
-- All-day events can have start_time = end_time (or null times with dates set)
ALTER TABLE calendar_events DROP CONSTRAINT IF EXISTS valid_time_range;
ALTER TABLE calendar_events ADD CONSTRAINT valid_time_range 
  CHECK (
    (all_day = true AND start_date IS NOT NULL AND end_date IS NOT NULL AND end_date >= start_date)
    OR 
    (all_day = false AND start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)
  );

-- Create index for date-based queries on all-day events
CREATE INDEX IF NOT EXISTS idx_calendar_events_dates ON calendar_events(start_date, end_date) WHERE all_day = true;

-- Function to convert all-day event dates to display range
-- Returns the date range as it should appear on the calendar (no timezone shifting)
CREATE OR REPLACE FUNCTION get_allday_display_range(
  p_start_date DATE,
  p_end_date DATE
)
RETURNS TABLE (
  display_start DATE,
  display_end DATE
) AS $$
BEGIN
  -- All-day events: end_date is inclusive, but FullCalendar expects exclusive end
  -- So we add 1 day to the end for display
  RETURN QUERY SELECT p_start_date, p_end_date + 1;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to check if a recurring event occurs on a given date
-- This is a simplified check; full RRULE expansion should be done client-side
CREATE OR REPLACE FUNCTION does_recurrence_occur_on_date(
  p_recurrence_rule TEXT,
  p_start_time TIMESTAMPTZ,
  p_check_date DATE
)
RETURNS BOOLEAN AS $$
DECLARE
  freq TEXT;
  interval_val INTEGER;
  days_diff INTEGER;
BEGIN
  -- Basic recurrence check (DAILY and WEEKLY only for now)
  -- Full RRULE parsing should be done client-side with rrule.js
  
  IF p_recurrence_rule IS NULL THEN
    RETURN FALSE;
  END IF;
  
  -- Extract frequency
  freq := substring(p_recurrence_rule FROM 'FREQ=([A-Z]+)');
  
  -- Extract interval (default 1)
  interval_val := COALESCE(
    substring(p_recurrence_rule FROM 'INTERVAL=([0-9]+)')::INTEGER,
    1
  );
  
  -- Calculate days difference
  days_diff := p_check_date - p_start_time::DATE;
  
  IF days_diff < 0 THEN
    RETURN FALSE;
  END IF;
  
  CASE freq
    WHEN 'DAILY' THEN
      RETURN days_diff % interval_val = 0;
    WHEN 'WEEKLY' THEN
      RETURN days_diff % (7 * interval_val) = 0;
    WHEN 'MONTHLY' THEN
      -- Simplified: same day of month
      RETURN EXTRACT(DAY FROM p_start_time) = EXTRACT(DAY FROM p_check_date)
        AND (EXTRACT(MONTH FROM p_check_date) - EXTRACT(MONTH FROM p_start_time) 
             + (EXTRACT(YEAR FROM p_check_date) - EXTRACT(YEAR FROM p_start_time)) * 12) % interval_val = 0;
    WHEN 'YEARLY' THEN
      RETURN EXTRACT(DAY FROM p_start_time) = EXTRACT(DAY FROM p_check_date)
        AND EXTRACT(MONTH FROM p_start_time) = EXTRACT(MONTH FROM p_check_date)
        AND (EXTRACT(YEAR FROM p_check_date) - EXTRACT(YEAR FROM p_start_time))::INTEGER % interval_val = 0;
    ELSE
      RETURN FALSE;
  END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Update get_user_busy_times to handle all-day events
-- Drop the existing function first since we're changing the return type
DROP FUNCTION IF EXISTS get_user_busy_times(UUID, TIMESTAMPTZ, TIMESTAMPTZ);

CREATE FUNCTION get_user_busy_times(
  p_user_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ
)
RETURNS TABLE (
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ,
  event_title TEXT,
  event_type TEXT,
  is_all_day BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  -- Timed events
  SELECT 
    ce.start_time,
    ce.end_time,
    ce.title as event_title,
    ce.event_type,
    ce.all_day as is_all_day
  FROM calendar_events ce
  WHERE ce.user_id = p_user_id
    AND ce.status != 'cancelled'
    AND ce.all_day = false
    AND ce.start_time < p_end_time
    AND ce.end_time > p_start_time
  UNION ALL
  -- All-day events (convert dates to timestamps for comparison)
  SELECT 
    ce.start_date::TIMESTAMPTZ as start_time,
    (ce.end_date + 1)::TIMESTAMPTZ as end_time, -- Exclusive end
    ce.title as event_title,
    ce.event_type,
    ce.all_day as is_all_day
  FROM calendar_events ce
  WHERE ce.user_id = p_user_id
    AND ce.status != 'cancelled'
    AND ce.all_day = true
    AND ce.start_date <= p_end_time::DATE
    AND ce.end_date >= p_start_time::DATE
  ORDER BY start_time;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

