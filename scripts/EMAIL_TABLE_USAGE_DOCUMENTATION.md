# Email Table Usage Documentation

## Overview

The email system uses two main tables with different purposes:

1. **`emails` table** - Email log for sent/received emails (legacy + current)
2. **`email_threads` + `email_messages` tables** - Threaded conversations for Unibox (new system)

---

## Table: `emails`

**Purpose:** Log all email sends and receives for tracking, analytics, and campaigns.

**Direction Values:** `'sent'` | `'received'`
- `'sent'`: Outbound emails sent from the system
- `'received'`: Inbound emails received into the system

**Use Cases:**
- Email campaign tracking (`campaign_id`, `campaign_step_id`, `campaign_recipient_id`)
- Delivery status tracking (`status: 'queued' | 'sending' | 'sent' | 'failed'`)
- Email analytics and reporting
- Rate limiting (counts sent emails per mailbox)
- Legacy Unibox view (receives-only view)

**Key Fields:**
- `direction`: `'sent'` or `'received'`
- `status`: Email delivery status
- `campaign_id`, `campaign_step_id`: Campaign tracking
- `provider_message_id`: Provider's message ID (for deduplication)
- `raw_message_id`: Raw message ID for received emails

**When to Use:**
- Logging email sends from campaigns or composer
- Logging received emails from webhooks/sync
- Email analytics and reporting
- Rate limiting calculations

---

## Tables: `email_threads` + `email_messages`

**Purpose:** Threaded conversation view for Unibox (Instantly/Apollo-style inbox).

**Direction Values:** `'inbound'` | `'outbound'`
- `'inbound'`: Emails received (from external senders)
- `'outbound'`: Emails sent (from this system)

**Use Cases:**
- Unified inbox with threaded conversations
- Email threading and conversation grouping
- Reply/forward functionality
- CRM integration (linking to contacts, listings, campaigns)
- Real-time email sync from Gmail/Outlook/IMAP

**Key Fields:**
- `email_threads`: Groups messages into conversations
- `email_messages.direction`: `'inbound'` or `'outbound'`
- `email_participants`: From/to/cc/bcc addresses
- CRM links: `contact_id`, `listing_id`, `campaign_id`

**When to Use:**
- Unibox unified inbox view
- Threaded conversation display
- Reply/forward operations
- Real-time email sync

---

## Direction Field Mapping

### `emails` table (Legacy + Tracking)
```sql
direction: 'sent' | 'received'
```
- `'sent'` = Email sent from this system (outbound)
- `'received'` = Email received by this system (inbound)

### `email_messages` table (Unibox)
```sql
direction: 'inbound' | 'outbound'
```
- `'inbound'` = Email received by this system (same as `'received'`)
- `'outbound'` = Email sent from this system (same as `'sent'`)

### Mapping Logic

When syncing emails into Unibox:
- If email is from external sender → `direction: 'inbound'` in `email_messages`
- If email is from our mailbox → `direction: 'outbound'` in `email_messages`

When logging to `emails` table:
- If email is from external sender → `direction: 'received'` in `emails`
- If email is from our mailbox → `direction: 'sent'` in `emails`

**Translation:**
- `emails.direction = 'sent'` ↔ `email_messages.direction = 'outbound'`
- `emails.direction = 'received'` ↔ `email_messages.direction = 'inbound'`

---

## Why Two Systems?

### `emails` Table (Log-Based)
- **Purpose:** Audit trail and analytics
- **Design:** Flat structure, one row per email send/receive
- **Optimized for:** Campaign tracking, delivery status, analytics queries
- **Good for:** "How many emails did we send?" "What's the delivery rate?"

### `email_threads` + `email_messages` (Thread-Based)
- **Purpose:** Unified inbox experience
- **Design:** Threaded conversations with participants
- **Optimized for:** Conversation view, threading, CRM integration
- **Good for:** "Show me all emails with this contact" "Thread this conversation"

---

## Migration Path

### Current State
- Both systems coexist
- `emails` table: Used for logging and analytics
- `email_threads` + `email_messages`: Used for Unibox

### Future Consideration
- Option 1: Keep both (recommended)
  - `emails`: Analytics and campaign tracking
  - `email_threads`/`email_messages`: Unibox conversations
  
- Option 2: Migrate everything to threads
  - More complex migration
  - Would require restructuring campaign tracking
  - Not recommended - both serve different purposes

---

## Sync Connectors

### Gmail Connector
- Fetches messages from Gmail API
- Stores in both:
  - `emails` table: `direction='received'` for inbound
  - `email_threads`/`email_messages`: `direction='inbound'` for inbound

### Outlook Connector
- Fetches messages from Microsoft Graph
- Stores in both:
  - `emails` table: `direction='received'` for inbound
  - `email_threads`/`email_messages`: `direction='inbound'` for inbound

### IMAP Connector
- Fetches messages via IMAP
- Stores in both:
  - `emails` table: `direction='received'` for inbound
  - `email_threads`/`email_messages`: `direction='inbound'` for inbound

### Outbound Sends
- When sending via `sendViaMailbox()`:
  - Logs to `emails` table: `direction='sent'`
  - Optionally logs to `email_threads`/`email_messages`: `direction='outbound'`

---

## Best Practices

1. **For Campaign Tracking:** Use `emails` table
2. **For Unibox/Conversations:** Use `email_threads` + `email_messages`
3. **For Analytics:** Query `emails` table
4. **For Threaded View:** Query `email_threads` + `email_messages`
5. **Direction Mapping:** Always map correctly when syncing between systems

---

## Examples

### Logging a Sent Email
```sql
-- In emails table
INSERT INTO emails (..., direction = 'sent', ...)

-- In email_messages table (if part of a thread)
INSERT INTO email_messages (..., direction = 'outbound', ...)
```

### Logging a Received Email
```sql
-- In emails table
INSERT INTO emails (..., direction = 'received', ...)

-- In email_threads/email_messages
INSERT INTO email_messages (..., direction = 'inbound', ...)
```

---

## Related Files

- `supabase/email_received_schema.sql` - `emails` table direction schema
- `supabase/unibox_schema.sql` - `email_threads`/`email_messages` schema
- `lib/email/unibox/gmail-connector.ts` - Gmail sync implementation
- `lib/email/unibox/outlook-connector.ts` - Outlook sync implementation
- `lib/email/unibox/imap-connector.ts` - IMAP sync implementation

