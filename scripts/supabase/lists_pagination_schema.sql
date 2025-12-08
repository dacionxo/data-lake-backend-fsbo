-- ============================================================================
-- Lists Pagination Schema
-- ============================================================================
-- This schema adds pagination support for lists and list_memberships
-- Includes optimized indexes, helper functions, and optional pagination preferences
-- ============================================================================

-- ============================================================================
-- PAGINATION OPTIMIZED INDEXES
-- ============================================================================
-- These indexes optimize common pagination queries for list_memberships

-- Index for pagination by list_id and created_at (most common sort)
-- This supports: ORDER BY created_at DESC/OFFSET/LIMIT queries
CREATE INDEX IF NOT EXISTS idx_list_memberships_list_id_created_at 
  ON list_memberships(list_id, created_at DESC);

-- Index for pagination by list_id, item_type, and created_at
-- This supports filtered pagination: WHERE list_id = X AND item_type = Y ORDER BY created_at
CREATE INDEX IF NOT EXISTS idx_list_memberships_list_type_created_at 
  ON list_memberships(list_id, item_type, created_at DESC);

-- Index for pagination by list_id and item_id (for sorting by item_id)
CREATE INDEX IF NOT EXISTS idx_list_memberships_list_id_item_id 
  ON list_memberships(list_id, item_id);

-- Composite index for efficient count queries with filters
CREATE INDEX IF NOT EXISTS idx_list_memberships_list_item_type 
  ON list_memberships(list_id, item_type) 
  WHERE item_type IS NOT NULL;

-- ============================================================================
-- PAGINATION HELPER FUNCTIONS
-- ============================================================================

-- Function to get paginated list memberships
-- Usage: SELECT * FROM get_list_memberships_paginated('list_id_here', 0, 50, 'listing');
CREATE OR REPLACE FUNCTION get_list_memberships_paginated(
  p_list_id UUID,
  p_offset INTEGER DEFAULT 0,
  p_limit INTEGER DEFAULT 50,
  p_item_type TEXT DEFAULT NULL,
  p_sort_by TEXT DEFAULT 'created_at',
  p_sort_order TEXT DEFAULT 'desc'
)
RETURNS TABLE (
  id UUID,
  list_id UUID,
  item_type TEXT,
  item_id TEXT,
  created_at TIMESTAMPTZ
) 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_sort_column TEXT;
  v_ascending BOOLEAN;
BEGIN
  -- Validate and set sort column
  IF p_sort_by = 'created_at' OR p_sort_by = 'item_id' THEN
    v_sort_column := p_sort_by;
  ELSE
    v_sort_column := 'created_at';
  END IF;
  
  -- Validate and set sort order
  v_ascending := LOWER(p_sort_order) = 'asc';
  
  -- Build and execute query
  RETURN QUERY
  SELECT 
    lm.id,
    lm.list_id,
    lm.item_type,
    lm.item_id,
    lm.created_at
  FROM list_memberships lm
  WHERE lm.list_id = p_list_id
    AND (p_item_type IS NULL OR lm.item_type = p_item_type)
  ORDER BY 
    CASE 
      WHEN v_sort_column = 'created_at' AND v_ascending THEN lm.created_at
    END ASC,
    CASE 
      WHEN v_sort_column = 'created_at' AND NOT v_ascending THEN lm.created_at
    END DESC,
    CASE 
      WHEN v_sort_column = 'item_id' AND v_ascending THEN lm.item_id
    END ASC,
    CASE 
      WHEN v_sort_column = 'item_id' AND NOT v_ascending THEN lm.item_id
    END DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

-- Function to get total count of items in a list (for pagination metadata)
-- Usage: SELECT get_list_memberships_count('list_id_here', 'listing');
CREATE OR REPLACE FUNCTION get_list_memberships_count(
  p_list_id UUID,
  p_item_type TEXT DEFAULT NULL
)
RETURNS INTEGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM list_memberships
  WHERE list_id = p_list_id
    AND (p_item_type IS NULL OR item_type = p_item_type);
  
  RETURN v_count;
END;
$$;

