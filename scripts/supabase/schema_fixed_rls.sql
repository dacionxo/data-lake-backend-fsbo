-- ============================================================================
-- FIXED RLS POLICIES FOR USER SIGNUP
-- ============================================================================
-- This file contains improved RLS policies and a trigger to auto-create
-- user profiles when auth users are created.
-- 
-- INSTRUCTIONS:
-- 1. Go to your Supabase Dashboard
-- 2. Navigate to SQL Editor
-- 3. Click "New Query"
-- 4. Copy and paste this entire file
-- 5. Click "Run" (or press Ctrl+Enter)
-- 6. Wait for "Success" message
-- ============================================================================

-- ============================================================================
-- DROP EXISTING POLICIES (to replace them)
-- ============================================================================

DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;

-- ============================================================================
-- IMPROVED RLS POLICIES FOR USERS TABLE
-- ============================================================================

-- Allow users to view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT 
  USING (auth.uid() = id);

-- Allow users to insert their own profile (when id matches their auth.uid())
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT 
  WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE 
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================================
-- AUTO-CREATE USER PROFILE TRIGGER
-- ============================================================================
-- This trigger automatically creates a profile in the public.users table
-- when a new user is created in auth.users. This ensures profiles are
-- always created, even if the API route fails.

-- Function to handle new user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, trial_end, is_subscribed, plan_tier)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email::text, 'User'),
    'user',
    NOW() + INTERVAL '7 days',
    false,
    'free'
  )
  ON CONFLICT (id) DO NOTHING; -- Don't error if profile already exists
  RETURN NEW;
END;
$$;

-- Drop trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create trigger on auth.users table
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT 'RLS policies and trigger updated successfully!' as status;

