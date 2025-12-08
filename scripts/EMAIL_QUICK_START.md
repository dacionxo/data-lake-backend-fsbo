# Email System Quick Start Guide for Vercel

Get your email marketing system up and running on Vercel in 5 steps!

**🚀 This guide is optimized for Vercel deployment.**

> **💡 For a comprehensive step-by-step guide with screenshots and detailed explanations, see [EMAIL_VERCEL_SETUP.md](./EMAIL_VERCEL_SETUP.md)**

## ✅ Step 1: Run Database Migrations

Run these SQL files in your Supabase SQL editor (in order):

1. `supabase/email_mailboxes_schema.sql` (if not already run)
2. `supabase/email_campaigns_schema.sql`

**How to run:**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **SQL Editor**
4. Copy and paste the contents of each SQL file
5. Click **Run**

## ✅ Step 2: Set Environment Variables on Vercel

### Generate CRON_SECRET

First, generate a secure random string for `CRON_SECRET`:

**Windows PowerShell:**
```powershell
$cronSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
Write-Host "CRON_SECRET=$cronSecret"
```

**Mac/Linux:**
```bash
openssl rand -base64 32
```

### Your Production Domain

Your domains are:
- **Production:** `https://www.growyourdigitalleverage.com`
- **Local Development:** `http://localhost:3000`

### Add Environment Variables to Vercel

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Add each variable below (click **Add** for each):

#### Required Variables:

```env
# Gmail OAuth (for Gmail mailboxes)
GOOGLE_CLIENT_ID=your_gmail_client_id_here
GOOGLE_CLIENT_SECRET=your_gmail_client_secret_here

# Outlook OAuth (optional - for Outlook mailboxes)
MICROSOFT_CLIENT_ID=your_microsoft_client_id_here
MICROSOFT_CLIENT_SECRET=your_microsoft_client_secret_here
MICROSOFT_TENANT_ID=common

# Cron Secret (paste the generated value from above)
CRON_SECRET=paste_your_generated_secret_here

# App URL (NO trailing slash!)
NEXT_PUBLIC_APP_URL=https://www.growyourdigitalleverage.com

# Supabase (should already exist, but verify)
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

**Important for each variable:**
- ✅ Set for **all environments** (Production, Preview, Development)
- ✅ Click **Save** after adding each variable

5. **After adding all variables, redeploy:**
   - Go to **Deployments** tab
   - Click **"..."** on the latest deployment
   - Click **"Redeploy"**
   - Uncheck **"Use existing Build Cache"** (important!)
   - Click **"Redeploy"**

**See [EMAIL_ENVIRONMENT_SETUP.md](./EMAIL_ENVIRONMENT_SETUP.md) for detailed OAuth setup instructions.**

## ✅ Step 3: Configure OAuth Redirect URIs for Vercel

**Important:** Use your **Vercel production domain** for the redirect URIs.

### Gmail OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Go to **APIs & Services** → **Credentials**
3. Edit your OAuth client (or create a new one)
4. Add these **exact** redirect URIs:
   - **Production:** `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback`
   - **Local:** `http://localhost:3000/api/mailboxes/oauth/gmail/callback`
5. Enable **Gmail API** in **APIs & Services** → **Library**
6. Copy the **Client ID** and **Client Secret** → Add to Vercel environment variables (Step 2)

**Required Scopes:**
- `https://www.googleapis.com/auth/gmail.send`
- `https://www.googleapis.com/auth/userinfo.email`

### Outlook OAuth (Optional)