-- Function to get pagination metadata (count, total pages, etc.)
-- Usage: SELECT * FROM get_list_memberships_pagination_metadata('list_id_here', 20, 'listing');
CREATE OR REPLACE FUNCTION get_list_memberships_pagination_metadata(
  p_list_id UUID,
  p_page_size INTEGER DEFAULT 20,
  p_item_type TEXT DEFAULT NULL
)
RETURNS TABLE (
  total_count INTEGER,
  total_pages INTEGER,
  page_size INTEGER,
  has_next_page BOOLEAN,
  has_previous_page BOOLEAN
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_count INTEGER;
  v_total_pages INTEGER;
BEGIN
  -- Get total count
  SELECT get_list_memberships_count(p_list_id, p_item_type) INTO v_total_count;
  
  -- Calculate total pages
  v_total_pages := CASE 
    WHEN v_total_count = 0 THEN 0
    ELSE CEIL(v_total_count::NUMERIC / GREATEST(p_page_size, 1))
  END;
  
  RETURN QUERY
  SELECT 
    v_total_count as total_count,
    v_total_pages as total_pages,
    p_page_size as page_size,
    (v_total_count > p_page_size) as has_next_page,
    FALSE as has_previous_page; -- Always false for first page, adjust based on current page in application
END;
$$;

-- ============================================================================
-- OPTIONAL: PAGINATION PREFERENCES TABLE
-- ============================================================================
-- This table stores user preferences for pagination (default page size, etc.)
-- Only create if you want to persist pagination preferences

CREATE TABLE IF NOT EXISTS list_pagination_preferences (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  list_id UUID REFERENCES lists(id) ON DELETE CASCADE,
  default_page_size INTEGER DEFAULT 20 CHECK (default_page_size > 0 AND default_page_size <= 100),
  default_sort_by TEXT DEFAULT 'created_at' CHECK (default_sort_by IN ('created_at', 'item_id')),
  default_sort_order TEXT DEFAULT 'desc' CHECK (default_sort_order IN ('asc', 'desc')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Allow one preference per user (global) or per list
  UNIQUE(user_id, list_id)
);

-- Index for quick lookup
CREATE INDEX IF NOT EXISTS idx_list_pagination_prefs_user_id 
  ON list_pagination_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_list_pagination_prefs_list_id 
  ON list_pagination_preferences(list_id) 
  WHERE list_id IS NOT NULL;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_list_pagination_prefs_updated_at()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER update_list_pagination_prefs_updated_at
  BEFORE UPDATE ON list_pagination_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_list_pagination_prefs_updated_at();

-- RLS Policies for pagination preferences
ALTER TABLE list_pagination_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own pagination preferences"
  ON list_pagination_preferences FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own pagination preferences"
  ON list_pagination_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pagination preferences"
  ON list_pagination_preferences FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own pagination preferences"
  ON list_pagination_preferences FOR DELETE
  USING (auth.uid() = user_id);

-- Function to get user's pagination preferences for a list
CREATE OR REPLACE FUNCTION get_list_pagination_preferences(
  p_user_id UUID,
  p_list_id UUID DEFAULT NULL
)
RETURNS TABLE (
  default_page_size INTEGER,
  default_sort_by TEXT,
  default_sort_order TEXT
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(lpp.default_page_size, 20) as default_page_size,
    COALESCE(lpp.default_sort_by, 'created_at') as default_sort_by,
    COALESCE(lpp.default_sort_order, 'desc') as default_sort_order
  FROM list_pagination_preferences lpp
  WHERE lpp.user_id = p_user_id
    AND (p_list_id IS NULL OR lpp.list_id = p_list_id)
  ORDER BY 
    CASE WHEN lpp.list_id IS NOT NULL THEN 0 ELSE 1 END, -- Prefer list-specific over global
    lpp.updated_at DESC
  LIMIT 1;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions on pagination functions
GRANT EXECUTE ON FUNCTION get_list_memberships_paginated(UUID, INTEGER, INTEGER, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_memberships_count(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_memberships_pagination_metadata(UUID, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_list_pagination_preferences(UUID, UUID) TO authenticated;

-- Grant permissions on pagination preferences table
GRANT ALL ON list_pagination_preferences TO authenticated;

-- ============================================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================================

COMMENT ON FUNCTION get_list_memberships_paginated IS 
  'Returns paginated list memberships with optional filtering by item_type. Supports sorting by created_at or item_id.';

COMMENT ON FUNCTION get_list_memberships_count IS 
  'Returns the total count of items in a list, optionally filtered by item_type. Used for pagination metadata.';

COMMENT ON FUNCTION get_list_memberships_pagination_metadata IS 
  'Returns pagination metadata including total count, total pages, and page size. Useful for building pagination UI.';

COMMENT ON TABLE list_pagination_preferences IS 
  'Stores user preferences for list pagination (default page size, sort order, etc.). Can be set globally per user or per list.';

COMMENT ON FUNCTION get_list_pagination_preferences IS 
  'Returns pagination preferences for a user, optionally filtered by list_id. Returns list-specific preferences if available, otherwise global preferences.';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify indexes were created
SELECT 'Pagination indexes created successfully!' as status;

-- Verify functions were created
SELECT 
  'Pagination functions created successfully!' as status,
  COUNT(*) as function_count
FROM pg_proc 
WHERE proname IN (
  'get_list_memberships_paginated',
  'get_list_memberships_count',
  'get_list_memberships_pagination_metadata',
  'get_list_pagination_preferences'
);

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================



