# Unibox Email System Implementation Guide

## Overview

This document describes the comprehensive Unibox email system implementation for LeadMap. The system provides a unified inbox experience similar to Instantly/Apollo, with multi-provider support (Gmail, Outlook, IMAP), threaded conversations, CRM integration, and real-time sync.

## Database Schema

### Setup Instructions

1. **Run the Unibox schema SQL:**
   ```sql
   -- Run this file in Supabase SQL Editor
   supabase/unibox_schema.sql
   ```

   This creates:
   - Updates to `mailboxes` table (sync_state, last_synced_at, IMAP fields)
   - `email_threads` - Groups related messages
   - `email_messages` - Individual email messages
   - `email_participants` - From/To/Cc/Bcc recipients
   - `email_attachments` - Attachment metadata
   - `email_forwarding_rules` - Auto-forwarding rules
   - `email_labels` - Gmail labels / Outlook folders
   - Full-text search indexes and RLS policies

### Key Tables

#### email_threads
- Groups messages into conversations
- Links to CRM entities (contacts, listings, campaigns)
- Tracks status (open, needs_reply, waiting, closed, ignored)
- Maintains unread, starred, archived states

#### email_messages
- Individual messages within threads
- Supports inbound and outbound
- Stores body (HTML and plain text)
- Preserves threading headers (In-Reply-To, References)

## Provider Connectors

### Gmail Connector (`lib/email/unibox/gmail-connector.ts`)

**Features:**
- Full message fetch with format=full
- Threaded message parsing
- Initial sync and polling
- Push notifications via Gmail Watch (integrated with existing watch system)

**Usage:**
```typescript
import { syncGmailMessages } from '@/lib/email/unibox/gmail-connector'

const result = await syncGmailMessages(mailboxId, userId, accessToken, {
  since: '2024-01-01T00:00:00Z',
  maxMessages: 100
})
```

### Outlook Connector (`lib/email/unibox/outlook-connector.ts`)

**Features:**
- Microsoft Graph API integration
- Change notifications support
- Automatic token refresh
- Conversation threading

**Usage:**
```typescript
import { syncOutlookMessages } from '@/lib/email/unibox/outlook-connector'

const result = await syncOutlookMessages(mailboxId, userId, accessToken, mailboxEmail, {
  since: '2024-01-01T00:00:00Z',
  maxMessages: 100
})
```

### IMAP Connector (TODO)

IMAP connector is planned but not yet implemented. It will support generic IMAP servers for email providers that don't have modern APIs.

## CRM Linking Service

### Email Linker (`lib/email/unibox/email-linker.ts`)

Automatically matches emails to CRM entities:

1. **Contact Matching:**
   - Matches participant emails to contacts table
   - Updates `email_participants.contact_id`
   - Updates `email_threads.contact_id`

2. **Listing Matching:**
   - Matches emails to listing owner emails
   - Updates `email_threads.listing_id`

3. **Campaign Reply Detection:**
   - Matches In-Reply-To and References headers
   - Links to original campaign email
   - Marks campaign recipients as "replied"

**Usage:**
```typescript
import { linkEmailToCRM } from '@/lib/email/unibox/email-linker'

const result = await linkEmailToCRM(messageId, userId, {
  from: { email: 'sender@example.com', name: 'Sender' },
  to: [{ email: 'recipient@example.com', name: 'Recipient' }],
  inReplyTo: '<message-id>',
  references: ['<msg1>', '<msg2>']
})
```

## API Endpoints

### Threads

#### GET `/api/unibox/threads`
List email threads with pagination and filtering.

**Query Parameters:**
- `mailboxId` - Filter by mailbox
- `status` - Filter by status (open, needs_reply, waiting, closed, ignored)
- `search` - Full-text search
- `campaignId` - Filter by campaign
- `contactId` - Filter by contact
- `page` - Page number (default: 1)
- `pageSize` - Items per page (default: 50, max: 100)

**Response:**
```json
{
  "threads": [
    {
      "id": "uuid",
      "subject": "Subject",
      "mailbox": { "id": "...", "email": "...", "provider": "gmail" },
      "status": "open",
      "unread": true,
      "unreadCount": 2,
      "lastMessage": { "direction": "inbound", "snippet": "...", "received_at": "..." },
      "lastMessageAt": "2024-01-01T00:00:00Z",
      "messageCount": 5
    }
  ],
  "pagination": { "page": 1, "pageSize": 50, "total": 100, "totalPages": 2 }
}
```

#### GET `/api/unibox/threads/[id]`
Get detailed thread with all messages, participants, and CRM context.

