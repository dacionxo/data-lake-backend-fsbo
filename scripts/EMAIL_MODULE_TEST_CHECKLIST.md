# Email Module Test Checklist

This document provides a comprehensive regression testing checklist for the email module improvements.

## Prerequisites

Before testing, ensure:
- [ ] Database migration has been run (`supabase/email_events_schema.sql`)
- [ ] Environment variables are set:
  - [ ] `NEXT_PUBLIC_SUPABASE_URL`
  - [ ] `SUPABASE_SERVICE_ROLE_KEY`
  - [ ] `CRON_SECRET`
- [ ] At least one mailbox is connected and active
- [ ] At least one email template exists

## 1. Event Tracking Tests

### 1.1 Open Tracking
- [ ] Send a test email
- [ ] Open the email in an email client
- [ ] Verify `opened` event appears in `email_events` table
- [ ] Verify event has correct `user_id`, `email_id`, `mailbox_id`
- [ ] Verify `ip_address` and `user_agent` are recorded
- [ ] Check analytics dashboard shows updated open count

### 1.2 Click Tracking
- [ ] Send an email with a tracked link
- [ ] Click the link in the email
- [ ] Verify `clicked` event appears in `email_events` table
- [ ] Verify `clicked_url` is recorded correctly
- [ ] Verify redirect to original URL works
- [ ] Check analytics dashboard shows updated click count

### 1.3 Send Event
- [ ] Create and send a campaign
- [ ] Verify `sent` event appears in `email_events` table
- [ ] Verify `provider_message_id` is recorded
- [ ] Check campaign stats update correctly

### 1.4 Delivery Event (via Webhook)
- [ ] Configure provider webhook (SendGrid/Mailgun/Resend/SES)
- [ ] Send a test email
- [ ] Verify webhook receives delivery notification
- [ ] Verify `delivered` event appears in `email_events` table
- [ ] Check analytics dashboard shows delivered count

### 1.5 Bounce Event (via Webhook)
- [ ] Send email to invalid/bouncing address
- [ ] Verify webhook receives bounce notification
- [ ] Verify `bounced` event appears in `email_events` table
- [ ] Verify `bounce_type` and `bounce_reason` are recorded
- [ ] Check recipient is marked as bounced in `campaign_recipients`

### 1.6 Complaint Event (via Webhook)
- [ ] Send email that triggers spam complaint (test environment)
- [ ] Verify webhook receives complaint notification
- [ ] Verify `complaint` event appears in `email_events` table
- [ ] Check recipient is marked appropriately

### 1.7 Reply Detection
- [ ] Send an email from a campaign
- [ ] Reply to the email
- [ ] Verify `replied` event appears in `email_events` table
- [ ] Verify `reply_message_id` is recorded
- [ ] Check campaign recipient is marked as replied

### 1.8 Failed Event
- [ ] Trigger a send failure (e.g., invalid mailbox, rate limit)
- [ ] Verify `failed` event appears in `email_events` table
- [ ] Verify error message is recorded in metadata
- [ ] Check failure appears in `email_failure_logs` table

## 2. Analytics Tests

### 2.1 Analytics Dashboard
- [ ] Navigate to `/dashboard/marketing/analytics`
- [ ] Verify all metric cards display correctly:
  - [ ] Delivered count
  - [ ] Open rate
  - [ ] Click rate
  - [ ] Reply rate
- [ ] Verify timeseries chart displays data
- [ ] Test mailbox filter (All vs specific mailbox)
- [ ] Test period filter (7d, 30d, 90d, all)
- [ ] Verify per-mailbox performance table displays

### 2.2 Health Widget
- [ ] Verify health widget displays on analytics page
- [ ] Check "Last 24h Failures" count
- [ ] Check bounce rate and complaint rate
- [ ] Verify top failure reasons display
- [ ] Test with healthy state (green)
- [ ] Test with unhealthy state (yellow) - trigger failures

