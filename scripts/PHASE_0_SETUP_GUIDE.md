# Phase 0: Baseline SMS Setup Guide

This guide walks you through setting up and verifying the baseline SMS functionality before implementing BYO Twilio.

## Prerequisites

- Supabase project set up
- Twilio account created
- Next.js application deployed or running locally

---

## Step 1: Run SMS Schema in Supabase

### 1.1 Open Supabase SQL Editor

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor** in the left sidebar
3. Click **New Query**

### 1.2 Run the Schema

1. Open `supabase/sms_schema.sql` in your code editor
2. Copy the entire contents
3. Paste into the Supabase SQL Editor
4. Click **Run** (or press `Ctrl+Enter` / `Cmd+Enter`)

### 1.3 Verify Schema Creation

Run this query to verify all tables were created:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name LIKE 'sms_%'
ORDER BY table_name;
```

You should see:
- `sms_campaigns`
- `sms_campaign_enrollments`
- `sms_campaign_steps`
- `sms_conversations`
- `sms_events`
- `sms_messages`

### 1.4 Verify Types Were Created

```sql
SELECT typname 
FROM pg_type 
WHERE typname LIKE 'sms_%'
ORDER BY typname;
```

You should see:
- `sms_campaign_status`
- `sms_campaign_type`
- `sms_direction`
- `sms_enrollment_status`
- `sms_event_type`
- `sms_message_status`

---

## Step 2: Add Twilio Environment Variables

### 2.1 Create/Update .env.local

Create or update `.env.local` in your project root with the following variables:

```bash
# Twilio Core
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token_here

# Conversations
TWILIO_CONVERSATIONS_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_SMS_NUMBER=+1xxxxxxxxxx

# Security
TWILIO_WEBHOOK_AUTH_TOKEN=some-long-random-string-here
CRON_SECRET=another-long-random-string-here

# App
NEXT_PUBLIC_APP_URL=https://your-domain.com
# Or for local development:
# NEXT_PUBLIC_APP_URL=http://localhost:3000
```

### 2.2 Get Your Twilio Credentials

1. Log in to [Twilio Console](https://console.twilio.com)
2. Your **Account SID** and **Auth Token** are on the main dashboard
3. Copy these values to `.env.local`

**⚠️ Security Note**: Never commit `.env.local` to git. It should already be in `.gitignore`.

---

## Step 3: Create Twilio Conversations Service

### 3.1 Navigate to Conversations

1. In Twilio Console, go to **Messaging** → **Conversations** → **Services**
2. Click **Create Service** (or **+** button)

### 3.2 Configure Service

1. **Service Name**: `LeadMapProd` (or your preferred name)
2. Click **Create**

### 3.3 Get Service SID

1. After creation, you'll see the **Service SID** (starts with `IS...`)
2. Copy this value
3. Update `.env.local` with:
   ```
   TWILIO_CONVERSATIONS_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

---

## Step 4: Provision SMS Number and Create Messaging Service

### 4.1 Buy/Provision a Phone Number

1. In Twilio Console, go to **Phone Numbers** → **Manage** → **Buy a number**
2. Select your country (e.g., United States)
3. Check **SMS** capability
4. Click **Search**
5. Select a number and click **Buy**
6. Copy the phone number (e.g., `+15551234567`)
7. Update `.env.local` with:
   ```
   TWILIO_SMS_NUMBER=+15551234567
   ```

### 4.2 Create Messaging Service

1. Go to **Messaging** → **Services** → **Messaging Services**
2. Click **Create Messaging Service**
3. **Service Name**: `LeadMapMessaging` (or your preferred name)
4. Click **Create**

### 4.3 Add Phone Number to Messaging Service

1. In your Messaging Service, go to **Sender Pool**
2. Click **Add Senders**
3. Select **Phone Numbers**
4. Check the number you just bought
5. Click **Add Senders**

### 4.4 Get Messaging Service SID

