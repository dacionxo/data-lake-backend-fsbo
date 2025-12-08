-- Countdown Timers Table
CREATE TABLE IF NOT EXISTS countdown_timers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('end_date', 'duration')),
  end_date TIMESTAMPTZ,
  duration_seconds INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_countdown_timers_user_id ON countdown_timers(user_id);
CREATE INDEX IF NOT EXISTS idx_countdown_timers_type ON countdown_timers(type);

-- RLS Policies
ALTER TABLE countdown_timers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own timers" ON countdown_timers;
CREATE POLICY "Users can view their own timers"
  ON countdown_timers FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own timers" ON countdown_timers;
CREATE POLICY "Users can insert their own timers"
  ON countdown_timers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own timers" ON countdown_timers;
CREATE POLICY "Users can update their own timers"
  ON countdown_timers FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own timers" ON countdown_timers;
CREATE POLICY "Users can delete their own timers"
  ON countdown_timers FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_countdown_timers_updated_at ON countdown_timers;
CREATE TRIGGER update_countdown_timers_updated_at
  BEFORE UPDATE ON countdown_timers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();



