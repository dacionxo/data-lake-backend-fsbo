-- Trigger Links Schema
-- This schema supports trigger links for tracking customer actions in SMS and emails

-- Trigger Links table
CREATE TABLE IF NOT EXISTS trigger_links (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  link_url TEXT NOT NULL,
  link_key TEXT NOT NULL UNIQUE, -- Unique key for tracking (e.g., "offer-2024", "newsletter-signup")
  description TEXT,
  click_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger Link Clicks table (for tracking individual clicks)
CREATE TABLE IF NOT EXISTS trigger_link_clicks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trigger_link_id UUID NOT NULL REFERENCES trigger_links(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  clicked_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT,
  referrer TEXT,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_trigger_links_user_id ON trigger_links(user_id);
CREATE INDEX IF NOT EXISTS idx_trigger_links_link_key ON trigger_links(link_key);
CREATE INDEX IF NOT EXISTS idx_trigger_link_clicks_trigger_link_id ON trigger_link_clicks(trigger_link_id);
CREATE INDEX IF NOT EXISTS idx_trigger_link_clicks_user_id ON trigger_link_clicks(user_id);
CREATE INDEX IF NOT EXISTS idx_trigger_link_clicks_clicked_at ON trigger_link_clicks(clicked_at);

-- RLS Policies
ALTER TABLE trigger_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE trigger_link_clicks ENABLE ROW LEVEL SECURITY;

-- Trigger Links policies
DROP POLICY IF EXISTS "Users can view their own trigger links" ON trigger_links;
CREATE POLICY "Users can view their own trigger links"
  ON trigger_links FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own trigger links" ON trigger_links;
CREATE POLICY "Users can insert their own trigger links"
  ON trigger_links FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own trigger links" ON trigger_links;
CREATE POLICY "Users can update their own trigger links"
  ON trigger_links FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own trigger links" ON trigger_links;
CREATE POLICY "Users can delete their own trigger links"
  ON trigger_links FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger Link Clicks policies
DROP POLICY IF EXISTS "Users can view clicks for their trigger links" ON trigger_link_clicks;
CREATE POLICY "Users can view clicks for their trigger links"
  ON trigger_link_clicks FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert clicks for their trigger links" ON trigger_link_clicks;
CREATE POLICY "Users can insert clicks for their trigger links"
  ON trigger_link_clicks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
DROP TRIGGER IF EXISTS update_trigger_links_updated_at ON trigger_links;
CREATE TRIGGER update_trigger_links_updated_at
  BEFORE UPDATE ON trigger_links
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

