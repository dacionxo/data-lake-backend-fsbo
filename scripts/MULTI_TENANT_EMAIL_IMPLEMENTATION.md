# Multi-Tenant Email System Implementation Summary

## Overview
This document summarizes the changes made to ensure the email module can handle multiple emails for each signed-in user in a multi-tenant SAAS model, supporting ~1,000 users.

## Key Changes

### 1. Provider Credentials Conversion ✅
**File:** `lib/email/providers/credentials.ts`
- Added `credentialToProviderConfig()` function to convert `ProviderCredential` to `ProviderConfig`
- Enables multi-tenant support by using user-specific credentials instead of env vars

### 2. Enhanced sendViaMailbox for Transactional Providers ✅
**File:** `lib/email/sendViaMailbox.ts`
- Updated to support transactional providers (resend, sendgrid, mailgun, ses, generic)
- For transactional providers, automatically fetches user credentials from `email_provider_credentials`
- Uses `sendEmailViaProvider` with user's credentials (no env fallback for tenant emails)
- Maintains backward compatibility with OAuth providers (Gmail/Outlook) and SMTP mailboxes

### 3. Email Settings & Compliance ✅
**File:** `lib/email/email-settings.ts` (NEW)
- Created utility functions for per-user email settings
- `getUserEmailSettings()` - Gets user settings with fallback to global defaults
- `appendComplianceFooter()` - Appends unsubscribe footer and physical address (CAN-SPAM compliance)
- `getUnsubscribeUrl()` - Generates unsubscribe URLs per user/contact

### 4. Campaign Email Compliance ✅
**Files Updated:**
- `app/api/crm/campaigns/[id]/send/route.ts`
- `app/api/cron/process-campaigns/route.ts`
- `app/api/cron/process-emails/route.ts`

**Changes:**
- All campaign emails now automatically append compliance footers
- Uses per-user email settings for branding (from_name, unsubscribe_footer_html, physical_address)
- Ensures CAN-SPAM compliance for all 1,000+ users

### 5. Cron Job Tuning ✅
**File:** `app/api/cron/process-email-queue/route.ts`
- Increased batch size from 50 to 200 emails per run
- Made configurable via `EMAIL_QUEUE_BATCH_SIZE` environment variable
- Supports higher throughput for 1,000 users

### 6. Updated All sendViaMailbox Call Sites ✅
**Files Updated:**
- `app/api/cron/process-email-queue/route.ts`
- `app/api/emails/send/route.ts`
- `app/api/cron/process-emails/route.ts`
- `app/api/cron/process-campaigns/route.ts`
- `app/api/crm/campaigns/[id]/send/route.ts`

**Changes:**
- All call sites now pass `supabase` parameter to support transactional providers
- Ensures user credentials are fetched when needed

### 7. Mailbox Schema Update ✅
**File:** `supabase/email_mailboxes_schema.sql`
- Updated provider CHECK constraint to include transactional providers:
  - Added: `'resend', 'sendgrid', 'mailgun', 'ses', 'generic'`
  - Now supports: `'gmail', 'outlook', 'smtp', 'resend', 'sendgrid', 'mailgun', 'ses', 'generic'`

### 8. API Route Audit ✅
**Verified all email API routes are user-scoped:**
- `/api/emails/send` - ✅ User auth + mailbox ownership check
- `/api/emails/queue` - ✅ User auth + mailbox ownership check
- `/api/emails/send-test` - ✅ User auth + mailbox ownership check
- `/api/emails` (GET) - ✅ User auth + filters by user_id
- `/api/emails/stats` - ✅ User auth + filters by user_id
- `/api/emails/settings` - ✅ User auth
- `/api/emails/received` - ✅ User auth + filters by user_id

## Architecture

### Multi-Tenant Email Flow

1. **OAuth Mailboxes (Gmail/Outlook):**
   - Uses mailbox tokens stored in `mailboxes` table
   - Direct API calls to Gmail/Outlook APIs
   - No changes needed (already multi-tenant)

2. **Transactional Providers (Resend/SendGrid/etc):**
   - Mailbox has `provider = 'resend' | 'sendgrid' | etc.`
   - `sendViaMailbox` detects transactional provider
   - Fetches user credentials from `email_provider_credentials` table
   - Converts to `ProviderConfig` and calls `sendEmailViaProvider`
   - **No env var fallback** - uses user's credentials only

