# Email Webhook Testing Guide

This guide explains how to test the email provider webhook handlers for delivered, bounced, and complaint events.

## Webhook Endpoint

**URL:** `POST /api/webhooks/email/providers`

**Headers:**
- `Content-Type: application/json`
- `x-provider: sendgrid|mailgun|resend|ses|generic` (optional - auto-detected)
- `x-webhook-secret: <your-secret>` (optional - only if `EMAIL_WEBHOOK_SECRET` is set)

## Prerequisites

1. **Get a test email ID**: First, send a test email through your system and note the `email_id` from the `emails` table in Supabase.

2. **Get provider message ID**: After sending, check the `emails` table for the `provider_message_id` field. This is used to match webhook events to emails.

3. **Set webhook secret (optional)**: If you set `EMAIL_WEBHOOK_SECRET` in your environment, include it in the `x-webhook-secret` header.

## Testing Methods

### Method 1: Using cURL (Command Line)

#### Test Generic Webhook (Easiest for Testing)

```bash
# Replace these values:
# - YOUR_APP_URL: Your app URL (e.g., http://localhost:3000 or https://yourdomain.com)
# - EMAIL_ID: UUID from the emails table
# - RECIPIENT_EMAIL: The recipient email address

# Test Delivered Event
curl -X POST https://YOUR_APP_URL/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "x-provider: generic" \
  -H "x-webhook-secret: YOUR_WEBHOOK_SECRET" \
  -d '{
    "eventType": "delivered",
    "emailId": "EMAIL_ID_HERE",
    "recipientEmail": "recipient@example.com",
    "providerMessageId": "test-message-id-123"
  }'

# Test Bounced Event
curl -X POST https://YOUR_APP_URL/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "x-provider: generic" \
  -H "x-webhook-secret: YOUR_WEBHOOK_SECRET" \
  -d '{
    "eventType": "bounced",
    "emailId": "EMAIL_ID_HERE",
    "recipientEmail": "recipient@example.com",
    "providerMessageId": "test-message-id-123",
    "bounceType": "hard",
    "bounceReason": "550 Mailbox not found"
  }'

# Test Complaint Event
curl -X POST https://YOUR_APP_URL/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "x-provider: generic" \
  -H "x-webhook-secret: YOUR_WEBHOOK_SECRET" \
  -d '{
    "eventType": "complaint",
    "emailId": "EMAIL_ID_HERE",
    "recipientEmail": "recipient@example.com",
    "providerMessageId": "test-message-id-123",
    "complaintType": "spam"
  }'
```

#### Test SendGrid Webhook

```bash
curl -X POST https://YOUR_APP_URL/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "User-Agent: SendGrid" \
  -H "x-webhook-secret: YOUR_WEBHOOK_SECRET" \
  -d '[
    {
      "email": "recipient@example.com",
      "event": "delivered",
      "sg_message_id": "PROVIDER_MESSAGE_ID_HERE",
      "timestamp": 1234567890,
      "user_id": "user123"
    }
  ]'
```

#### Test Mailgun Webhook

```bash
curl -X POST https://YOUR_APP_URL/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mailgun" \
  -H "x-webhook-secret: YOUR_WEBHOOK_SECRET" \
  -d '{
    "event-data": {
      "event": "delivered",
      "recipient": "recipient@example.com",
      "message": {
        "headers": {
          "message-id": "PROVIDER_MESSAGE_ID_HERE"
        },
        "id": "PROVIDER_MESSAGE_ID_HERE"
      }
    }
  }'
```

#### Test Resend Webhook

```bash
curl -X POST https://YOUR_APP_URL/api/webhooks/email/providers \
  -H "Content-Type: application/json" \
  -H "x-webhook-secret: YOUR_WEBHOOK_SECRET" \
  -d '{
    "type": "email.delivered",
    "data": {
      "email_id": "PROVIDER_MESSAGE_ID_HERE",
      "to": "recipient@example.com"
    }
  }'
```

### Method 2: Using Postman

1. **Create a new POST request**
   - URL: `https://YOUR_APP_URL/api/webhooks/email/providers`
   - Method: POST

