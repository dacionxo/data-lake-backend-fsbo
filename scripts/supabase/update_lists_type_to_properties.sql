-- ============================================================================
-- Update Lists Type from 'company' to 'properties'
-- ============================================================================
-- This migration updates existing lists and the constraint to use 'properties'
-- instead of 'company'
-- ============================================================================

-- Update existing data
UPDATE lists SET type = 'properties' WHERE type = 'company';

-- Drop the old constraint
ALTER TABLE lists DROP CONSTRAINT IF EXISTS lists_type_check;

-- Add the new constraint
ALTER TABLE lists ADD CONSTRAINT lists_type_check CHECK (type IN ('people', 'properties'));

-- Update list_items item_type if needed (keeping 'company' for backward compatibility with existing data)
-- Note: item_type can still be 'company' as it refers to company records, not list types
-- Only the lists.type field is changing from 'company' to 'properties'

