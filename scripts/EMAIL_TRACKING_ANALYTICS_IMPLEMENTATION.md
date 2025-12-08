# Email Tracking, Analytics & Logging Implementation

## Overview

This document describes the comprehensive email tracking, analytics, and logging system that has been implemented for the LeadMap email marketing platform.

## ✅ Completed Features

### 1. Unified Email Events Table

**File:** `supabase/email_events_schema.sql`

A unified `email_events` table tracks all email events in one place:
- **Event Types:** `sent`, `delivered`, `opened`, `clicked`, `replied`, `bounced`, `complaint`, `failed`, `deferred`, `dropped`
- **Comprehensive Metadata:** IP addresses, user agents, bounce reasons, complaint details, etc.
- **Deduplication:** Automatic event hash generation to prevent duplicate events
- **Backwards Compatible:** Migrates existing data from `email_opens` and `email_clicks` tables

**Key Features:**
- Links to emails, campaigns, mailboxes, contacts
- Flexible JSONB metadata field for event-specific data
- Optimized indexes for fast queries
- Database functions for easy event recording

### 2. Open Tracking

**Files:**
- `app/api/email/track/open/route.ts` (enhanced)

**Features:**
- Returns 1x1 transparent pixel image
- Records opens to unified `email_events` table
- Backwards compatible with legacy `email_opens` table
- Deduplication support
- IP and user agent tracking
- Device type detection (mobile/desktop)

**Usage:**
```
GET /api/email/track/open?email_id=...&recipient_id=...&campaign_id=...
```

### 3. Click Tracking

**Files:**
- `app/api/email/track/click/route.ts` (enhanced)
- `app/api/r/[eventId]/route.ts` (new clean URL pattern)

**Features:**
- Two tracking methods:
  1. Query parameter: `/api/email/track/click?url=...&email_id=...`
  2. Clean URL: `/r/{eventId}` (shorter, branded URLs)
- Records clicks to unified `email_events` table
- Backwards compatible with legacy `email_clicks` table
- Redirects to original URL
- Tracks clicked URL, IP, user agent

**Usage:**
```
GET /api/email/track/click?url=https://example.com&email_id=...&recipient_id=...
GET /r/{base64EncodedEventId}
```

### 4. Per-Recipient Engagement Profiles

**Files:**
- Database view: `recipient_engagement_profiles`
- Database function: `get_recipient_engagement()`
- API endpoint: `app/api/email/analytics/recipient/route.ts`

**Features:**
- Aggregated metrics per recipient email:
  - Total emails sent/delivered/opened/clicked/replied
  - Total opens/clicks (not unique emails)
  - Open rate, click rate, reply rate
  - First/last contact timestamps
  - First/last open/click/reply timestamps
- Recent events history
- Link to contacts table

**Usage:**
```
GET /api/email/analytics/recipient?email=recipient@example.com
GET /api/email/analytics/recipient?contactId=...
```

### 5. Time-Series Analytics

**File:** `app/api/email/analytics/timeseries/route.ts`

**Features:**
- Daily/weekly/monthly aggregated metrics
- Event counts by type per time period
- Total counts and rates across period
- Filterable by mailbox, campaign, date range
- Optimized queries with indexes

**Metrics Tracked:**
- Sends, delivered, opened, clicked, replied
- Bounced, complaint, failed
- Delivery rate, open rate, click rate, reply rate
- Bounce rate, complaint rate, failure rate

**Usage:**
```
GET /api/email/analytics/timeseries?startDate=2024-01-01&endDate=2024-01-31&mailboxId=...&groupBy=day
```

### 6. Enhanced Stats Endpoint

**File:** `app/api/emails/stats/route.ts` (enhanced)

**Features:**
- Uses unified `email_events` table for accurate metrics
- Fallback to `emails` table if events not available
- Per-mailbox statistics
- All standard email metrics
- Filterable by date range and mailbox

**Response Format:**
```json
{
  "stats": {
    "delivered": 1000,
    "opened": 250,
    "clicked": 50,
    "bounced": 10,
    "spamComplaints": 2,
    "openRate": 25.0,
    "clickRate": 5.0,
    ...
  },
  "perMailbox": [
    {
      "mailboxId": "...",
      "mailboxEmail": "sender@example.com",
      "delivered": 500,
      "opened": 125,
      "openRate": 25.0,
      ...
    }
  ]
}
```

### 7. CSV Export

**File:** `app/api/email/analytics/export/route.ts`

