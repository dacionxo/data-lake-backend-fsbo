-- ============================================================================
-- Deals Form Fields Update
-- ============================================================================
-- This file adds new fields to the deals table for the enhanced deal form:
-- - closed_won_reason: Reason for winning the deal
-- - closed_lost_reason: Reason for losing the deal
-- ============================================================================

-- Add closed_won_reason and closed_lost_reason fields to deals table
ALTER TABLE deals 
ADD COLUMN IF NOT EXISTS closed_won_reason TEXT,
ADD COLUMN IF NOT EXISTS closed_lost_reason TEXT;

-- Add comments for documentation
COMMENT ON COLUMN deals.closed_won_reason IS 'Reason for winning the deal when stage is closed_won';
COMMENT ON COLUMN deals.closed_lost_reason IS 'Reason for losing the deal when stage is closed_lost';

