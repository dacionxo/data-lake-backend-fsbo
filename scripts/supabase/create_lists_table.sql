-- ============================================================================
-- Create Lists Table
-- ============================================================================
-- This migration creates the lists table for organizing contacts and companies
-- ============================================================================

-- Drop table if exists (for development)
DROP TABLE IF EXISTS lists CASCADE;
DROP TABLE IF EXISTS list_items CASCADE;

-- Lists Table
-- Stores user-created lists for organizing contacts and properties
CREATE TABLE lists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('people', 'properties')),
  description TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- List Items Table
-- Stores the relationship between lists and items (contacts/companies)
CREATE TABLE list_items (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  list_id UUID REFERENCES lists(id) ON DELETE CASCADE NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('contact', 'company', 'listing')),
  item_id TEXT NOT NULL, -- Can reference different tables based on item_type
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(list_id, item_type, item_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_lists_user_id ON lists(user_id);
CREATE INDEX idx_lists_type ON lists(type);
CREATE INDEX idx_lists_updated_at ON lists(updated_at DESC);
CREATE INDEX idx_list_items_list_id ON list_items(list_id);
CREATE INDEX idx_list_items_item ON list_items(item_type, item_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_lists_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_lists_updated_at
  BEFORE UPDATE ON lists
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at();

-- Enable Row Level Security
ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_items ENABLE ROW LEVEL SECURITY;

-- RLS Policies for lists
CREATE POLICY "Users can view their own lists"
  ON lists FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own lists"
  ON lists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own lists"
  ON lists FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own lists"
  ON lists FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for list_items
CREATE POLICY "Users can view items in their lists"
  ON list_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can add items to their lists"
  ON list_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete items from their lists"
  ON list_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_items.list_id
      AND lists.user_id = auth.uid()
    )
  );

-- Create a view to get list counts
CREATE OR REPLACE VIEW list_counts AS
SELECT 
  l.id,
  l.name,
  l.type,
  l.user_id,
  COUNT(li.id) as count
FROM lists l
LEFT JOIN list_items li ON l.id = li.list_id
GROUP BY l.id, l.name, l.type, l.user_id;

-- Grant permissions
GRANT ALL ON lists TO authenticated;
GRANT ALL ON list_items TO authenticated;
GRANT SELECT ON list_counts TO authenticated;

