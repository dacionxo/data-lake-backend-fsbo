# Email System Cron Job Setup Guide

This guide explains how to set up the email processing cron job that runs every minute to process queued emails.

## 📋 Overview

The email scheduler endpoint at `/api/cron/process-emails` needs to be called every minute to:
- Process queued emails
- Send scheduled emails
- Advance multi-step email sequences
- Respect rate limits (hourly/daily per mailbox)
- Handle campaign status (pause/resume)

## ✅ Option 1: Vercel Cron Jobs (Recommended)

Vercel Cron is the easiest and most reliable option. It's already configured in `vercel.json`.

### Already Configured!

The cron job is already added to `vercel.json`:

```json
{
  "path": "/api/cron/process-emails",
  "schedule": "* * * * *"
}
```

This means:
- ✅ **Path:** `/api/cron/process-emails`
- ✅ **Schedule:** Every minute (`* * * * *`)
- ✅ **Authentication:** Automatic via Vercel's `x-vercel-cron-secret` header

### Required Environment Variable

Make sure `CRON_SECRET` is set in your Vercel environment variables:

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **"Settings"** > **"Environment Variables"**
4. Ensure `CRON_SECRET` is set (see `EMAIL_ENVIRONMENT_SETUP.md`)

### Verify It's Working

1. **Deploy your changes:**
   ```bash
   git add vercel.json
   git commit -m "Add email processing cron job"
   git push
   ```

2. **Check Vercel Dashboard:**
   - Go to **"Cron Jobs"** tab in your Vercel project
   - You should see `/api/cron/process-emails` listed
   - Status should show recent execution times

3. **Check Logs:**
   - Go to **"Deployments"** > Select latest deployment
   - Check **"Function Logs"** for `/api/cron/process-emails`
   - Should see execution logs every minute

### How It Works

- Vercel automatically calls your endpoint every minute
- Sets `x-vercel-cron-secret` header with value from `CRON_SECRET` env variable
- Your endpoint verifies the header matches
- Processes queued emails if any exist

## ✅ Option 2: External Cron Service

If you prefer not to use Vercel Cron, you can use an external service.

### Setup with EasyCron

