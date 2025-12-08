-- ============================================================================
-- Update Calendar Connections Provider Types
-- ============================================================================
-- Adds support for microsoft365 and exchange providers
-- ============================================================================

-- Drop the existing check constraint
ALTER TABLE calendar_connections
DROP CONSTRAINT IF EXISTS calendar_connections_provider_check;

-- Add new check constraint with updated provider types
ALTER TABLE calendar_connections
ADD CONSTRAINT calendar_connections_provider_check 
  CHECK (provider IN ('google', 'outlook', 'microsoft365', 'exchange', 'icloud'));

-- Add comment
COMMENT ON COLUMN calendar_connections.provider IS 
  'Calendar provider: google, outlook (personal), microsoft365 (business), exchange (on-premise), or icloud';