1. The **Service SID** is shown at the top (starts with `MG...`)
2. Copy this value
3. Update `.env.local` with:
   ```
   TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

---

## Step 5: Link Messaging Service to Conversations Service

### 5.1 Configure Conversations Service

1. Go back to **Messaging** → **Conversations** → **Services**
2. Click on your Conversations Service
3. Go to **Configuration** tab

### 5.2 Set Default Messaging Service

1. Under **Default Messaging Service**, select your Messaging Service
2. Click **Save**

This links your Conversations Service to your SMS number via the Messaging Service.

---

## Step 6: Configure Webhook URL

### 6.1 Set Webhook URL

1. In your Conversations Service, go to **Webhooks** tab
2. Under **Webhooks**, click **Add Webhook**

### 6.2 Configure Webhook

1. **Event Type**: Select multiple:
   - ✅ `onMessageAdded`
   - ✅ `onDeliveryUpdated`
   - ✅ `onConversationAdded`
   - ✅ `onParticipantAdded` (optional)

2. **URL**: 
   ```
   https://your-domain.com/api/twilio/conversations/webhook
   ```
   Or for local testing with ngrok:
   ```
   https://your-ngrok-url.ngrok.io/api/twilio/conversations/webhook
   ```

3. **Method**: `POST`

4. Click **Save**

### 6.3 Test Webhook (Optional)

Twilio will send a test webhook. Check your application logs to verify it's received.

---

## Step 7: Set Up Cron Job for Drip Runner

The drip campaign runner needs to be called every minute to process due enrollments.

### Option A: Vercel Cron (Recommended for Vercel deployments)

1. Create or update `vercel.json` in project root:

```json
{
  "crons": [
    {
      "path": "/api/sms/drip/run",
      "schedule": "*/1 * * * *"
    }
  ]
}
```

2. Deploy to Vercel
3. Vercel will automatically set up the cron job

### Option B: Supabase Cron (Recommended for Supabase projects)

Run this SQL in Supabase SQL Editor:

```sql
-- Install pg_cron extension if not already installed
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the drip runner (replace YOUR_DOMAIN and CRON_SECRET)
SELECT cron.schedule(
  'sms-drip-runner',
  '* * * * *', -- Every minute
  $$
  SELECT net.http_post(
    url := 'https://YOUR_DOMAIN.com/api/sms/drip/run',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Cron-Secret', 'YOUR_CRON_SECRET'
    )
  ) AS request_id;
  $$
);
```

**Replace:**
- `YOUR_DOMAIN.com` with your actual domain
- `YOUR_CRON_SECRET` with the value from `.env.local`

### Option C: External Cron Service

Use a service like [cron-job.org](https://cron-job.org) or [EasyCron](https://www.easycron.com):

1. Create a new cron job
2. **URL**: `https://your-domain.com/api/sms/drip/run`
3. **Method**: `POST`
4. **Headers**: 
   - `Content-Type: application/json`
   - `X-Cron-Secret: your-cron-secret`
5. **Schedule**: Every minute (`*/1 * * * *`)

### Option D: Local Testing (Manual)

For local development, you can manually trigger:

```bash
curl -X POST http://localhost:3000/api/sms/drip/run \
  -H "X-Cron-Secret: your-cron-secret"
```

---

## Step 8: Test SMS Functionality

### 8.1 Start Your Application

```bash
npm run dev
```

### 8.2 Test Sending SMS

1. Navigate to `/dashboard/conversations` in your app
2. If you have a lead with a phone number:
   - Click on a conversation or create a new one
   - Type a test message
   - Click **Send**
3. Check your phone to verify the message was received

### 8.3 Test Receiving SMS

1. Send an SMS from your phone to your Twilio number
2. Check the conversations page - the message should appear
3. Verify the message shows as "inbound"

### 8.4 Test Webhook Logs

1. Check your application logs/console for webhook events
2. You should see logs like:
   ```
   [Twilio Webhook] onMessageAdded
   [handleMessageAdded] Message received
   ```

### 8.5 Verify Database

Check Supabase to verify data is being stored:

```sql
-- Check conversations
SELECT * FROM sms_conversations ORDER BY created_at DESC LIMIT 5;

-- Check messages
SELECT * FROM sms_messages ORDER BY created_at DESC LIMIT 5;

-- Check events
SELECT * FROM sms_events ORDER BY occurred_at DESC LIMIT 10;
```

---

## Verification Checklist

Before moving to Phase 1, verify:

- [ ] SMS schema tables created in Supabase
- [ ] All Twilio environment variables set in `.env.local`
- [ ] Twilio Conversations Service created and SID saved
- [ ] SMS phone number provisioned and added to Messaging Service
- [ ] Messaging Service linked to Conversations Service
- [ ] Webhook URL configured in Twilio
- [ ] Cron job set up and running
- [ ] Can send SMS from conversations page
- [ ] Can receive SMS via webhook
- [ ] Messages appear in database
- [ ] Delivery status updates work

---

## Troubleshooting

### Issue: Schema fails to run

**Solution**: 
- Check for existing tables that might conflict
- The schema includes `DROP TABLE IF EXISTS` statements
- Ensure you have proper permissions in Supabase

### Issue: Webhook not receiving events

**Solution**:
- Verify webhook URL is accessible (use ngrok for local testing)
- Check Twilio webhook logs in Console → Monitor → Logs
- Verify webhook signature validation is working
- Check application logs for errors

### Issue: Messages not sending

**Solution**:
- Verify all environment variables are set correctly
- Check Twilio Console for error messages
- Verify phone number is SMS-capable
- Check application logs for API errors

### Issue: Cron job not running

**Solution**:
- Verify cron job is set up correctly
- Check cron service logs
- Verify `CRON_SECRET` matches in both places
- Test endpoint manually with curl

---

## Next Steps

Once Phase 0 is complete and verified:

✅ Proceed to **Phase 1**: Add per-user Twilio settings table
✅ See `BYO_TWILIO_IMPLEMENTATION.md` for next steps

---

## Support

If you encounter issues:
1. Check Twilio Console → Monitor → Logs
2. Check Supabase logs
3. Check application console/logs
4. Verify all environment variables are correct
5. Test webhook with Twilio's webhook tester