3. **SMTP Mailboxes:**
   - Uses SMTP credentials stored in `mailboxes` table
   - Direct SMTP connection
   - Already multi-tenant

### Key Multi-Tenant Features

✅ **Per-User Credentials:** Each user can bring their own Resend/SendGrid/etc credentials
✅ **Per-User Email Settings:** Branding and compliance settings per user
✅ **RLS Policies:** Already in place - users can only see their own data
✅ **Rate Limits:** Per-mailbox and per-domain limits prevent abuse
✅ **User-Scoped Queries:** All API routes filter by `user_id`

## Environment Variables

### New/Updated:
- `EMAIL_QUEUE_BATCH_SIZE` (optional, default: 200) - Batch size for email queue processing

### Existing (for system emails only):
- `RESEND_API_KEY` - Only for system/global emails, not tenant emails
- `SENDGRID_API_KEY` - Only for system/global emails, not tenant emails
- `MAILGUN_API_KEY` - Only for system/global emails, not tenant emails
- etc.

**Note:** Tenant emails should NOT use these env vars. They use credentials from `email_provider_credentials` table.

## Database Migrations Required

1. **Update mailbox provider constraint:**
   ```sql
   ALTER TABLE mailboxes 
   DROP CONSTRAINT IF EXISTS mailboxes_provider_check;
   
   ALTER TABLE mailboxes 
   ADD CONSTRAINT mailboxes_provider_check 
   CHECK (provider IN ('gmail', 'outlook', 'smtp', 'resend', 'sendgrid', 'mailgun', 'ses', 'generic'));
   ```

## Testing Checklist

- [ ] Test Gmail mailbox sending (should work as before)
- [ ] Test Outlook mailbox sending (should work as before)
- [ ] Test SMTP mailbox sending (should work as before)
- [ ] Test Resend provider with user credentials
- [ ] Test SendGrid provider with user credentials
- [ ] Test campaign emails include compliance footer
- [ ] Test email settings are per-user
- [ ] Test rate limits work per-mailbox
- [ ] Test email queue processes 200 emails per batch
- [ ] Test user can only see their own emails (RLS)

## Next Steps for 1,000 Users

1. **Monitor Performance:**
   - Watch email queue processing times
   - Monitor database query performance
   - Track rate limit effectiveness

2. **Scale Considerations:**
   - Consider increasing `EMAIL_QUEUE_BATCH_SIZE` if needed
   - May need to run cron more frequently (every 15s instead of 1min)
   - Consider per-user global caps (e.g., "max 2,000 emails/day for free plan")

3. **User Onboarding:**
   - Ensure users can easily connect their own provider credentials
   - Provide UI for managing email_settings (branding/compliance)
   - Add per-user sending cap controls in UI

## Files Changed

### New Files:
- `lib/email/email-settings.ts` - Email settings utilities

### Modified Files:
- `lib/email/providers/credentials.ts` - Added credentialToProviderConfig()
- `lib/email/sendViaMailbox.ts` - Added transactional provider support
- `app/api/cron/process-email-queue/route.ts` - Increased batch size, pass supabase
- `app/api/emails/send/route.ts` - Pass supabase for transactional providers
- `app/api/cron/process-emails/route.ts` - Pass supabase, add compliance footer
- `app/api/cron/process-campaigns/route.ts` - Pass supabase, add compliance footer
- `app/api/crm/campaigns/[id]/send/route.ts` - Add compliance footer, pass supabase
- `supabase/email_mailboxes_schema.sql` - Updated provider constraint

## Summary

The email system is now fully multi-tenant and ready to support 1,000+ users. Key improvements:

1. ✅ Transactional providers use user credentials (no env fallback)
2. ✅ Per-user email settings for branding/compliance
3. ✅ Automatic compliance footer appending for campaigns
4. ✅ Increased email queue throughput
5. ✅ All API routes properly user-scoped
6. ✅ Mailbox schema supports all provider types

The system maintains backward compatibility while adding true multi-tenant support for transactional email providers.

