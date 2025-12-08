# Calendar Cron Jobs Documentation

This document describes all cron jobs configured for the world-class calendar system.

## Overview

The calendar system uses **7 cron jobs** running on Vercel to maintain synchronization, process reminders, handle follow-ups, and keep the system running smoothly.

## Cron Jobs

### 1. Reminders Processing
**Endpoint:** `/api/calendar/reminders/process`  
**Schedule:** Every 5 minutes (`*/5 * * * *`)  
**Purpose:** Process and send calendar reminders to users

**What it does:**
- Finds reminders that are due to be sent (within next 5 minutes)
- Sends email reminders via Resend
- Updates reminder status to 'sent'
- Handles multiple reminder types (email, in-app, SMS)

**Why every 5 minutes:**
- Ensures reminders are sent close to the scheduled time
- Balances accuracy with API rate limits

---

### 2. Follow-ups Processing
**Endpoint:** `/api/calendar/followups/process`  
**Schedule:** Every hour (`0 * * * *`)  
**Purpose:** Trigger automated follow-up workflows after events complete

**What it does:**
- Finds completed events with follow-up enabled
- Checks if follow-up delay has passed
- Triggers follow-up workflows:
  - Sends follow-up emails
  - Creates follow-up tasks
  - Updates CRM contact status
  - Schedules next follow-up events
- Marks follow-ups as triggered

**Why hourly:**
- Follow-ups typically have delays of hours or days
- Hourly check is sufficient for accuracy

---

### 3. Google Calendar Sync
**Endpoint:** `/api/calendar/cron/sync`  
**Schedule:** Every 15 minutes (`*/15 * * * *`)  
**Purpose:** Pull new and updated events from Google Calendar

**What it does:**
- Fetches events from Google Calendar (last 24 hours to next 7 days)
- Compares with local database
- Creates new events that don't exist locally
- Updates existing events that changed in Google Calendar
- Skips events if local version is newer (prevents overwriting local changes)
- Updates connection's `last_sync_at` timestamp

**Why every 15 minutes:**
- Balances real-time sync with API rate limits
- Ensures events appear within 15 minutes of creation in Google Calendar
- Prevents excessive API calls

---

### 4. Token Refresh
**Endpoint:** `/api/calendar/cron/token-refresh`  
**Schedule:** Every hour (`0 * * * *`)  
**Purpose:** Refresh expired or expiring Google Calendar access tokens

**What it does:**
- Finds Google Calendar connections with tokens expiring in the next hour
- Uses refresh tokens to get new access tokens
- Updates stored access tokens and expiration times
- Ensures connections remain active

**Why hourly:**
- Google tokens typically last 1 hour
- Refreshing before expiration prevents sync failures
- Hourly check catches all expiring tokens

---

### 5. Sync Retry
**Endpoint:** `/api/calendar/cron/sync-retry`  
**Schedule:** Every 30 minutes (`*/30 * * * *`)  
**Purpose:** Retry failed syncs to Google Calendar

**What it does:**
- Finds events with `sync_status = 'failed'` from the last 24 hours
- Retries pushing them to Google Calendar
- Updates sync status to 'synced' on success
- Handles up to 50 retries per run (prevents overload)

**Why every 30 minutes:**
- Gives transient errors time to resolve
- Balances retry frequency with system load
- Ensures failed syncs are eventually successful

---

### 6. Cleanup
**Endpoint:** `/api/calendar/cron/cleanup`  
**Schedule:** Daily at 2 AM (`0 2 * * *`)  
**Purpose:** Archive old events and clean up logs

**What it does:**
- Archives events older than 1 year (soft delete)
- Deletes sync logs older than 30 days
- Deletes sent reminders older than 7 days
- Clears expired webhook subscriptions

**Why daily:**
- Cleanup doesn't need to run frequently
- Running at night minimizes impact on users
- Keeps database size manageable

---

### 7. Webhook Renewal
**Endpoint:** `/api/calendar/cron/webhook-renewal`  
**Schedule:** Daily at 3 AM (`0 3 * * *`)  
**Purpose:** Renew Google Calendar webhook subscriptions

**What it does:**
- Finds webhooks expiring in the next 24 hours or already expired
- Deletes old webhook subscriptions
- Creates new webhook subscriptions (last 7 days)
- Updates connection records with new webhook IDs and expiration times