1. Go to [Azure Portal](https://portal.azure.com)
2. Go to **Azure Active Directory** → **App registrations**
3. Create new registration or edit existing
4. Add these **exact** redirect URIs:
   - **Production:** `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback`
   - **Local:** `http://localhost:3000/api/mailboxes/oauth/outlook/callback`
5. Add API permission: `Mail.Send`
6. Copy the **Client ID** and **Client Secret** → Add to Vercel environment variables (Step 2)

**See [EMAIL_ENVIRONMENT_SETUP.md](./EMAIL_ENVIRONMENT_SETUP.md) for complete OAuth setup.**

## ✅ Step 4: Deploy to Vercel (Cron Job Auto-Activates!)

The cron job is already configured in `vercel.json` and will automatically activate when you deploy.

### Deploy Your Changes

1. **Commit and push your changes:**
   ```bash
   git add .
   git commit -m "Add email marketing system"
   git push
   ```

2. **Vercel will automatically deploy** (if you have auto-deploy enabled)

3. **OR manually deploy:**
   - Go to [Vercel Dashboard](https://vercel.com/dashboard)
   - Select your project
   - Click **"Deployments"** → **"Create Deployment"**
   - Select your branch and deploy

### Verify Cron Job

After deployment:

1. Go to your Vercel project dashboard
2. Click **"Cron Jobs"** tab (in the left sidebar)
3. You should see `/api/cron/process-emails` listed
4. It should show recent execution times (runs every minute)

**That's it!** Vercel automatically:
- ✅ Calls your endpoint every minute
- ✅ Sets authentication headers
- ✅ Handles retries and errors
- ✅ Provides logs and monitoring

**See [EMAIL_CRON_SETUP.md](./EMAIL_CRON_SETUP.md) for more details.**

## ✅ Step 5: Test the System on Vercel

### 1. Visit Your Deployed Site

Go to your Vercel deployment URL:
- `https://your-project.vercel.app`
- OR your custom domain

### 2. Connect a Mailbox

1. Go to `/dashboard/email/mailboxes`
2. Click **"Connect Gmail"** or **"Connect Outlook"**
3. Complete OAuth flow
4. Mailbox should appear in the list

### 3. Send a Test Email

1. Go to `/dashboard/email/compose`
2. Select your mailbox
3. Enter recipient email
4. Enter subject and body
5. Click **"Send Now"**
6. Check recipient's inbox!

### 4. Create a Campaign (Optional)

1. Go to `/dashboard/email/campaigns/new`
2. Fill in campaign details
3. Add email steps
4. Add recipients
5. Create campaign
6. View at `/dashboard/email/campaigns`

### 5. Verify Cron Job on Vercel

1. Wait 1-2 minutes after deployment
2. Go to Vercel Dashboard → Your Project → **Cron Jobs** tab
3. Should see `/api/cron/process-emails` with recent execution times
4. Click on the cron job to see execution logs
5. Check **Deployments** → Select deployment → **Function Logs** for detailed logs

## ✅ Verification Checklist for Vercel

- [ ] Database migrations run successfully in Supabase
- [ ] All environment variables set in Vercel dashboard
- [ ] Environment variables set for all environments (Production, Preview, Development)
- [ ] OAuth redirect URIs configured with Vercel domain
- [ ] Application redeployed after adding environment variables
- [ ] Cron job appears in Vercel dashboard → Cron Jobs tab
- [ ] Can access `/dashboard/email/mailboxes` on deployed site
- [ ] Mailbox connected successfully via OAuth
- [ ] Test email sent successfully
- [ ] Cron job showing execution logs every minute
- [ ] Queued emails are being processed

## 🐛 Common Issues

### "Google OAuth not configured"
- **Fix:** Set `GOOGLE_CLIENT_ID` in environment variables
- Restart dev server after adding variables

### "redirect_uri_mismatch"
- **Fix:** Add exact redirect URI to Google Cloud Console
- Production: `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback`
- Local: `http://localhost:3000/api/mailboxes/oauth/gmail/callback`
- No trailing slash!

### Cron job not running on Vercel
- **Fix:** Verify `CRON_SECRET` is set in Vercel environment variables
- Check Vercel dashboard → Cron Jobs tab → Should see the job listed
- Ensure project is deployed (cron jobs only activate after deployment)
- Check deployment logs for any errors
- Verify `vercel.json` includes the cron job configuration

### Emails not sending
- **Check:** Mailbox is active
- **Check:** Rate limits not exceeded
- **Check:** Campaign status is "running"
- **Check:** Vercel function logs for errors

## 📚 Next Steps

- Read [EMAIL_VERCEL_SETUP.md](./EMAIL_VERCEL_SETUP.md) for complete Vercel setup guide
- Read [EMAIL_SYSTEM_IMPLEMENTATION.md](./EMAIL_SYSTEM_IMPLEMENTATION.md) for full feature list
- Read [EMAIL_ENVIRONMENT_SETUP.md](./EMAIL_ENVIRONMENT_SETUP.md) for detailed OAuth setup
- Read [EMAIL_CRON_SETUP.md](./EMAIL_CRON_SETUP.md) for cron job details

## 🎉 You're Done!

Your email marketing system is now set up and ready to use!

**Features available:**
- ✅ Connect Gmail/Outlook mailboxes
- ✅ Send individual emails
- ✅ Create email campaigns
- ✅ Multi-step email sequences
- ✅ Automatic scheduling and sending
- ✅ Rate limiting protection

---

**Need help?** Check the troubleshooting sections in the detailed guides above.

