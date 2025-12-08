# Cron Job Verification Guide

This guide helps you verify that the email processing cron job is properly configured and working.

## ✅ Step 1: Verify CRON_SECRET Environment Variable

### Check in Vercel:
1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **Settings** → **Environment Variables**
4. Verify `CRON_SECRET` is set
5. Copy the value (you'll need it for testing)

### Generate CRON_SECRET (if not set):

**Windows PowerShell:**
```powershell
$cronSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})
Write-Host "CRON_SECRET=$cronSecret"
```

**Mac/Linux:**
```bash
openssl rand -base64 32
```

## ✅ Step 2: Verify Vercel Cron Configuration

### Check vercel.json:
The cron job should be configured in `vercel.json`:

```json
{
  "crons": [
    {
      "path": "/api/cron/process-emails",
      "schedule": "* * * * *"
    }
  ]
}
```

### Verify in Vercel Dashboard:
1. Go to your project in Vercel Dashboard
2. Click on **"Cron Jobs"** tab (if available)
3. You should see `/api/cron/process-emails` listed
4. Check execution logs to see if it's running

## ✅ Step 3: Test the Cron Endpoint Manually

### Test with cURL (PowerShell):

```powershell
# Replace YOUR_CRON_SECRET with your actual CRON_SECRET value
$CRON_SECRET = "YOUR_CRON_SECRET"
$APP_URL = "http://localhost:3000"  # or your production URL

# Test the endpoint
$headers = @{
    "Authorization" = "Bearer $CRON_SECRET"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "$APP_URL/api/cron/process-emails" `
        -Method GET -Headers $headers
    Write-Host "✅ Success!" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json)
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
```

### Test with cURL (Bash):

```bash
# Replace YOUR_CRON_SECRET with your actual CRON_SECRET value
CRON_SECRET="YOUR_CRON_SECRET"
APP_URL="http://localhost:3000"  # or your production URL

curl -X GET "$APP_URL/api/cron/process-emails" \
  -H "Authorization: Bearer $CRON_SECRET" \
  -H "Content-Type: application/json"
```

### Expected Response:
```json
{
  "success": true,
  "message": "No emails to process",
  "processed": 0
}
```

Or if there are emails to process:
```json
{
  "success": true,
  "processed": 5,
  "sent": 3,
  "failed": 2
}
```

## ✅ Step 4: Verify Cron Job is Running

### Check Vercel Logs:
1. Go to Vercel Dashboard → Your Project
2. Click on **"Deployments"**
3. Select the latest deployment
4. Click on **"Function Logs"**
5. Filter for `/api/cron/process-emails`
6. You should see logs every minute if the cron is running

### Check Database for Activity:
```sql
-- Check for recent email processing activity
SELECT 
  id,
  to_email,
  status,
  scheduled_at,
  sent_at,
  updated_at
FROM emails
WHERE status IN ('queued', 'sent', 'failed')
  AND updated_at > NOW() - INTERVAL '5 minutes'
ORDER BY updated_at DESC
LIMIT 10;
```

## ✅ Step 5: Verify Authentication

The endpoint accepts authentication via:

1. **`x-vercel-cron-secret` header** (automatically set by Vercel Cron)
   - Must match `CRON_SECRET` environment variable

2. **`Authorization: Bearer` header**
   - Can use `CRON_SECRET` value

3. **`x-service-key` header** (alternative)
   - Can use `CALENDAR_SERVICE_KEY` if set

### Test Authentication:
```powershell
# Test with correct secret (should succeed)
$headers = @{
    "Authorization" = "Bearer YOUR_CRON_SECRET"
}
Invoke-RestMethod -Uri "http://localhost:3000/api/cron/process-emails" -Headers $headers

# Test with wrong secret (should fail with 401)
$headers = @{
    "Authorization" = "Bearer wrong-secret"
}
Invoke-RestMethod -Uri "http://localhost:3000/api/cron/process-emails" -Headers $headers
```

## ✅ Step 6: Monitor Cron Job Health

### Create a Test Email to Process:
1. Go to your email campaign builder
2. Create a test campaign with a scheduled email
3. Set `scheduled_at` to a time in the past (so it's ready to process)
4. The cron job should pick it up within 1 minute

### Check Processing:
```sql
-- Check if emails are being processed
SELECT 
  COUNT(*) as queued_count,
  COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
  COUNT(*) FILTER (WHERE status = 'failed') as failed_count
FROM emails
WHERE status IN ('queued', 'sent', 'failed')
  AND scheduled_at <= NOW();
```

## 🔧 Troubleshooting

### Cron Job Not Running:
1. **Check Vercel Cron is enabled:**
   - Verify `vercel.json` has the cron configuration
   - Check Vercel Dashboard → Cron Jobs tab

2. **Check Environment Variables:**
   - Ensure `CRON_SECRET` is set in Vercel
   - Ensure `NEXT_PUBLIC_SUPABASE_URL` is set
   - Ensure `SUPABASE_SERVICE_ROLE_KEY` is set

3. **Check Deployment:**
   - Make sure latest code is deployed
   - Check deployment logs for errors

### Getting 401 Unauthorized:
- Verify `CRON_SECRET` matches between:
  - Vercel environment variables
  - Your test request header
- Check that the header name is correct (`Authorization: Bearer` or `x-vercel-cron-secret`)

### Getting 500 Server Error:
- Check that `NEXT_PUBLIC_SUPABASE_URL` is set
- Check that `SUPABASE_SERVICE_ROLE_KEY` is set
- Check Vercel function logs for detailed error messages

### No Emails Being Processed:
- Verify there are emails with `status = 'queued'`
- Verify `scheduled_at <= NOW()`
- Check mailbox is active
- Check campaign is not paused/cancelled

## 📊 Verification Checklist

- [ ] `CRON_SECRET` is set in Vercel environment variables
- [ ] `vercel.json` has cron job configuration
- [ ] Cron job appears in Vercel Dashboard (if available)
- [ ] Manual test of endpoint returns success (200 OK)
- [ ] Authentication works (correct secret = success, wrong = 401)
- [ ] Vercel logs show cron job executing
- [ ] Database shows email processing activity
- [ ] Test emails are being processed correctly

## 🎯 Next Steps

After verification:
1. Monitor cron job execution in Vercel logs
2. Set up alerts for cron job failures (if available)
3. Test with real email campaigns
4. Monitor email processing metrics in analytics dashboard

