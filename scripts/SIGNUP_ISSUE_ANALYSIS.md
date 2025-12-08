# Signup Issue Analysis & Password Security

## Password Security ✅

**IMPORTANT: Supabase does NOT log or store passwords in plain text.**

- Passwords are **hashed using bcrypt** before storage
- Passwords are stored in the `auth.users` table (managed by Supabase Auth)
- The `public.users` table does NOT contain passwords
- Passwords are **never** logged, transmitted in plain text, or accessible via API
- The password field in `auth.users` is encrypted and cannot be read

## Signup Flow Analysis

The signup process works as follows:

1. **User submits signup form** → `SignUpPage.tsx` or `LandingPage.tsx`
2. **Supabase Auth creates user** → `supabase.auth.signUp()` creates entry in `auth.users`
3. **Profile creation** → `/api/users/create-profile` creates entry in `public.users`
4. **Redirect to dashboard** → User is redirected after successful signup

## Potential Issues

### 1. Email Confirmation Required
If email confirmation is enabled in Supabase:
- User account is created but marked as unconfirmed
- User must click confirmation link in email before they can sign in
- The profile creation might fail if the user isn't fully authenticated

**Solution**: Check Supabase Dashboard → Authentication → Settings → "Enable email confirmations"

### 2. RLS Policy Issues
The current RLS policy for user inserts:
```sql
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = (SELECT auth.uid()));
```

This is redundant and might cause issues. The API route uses service role key to bypass RLS, but if there's a timing issue, this could fail.

### 3. Service Role Key Not Configured
The API route requires `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS. If this is missing or incorrect, profile creation will fail.

**Check**: Verify `.env.local` has:
```
SUPABASE_SERVICE_ROLE_KEY=your_actual_service_role_key
```

### 4. Database Constraints
The `users` table has constraints:
- `id` must reference `auth.users(id)`
- `email` is required
- `name` is required

If any of these fail, the insert will be rejected.

## Recommended Fixes

1. **Update RLS Policies** - Make them more explicit and allow service role bypass
2. **Add Better Error Logging** - Log specific errors from Supabase
3. **Handle Email Confirmation** - Check if email confirmation is required and handle accordingly
4. **Add Database Trigger** - Auto-create profile when auth user is created

## Testing Steps

1. Check browser console for errors
2. Check server logs for API route errors
3. Verify Supabase Dashboard → Authentication → Users (see if user was created)
4. Verify Supabase Dashboard → Table Editor → users (see if profile was created)
5. Check Network tab in browser DevTools for API response

## Next Steps

See the updated RLS policies and database trigger in the schema fix below.