**Why daily:**
- Google Calendar webhooks expire after 7 days
- Daily renewal ensures webhooks never expire
- Running at night minimizes impact

---

## Webhook Handler

### Google Calendar Webhooks
**Endpoint:** `/api/calendar/webhooks/google`  
**Type:** Push notification handler (not a cron job)  
**Purpose:** Receive real-time notifications from Google Calendar

**What it does:**
- Receives push notifications when events change in Google Calendar
- Triggers immediate sync for the affected calendar
- Handles webhook verification requests
- Processes sync notifications

**How it works:**
- Google Calendar sends POST requests when events change
- Webhook handler extracts connection ID from notification
- Triggers sync cron job to pull latest events
- Provides near real-time sync (within 15 minutes)

---

## Authentication

All cron jobs require authentication via one of:
- `x-vercel-cron-secret` header (set by Vercel automatically)
- `x-service-key` header (custom service key)
- `Authorization: Bearer {CALENDAR_SERVICE_KEY}` header

**Environment Variables Required:**
- `CRON_SECRET` - Secret for Vercel cron authentication
- `CALENDAR_SERVICE_KEY` - Custom service key for authentication
- `NEXT_PUBLIC_SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase service role key
- `GOOGLE_CLIENT_ID` - Google OAuth client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `NEXT_PUBLIC_APP_URL` - Application URL (for webhooks)

---

## Monitoring

### Success Indicators
- Reminders: Check `calendar_reminders` table for `status = 'sent'`
- Follow-ups: Check `calendar_events` for `follow_up_triggered = true`
- Sync: Check `calendar_connections` for `last_sync_at` timestamps
- Token refresh: Check `calendar_connections` for recent `token_expires_at` updates
- Sync retry: Check `calendar_events` for `sync_status = 'synced'`
- Cleanup: Check archived events and deleted logs
- Webhook renewal: Check `calendar_connections` for `webhook_expires_at` > 7 days from now

### Error Handling
- All cron jobs log errors to console
- Failed operations don't block other operations
- Sync retry cron handles transient failures
- Token refresh prevents authentication failures

---

## Performance Considerations

### Rate Limits
- **Google Calendar API:** 1,000,000 queries per day per project
- **Vercel Cron:** Unlimited (but respect API rate limits)
- Each sync fetches up to 250 events per connection
- Sync retry limits to 50 events per run

### Optimization
- Sync only fetches events from last 24 hours to next 7 days
- Cleanup runs at night to minimize impact
- Webhook renewal batches all connections
- Token refresh only processes expiring tokens

---

## Total Cron Jobs: 7

1. ✅ Reminders Processing (every 5 minutes)
2. ✅ Follow-ups Processing (hourly)
3. ✅ Google Calendar Sync (every 15 minutes)
4. ✅ Token Refresh (hourly)
5. ✅ Sync Retry (every 30 minutes)
6. ✅ Cleanup (daily at 2 AM)
7. ✅ Webhook Renewal (daily at 3 AM)

---

## Future Enhancements

Potential additional cron jobs:
- **Free/Busy Cache Refresh** - Update availability cache hourly
- **Analytics Aggregation** - Daily aggregation of calendar metrics
- **Notification Queue Processing** - Process queued notifications
- **Backup** - Daily backup of calendar data
- **Health Check** - Monitor cron job health and alert on failures

---

## Troubleshooting

### Cron jobs not running
- Check Vercel dashboard for cron job status
- Verify `CRON_SECRET` environment variable is set
- Check Vercel logs for authentication errors

### Sync not working
- Verify Google Calendar connection is active
- Check token expiration times
- Review sync logs in database
- Ensure webhook subscriptions are active

### High API usage
- Review sync frequency (currently every 15 minutes)
- Check number of active connections
- Monitor Google Cloud Console for quota usage
- Consider implementing incremental sync tokens

---

## Summary

This comprehensive cron job system ensures:
- ✅ **Real-time sync** - Events appear within 15 minutes
- ✅ **Reliable reminders** - Sent within 5 minutes of scheduled time
- ✅ **Automated follow-ups** - Triggered automatically after events
- ✅ **Token management** - Tokens refreshed before expiration
- ✅ **Error recovery** - Failed syncs automatically retried
- ✅ **Database maintenance** - Old data cleaned up regularly
- ✅ **Webhook reliability** - Webhooks renewed before expiration

The system is designed to be **world-class**, **reliable**, and **scalable**.

