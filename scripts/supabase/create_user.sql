-- ============================================================================
-- Create User Script
-- ============================================================================
-- This script creates a user in Supabase Auth
-- 
-- IMPORTANT: This requires superuser/admin access to the auth schema.
-- For most users, it's better to use the Supabase Dashboard or Auth API.
-- 
-- To use this script:
-- 1. Go to Supabase Dashboard → SQL Editor
-- 2. Run this script (requires admin privileges)
-- ============================================================================

-- Create user in auth.users table
-- Note: This requires direct access to the auth schema which may not be available
-- The recommended approach is to use the Supabase Dashboard or Auth API

-- Option 1: Using Supabase Dashboard (RECOMMENDED)
-- 1. Go to Authentication → Users
-- 2. Click "Add user" → "Create new user"
-- 3. Enter email and password
-- 4. Enable "Auto Confirm User"

-- Option 2: Using Supabase Management API (if you have API access)
-- POST https://<project-ref>.supabase.co/auth/v1/admin/users
-- Headers: {
--   "apikey": "<service-role-key>",
--   "Authorization": "Bearer <service-role-key>",
--   "Content-Type": "application/json"
-- }
-- Body: {
--   "email": "tyquanwilkerson1118345@gmail.com",
--   "password": "Flower12!",
--   "email_confirm": true,
--   "user_metadata": {}
-- }

-- Option 3: Direct SQL (requires superuser access - NOT RECOMMENDED)
-- WARNING: This bypasses Supabase Auth security and should only be used
-- in development or if you have explicit permission from Supabase support.

-- DO NOT run this unless you have superuser access:
/*
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  confirmation_token,
  recovery_token
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'tyquanwilkerson1118345@gmail.com',
  crypt('Flower12!', gen_salt('bf')),
  NOW(),
  NOW(),
  NOW(),
  '{"provider":"email","providers":["email"]}',
  '{}',
  false,
  '',
  ''
);
*/

-- ============================================================================
-- After creating the user, the handle_new_user() trigger will automatically
-- create a corresponding record in the public.users table
-- ============================================================================

