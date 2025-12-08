# Phase 0: Baseline SMS Verification Checklist

Use this checklist to verify each step of Phase 0 setup.

## ✅ Step 1: Database Schema

- [ ] Opened Supabase SQL Editor
- [ ] Copied contents of `supabase/sms_schema.sql`
- [ ] Pasted and ran in SQL Editor
- [ ] Verified all 6 SMS tables created:
  - [ ] `sms_conversations`
  - [ ] `sms_messages`
  - [ ] `sms_campaigns`
  - [ ] `sms_campaign_steps`
  - [ ] `sms_campaign_enrollments`
  - [ ] `sms_events`
- [ ] Verified all 6 SMS types created:
  - [ ] `sms_direction`
  - [ ] `sms_message_status`
  - [ ] `sms_campaign_type`
  - [ ] `sms_campaign_status`
  - [ ] `sms_enrollment_status`
  - [ ] `sms_event_type`
- [ ] Verified analytics views created:
  - [ ] `sms_campaign_performance`
  - [ ] `sms_user_daily_metrics`

## ✅ Step 2: Environment Variables

- [ ] Created/updated `.env.local` file
- [ ] Added `TWILIO_ACCOUNT_SID` (from Twilio Console)
- [ ] Added `TWILIO_AUTH_TOKEN` (from Twilio Console)
- [ ] Added `TWILIO_CONVERSATIONS_SERVICE_SID` (will get in Step 3)
- [ ] Added `TWILIO_MESSAGING_SERVICE_SID` (will get in Step 4)
- [ ] Added `TWILIO_SMS_NUMBER` (will get in Step 4)
- [ ] Added `TWILIO_WEBHOOK_AUTH_TOKEN` (random string)
- [ ] Added `CRON_SECRET` (random string)
- [ ] Added `NEXT_PUBLIC_APP_URL` (your domain or localhost)
- [ ] Verified `.env.local` is in `.gitignore`

## ✅ Step 3: Twilio Conversations Service

- [ ] Logged into Twilio Console
- [ ] Navigated to Messaging → Conversations → Services
- [ ] Created new Conversations Service
- [ ] Named service (e.g., "LeadMapProd")
- [ ] Copied Service SID (starts with `IS...`)
- [ ] Updated `.env.local` with `TWILIO_CONVERSATIONS_SERVICE_SID`

## ✅ Step 4: SMS Number & Messaging Service

- [ ] Navigated to Phone Numbers → Buy a number
- [ ] Selected country and SMS capability
- [ ] Purchased phone number
- [ ] Copied phone number (e.g., `+15551234567`)
- [ ] Updated `.env.local` with `TWILIO_SMS_NUMBER`
- [ ] Created Messaging Service
- [ ] Added phone number to Messaging Service sender pool
- [ ] Copied Messaging Service SID (starts with `MG...`)
- [ ] Updated `.env.local` with `TWILIO_MESSAGING_SERVICE_SID`

## ✅ Step 5: Link Services

- [ ] Opened Conversations Service configuration
- [ ] Set Default Messaging Service to created Messaging Service
- [ ] Saved configuration
- [ ] Verified link is active

## ✅ Step 6: Webhook Configuration

- [ ] Opened Conversations Service webhooks tab
- [ ] Added new webhook
- [ ] Selected event types:
  - [ ] `onMessageAdded`
  - [ ] `onDeliveryUpdated`
  - [ ] `onConversationAdded`
- [ ] Set webhook URL: `https://your-domain.com/api/twilio/conversations/webhook`
- [ ] Set method to POST
- [ ] Saved webhook
- [ ] Verified webhook appears in list

## ✅ Step 7: Cron Job Setup

**Choose one option:**

### Option A: Vercel Cron
- [ ] Created/updated `vercel.json` with cron configuration
- [ ] Deployed to Vercel
- [ ] Verified cron job appears in Vercel dashboard

### Option B: Supabase Cron
- [ ] Ran pg_cron extension SQL
- [ ] Ran cron.schedule SQL with correct domain and secret
- [ ] Verified cron job in Supabase

### Option C: External Cron Service
- [ ] Created account on cron service
- [ ] Created new cron job
- [ ] Set URL to `/api/sms/drip/run`
- [ ] Set schedule to every minute
- [ ] Added `X-Cron-Secret` header
- [ ] Verified cron job is active

## ✅ Step 8: Testing

### 8.1 Application Setup
- [ ] Started application (`npm run dev`)
- [ ] Verified no startup errors
- [ ] Checked console for Twilio connection warnings (should be none if env vars set)

### 8.2 Send SMS Test
- [ ] Navigated to `/dashboard/conversations`
- [ ] Found or created a conversation with a phone number
- [ ] Sent a test SMS message
- [ ] Verified message appears in UI
- [ ] Checked phone to confirm message received
- [ ] Verified message status shows as "sent" or "delivered"

### 8.3 Receive SMS Test
- [ ] Sent SMS from phone to Twilio number
- [ ] Verified message appears in conversations page
- [ ] Verified message shows as "inbound"
- [ ] Verified message body is correct

### 8.4 Database Verification
- [ ] Opened Supabase SQL Editor
- [ ] Ran: `SELECT * FROM sms_conversations ORDER BY created_at DESC LIMIT 5;`
- [ ] Verified conversations are being created
- [ ] Ran: `SELECT * FROM sms_messages ORDER BY created_at DESC LIMIT 5;`
- [ ] Verified messages are being stored
- [ ] Ran: `SELECT * FROM sms_events ORDER BY occurred_at DESC LIMIT 10;`
- [ ] Verified events are being logged

### 8.5 Webhook Verification
- [ ] Checked application logs/console
- [ ] Verified webhook events are being received
- [ ] Checked Twilio Console → Monitor → Logs
- [ ] Verified webhook requests are successful (200 status)

### 8.6 Drip Runner Test
- [ ] Manually triggered `/api/sms/drip/run` endpoint
- [ ] Verified endpoint returns success
- [ ] Checked logs for any errors
- [ ] Verified cron job will run automatically

## 🎯 Final Verification

Before marking Phase 0 complete, ensure:

- [ ] All checklist items above are checked
- [ ] Can send SMS successfully
- [ ] Can receive SMS successfully
- [ ] Messages appear in database
- [ ] Webhooks are working
- [ ] No errors in application logs
- [ ] No errors in Twilio Console
- [ ] Cron job is configured and will run

## ✅ Phase 0 Complete!

Once all items are verified, Phase 0 is complete. You can now proceed to:

**Next: Phase 1 - Add Per-User Twilio Settings Table**

See `BYO_TWILIO_IMPLEMENTATION.md` for Phase 1 instructions.






