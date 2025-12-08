-- ============================================================================
-- Update RLS Policies for fsbo_leads to allow service_role
-- ============================================================================
-- This script updates the RLS policies for fsbo_leads table to allow
-- both authenticated users and service_role to perform operations.
-- 
-- Run this in your Supabase SQL Editor to fix the RLS policy violations.
-- ============================================================================

-- Drop existing policies
DROP POLICY IF EXISTS "All authenticated users can view fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can insert fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can update fsbo_leads" ON fsbo_leads;
DROP POLICY IF EXISTS "Authenticated users can delete fsbo_leads" ON fsbo_leads;

-- Recreate policies with service_role support
CREATE POLICY "All authenticated users can view fsbo_leads" ON fsbo_leads
  FOR SELECT USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can insert fsbo_leads" ON fsbo_leads
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can update fsbo_leads" ON fsbo_leads
  FOR UPDATE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

CREATE POLICY "Authenticated users can delete fsbo_leads" ON fsbo_leads
  FOR DELETE USING (auth.role() = 'authenticated' OR auth.role() = 'service_role');

-- ============================================================================
-- Verification
-- ============================================================================
SELECT 'FSBO leads RLS policies updated successfully!' as status;

