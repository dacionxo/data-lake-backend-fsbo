# Gmail Webhook Setup Guide

## Overview

This guide explains how to set up Gmail push notifications to automatically receive and log incoming emails to your Unibox.

## Architecture

```
Gmail → Google Cloud Pub/Sub → Your Webhook Endpoint → Database → Unibox
```

## Prerequisites

1. ✅ Gmail mailbox connected via OAuth
2. ✅ Google Cloud Project with Gmail API enabled
3. ✅ Google Cloud Pub/Sub enabled
4. ✅ Webhook endpoint deployed

## Setup Steps

### Step 1: Create Google Cloud Pub/Sub Topic

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **Pub/Sub** → **Topics**
3. Click **Create Topic**
4. Name it `gmail-notifications` (or any name you prefer)
5. Note the full topic name: `projects/YOUR_PROJECT_ID/topics/gmail-notifications`

### Step 2: Create Pub/Sub Push Subscription

1. In your Pub/Sub topic, click **Create Subscription**
2. Choose **Push** subscription type
3. Name: `gmail-webhook-push`
4. **Endpoint URL**: `https://www.growyourdigitalleverage.com/api/webhooks/gmail`
5. Click **Create**

### Step 3: Grant Pub/Sub Permissions (Optional)

**Good News:** Gmail Watch API automatically grants permissions when you set up the watch! 

If you get a "Domain Restricted Sharing" error when trying to manually grant permissions, **you can skip this step**. The Gmail Watch API will handle permissions automatically.

**Optional - Manual Permission Granting:**
If your organization doesn't have domain restrictions, you can manually grant permissions for better visibility:

**📖 See detailed instructions: [GMAIL_PUBSUB_PERMISSIONS.md](./GMAIL_PUBSUB_PERMISSIONS.md)**

**Quick steps:**

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → **Pub/Sub** → **Topics**
2. Click on your topic → **PERMISSIONS** tab
3. Click **GRANT ACCESS**
4. Add principal: `gmail-api-push@system.gserviceaccount.com`
5. Select role: **Pub/Sub Publisher**
6. Click **SAVE**

**Note:** If you get a "Domain Restricted Sharing" error, that's fine - Gmail Watch will grant permissions automatically in Step 6.

### Step 4: Set Environment Variable

Add to your Vercel environment variables (or `.env.local` for local):

```bash
GMAIL_PUBSUB_TOPIC_NAME=projects/YOUR_PROJECT_ID/topics/gmail-notifications
```

### Step 5: Run Database Migration

Execute the SQL schema to add watch fields to mailboxes:

```sql
-- Run supabase/email_mailboxes_watch_schema.sql
```

This adds:
- `watch_expiration` - When the watch subscription expires
- `watch_history_id` - Last processed Gmail history ID

### Step 6: Enable Gmail Watch

Once your mailbox is connected, enable Gmail Watch:

```bash
POST /api/mailboxes/{mailboxId}/watch
```

**Response:**
```json
{
  "success": true,
  "expiration": 1234567890000,
  "historyId": "12345",
  "message": "Gmail Watch set up successfully"
}
```

### Step 7: Test the Webhook

1. Send a test email to your Gmail inbox
2. Check the webhook logs in Vercel
3. Verify the email appears in Unibox

## API Endpoints

### Enable Gmail Watch
```
POST /api/mailboxes/{mailboxId}/watch
```

Sets up Gmail Watch for push notifications. The watch expires after 7 days and needs to be renewed.

### Disable Gmail Watch
```
DELETE /api/mailboxes/{mailboxId}/watch
```

Stops Gmail Watch for a mailbox.

### Webhook Handler
```
POST /api/webhooks/gmail
```

This endpoint receives push notifications from Google Pub/Sub and:
1. Decodes the Pub/Sub message
2. Finds the mailbox by email address
3. Fetches new emails from Gmail API
4. Logs received emails via `/api/emails/received`

## Watch Renewal

Gmail Watch subscriptions expire after 7 days. A cron job has been set up to automatically renew them.

**✅ Implementation Status:** **COMPLETE**

The renewal cron job is already configured in `vercel.json` and will run daily at 3 AM:

```json
{
  "path": "/api/cron/gmail-watch-renewal",
  "schedule": "0 3 * * *"
}
```

**What it does:**
- Finds Gmail mailboxes with watch subscriptions expiring in the next 24 hours
- Automatically refreshes access tokens if needed
- Renews Gmail Watch subscriptions
- Updates `watch_expiration` and `watch_history_id` in database

**No action required** - this runs automatically once deployed to Vercel. The cron job will keep your Gmail Watch subscriptions active so you never miss incoming emails.

## Troubleshooting

### Domain Restricted Sharing Error

**If you get:** "Domain Restricted Sharing organization policy is enforced"

**Solution:** ✅ **This is normal!** Skip manual permission granting. Gmail Watch API automatically grants permissions when you set up the watch. See [GMAIL_DOMAIN_RESTRICTION_FIX.md](./GMAIL_DOMAIN_RESTRICTION_FIX.md) for details.

### Webhook Not Receiving Notifications

1. **Check Pub/Sub Subscription**: Verify the endpoint URL is correct
2. **Check Watch Status**: Verify watch is active and not expired (check `watch_expiration` in database)
3. **Check Logs**: Review Vercel function logs for errors
4. **Verify Automatic Permissions**: Gmail Watch should have automatically granted permissions - check topic permissions after setting up watch

### Emails Not Appearing in Unibox

1. **Check Webhook Logs**: Verify webhook is receiving notifications
2. **Check Gmail API**: Ensure access token is valid
3. **Check Database**: Verify emails are being inserted with `direction = 'received'`
4. **Check Unibox Query**: Verify Unibox is querying for `direction = 'received'`

### Watch Expiration

Gmail Watch expires after 7 days. If emails stop appearing:
1. Check `watch_expiration` in mailboxes table
2. Renew the watch by calling `POST /api/mailboxes/{mailboxId}/watch` again

## Local Development

For local development, you'll need to use a tunneling service like ngrok:

```bash
# Install ngrok
npm install -g ngrok

# Start your Next.js app
npm run dev

# Create tunnel
ngrok http 3000

# Update Pub/Sub subscription endpoint to ngrok URL
# https://your-ngrok-url.ngrok.io/api/webhooks/gmail
```

**Note:** Update the subscription endpoint in Google Cloud Console.

## Alternative: Polling Approach

If Pub/Sub setup is too complex, you can use a polling approach:

1. Create a cron job that runs every 5 minutes
2. Fetch unread emails from Gmail API
3. Log them via `/api/emails/received`

This is simpler but not real-time (5-minute delay).

## Security Considerations

1. **Webhook Verification**: Consider adding Pub/Sub message verification
2. **Rate Limiting**: Implement rate limiting on webhook endpoint
3. **Access Tokens**: Store tokens securely (encrypted)
4. **HTTPS Only**: Always use HTTPS for webhook endpoints

## Next Steps

- ✅ Set up Pub/Sub topic and subscription
- ✅ Configure environment variables
- ✅ Run database migration
- ✅ Enable Gmail Watch for your mailbox
- ✅ Test with a test email
- ✅ Set up watch renewal cron job (optional but recommended)

