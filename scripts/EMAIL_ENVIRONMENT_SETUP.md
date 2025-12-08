# Email System Environment Variables Setup Guide for Vercel

This guide will walk you through setting up all environment variables needed for the email marketing system on Vercel.

**🚀 Optimized for Vercel deployment.**

## 📋 Required Environment Variables

### 1. Gmail OAuth Credentials (for Gmail mailboxes)

These should already be set if you've configured Google Calendar integration. If not, follow these steps:

#### Getting Gmail OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project (or create a new one)
3. Go to **"APIs & Services"** > **"Credentials"**
4. Click **"Create Credentials"** > **"OAuth client ID"**
5. Select **"Web application"**
6. Add authorized redirect URIs:
   - **Local:** `http://localhost:3000/api/mailboxes/oauth/gmail/callback`
   - **Production:** `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback`
7. Click **"Create"** and copy the Client ID and Client Secret

**Required Scopes for Gmail:**
- `https://www.googleapis.com/auth/gmail.send` - Send emails
- `https://www.googleapis.com/auth/userinfo.email` - Get user email

#### Enable Gmail API

1. In Google Cloud Console, go to **"APIs & Services"** > **"Library"**
2. Search for **"Gmail API"**
3. Click **"Enable"**

### 2. Microsoft Outlook OAuth Credentials (for Outlook mailboxes)

#### Getting Microsoft OAuth Credentials

