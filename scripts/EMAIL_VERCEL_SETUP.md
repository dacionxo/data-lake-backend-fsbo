# Email System - Complete Vercel Setup Guide

This is a **Vercel-focused** setup guide for deploying the email marketing system.

## 🎯 Overview

This system is optimized for Vercel deployment with:
- ✅ Automatic cron job activation via `vercel.json`
- ✅ Environment variables managed in Vercel dashboard
- ✅ Automatic authentication headers
- ✅ Built-in monitoring and logs

## 📋 Prerequisites

- Vercel account and project
- Supabase project (for database)
- Google Cloud Console account (for Gmail OAuth)
- Azure account (optional, for Outlook OAuth)

## ✅ Step 1: Database Setup (Supabase)

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **SQL Editor**
4. Run these SQL files in order:

### Run Migration 1: Email Mailboxes Schema

Copy and paste the contents of `supabase/email_mailboxes_schema.sql` and click **Run**.

### Run Migration 2: Email Campaigns Schema

Copy and paste the contents of `supabase/email_campaigns_schema.sql` and click **Run**.

✅ **Verify:** Both migrations should complete without errors.

## ✅ Step 2: Get Your Production Domain

Your production domain is:
- **Production:** `https://www.growyourdigitalleverage.com`
- **Local Development:** `http://localhost:3000`

**Important:** Use these exact domains for OAuth redirect URIs.

## ✅ Step 3: Configure Gmail OAuth

### 3.1 Create/Edit OAuth Client

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project (or create a new one)
3. Go to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth client ID** (or edit existing)
5. Select **Web application**

### 3.2 Add Redirect URIs

Add these **exact** redirect URIs:

**Production:**
```
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback
```

**Local Development:**
```
http://localhost:3000/api/mailboxes/oauth/gmail/callback
```

### 3.3 Enable Gmail API

1. Go to **APIs & Services** → **Library**
2. Search for **"Gmail API"**
3. Click **Enable**

### 3.4 Copy Credentials

After creating the OAuth client:
- Copy the **Client ID** (looks like: `123456789-abc...apps.googleusercontent.com`)
- Copy the **Client Secret** (looks like: `GOCSPX-abc...`)
- ⚠️ **Save these immediately** - the secret is only shown once!

## ✅ Step 4: Configure Outlook OAuth (Optional)

If you want to support Outlook mailboxes:

### 4.1 Create App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Go to **Azure Active Directory** → **App registrations**
3. Click **New registration**
4. Name: "LeadMap Email"
5. Select: **"Accounts in any organizational directory and personal Microsoft accounts"**
6. Click **Register**

### 4.2 Add Redirect URIs

1. Go to **Authentication**
2. Click **Add a platform** → **Web**
3. Add these **exact** redirect URIs:

**Production:**
```
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback
```

**Local Development:**
```
http://localhost:3000/api/mailboxes/oauth/outlook/callback
```

4. Click **Save**

### 4.3 Add API Permissions

1. Go to **API permissions**
2. Click **Add a permission** → **Microsoft Graph** → **Delegated permissions**
3. Add: `Mail.Send`
4. Click **Add permissions**

### 4.4 Create Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Copy the **Value** (only shown once!)
4. Note your **Application (client) ID** and **Directory (tenant) ID**

## ✅ Step 5: Generate CRON_SECRET

Generate a secure random string for the cron job authentication.

**Windows PowerShell:**
```powershell
$cronSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
Write-Host "CRON_SECRET=$cronSecret"
```

**Mac/Linux:**
```bash
openssl rand -base64 32
```

Copy the generated value - you'll add it to Vercel next.

## ✅ Step 6: Add Environment Variables to Vercel

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Click **Add New** for each variable below

### Required Variables

Add these one by one:

#### 1. Gmail OAuth
- **Key:** `GOOGLE_CLIENT_ID`
- **Value:** Your Google Client ID (from Step 3.4)
- **Environments:** ✅ Production ✅ Preview ✅ Development
- Click **Save**

- **Key:** `GOOGLE_CLIENT_SECRET`
- **Value:** Your Google Client Secret (from Step 3.4)
- **Environments:** ✅ Production ✅ Preview ✅ Development
- Click **Save**

#### 2. Outlook OAuth (Optional)
- **Key:** `MICROSOFT_CLIENT_ID`
- **Value:** Your Azure Application (client) ID (from Step 4.4)
- **Environments:** ✅ Production ✅ Preview ✅ Development
- Click **Save**

- **Key:** `MICROSOFT_CLIENT_SECRET`
- **Value:** Your Azure Client Secret (from Step 4.4)
- **Environments:** ✅ Production ✅ Preview ✅ Development
- Click **Save**

- **Key:** `MICROSOFT_TENANT_ID`
- **Value:** `common` (or your Directory tenant ID)
- **Environments:** ✅ Production ✅ Preview ✅ Development
- Click **Save**

#### 3. Cron Secret
- **Key:** `CRON_SECRET`
- **Value:** The generated secret from Step 5
- **Environments:** ✅ Production ✅ Preview ✅ Development
- Click **Save**

#### 4. App URL
- **Key:** `NEXT_PUBLIC_APP_URL`
- **Value:** `https://www.growyourdigitalleverage.com` - **NO trailing slash!**
- **Environments:** ✅ Production ✅ Preview ✅ Development
- Click **Save**

