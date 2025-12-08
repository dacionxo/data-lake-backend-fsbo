# Supabase Connection Setup Guide

This guide ensures that LeadMap is properly configured to use your Supabase connection.

## ✅ How LeadMap Connects to Supabase

LeadMap uses `@supabase/auth-helpers-nextjs` which **automatically reads** from environment variables. The Supabase client is initialized without explicitly passing credentials - it reads them from your environment automatically.

## 📋 Required Environment Variables

Create or update your `.env.local` file in the `LeadMap-main` directory with:

```env
# Supabase Configuration (REQUIRED)
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
```

### Where to Find These Values

1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **anon public** key → `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - **service_role** key → `SUPABASE_SERVICE_ROLE_KEY` (keep this secret!)

## 🔍 Verification Steps

### 1. Check Environment Variables Are Set

The app checks for these variables in several places:
- `app/page.tsx` - Home page
- `app/login/page.tsx` - Login page
- `app/signup/page.tsx` - Signup page
- `app/api/users/create-profile/route.ts` - User profile creation
- `app/api/auth/callback/route.ts` - OAuth callback

### 2. Verify Supabase Client Initialization

The Supabase clients are created using:
- **Client Components**: `createClientComponentClient()` - automatically reads from `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- **Server Components**: `createServerComponentClient()` - automatically reads from environment variables
- **API Routes**: `createRouteHandlerClient()` - automatically reads from environment variables

All of these functions **automatically** read from your `.env.local` file - no code changes needed!

### 3. Test the Connection

1. Restart your dev server after updating `.env.local`:
   ```bash
   npm run dev
   ```

2. Check the browser console and server logs for any Supabase connection errors

3. Try logging in or signing up - if the connection works, authentication should succeed

## 🔧 Files That Use Supabase

### Next.js App (Uses Environment Variables Automatically)
- `lib/supabase.ts` - Main Supabase client exports
- `lib/supabase-client-cache.ts` - Cached client instances
- `app/providers.tsx` - App context with Supabase client
- All API routes in `app/api/`
- All dashboard pages in `app/dashboard/`

### Python Scripts (Requires Environment Variables)
- `scripts/redfin-scraper/supabase_client.py` - Now requires `SUPABASE_URL` and `SUPABASE_KEY` environment variables

## ⚠️ Important Notes

1. **Never commit `.env.local`** - It's already in `.gitignore`
2. **Restart the dev server** after changing environment variables
3. **Service Role Key** should only be used server-side (in API routes)
4. **Anon Key** is safe to expose in client-side code (it's public)

## 🐛 Troubleshooting

### "Supabase environment variables not configured"
- Check that `.env.local` exists in `LeadMap-main/` directory
- Verify variable names are exactly: `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- Restart the dev server

### "Invalid API key" errors
- Verify you copied the correct keys from Supabase dashboard
- Check for extra spaces or quotes in `.env.local`
- Ensure you're using the **anon** key for client-side, not the service_role key

### Connection works but authentication fails
- Check that your Supabase project has Authentication enabled
- Verify email confirmation settings in Supabase Auth settings
- Check Supabase logs in the dashboard for detailed error messages

## 📝 Example `.env.local` File

```env
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=https://xxxxxxxxxxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4eHh4eHh4eHh4eHh4eHh4eCIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjE2MjM5MDIyLCJleHAiOjE5MzE4MTUwMjJ9.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4eHh4eHh4eHh4eHh4eHh4eCIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2MTYyMzkwMjIsImV4cCI6MTkzMTgxNTAyMn0.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Other environment variables...
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## ✅ Checklist

- [ ] `.env.local` file exists in `LeadMap-main/` directory
- [ ] `NEXT_PUBLIC_SUPABASE_URL` is set to your Supabase project URL
- [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY` is set to your Supabase anon key
- [ ] `SUPABASE_SERVICE_ROLE_KEY` is set to your Supabase service role key
- [ ] Dev server has been restarted after setting environment variables
- [ ] No hardcoded Supabase credentials in the codebase
- [ ] Can successfully connect to Supabase (check browser console/server logs)