2. **Add Headers:**
   - `Content-Type: application/json`
   - `x-provider: generic` (or the provider you're testing)
   - `x-webhook-secret: YOUR_WEBHOOK_SECRET` (if configured)

3. **Add Body (raw JSON):**
   ```json
   {
     "eventType": "delivered",
     "emailId": "YOUR_EMAIL_ID",
     "recipientEmail": "recipient@example.com",
     "providerMessageId": "test-123"
   }
   ```

4. **Send the request** and check the response (should be `{ "success": true }`)

### Method 3: Testing Locally with ngrok

If you're testing locally, use ngrok to expose your local server:

1. **Install ngrok**: https://ngrok.com/download

2. **Start your Next.js dev server:**
   ```bash
   npm run dev
   ```

3. **Start ngrok:**
   ```bash
   ngrok http 3000
   ```

4. **Use the ngrok URL** in your webhook tests:
   ```bash
   curl -X POST https://your-ngrok-url.ngrok.io/api/webhooks/email/providers \
     -H "Content-Type: application/json" \
     -d '{ ... }'
   ```

5. **Configure provider webhooks** to point to your ngrok URL (for real provider testing)

### Method 4: Using Provider Dashboards

#### SendGrid
1. Go to SendGrid Dashboard → Settings → Mail Settings → Event Webhook
2. Add your webhook URL: `https://YOUR_APP_URL/api/webhooks/email/providers`
3. Select events: `delivered`, `bounce`, `dropped`, `spamreport`
4. Send a test email and check webhook logs in SendGrid

#### Mailgun
1. Go to Mailgun Dashboard → Sending → Webhooks
2. Add webhook URL: `https://YOUR_APP_URL/api/webhooks/email/providers`
3. Select events: `delivered`, `bounced`, `failed`, `complained`
4. Send a test email and check webhook logs

#### Resend
1. Go to Resend Dashboard → Webhooks
2. Add webhook URL: `https://YOUR_APP_URL/api/webhooks/email/providers`
3. Select events: `email.delivered`, `email.bounced`, `email.complained`
4. Send a test email and check webhook logs

## Verifying Webhook Events

After sending a webhook, verify the event was recorded:

### 1. Check `email_events` Table

```sql
-- View recent email events
SELECT 
  event_type,
  recipient_email,
  event_timestamp,
  provider_message_id,
  bounce_type,
  bounce_reason
FROM email_events
ORDER BY event_timestamp DESC
LIMIT 10;
```

### 2. Check Email Status

```sql
-- Check if email status was updated
SELECT 
  id,
  to_email,
  status,
  delivered_at,
  bounced_at
FROM emails
WHERE id = 'YOUR_EMAIL_ID';
```

### 3. Check Campaign Recipient Status

```sql
-- If email was part of a campaign
SELECT 
  id,
  email,
  status,
  delivered,
  bounced,
  delivered_at,
  bounced_at
FROM campaign_recipients
WHERE campaign_id = 'YOUR_CAMPAIGN_ID';
```

### 4. Check Analytics Dashboard

1. Go to `/dashboard/marketing/analytics`
2. Check if the event appears in the metrics
3. Verify bounce/complaint counts increased

## Testing Checklist

- [ ] **Delivered Event**: Send a delivered webhook and verify:
  - Event appears in `email_events` with `event_type = 'delivered'`
  - Email `status` is updated to 'delivered'
  - `delivered_at` timestamp is set
  - Analytics dashboard shows increased delivered count

- [ ] **Bounced Event (Hard)**: Send a hard bounce webhook and verify:
  - Event appears in `email_events` with `event_type = 'bounced'` and `bounce_type = 'hard'`
  - Email `status` is updated to 'bounced'
  - `bounced_at` timestamp is set
  - Campaign recipient `status` is updated to 'bounced'
  - Analytics dashboard shows increased bounce count

- [ ] **Bounced Event (Soft)**: Send a soft bounce webhook and verify:
  - Event appears with `bounce_type = 'soft'`
  - Other fields updated similarly to hard bounce

- [ ] **Complaint Event**: Send a complaint webhook and verify:
  - Event appears in `email_events` with `event_type = 'complaint'`
  - Campaign recipient `status` is updated appropriately
  - Analytics dashboard shows increased complaint count

- [ ] **Webhook Secret**: Test with and without webhook secret:
  - Without secret: Should work if `EMAIL_WEBHOOK_SECRET` is not set
  - With correct secret: Should work
  - With incorrect secret: Should return 401 Unauthorized

- [ ] **Provider Detection**: Test auto-detection:
  - Send without `x-provider` header
  - Verify provider is detected from User-Agent or body format

## Troubleshooting

### Webhook Returns 401 Unauthorized
- Check if `EMAIL_WEBHOOK_SECRET` is set in environment
- Verify the `x-webhook-secret` header matches the environment variable

### Webhook Returns "Email not found"
- Verify the `emailId` or `provider_message_id` exists in the `emails` table
- Check that the email was sent through your system
- For provider-specific webhooks, ensure `provider_message_id` matches

### Events Not Appearing in Database
- Check server logs for errors
- Verify `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set
- Check Supabase logs for database errors
- Verify the `email_events` table exists (run migration if needed)

### Provider-Specific Issues

**SendGrid:**
- Ensure `sg_message_id` matches the `provider_message_id` in your `emails` table
- SendGrid sends events as an array, even for single events

**Mailgun:**
- Ensure message ID is in `event-data.message.headers['message-id']` or `event-data.message.id`
- Mailgun uses nested `event-data` structure

**Resend:**
- Resend uses `email_id` in the `data` object
- Ensure this matches your `provider_message_id`

**AWS SES:**
- SES sends SNS notifications, which need to be parsed
- Ensure `mail.messageId` matches your `provider_message_id`

## Quick Test Script

Save this as `test-webhook.sh`:

```bash
#!/bin/bash

# Configuration
APP_URL="${APP_URL:-http://localhost:3000}"
EMAIL_ID="${EMAIL_ID:-your-email-id-here}"
RECIPIENT_EMAIL="${RECIPIENT_EMAIL:-test@example.com}"
WEBHOOK_SECRET="${WEBHOOK_SECRET:-}"

# Test delivered event
echo "Testing delivered event..."
curl -X POST "$APP_URL/api/webhooks/email/providers" \
  -H "Content-Type: application/json" \
  -H "x-provider: generic" \
  ${WEBHOOK_SECRET:+-H "x-webhook-secret: $WEBHOOK_SECRET"} \
  -d "{
    \"eventType\": \"delivered\",
    \"emailId\": \"$EMAIL_ID\",
    \"recipientEmail\": \"$RECIPIENT_EMAIL\",
    \"providerMessageId\": \"test-$(date +%s)\"
  }" | jq '.'

echo -e "\n✅ Delivered event sent. Check email_events table."
```

Run with:
```bash
chmod +x test-webhook.sh
APP_URL=https://yourdomain.com EMAIL_ID=your-email-id ./test-webhook.sh
```

## Next Steps

After testing webhooks:
1. Configure your email provider to send webhooks to your production URL
2. Monitor webhook logs in your provider dashboard
3. Set up alerts for webhook failures
4. Test with real email sends to verify end-to-end flow