1. Go to [EasyCron](https://www.easycron.com)
2. Create an account and add a new cron job
3. Configure:
   - **URL:** `https://www.growyourdigitalleverage.com/api/cron/process-emails`
   - **Schedule:** `* * * * *` (every minute)
   - **Method:** POST
   - **Headers:**
     ```
     Authorization: Bearer YOUR_CRON_SECRET
     Content-Type: application/json
     ```
4. Save and enable

### Setup with Supabase Cron

If you have Supabase and want to use their cron extension:

1. Enable the `pg_cron` extension in Supabase
2. Run this SQL:

```sql
SELECT cron.schedule(
  'process-emails',
  '* * * * *', -- Every minute
  $$
  SELECT net.http_post(
    url:='https://www.growyourdigitalleverage.com/api/cron/process-emails',
    headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_CRON_SECRET"}'::jsonb
  ) AS request_id;
  $$
);
```

Replace:
- Use: `https://www.growyourdigitalleverage.com/api/cron/process-emails`
- `YOUR_CRON_SECRET` with your actual `CRON_SECRET` value

### Setup with Other Services

Any cron service that can make HTTP POST requests will work:

- **Cronitor:** https://cronitor.io
- **Cron-job.org:** https://cron-job.org
- **GitHub Actions:** Set up a workflow that runs every minute
- **CloudWatch Events:** If using AWS

**Required:**
- POST request to `/api/cron/process-emails`
- Header: `Authorization: Bearer YOUR_CRON_SECRET`

## 🔐 Authentication

The endpoint accepts authentication via:

1. **`x-vercel-cron-secret` header** (set automatically by Vercel Cron)
   - Must match `CRON_SECRET` environment variable

2. **`x-service-key` header** (custom service key)
   - Must match `CALENDAR_SERVICE_KEY` environment variable

3. **`Authorization: Bearer` header**
   - Can use either `CRON_SECRET` or `CALENDAR_SERVICE_KEY`

## 📊 Monitoring

### Check Email Processing

1. **Via Database:**
   ```sql
   -- Check queued emails
   SELECT COUNT(*) FROM emails WHERE status = 'queued';
   
   -- Check sent emails today
   SELECT COUNT(*) FROM emails 
   WHERE status = 'sent' 
   AND sent_at >= CURRENT_DATE;
   
   -- Check failed emails
   SELECT * FROM emails 
   WHERE status = 'failed' 
   ORDER BY created_at DESC 
   LIMIT 10;
   ```

2. **Via API Logs:**
   - Check Vercel function logs for `/api/cron/process-emails`
   - Should see execution every minute
   - Check response status (200 = success)

3. **Via Campaign Stats:**
   - Go to `/dashboard/email/campaigns`
   - Check campaign stats for sent/pending emails

### Success Indicators

- ✅ Emails with `status = 'queued'` decrease over time
- ✅ Emails with `status = 'sent'` increase
- ✅ Campaign recipients progress through steps
- ✅ No errors in Vercel logs

## 🐛 Troubleshooting

### Cron job not running

**Vercel Cron:**
- Check `vercel.json` has the cron job configured
- Verify `CRON_SECRET` is set in environment variables
- Check Vercel dashboard > Cron Jobs tab
- Ensure project is deployed

**External Cron:**
- Verify the URL is correct
- Check authentication header matches `CRON_SECRET`
- Test manually with curl:
  ```bash
  curl -X POST https://www.growyourdigitalleverage.com/api/cron/process-emails \
    -H "Authorization: Bearer YOUR_CRON_SECRET" \
    -H "Content-Type: application/json"
  ```

### Getting "Unauthorized" errors

- Verify `CRON_SECRET` environment variable is set correctly
- Check the header name and value match exactly
- For Vercel Cron, the header is automatically set
- For external services, ensure you're sending the correct header

### Emails not being processed

1. **Check if emails are queued:**
   ```sql
   SELECT COUNT(*) FROM emails WHERE status = 'queued';
   ```

2. **Check mailbox status:**
   ```sql
   SELECT id, email, active, last_error FROM mailboxes;
   ```
   - Mailboxes must be `active = true`
   - Check `last_error` for issues

3. **Check campaign status:**
   ```sql
   SELECT id, name, status FROM campaigns;
   ```
   - Campaigns should be `status = 'running'` or `status = 'scheduled'`

4. **Check rate limits:**
   - Verify mailboxes haven't hit hourly/daily limits
   - Check recent email sends in the last hour/day

5. **Check cron job logs:**
   - Look for errors in Vercel function logs
   - Check for rate limit errors
   - Check for authentication errors

### Rate limits being hit

If you're hitting rate limits too quickly:

1. **Increase limits in mailbox settings:**
   - Edit mailbox via `/dashboard/email/mailboxes`
   - Increase `hourly_limit` or `daily_limit`

2. **Add more mailboxes:**
   - Distribute sending across multiple mailboxes
   - Each mailbox has its own rate limits

3. **Check scheduled time:**
   - Emails scheduled in the future won't be sent until their time
   - Verify `scheduled_at` timestamps

## 📝 Schedule Format

The cron schedule `* * * * *` means:
- `*` = every minute
- `*` = every hour  
- `*` = every day
- `*` = every month
- `*` = every day of week

**Result:** Runs every minute

## 🎯 Performance

- **Processing speed:** ~100-200 emails per minute (depends on rate limits)
- **Rate limits:** Respects mailbox hourly/daily limits automatically
- **Batching:** Groups emails by mailbox for efficient processing
- **Error handling:** Failed emails are marked and logged, don't block others

## ✅ Checklist

- [ ] `CRON_SECRET` environment variable is set
- [ ] `vercel.json` includes the cron job (already done)
- [ ] Project is deployed to Vercel
- [ ] Cron job appears in Vercel dashboard > Cron Jobs
- [ ] Can see execution logs in Vercel function logs
- [ ] Queued emails are being processed
- [ ] Campaign recipients are progressing through steps

---

**Recommended:** Use Vercel Cron (Option 1) - it's already configured and requires no additional setup beyond setting the `CRON_SECRET` environment variable!