1. Go to [Azure Portal](https://portal.azure.com)
2. Go to **"Azure Active Directory"** > **"App registrations"**
3. Click **"New registration"**
4. Enter a name (e.g., "LeadMap Email")
5. Select **"Accounts in any organizational directory and personal Microsoft accounts"**
6. Add redirect URI:
   - **Type:** Web
   - **Local:** `http://localhost:3000/api/mailboxes/oauth/outlook/callback`
   - **Production:** `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback`
7. Click **"Register"**
8. Go to **"Certificates & secrets"** > **"New client secret"**
9. Copy the **Client ID** and **Client Secret**
10. Note your **Tenant ID** (or use "common")

**Required API Permissions:**
- `Mail.Send` - Send emails
- `offline_access` - Refresh tokens

### 3. Cron Secret (for email scheduler security)

This is a secure random string to protect your cron endpoint.

## 🔧 Setting Up Environment Variables on Vercel

**Primary Method: Vercel Dashboard (Recommended)**

This guide focuses on setting up environment variables in Vercel. For local development, see the quick reference at the end.

### Step 1: Get Your Vercel Domain

Before starting, get your Vercel production domain:
1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Your production domain is: `https://www.growyourdigitalleverage.com`
4. You'll use this for `NEXT_PUBLIC_APP_URL`

### Step 2: Add Variables to Vercel Dashboard

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **"Settings"** > **"Environment Variables"**
4. Click **"Add New"** for each variable below

---

### For Local Development (Optional)

Create or update `.env.local` in your project root for local testing:

```env
# Gmail OAuth (for Gmail mailboxes)
GOOGLE_CLIENT_ID=your_gmail_client_id_here.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your_gmail_client_secret_here

# Microsoft Outlook OAuth (for Outlook mailboxes)
MICROSOFT_CLIENT_ID=your_microsoft_client_id_here
MICROSOFT_CLIENT_SECRET=your_microsoft_client_secret_here
MICROSOFT_TENANT_ID=common  # Use "common" for personal accounts, or your tenant ID for organization

# Cron Secret (generate a secure random string)
CRON_SECRET=generate_a_secure_random_string_here_at_least_32_characters

# App URL (must match your OAuth redirect URIs)
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Supabase (should already be set)
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
```

### Generating CRON_SECRET

**On Windows (PowerShell):**
```powershell
$cronSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
Write-Host "CRON_SECRET=$cronSecret"
```

**On Mac/Linux:**
```bash
openssl rand -base64 32
```

**Or use online generator:**
- Visit: https://www.random.org/strings/
- Set length to 64
- Copy the generated string

---

## ✅ Adding Variables to Vercel (Step by Step)

Follow these steps to add each variable:

#### Gmail OAuth
- **Name:** `GOOGLE_CLIENT_ID`
- **Value:** Your Google Client ID
- **Environment:** Production, Preview, Development (select all)
- Click **"Save"**

- **Name:** `GOOGLE_CLIENT_SECRET`
- **Value:** Your Google Client Secret
- **Environment:** Production, Preview, Development (select all)
- Click **"Save"**

#### Microsoft Outlook OAuth
- **Name:** `MICROSOFT_CLIENT_ID`
- **Value:** Your Microsoft Client ID
- **Environment:** Production, Preview, Development (select all)
- Click **"Save"**

- **Name:** `MICROSOFT_CLIENT_SECRET`
- **Value:** Your Microsoft Client Secret
- **Environment:** Production, Preview, Development (select all)
- Click **"Save"**

- **Name:** `MICROSOFT_TENANT_ID`
- **Value:** `common` (or your tenant ID)
- **Environment:** Production, Preview, Development (select all)
- Click **"Save"**

#### Cron Secret
- **Name:** `CRON_SECRET`
- **Value:** Your secure random string (64 characters recommended)
- **Environment:** Production, Preview, Development (select all)
- Click **"Save"**

#### App URL
- **Name:** `NEXT_PUBLIC_APP_URL`
- **Value:** `https://www.growyourdigitalleverage.com` (no trailing slash!)
- **Environment:** Production, Preview, Development (select all)
- Click **"Save"**

**Note:** For local development, use `http://localhost:3000` in your `.env.local` file.

### After Adding All Variables

**⚠️ CRITICAL:** You must redeploy after adding environment variables:

1. Go to **"Deployments"** tab in Vercel dashboard
2. Click **"..."** (three dots) on the latest deployment
3. Click **"Redeploy"**
4. ⚠️ **Uncheck "Use existing Build Cache"** (very important!)
5. Click **"Redeploy"**

Without redeploying, your new environment variables won't be available to your application!

### Quick Add Script

To add all variables at once, you can use this format (but still need to add each individually in Vercel):

```env
GOOGLE_CLIENT_ID=your_gmail_client_id_here.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your_gmail_client_secret_here
MICROSOFT_CLIENT_ID=your_microsoft_client_id_here
MICROSOFT_CLIENT_SECRET=your_microsoft_client_secret_here
MICROSOFT_TENANT_ID=common
CRON_SECRET=your_generated_secret_64_characters
NEXT_PUBLIC_APP_URL=https://www.growyourdigitalleverage.com
```

## ✅ Verification Checklist

After setting up environment variables:

### Local Development:
- [ ] Created `.env.local` file
- [ ] Added all required variables
- [ ] Restarted development server (`npm run dev`)
- [ ] Can access `/dashboard/email/mailboxes` page
- [ ] Can see "Connect Gmail" and "Connect Outlook" buttons

### Production (Vercel):
- [ ] Added all environment variables in Vercel dashboard
- [ ] Set variables for all environments (Production, Preview, Development)
- [ ] Redeployed application
- [ ] Verified OAuth redirect URIs match your domain

## 🐛 Troubleshooting

### Error: "Google OAuth not configured"
- **Solution:** Make sure `GOOGLE_CLIENT_ID` is set in environment variables
- Restart development server after adding variables
- For Vercel, ensure you've redeployed after adding variables

### Error: "redirect_uri_mismatch" (Google)
- **Solution:** 
  1. Go to Google Cloud Console > Credentials
  2. Edit your OAuth client
  3. Add the exact redirect URIs:
     - Local: `http://localhost:3000/api/mailboxes/oauth/gmail/callback`
     - Production: `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback`
  4. Make sure `NEXT_PUBLIC_APP_URL` matches your domain (no trailing slash)

### Error: "Invalid redirect URI" (Microsoft)
- **Solution:**
  1. Go to Azure Portal > App registrations > Your app
  2. Go to "Authentication"
  3. Add redirect URIs:
     - Local: `http://localhost:3000/api/mailboxes/oauth/outlook/callback`
     - Production: `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback`
  4. Click "Save"

### Cron job returns "Unauthorized"
- **Solution:**
  1. Verify `CRON_SECRET` is set correctly
  2. Check that the value matches in vercel.json cron configuration
  3. For Vercel cron jobs, the header is automatically set
  4. For manual testing, use: `Authorization: Bearer YOUR_CRON_SECRET`

### Environment variables not loading
- **Vercel:** Make sure you've redeployed after adding variables
- **Local:** Restart your development server
- Check for typos in variable names
- Ensure no extra spaces or quotes around values

## 📝 Quick Reference

### Required Variables Summary:
```env
# Gmail
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...

# Outlook
MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...
MICROSOFT_TENANT_ID=common

# Security
CRON_SECRET=...

# App Config
NEXT_PUBLIC_APP_URL=https://www.growyourdigitalleverage.com

# Supabase (should already exist)
NEXT_PUBLIC_SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
```

## 🔐 Security Notes

- **Never commit** `.env.local` to git (it's in `.gitignore`)
- Store secrets securely in Vercel dashboard
- Rotate secrets periodically
- Use different OAuth apps for development and production if possible
- Keep `CRON_SECRET` private and long (64+ characters)

---

**Next Step:** After setting up environment variables, configure the cron job. See the cron setup section in `EMAIL_SYSTEM_IMPLEMENTATION.md`.

