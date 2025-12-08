# Quick Webhook Test Guide

## Step 1: Get an Email ID

Run this SQL in Supabase SQL Editor:
```sql
SELECT id, to_email, created_at 
FROM emails 
ORDER BY created_at DESC 
LIMIT 1;
```

Copy the `id` value - you'll need it for testing.

## Step 2: Run the Test Script

### PowerShell (Windows):
```powershell
# Set your values
$env:APP_URL = "http://localhost:3000"  # or your production URL
$env:EMAIL_ID = "paste-your-email-id-here"
$env:EMAIL_WEBHOOK_SECRET = "your-secret"  # optional

# Run the test
.\test-webhooks.ps1
```

### Bash (Mac/Linux):
```bash
# Set your values
export APP_URL="http://localhost:3000"
export EMAIL_ID="paste-your-email-id-here"
export EMAIL_WEBHOOK_SECRET="your-secret"  # optional

# Run the test
./test-webhooks.sh
```

## Step 3: Manual cURL Commands

If you prefer to test manually, here are the exact curl commands:

### Test Delivered Event:
```bash
curl -X POST http://localhost:3000/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "x-provider: generic" \
  -H "x-webhook-secret: YOUR_SECRET" \
  -d "{\"eventType\":\"delivered\",\"emailId\":\"YOUR_EMAIL_ID\",\"recipientEmail\":\"test@example.com\",\"providerMessageId\":\"test-delivered-123\"}"
```

### Test Bounced Event:
```bash
curl -X POST http://localhost:3000/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "x-provider: generic" \
  -d "{\"eventType\":\"bounced\",\"emailId\":\"YOUR_EMAIL_ID\",\"recipientEmail\":\"test@example.com\",\"providerMessageId\":\"test-bounced-123\",\"bounceType\":\"hard\",\"bounceReason\":\"550 Mailbox not found\"}"
```

### Test Complaint Event:
```bash
curl -X POST http://localhost:3000/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "x-provider: generic" \
  -d "{\"eventType\":\"complaint\",\"emailId\":\"YOUR_EMAIL_ID\",\"recipientEmail\":\"test@example.com\",\"providerMessageId\":\"test-complaint-123\",\"complaintType\":\"spam\"}"
```

## Step 4: Verify Results

Check the `email_events` table:
```sql
SELECT * FROM email_events 
WHERE email_id = 'YOUR_EMAIL_ID' 
ORDER BY event_timestamp DESC;
```

You should see the events you just sent!

