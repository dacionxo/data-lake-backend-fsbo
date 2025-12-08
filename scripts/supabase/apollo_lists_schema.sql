-- ============================================================================
-- Apollo-Grade Lists System - Complete Database Schema
-- ============================================================================
-- World-class many-to-many relationship for lists and leads
-- Matches Apollo.io, Clay, and DealMachine architecture
-- ============================================================================

-- Drop existing tables if they exist (for clean migration)
DROP TABLE IF EXISTS list_memberships CASCADE;
DROP TABLE IF EXISTS lists CASCADE;

-- ============================================================================
-- LISTS TABLE
-- ============================================================================
-- Stores user-created lists for organizing prospects
CREATE TABLE lists (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('people', 'properties')),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, name)
);

-- ============================================================================
-- LIST_MEMBERSHIPS TABLE (The Powerful Link Table)
-- ============================================================================
-- Many-to-many relationship between lists and items
-- This is the 160-IQ part - fully normalized, zero duplication
CREATE TABLE list_memberships (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  list_id UUID REFERENCES lists(id) ON DELETE CASCADE NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('listing', 'contact', 'company')),
  item_id TEXT NOT NULL, -- References listing_id, contact.id, or company.id
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(list_id, item_type, item_id) -- Prevents duplicates
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX idx_lists_user_id ON lists(user_id);
CREATE INDEX idx_lists_type ON lists(type);
CREATE INDEX idx_lists_updated_at ON lists(updated_at DESC);
CREATE INDEX idx_lists_user_type ON lists(user_id, type);

CREATE INDEX idx_list_memberships_list_id ON list_memberships(list_id);
CREATE INDEX idx_list_memberships_item ON list_memberships(item_type, item_id);
CREATE INDEX idx_list_memberships_created_at ON list_memberships(created_at DESC);
CREATE INDEX idx_list_memberships_composite ON list_memberships(list_id, item_type, item_id);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Update lists.updated_at when list_memberships change
CREATE OR REPLACE FUNCTION update_lists_updated_at_on_membership_change()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lists
  SET updated_at = NOW()
  WHERE id = COALESCE(NEW.list_id, OLD.list_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger to update list timestamp when memberships change
CREATE TRIGGER trigger_update_list_on_membership_change
  AFTER INSERT OR UPDATE OR DELETE ON list_memberships
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_membership_change();

-- Function to get list item count
CREATE OR REPLACE FUNCTION get_list_item_count(list_uuid UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM list_memberships
    WHERE list_id = list_uuid
  );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_memberships ENABLE ROW LEVEL SECURITY;

-- Users can only see their own lists
CREATE POLICY "Users can view own lists"
  ON lists FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own lists
CREATE POLICY "Users can create own lists"
  ON lists FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own lists
CREATE POLICY "Users can update own lists"
  ON lists FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Users can delete their own lists
CREATE POLICY "Users can delete own lists"
  ON lists FOR DELETE
  USING (auth.uid() = user_id);

-- Users can view memberships for their own lists
CREATE POLICY "Users can view own list memberships"
  ON list_memberships FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_memberships.list_id
      AND lists.user_id = auth.uid()
    )
  );

-- Users can create memberships for their own lists
CREATE POLICY "Users can create own list memberships"
  ON list_memberships FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_memberships.list_id
      AND lists.user_id = auth.uid()
    )
  );

-- Users can delete memberships from their own lists
CREATE POLICY "Users can delete own list memberships"
  ON list_memberships FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM lists
      WHERE lists.id = list_memberships.list_id
      AND lists.user_id = auth.uid()
    )
  );

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
-- If you have existing list_items table, migrate data:
-- 
-- INSERT INTO list_memberships (list_id, item_type, item_id, created_at)
-- SELECT list_id, item_type, item_id, created_at
-- FROM list_items
-- ON CONFLICT (list_id, item_type, item_id) DO NOTHING;
-- 
-- Then drop the old table:
-- DROP TABLE IF EXISTS list_items CASCADE;

