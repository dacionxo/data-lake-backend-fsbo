-- Snippets Schema
-- This schema supports text snippets, email snippets, and SMS snippets for quick message insertion

-- Snippet folders table
CREATE TABLE IF NOT EXISTS snippet_folders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- Snippets table
CREATE TABLE IF NOT EXISTS snippets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  body TEXT NOT NULL,
  folder_id UUID REFERENCES snippet_folders(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('text', 'email', 'sms')) DEFAULT 'text',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_snippet_folders_user_id ON snippet_folders(user_id);
CREATE INDEX IF NOT EXISTS idx_snippets_user_id ON snippets(user_id);
CREATE INDEX IF NOT EXISTS idx_snippets_folder_id ON snippets(folder_id);
CREATE INDEX IF NOT EXISTS idx_snippets_type ON snippets(type);

-- RLS Policies
ALTER TABLE snippet_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE snippets ENABLE ROW LEVEL SECURITY;

-- Snippet folders policies
DROP POLICY IF EXISTS "Users can view their own snippet folders" ON snippet_folders;
CREATE POLICY "Users can view their own snippet folders"
  ON snippet_folders FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own snippet folders" ON snippet_folders;
CREATE POLICY "Users can insert their own snippet folders"
  ON snippet_folders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own snippet folders" ON snippet_folders;
CREATE POLICY "Users can update their own snippet folders"
  ON snippet_folders FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own snippet folders" ON snippet_folders;
CREATE POLICY "Users can delete their own snippet folders"
  ON snippet_folders FOR DELETE
  USING (auth.uid() = user_id);

-- Snippets policies
DROP POLICY IF EXISTS "Users can view their own snippets" ON snippets;
CREATE POLICY "Users can view their own snippets"
  ON snippets FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own snippets" ON snippets;
CREATE POLICY "Users can insert their own snippets"
  ON snippets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own snippets" ON snippets;
CREATE POLICY "Users can update their own snippets"
  ON snippets FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own snippets" ON snippets;
CREATE POLICY "Users can delete their own snippets"
  ON snippets FOR DELETE
  USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_snippets_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_snippet_folders_updated_at ON snippet_folders;
CREATE TRIGGER update_snippet_folders_updated_at
  BEFORE UPDATE ON snippet_folders
  FOR EACH ROW
  EXECUTE FUNCTION update_snippets_updated_at_column();

DROP TRIGGER IF EXISTS update_snippets_updated_at ON snippets;
CREATE TRIGGER update_snippets_updated_at
  BEFORE UPDATE ON snippets
  FOR EACH ROW
  EXECUTE FUNCTION update_snippets_updated_at_column();



