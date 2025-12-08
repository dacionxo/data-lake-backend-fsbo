# Email Unibox - Received Emails Setup Guide

## Overview

The Unibox displays **only received/incoming emails** (not sent emails). This guide explains how received emails are logged and displayed.

## Database Schema

The `emails` table has been extended to support received emails with the following fields:

- `direction`: `'sent'` or `'received'` (default: `'sent'`)
- `from_email`: Sender's email address
- `from_name`: Sender's display name
- `received_at`: Timestamp when email was received
- `thread_id`: For grouping conversation threads
- `in_reply_to`: Message ID this is replying to
- `raw_message_id`: Provider's message ID (Gmail/Outlook)
- `is_read`: Whether the email has been read
- `is_starred`: Whether the email is starred

**Important:** Run `supabase/email_received_schema.sql` to add these columns to your database.

## API Endpoints

### GET `/api/emails/received`
Fetches only received emails for the authenticated user.

**Query Parameters:**
- `limit`: Number of emails to fetch (default: 50)
- `offset`: Pagination offset (default: 0)
- `mailboxId`: Filter by specific mailbox (optional)

**Response:**
```json
{
  "emails": [
    {
      "id": "...",
      "from_email": "sender@example.com",
      "from_name": "Sender Name",
      "to_email": "your@email.com",
      "subject": "Email Subject",
      "html": "...",
      "received_at": "2025-11-29T21:46:00Z",
      "is_read": false,
      "is_starred": false
    }
  ],
  "count": 1
}
```

### POST `/api/emails/received`
Logs a received email (typically called by webhook or email sync service).

**Request Body:**
```json
{
  "mailbox_id": "uuid",
  "from_email": "sender@example.com",
  "from_name": "Sender Name",
  "to_email": "your@email.com",
  "subject": "Email Subject",
  "html": "<p>Email content</p>",
  "received_at": "2025-11-29T21:46:00Z",
  "raw_message_id": "gmail_message_id_123",
  "thread_id": "thread_123",
  "in_reply_to": "message_id_456"
}
```

## How to Log Received Emails

### Option 1: Gmail API Webhook (Recommended)

Set up Gmail push notifications to receive emails in real-time:

1. **Configure Gmail Watch** - Use Gmail API to watch for new messages
2. **Webhook Endpoint** - When a new email arrives, call `POST /api/emails/received`
3. **Real-time Sync** - Emails appear in Unibox immediately

**Implementation Status:** ✅ **COMPLETE**

The Gmail webhook handler has been fully implemented:

- **Webhook Endpoint**: `/api/webhooks/gmail` - Receives push notifications from Gmail
- **Watch Setup API**: `POST /api/mailboxes/[id]/watch` - Sets up Gmail Watch for a mailbox
- **Watch Stop API**: `DELETE /api/mailboxes/[id]/watch` - Stops Gmail Watch
- **Gmail Utilities**: `lib/email/providers/gmail-watch.ts` - Helper functions for Gmail API

**Setup Steps:**

1. **Run Database Migration**: Execute `supabase/email_mailboxes_watch_schema.sql` to add watch fields

2. **Configure Google Cloud Pub/Sub**:
   - Create a Pub/Sub topic in Google Cloud Console
   - Create a push subscription pointing to: `https://www.growyourdigitalleverage.com/api/webhooks/gmail`
   - Set `GMAIL_PUBSUB_TOPIC_NAME` environment variable (e.g., `projects/your-project/topics/gmail-notifications`)

3. **Set Up Gmail Watch**:
   ```bash
   # Enable Gmail Watch for a mailbox
   POST /api/mailboxes/{mailboxId}/watch
   ```

4. **How It Works**:
   - Gmail sends push notifications to your Pub/Sub topic
   - Pub/Sub forwards to `/api/webhooks/gmail`
   - Webhook handler fetches new emails from Gmail API
   - Emails are logged via `POST /api/emails/received`
   - Unibox displays received emails in real-time

**Example Webhook Handler (Already Implemented):**
```typescript
// app/api/webhooks/gmail/route.ts
// This file has been created and handles:
// - Pub/Sub message decoding
// - Mailbox lookup by email address
// - Gmail API message fetching
// - Email parsing and logging
```

### Option 2: Polling Service

Create a cron job or background service that periodically fetches new emails:

1. **Poll Gmail/Outlook API** - Check for new messages every few minutes
2. **Filter by `received_at`** - Only fetch emails newer than last sync
3. **Insert via API** - Call `POST /api/emails/received` for each new email

### Option 3: Manual Logging

For testing or manual processes, you can directly call the API:

```bash
curl -X POST http://localhost:3000/api/emails/received \
  -H "Content-Type: application/json" \
  -d '{
    "mailbox_id": "your-mailbox-id",
    "from_email": "sender@example.com",
    "from_name": "Sender",
    "to_email": "your@email.com",
    "subject": "Test Email",
    "html": "<p>Test content</p>"
  }'
```

## Unibox Display

The Unibox component:
- ✅ Only fetches emails with `direction = 'received'`
- ✅ Displays emails in a clean, readable format
- ✅ Shows sender, recipient, date, and formatted content
- ✅ Shows demo email if no received emails exist

## Important Notes

1. **Sent emails are NOT shown in Unibox** - Only received emails appear
2. **Direction field is required** - All emails must have `direction` set to either `'sent'` or `'received'`
3. **Default behavior** - Existing emails default to `direction = 'sent'`
4. **Schema migration** - Run `supabase/email_received_schema.sql` before using Unibox

## Next Steps

1. ✅ Run the database schema migration
2. ✅ Set up Gmail/Outlook webhooks or polling service
3. ✅ Test by manually logging a received email via API
4. ✅ Verify Unibox displays received emails correctly

## Example: Setting Up Gmail Webhook

```typescript
// 1. Watch Gmail inbox for new messages
const { data } = await gmail.users.watch({
  userId: 'me',
  requestBody: {
    topicName: 'projects/your-project/topics/gmail-notifications',
    labelIds: ['INBOX']
  }
})

// 2. When notification arrives, fetch email
const email = await gmail.users.messages.get({
  userId: 'me',
  id: notification.messageId,
  format: 'full'
})

// 3. Log to database
await fetch('/api/emails/received', {
  method: 'POST',
  body: JSON.stringify({
    mailbox_id: mailboxId,
    from_email: email.payload.headers.find(h => h.name === 'From').value,
    // ... other fields
  })
})
```

