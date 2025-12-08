# Calendar Environment Variables Setup Guide

This guide explains all environment variables needed for the calendar system and where to set them.

## Required Environment Variables

### 1. CALENDAR_SERVICE_KEY

**Purpose:** Authenticates cron jobs and internal API calls for calendar operations.

**Where to Set:**

#### For Vercel Production:

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Click **Add New**
5. Enter:
   - **Name:** `CALENDAR_SERVICE_KEY`
   - **Value:** Generate a secure random string (see below)
   - **Environment:** Select all (Production, Preview, Development)
6. Click **Save**

#### For Local Development:

Add to your `.env.local` file in the project root:

```env
CALENDAR_SERVICE_KEY=your_secure_random_string_here
```

**How to Generate a Secure Value:**

You can generate a secure random string using any of these methods:

**Option 1: Using Node.js (Recommended)**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

**Option 2: Using OpenSSL**
```bash
openssl rand -hex 32
```

**Option 3: Using PowerShell (Windows)**
```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
```

**Option 4: Online Generator**
- Visit: https://randomkeygen.com/
- Use a "CodeIgniter Encryption Keys" or "Fort Knox Passwords"
- Copy a 64-character string

**Example Value:**
```
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
```

**Security Notes:**
- Use a long, random string (at least 32 characters, preferably 64)
- Never commit this value to version control
- Use different values for development and production
- Keep it secret - treat it like a password

---

### 2. CRON_SECRET

**Purpose:** Authenticates Vercel cron job requests (alternative to CALENDAR_SERVICE_KEY).

**Where to Set:**

#### For Vercel Production:

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Click **Add New**
5. Enter:
   - **Name:** `CRON_SECRET`
   - **Value:** Generate a secure random string (same method as above)
   - **Environment:** Select all (Production, Preview, Development)
6. Click **Save**

#### For Local Development:

Add to your `.env.local` file:

```env
CRON_SECRET=your_secure_random_string_here
```

**Note:** Vercel automatically sets `x-vercel-cron-secret` header when calling cron jobs, but you can also use `CRON_SECRET` for manual testing.

---

### 3. Google Calendar OAuth Variables

**GOOGLE_CLIENT_ID** and **GOOGLE_CLIENT_SECRET**

See `GOOGLE_CALENDAR_SETUP.md` for detailed instructions on obtaining these from Google Cloud Console.

**Where to Set:**

#### For Vercel Production:

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Add both variables:
   - `GOOGLE_CLIENT_ID` - Your Google OAuth Client ID
   - `GOOGLE_CLIENT_SECRET` - Your Google OAuth Client Secret
5. Set for all environments (Production, Preview, Development)

#### For Local Development:

Add to `.env.local`:

```env
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
```

---

### 4. Supabase Variables

**NEXT_PUBLIC_SUPABASE_URL** and **SUPABASE_SERVICE_ROLE_KEY**

These should already be set if you're using Supabase.

**Where to Find:**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings** → **API**
4. Copy:
   - **Project URL** → `NEXT_PUBLIC_SUPABASE_URL`
   - **service_role** key → `SUPABASE_SERVICE_ROLE_KEY`

---

### 5. App URL

**NEXT_PUBLIC_APP_URL**

**Where to Set:**

#### For Vercel Production:

Set to your production domain:
```env
NEXT_PUBLIC_APP_URL=https://www.growyourdigitalleverage.com
```

**Important:** No trailing slash!

#### For Local Development:

```env
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

---

## Complete Environment Variables Checklist

### Required for Calendar System:

- [ ] `CALENDAR_SERVICE_KEY` - Custom service key for cron authentication
- [ ] `CRON_SECRET` - Alternative cron authentication (optional, Vercel provides this automatically)
- [ ] `GOOGLE_CLIENT_ID` - Google OAuth Client ID
- [ ] `GOOGLE_CLIENT_SECRET` - Google OAuth Client Secret
- [ ] `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- [ ] `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key
- [ ] `NEXT_PUBLIC_APP_URL` - Application URL (no trailing slash)

### Optional (for email reminders):

- [ ] `RESEND_API_KEY` - Resend API key for sending email reminders
- [ ] `RESEND_FROM_EMAIL` - Email address to send from (e.g., `noreply@yourdomain.com`)

---

## Quick Setup Script

You can use this PowerShell script to generate secure keys:

```powershell
# Generate CALENDAR_SERVICE_KEY
$calendarKey = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
Write-Host "CALENDAR_SERVICE_KEY=$calendarKey"

# Generate CRON_SECRET
$cronSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
Write-Host "CRON_SECRET=$cronSecret"
```

---

## Verification

After setting environment variables:

1. **For Vercel:** Redeploy your application
2. **For Local:** Restart your development server
3. Check cron job logs in Vercel dashboard to verify authentication works

---

## Troubleshooting

### Cron jobs returning "Unauthorized"
- Verify `CALENDAR_SERVICE_KEY` is set correctly
- Check that the value matches in all environments
- Ensure no extra spaces or quotes in the value
- Redeploy after adding/changing environment variables

### Environment variables not loading
- **Vercel:** Make sure you've redeployed after adding variables
- **Local:** Restart the dev server (`npm run dev`)
- Check that variable names match exactly (case-sensitive)
- Verify `.env.local` is in the project root (not in a subdirectory)

---

## Security Best Practices

1. **Never commit** `.env.local` to version control
2. **Use different keys** for development and production
3. **Rotate keys** if they're accidentally exposed
4. **Use long, random strings** (64+ characters)
5. **Restrict access** to environment variables in Vercel
6. **Monitor usage** - Check logs for unauthorized access attempts

---

## Summary

The `CALENDAR_SERVICE_KEY` is a **custom environment variable you need to create**. It's not provided by any service - you generate it yourself and set it in:

- **Vercel:** Settings → Environment Variables
- **Local:** `.env.local` file

Generate a secure random string (64 characters recommended) and use it as the value. This key authenticates your cron jobs to prevent unauthorized access.