**Features:**
- Export email events as CSV
- Export time-series data as CSV
- Export recipient engagement profiles as CSV
- Limit of 10,000 records per export
- Properly escaped CSV formatting
- Downloadable files with appropriate headers

**Usage:**
```
GET /api/email/analytics/export?format=csv&type=events&startDate=...&endDate=...
GET /api/email/analytics/export?format=csv&type=recipients
GET /api/email/analytics/export?format=csv&type=timeseries
```

### 8. Email Failure Logging

**File:** `supabase/email_events_schema.sql` (email_failure_logs table)

**Features:**
- Dedicated table for tracking failures
- Failure types:
  - `send_failed`, `provider_error`, `rate_limit_exceeded`
  - `authentication_error`, `webhook_error`, `cron_job_failed`
  - `database_error`, `unknown_error`
- Error messages, codes, stack traces
- Context metadata (JSONB)
- Alerting support (alert_sent flag)
- Resolution tracking

## 🔄 Integration Points (To Be Completed)

The following need to be integrated with existing systems:

### 9. Event Tracking in Email Sending

**Status:** Pending

Need to add event recording when emails are sent:
- Record `sent` event when email is queued/sent
- Record `delivered` event when provider confirms delivery
- Record `failed` event on send failures

**Files to modify:**
- `app/api/cron/process-emails/route.ts`
- `lib/email/sendViaMailbox.ts`

### 10. Webhook Integration for Provider Events

**Status:** Pending

Need to add webhook handlers for:
- Delivery confirmations → `delivered` events
- Bounce notifications → `bounced` events
- Spam complaints → `complaint` events

**Files to create/modify:**
- `app/api/webhooks/email/providers/route.ts` (new)
- Existing bounce handler: `app/api/emails/bounces/route.ts` (enhance)

### 11. Reply Detection Event Tracking

**Status:** Pending

Need to record `replied` events when replies are detected:
- Integrate with existing reply detection
- Link to original email/campaign

**Files to modify:**
- `lib/email/reply-detection.ts`

## Database Schema

### Main Tables

1. **`email_events`** - Unified event tracking
   - Primary table for all email events
   - Links to emails, campaigns, mailboxes, contacts
   - Comprehensive metadata storage

2. **`email_failure_logs`** - Failure tracking
   - Dedicated table for errors and failures
   - Alerting and resolution tracking

3. **`recipient_engagement_profiles`** (view) - Aggregated recipient metrics
   - Materialized view of engagement data
   - Fast queries for recipient analytics

### Migration

The schema automatically migrates existing data:
- `email_opens` → `email_events` (event_type: 'opened')
- `email_clicks` → `email_events` (event_type: 'clicked')

Old tables remain for backwards compatibility.

## API Endpoints Summary

### Tracking Endpoints
- `GET /api/email/track/open` - Open tracking pixel
- `GET /api/email/track/click` - Click tracking (query params)
- `GET /r/:eventId` - Click tracking (clean URLs)

### Analytics Endpoints
- `GET /api/email/analytics/timeseries` - Time-series data
- `GET /api/email/analytics/recipient` - Per-recipient engagement
- `GET /api/emails/stats` - Overall statistics (enhanced)

### Export Endpoints
- `GET /api/email/analytics/export` - CSV export

## Next Steps

1. **Run Database Migration:**
   ```sql
   -- Run in Supabase SQL Editor
   \i supabase/email_events_schema.sql
   ```

2. **Integrate Event Tracking:**
   - Add `sent`/`delivered` events to email sending
   - Add webhook handlers for provider events
   - Add `replied` events to reply detection

3. **Create Dashboard Components:**
   - Email analytics dashboard
   - Time-series charts
   - Per-mailbox performance views
   - Recipient engagement views

4. **Set Up Alerting:**
   - Configure alerts for email failures
   - Set up notifications for high bounce/complaint rates
   - Monitor mailbox reputation

5. **Add UI Features:**
   - Email performance dashboard
   - Export buttons in analytics views
   - Per-recipient engagement profiles in contact views

## Performance Considerations

- All queries use indexed columns for fast lookups
- Composite indexes for common query patterns
- Event deduplication prevents duplicate records
- Time-series queries optimized with date-based indexes
- Export endpoints limited to 10,000 records

## Security

- All endpoints require authentication
- User isolation (events filtered by user_id)
- Input validation and sanitization
- Rate limiting recommended for tracking endpoints

