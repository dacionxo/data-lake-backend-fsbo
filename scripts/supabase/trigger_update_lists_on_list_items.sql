-- ============================================================================
-- Trigger to Update lists.updated_at When list_items Change
-- ============================================================================
-- This trigger automatically updates the lists.updated_at timestamp whenever
-- list_items are inserted, updated, or deleted. This ensures consistency
-- across all code paths that modify list_items.
-- ============================================================================

-- Function to update lists.updated_at when list_items change
CREATE OR REPLACE FUNCTION update_lists_updated_at_on_list_items_change()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update the parent list's updated_at timestamp
  IF TG_OP = 'DELETE' THEN
    -- For DELETE, use OLD.list_id
    UPDATE lists 
    SET updated_at = NOW() 
    WHERE id = OLD.list_id;
    RETURN OLD;
  ELSE
    -- For INSERT or UPDATE, use NEW.list_id
    UPDATE lists 
    SET updated_at = NOW() 
    WHERE id = NEW.list_id;
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for INSERT, UPDATE, and DELETE on list_items
DROP TRIGGER IF EXISTS update_lists_on_list_items_insert ON list_items;
CREATE TRIGGER update_lists_on_list_items_insert
  AFTER INSERT ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

DROP TRIGGER IF EXISTS update_lists_on_list_items_update ON list_items;
CREATE TRIGGER update_lists_on_list_items_update
  AFTER UPDATE ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

DROP TRIGGER IF EXISTS update_lists_on_list_items_delete ON list_items;
CREATE TRIGGER update_lists_on_list_items_delete
  AFTER DELETE ON list_items
  FOR EACH ROW
  EXECUTE FUNCTION update_lists_updated_at_on_list_items_change();

-- ============================================================================
-- Verification Query
-- ============================================================================
-- Run this to verify the trigger works:
-- 
-- 1. Get a list_id: SELECT id FROM lists LIMIT 1;
-- 2. Note the updated_at: SELECT id, updated_at FROM lists WHERE id = '<list_id>';
-- 3. Insert an item: INSERT INTO list_items (list_id, item_type, item_id) VALUES ('<list_id>', 'listing', 'test-id');
-- 4. Check updated_at changed: SELECT id, updated_at FROM lists WHERE id = '<list_id>';
-- 5. Clean up: DELETE FROM list_items WHERE item_id = 'test-id';
-- ============================================================================




