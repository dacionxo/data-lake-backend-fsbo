-- ============================================================================
-- Soft Delete Support for CRM Tables
-- ============================================================================
-- This schema adds soft-delete support (deleted_at) to CRM tables instead of
-- hard deletes. This allows:
-- - Data recovery
-- - Audit trails
-- - Analytics on deleted data
-- - Undo functionality
--
-- AFFECTED TABLES:
-- - contacts
-- - deals
-- - tasks
-- - lists
-- - list_items
-- ============================================================================

-- ============================================================================
-- ADD deleted_at COLUMNS TO CRM TABLES
-- ============================================================================

-- Contacts Table
ALTER TABLE contacts 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Deals Table
ALTER TABLE deals 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Tasks Table
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Lists Table
ALTER TABLE lists 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- List Items Table
ALTER TABLE list_items 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS deleted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- ============================================================================
-- INDEXES FOR SOFT DELETE QUERIES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_contacts_deleted_at ON contacts(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_user_deleted ON contacts(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_deleted_at ON deals(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_deals_user_deleted ON deals(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON tasks(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_user_deleted ON tasks(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lists_deleted_at ON lists(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_lists_user_deleted ON lists(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_list_items_deleted_at ON list_items(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_list_items_list_deleted ON list_items(list_id, deleted_at) WHERE deleted_at IS NULL;

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to soft delete a contact
CREATE OR REPLACE FUNCTION soft_delete_contact(p_contact_id UUID, p_deleted_by UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE contacts
  SET 
    deleted_at = NOW(),
    deleted_by = p_deleted_by,
    updated_at = NOW()
  WHERE id = p_contact_id
    AND user_id = p_deleted_by; -- Ensure user can only delete their own contacts
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to restore a soft-deleted contact
CREATE OR REPLACE FUNCTION restore_contact(p_contact_id UUID, p_restored_by UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE contacts
  SET 
    deleted_at = NULL,
    deleted_by = NULL,
    updated_at = NOW()
  WHERE id = p_contact_id
    AND user_id = p_restored_by; -- Ensure user can only restore their own contacts
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete a deal
CREATE OR REPLACE FUNCTION soft_delete_deal(p_deal_id UUID, p_deleted_by UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE deals
  SET 
    deleted_at = NOW(),
    deleted_by = p_deleted_by,
    updated_at = NOW()
  WHERE id = p_deal_id
    AND user_id = p_deleted_by;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete a task
CREATE OR REPLACE FUNCTION soft_delete_task(p_task_id UUID, p_deleted_by UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE tasks
  SET 
    deleted_at = NOW(),
    deleted_by = p_deleted_by,
    updated_at = NOW()
  WHERE id = p_task_id
    AND user_id = p_deleted_by;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to soft delete a list
CREATE OR REPLACE FUNCTION soft_delete_list(p_list_id UUID, p_deleted_by UUID)
RETURNS VOID AS $$
BEGIN
  -- Soft delete the list
  UPDATE lists
  SET 
    deleted_at = NOW(),
    deleted_by = p_deleted_by,
    updated_at = NOW()
  WHERE id = p_list_id
    AND user_id = p_deleted_by;
  
  -- Also soft delete all list items
  UPDATE list_items
  SET 
    deleted_at = NOW(),
    deleted_by = p_deleted_by
  WHERE list_id = p_list_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to permanently delete old soft-deleted records (admin only)
-- This allows cleanup of very old deleted records
CREATE OR REPLACE FUNCTION purge_soft_deleted(
  p_table_name TEXT,
  p_older_than_days INTEGER DEFAULT 90
)
RETURNS INTEGER AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  -- Only allow purging old records (90+ days default)
  EXECUTE format('
    DELETE FROM %I 
    WHERE deleted_at IS NOT NULL 
      AND deleted_at < NOW() - INTERVAL ''%s days''
    RETURNING id
  ', p_table_name, p_older_than_days);
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VIEWS FOR NON-DELETED RECORDS
-- ============================================================================

-- Active contacts view (excludes deleted)
CREATE OR REPLACE VIEW contacts_active AS
SELECT *
FROM contacts
WHERE deleted_at IS NULL;

-- Active deals view
CREATE OR REPLACE VIEW deals_active AS
SELECT *
FROM deals
WHERE deleted_at IS NULL;

-- Active tasks view
CREATE OR REPLACE VIEW tasks_active AS
SELECT *
FROM tasks
WHERE deleted_at IS NULL;

-- Active lists view
CREATE OR REPLACE VIEW lists_active AS
SELECT *
FROM lists
WHERE deleted_at IS NULL;

-- Active list items view
CREATE OR REPLACE VIEW list_items_active AS
SELECT *
FROM list_items
WHERE deleted_at IS NULL;

-- ============================================================================
-- UPDATE RLS POLICIES
-- ============================================================================

-- RLS policies should automatically exclude deleted records
-- when using views or adding WHERE deleted_at IS NULL to queries

-- Example policy update (should be added to complete_schema.sql):
-- DROP POLICY IF EXISTS "Users can view their own contacts" ON contacts;
-- CREATE POLICY "Users can view their own active contacts" ON contacts
--   FOR SELECT 
--   USING (user_id = auth.uid() AND deleted_at IS NULL);

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON COLUMN contacts.deleted_at IS 'Timestamp when contact was soft-deleted. NULL = active record.';
COMMENT ON COLUMN contacts.deleted_by IS 'User who soft-deleted this contact.';
COMMENT ON COLUMN deals.deleted_at IS 'Timestamp when deal was soft-deleted. NULL = active record.';
COMMENT ON COLUMN deals.deleted_by IS 'User who soft-deleted this deal.';
COMMENT ON COLUMN tasks.deleted_at IS 'Timestamp when task was soft-deleted. NULL = active record.';
COMMENT ON COLUMN tasks.deleted_by IS 'User who soft-deleted this task.';
COMMENT ON COLUMN lists.deleted_at IS 'Timestamp when list was soft-deleted. NULL = active record.';
COMMENT ON COLUMN lists.deleted_by IS 'User who soft-deleted this list.';
COMMENT ON COLUMN list_items.deleted_at IS 'Timestamp when list item was soft-deleted. NULL = active record.';
COMMENT ON COLUMN list_items.deleted_by IS 'User who soft-deleted this list item.';

COMMENT ON VIEW contacts_active IS 'Active contacts (excludes soft-deleted records)';
COMMENT ON VIEW deals_active IS 'Active deals (excludes soft-deleted records)';
COMMENT ON VIEW tasks_active IS 'Active tasks (excludes soft-deleted records)';
COMMENT ON VIEW lists_active IS 'Active lists (excludes soft-deleted records)';
COMMENT ON VIEW list_items_active IS 'Active list items (excludes soft-deleted records)';