**Response:**
```json
{
  "thread": {
    "id": "uuid",
    "subject": "Subject",
    "status": "open",
    "mailbox": { ... },
    "messages": [
      {
        "id": "uuid",
        "direction": "inbound",
        "subject": "Subject",
        "body_html": "<html>...</html>",
        "body_plain": "Plain text",
        "received_at": "2024-01-01T00:00:00Z",
        "email_participants": [ ... ],
        "email_attachments": [ ... ]
      }
    ],
    "contact": { ... },
    "listing": { ... },
    "campaign": { ... }
  }
}
```

#### PATCH `/api/unibox/threads/[id]`
Update thread properties (status, unread, starred, archived).

**Body:**
```json
{
  "status": "closed",
  "unread": false,
  "starred": true
}
```

#### POST `/api/unibox/threads/[id]/reply`
Reply to a thread.

**Body:**
```json
{
  "mailboxId": "uuid",
  "bodyHtml": "<p>Reply content</p>",
  "bodyText": "Reply content",
  "replyAll": false,
  "cc": ["cc@example.com"],
  "bcc": []
}
```

### Sync

#### POST `/api/cron/sync-mailboxes`
Cron job endpoint to sync all active mailboxes. Should be called every 5 minutes.

**Authentication:**
- Requires `x-vercel-cron-secret` header or `CRON_SECRET` in Authorization header

**Response:**
```json
{
  "success": true,
  "synced": 3,
  "failed": 0,
  "total": 3,
  "results": [
    {
      "mailboxId": "uuid",
      "email": "user@example.com",
      "status": "success",
      "messagesProcessed": 15,
      "threadsCreated": 5,
      "threadsUpdated": 10
    }
  ]
}
```

## Sync Configuration

### Vercel Cron Jobs

Add to `vercel.json`:

```json
{
  "crons": [
    {
      "path": "/api/cron/sync-mailboxes",
      "schedule": "*/5 * * * *"
    }
  ]
}
```

This syncs mailboxes every 5 minutes.

## Frontend Components (TODO)

### Unibox Page (`app/dashboard/unibox/page.tsx`)

Three-pane layout:
1. **Left Sidebar:** Mailbox filter, folders (Inbox, Needs Reply, Waiting, Closed), filters by campaign/contact
2. **Middle Column:** Thread list with unread indicators, snippets, timestamps
3. **Right Panel:** Conversation view with reply/compose interface

### Components Needed:
- `UniboxSidebar.tsx` - Left sidebar with filters
- `ThreadList.tsx` - List of email threads
- `ThreadView.tsx` - Conversation view
- `ReplyComposer.tsx` - Rich text editor for replies/forwards

## Next Steps

1. **Create IMAP connector** for generic email providers
2. **Build Unibox UI components** (see Frontend Components section)
3. **Add Outlook reply headers** support in Outlook provider
4. **Implement forward endpoint** (`/api/unibox/threads/[id]/forward`)
5. **Add attachment handling** for inbound/outbound messages
6. **Create email forwarding rules UI** in settings
7. **Add real-time updates** via WebSocket or polling

## Testing

### Manual Testing Checklist

1. **Gmail Sync:**
   - Connect Gmail mailbox
   - Wait for cron sync
   - Verify emails appear in Unibox
   - Check threading is correct

2. **Outlook Sync:**
   - Connect Outlook mailbox
   - Wait for cron sync
   - Verify emails appear
   - Check conversation threading

3. **CRM Linking:**
   - Send email to contact
   - Receive reply
   - Verify thread linked to contact
   - Verify campaign recipient marked as replied

4. **Reply Functionality:**
   - Open thread
   - Click reply
   - Send reply
   - Verify outbound message logged
   - Verify thread status updated

## Troubleshooting

### Common Issues

1. **Emails not syncing:**
   - Check mailbox `sync_state` in database
   - Check `last_error` field
   - Verify access token is valid
   - Check cron job is running

2. **Threading issues:**
   - Verify `provider_thread_id` is set correctly
   - Check In-Reply-To and References headers are preserved

3. **CRM links not working:**
   - Verify contact email matches participant email
   - Check campaign emails have `provider_message_id` set

## Security Considerations

1. **Token Storage:** Access tokens are stored in Supabase (should be encrypted in production)
2. **RLS Policies:** All tables have RLS enabled - users can only see their own data
3. **Rate Limiting:** Mailbox rate limits are enforced
4. **Cron Authentication:** Sync endpoint requires cron secret

## Performance

- Full-text search indexes on subject and body
- Indexes on user_id, mailbox_id, provider_thread_id
- Pagination on all list endpoints
- Efficient queries with proper joins