### 2.3 Email Marketing Tab
- [ ] Navigate to `/dashboard/marketing` → Emails tab
- [ ] Verify "Recent Performance" chart uses real data (not stub)
- [ ] Verify "View full analytics" link works
- [ ] Check KPI cards display correct values
- [ ] Verify timeseries data updates correctly

### 2.4 Per-Recipient Analytics
- [ ] Navigate to a contact/lead detail page
- [ ] Click "Email engagement" button (if implemented)
- [ ] Verify engagement profile displays:
  - [ ] Total sent/delivered/opened/clicked/replied
  - [ ] Last open, click, reply timestamps
  - [ ] Recent event timeline
- [ ] Test with contact that has no email history
- [ ] Test with contact that has multiple email interactions

## 3. Mailbox Management Tests

### 3.1 Mailbox Display
- [ ] Navigate to Emails tab
- [ ] Verify mailbox cards show:
  - [ ] Provider icon (Gmail/Outlook/SMTP)
  - [ ] Status indicator (Connected/Token Expiring/Error/Inactive)
  - [ ] Last error message (if error exists)
  - [ ] Per-mailbox metrics (delivered, open rate, click rate)
- [ ] Test with multiple mailboxes
- [ ] Test with mailbox that has errors
- [ ] Test with mailbox with expiring token

### 3.2 Mailbox Selection
- [ ] Select a mailbox
- [ ] Verify campaigns/emails filter by selected mailbox
- [ ] Verify analytics filter by selected mailbox

## 4. Campaign Tests

### 4.1 Campaign Progress Display
- [ ] Create a multi-step campaign
- [ ] Create a single-send campaign
- [ ] Navigate to Emails tab → Campaigns
- [ ] Verify campaigns show:
  - [ ] "Multi-step" vs "Single send" label
  - [ ] Progress indicator (e.g., "250/1000 recipients completed")
  - [ ] Reply count (e.g., "50 replied")
- [ ] Verify progress updates as campaign runs

### 4.2 Campaign Preview
- [ ] Navigate to campaign builder
- [ ] Verify preview panel displays (if implemented)
- [ ] Test with sample recipient data:
  - [ ] First name substitution
  - [ ] Last name substitution
  - [ ] Custom metadata substitution
- [ ] Verify "Stop on reply" option is clearly visible

## 5. Social Planner Integration Tests

### 5.1 Email Events in Calendar
- [ ] Create a scheduled email campaign
- [ ] Navigate to Social Planner or Calendar
- [ ] Verify email events appear on calendar/timeline
- [ ] Verify events show correct date/time
- [ ] Click email event → verify opens campaign or analytics
- [ ] Test with multiple scheduled emails

### 5.2 Create Email Campaign from Planner
- [ ] Navigate to Social Planner
- [ ] Click on a calendar slot
- [ ] Verify "Create email campaign" action exists
- [ ] Click action → verify navigates to campaign builder
- [ ] Verify start date/time is pre-filled
- [ ] Verify mailbox is pre-selected (if applicable)

### 5.3 Cross-Channel Reporting
- [ ] Navigate to Analytics or cross-channel view
- [ ] Verify email metrics display alongside social metrics
- [ ] Test comparison chart (email sends vs social posts)
- [ ] Verify weekly/monthly comparison works

## 6. Cron Job Tests

### 6.1 Email Processing
- [ ] Queue an email (status = 'queued')
- [ ] Wait for cron job to run (up to 1 minute)
- [ ] Verify email status changes to 'sent'
- [ ] Verify `sent` event is recorded
- [ ] Check rate limits are respected
- [ ] Test with paused campaign (should not send)
- [ ] Test with cancelled campaign (should not send)

### 6.2 Rate Limiting
- [ ] Set mailbox with low hourly/daily limits
- [ ] Queue multiple emails
- [ ] Verify only allowed number are sent
- [ ] Verify remaining emails stay queued
- [ ] Check rate limit errors are logged