**Note:** For local development, you can override this with `http://localhost:3000` in your `.env.local` file.

#### 5. Verify Supabase Variables

Make sure these are already set (they should be if you're using Supabase):

- **Key:** `NEXT_PUBLIC_SUPABASE_URL`
- **Key:** `SUPABASE_SERVICE_ROLE_KEY`

If not, add them:
1. Go to [Supabase Dashboard](https://supabase.com/dashboard) → Your Project
2. Go to **Settings** → **API**
3. Copy **Project URL** → Add as `NEXT_PUBLIC_SUPABASE_URL`
4. Copy **service_role** key → Add as `SUPABASE_SERVICE_ROLE_KEY`

## ✅ Step 7: Deploy to Vercel

### Option A: Auto-Deploy (Recommended)

If you have GitHub/GitLab connected:

1. Commit your changes:
   ```bash
   git add .
   git commit -m "Add email marketing system"
   git push
   ```

2. Vercel will automatically deploy

### Option B: Manual Deploy

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Click **Deployments** → **Create Deployment**
4. Select your branch
5. Click **Deploy**

### ⚠️ Important: Redeploy After Adding Environment Variables

If you added environment variables after deployment:

1. Go to **Deployments** tab
2. Click **"..."** on the latest deployment
3. Click **"Redeploy"**
4. ⚠️ **Uncheck "Use existing Build Cache"** (important!)
5. Click **"Redeploy"**

## ✅ Step 8: Verify Cron Job

After deployment:

1. Go to Vercel Dashboard → Your Project
2. Click **Cron Jobs** in the left sidebar
3. You should see `/api/cron/process-emails` listed
4. Wait 1-2 minutes and refresh - you should see execution times
5. Click on the cron job to see execution logs

**If you don't see the cron job:**
- Verify `vercel.json` includes the cron configuration
- Check deployment logs for errors
- Ensure the deployment completed successfully

## ✅ Step 9: Test the System

### 9.1 Visit Your Deployed Site

Go to: [https://www.growyourdigitalleverage.com](https://www.growyourdigitalleverage.com)

### 9.2 Connect a Gmail Mailbox

1. Navigate to `/dashboard/email/mailboxes`
2. Click **"Connect Gmail"**
3. Complete OAuth flow
4. Mailbox should appear in the list

### 9.3 Send a Test Email

1. Go to `/dashboard/email/compose`
2. Select your mailbox
3. Enter recipient email
4. Enter subject and body
5. Click **"Send Now"**
6. Check recipient's inbox!

### 9.4 Verify Cron Job is Processing

1. Create a scheduled email or campaign
2. Wait 1-2 minutes
3. Check Vercel Dashboard → **Cron Jobs** → Click on `/api/cron/process-emails`
4. Should see execution logs showing processed emails

## 🐛 Troubleshooting

### Environment Variables Not Working

**Symptoms:** Errors about missing configuration

**Fix:**
1. Verify all variables are added in Vercel dashboard
2. Check variable names match exactly (case-sensitive)
3. **Redeploy** after adding variables (uncheck build cache)
4. Restart development server if testing locally

### OAuth Redirect URI Mismatch

**Symptoms:** "redirect_uri_mismatch" error

**Fix:**
1. Verify redirect URI in Google/Azure matches exactly
2. Production URL: `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback`
3. Local URL: `http://localhost:3000/api/mailboxes/oauth/gmail/callback`
4. No trailing slash!
5. Ensure `NEXT_PUBLIC_APP_URL` is set to `https://www.growyourdigitalleverage.com`

### Cron Job Not Running

**Symptoms:** No execution logs, emails not processing

**Fix:**
1. Verify `CRON_SECRET` is set in Vercel
2. Check **Cron Jobs** tab shows the job
3. Ensure deployment completed successfully
4. Check function logs for errors
5. Verify `vercel.json` has the cron job configuration

### Emails Not Sending

**Symptoms:** Emails stuck in "queued" status

**Fix:**
1. Check mailbox is active (`active = true`)
2. Check rate limits haven't been exceeded
3. Verify campaign status is "running"
4. Check Vercel function logs for errors
5. Verify OAuth tokens haven't expired

## ✅ Complete Checklist

- [ ] Database migrations run in Supabase
- [ ] Vercel domain identified
- [ ] Gmail OAuth configured with Vercel redirect URI
- [ ] Outlook OAuth configured (optional)
- [ ] CRON_SECRET generated
- [ ] All environment variables added to Vercel
- [ ] Variables set for all environments
- [ ] Application deployed to Vercel
- [ ] Redeployed after adding environment variables
- [ ] Cron job visible in Vercel dashboard
- [ ] Cron job showing execution logs
- [ ] Mailbox connected successfully
- [ ] Test email sent successfully
- [ ] Campaign emails being processed

## 📚 Next Steps

- Read [EMAIL_SYSTEM_IMPLEMENTATION.md](./EMAIL_SYSTEM_IMPLEMENTATION.md) for full feature list
- Read [EMAIL_QUICK_START.md](./EMAIL_QUICK_START.md) for quick reference
- Monitor cron job execution in Vercel dashboard
- Check email processing logs regularly

---

**🎉 Congratulations!** Your email marketing system is now live on Vercel!