### 6.3 Token Refresh
- [ ] Set up Gmail/Outlook mailbox
- [ ] Wait for token to approach expiration
- [ ] Verify token refreshes automatically
- [ ] Verify emails continue sending after refresh

## 7. Error Handling Tests

### 7.1 Failure Logging
- [ ] Trigger various failure types:
  - [ ] Send failure
  - [ ] Provider error
  - [ ] Rate limit exceeded
  - [ ] Authentication error
- [ ] Verify failures appear in `email_failure_logs`
- [ ] Verify error message, code, stack are recorded
- [ ] Check context metadata is saved

### 7.2 Unsubscribe/Bounce Handling
- [ ] Mark recipient as unsubscribed
- [ ] Queue email to that recipient
- [ ] Verify email is not sent
- [ ] Verify appropriate status is set
- [ ] Test with hard-bounced email
- [ ] Test with globally unsubscribed email

## 8. Performance Tests

### 8.1 Large Campaigns
- [ ] Create campaign with 1000+ recipients
- [ ] Verify campaign processes correctly
- [ ] Check analytics load time
- [ ] Verify timeseries queries are performant

### 8.2 Multiple Mailboxes
- [ ] Set up 5+ mailboxes
- [ ] Verify mailbox selection works
- [ ] Check per-mailbox stats load correctly
- [ ] Test filtering performance

## 9. UI/UX Tests

### 9.1 Navigation
- [ ] Verify "Email Analytics" link in sidebar
- [ ] Test navigation between tabs
- [ ] Verify "View full analytics" link works
- [ ] Check breadcrumbs and back navigation

### 9.2 Responsive Design
- [ ] Test on mobile viewport
- [ ] Test on tablet viewport
- [ ] Verify charts are responsive
- [ ] Check tables scroll correctly

### 9.3 Dark Mode
- [ ] Toggle dark mode
- [ ] Verify all components display correctly
- [ ] Check charts are readable
- [ ] Verify status indicators are visible

## 10. Data Integrity Tests

### 10.1 Event Deduplication
- [ ] Open same email multiple times
- [ ] Verify only one `opened` event per day (or as configured)
- [ ] Click same link multiple times
- [ ] Verify click events are handled correctly

### 10.2 Data Migration
- [ ] Verify existing `email_opens` data migrated to `email_events`
- [ ] Verify existing `email_clicks` data migrated to `email_events`
- [ ] Check no duplicate events created

## 11. Export Tests

### 11.1 CSV Export
- [ ] Navigate to analytics page
- [ ] Click "Export CSV"
- [ ] Verify CSV downloads
- [ ] Open CSV and verify data:
  - [ ] Events export
  - [ ] Timeseries export
  - [ ] Recipients export
- [ ] Check CSV formatting (escaping, quotes, etc.)

## 12. Integration Tests

### 12.1 Webhook Integration
- [ ] Configure SendGrid webhook
- [ ] Send test email
- [ ] Verify webhook receives events
- [ ] Check events are recorded correctly
- [ ] Test with Mailgun, Resend, SES (if applicable)

### 12.2 Template Variables
- [ ] Create email with variables: {{firstName}}, {{lastName}}
- [ ] Send to recipient with data
- [ ] Verify variables are substituted correctly
- [ ] Check preview shows sample data

## Success Criteria

All tests should pass with:
- ✅ No console errors
- ✅ No database errors
- ✅ Events recorded correctly
- ✅ Analytics display accurate data
- ✅ UI is responsive and functional
- ✅ Performance is acceptable (< 2s load time)

## Known Issues / Limitations

Document any known issues or limitations discovered during testing:

1. 
2. 
3. 

## Test Results Summary

**Date**: _______________
**Tester**: _______________
**Environment**: _______________

**Total Tests**: _____
**Passed**: _____
**Failed**: _____
**Skipped**: _____

**Notes**:
_________________________________________________________________
_________________________________________________________________
_________________________________________________________________

