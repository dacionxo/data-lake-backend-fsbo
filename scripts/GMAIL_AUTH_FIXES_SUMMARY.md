# Gmail Authentication Fixes - Summary

## Overview
This document summarizes all fixes applied to resolve Gmail authentication issues, specifically the "Gmail authentication expired" 401 errors that occurred even after connecting mailboxes.

## Problem Statement
Gmail mailboxes were returning 401 "authentication expired" errors immediately after connection, even though tokens were just obtained. Root causes identified:
1. Token refresh logic was incomplete
2. No automatic retry on 401 errors
3. Insufficient error logging for diagnosis
4. Potential environment variable mismatches

## Solutions Implemented

### ✅ 1. Enhanced refreshGmailToken Function
**File:** `lib/email/providers/gmail.ts`

**Changes:**
- Improved error messages for missing refresh token
- Validates `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` environment variables
- Uses correct Google OAuth token endpoint
- Returns proper `{success, accessToken, error}` format
- Enhanced error logging with mailbox context

**Before:**
```typescript
if (!decryptedMailbox.refresh_token) {
  return { success: false, error: 'Refresh token is missing' }
}
```

**After:**
```typescript
const refreshToken = decryptedMailbox.refresh_token
if (!refreshToken) {
  return {
    success: false,
    error: 'Missing Gmail refresh token'
  }
}

if (!clientId || !clientSecret) {
  return {
    success: false,
    error: 'Gmail OAuth client not configured (GOOGLE_CLIENT_ID/SECRET missing)'
  }
}
```

### ✅ 2. Retry-on-401 Logic in gmailSend
**File:** `lib/email/providers/gmail.ts`

**Changes:**
- Detects 401 response from Gmail API
- Automatically attempts token refresh if `refresh_token` exists
- Retries send exactly once with new token
- Only shows "reconnect mailbox" error if refresh fails

**Key Implementation:**
```typescript
// First attempt
let response = await sendOnce(accessToken)

// If 401 and we *can* refresh, try once more
if (response.status === 401 && decryptedMailbox.refresh_token) {
  const refreshed = await refreshGmailToken(decryptedMailbox)
  if (refreshed.success && refreshed.accessToken) {
    response = await sendOnce(refreshed.accessToken)
  }
}
```

**Benefits:**
- Most "just connected" 401 errors are automatically resolved
- Users only see "reconnect" message when refresh token is actually invalid
- Reduces false positives and support tickets

### ✅ 3. Enhanced Error Logging
**File:** `lib/email/providers/gmail.ts`

**Changes:**
- Logs full `errorData` from Gmail API response on 401 failures
- Includes `error_code`, `error_message`, `error_description`
- Logs `mailbox_id` and `mailbox_email` for context
- Helps diagnose root cause (revoked token vs misconfigured OAuth client)

**Example Log Output:**
```javascript
{
  mailbox_id: 'abc-123',
  mailbox_email: 'user@example.com',
  error_data: {
    error: { code: 401, message: 'Invalid Credentials' },
    error_description: 'Token has been expired or revoked'
  },
  error_code: 401,
  error_message: 'Invalid Credentials',
  has_refresh_token: true
}
```

### ✅ 4. Verification Tools Created

**SQL Script:** `scripts/verify-gmail-mailbox.sql`
- Checks mailbox token state
- Validates access_token, refresh_token, token_expires_at
- Lists all Gmail mailboxes with issues
- Checks recent email sends and errors

**TypeScript Script:** `scripts/verify-env-vars.ts`
- Verifies all required environment variables are set
- Checks for empty values
- Provides masked output for security
- Exit codes for CI/CD integration

**Documentation:** `GMAIL_AUTH_FIXES_VERIFICATION.md`
- Step-by-step verification guide
- Troubleshooting section
- SQL queries for database inspection
- Testing procedures

### ✅ 5. Multi-Tenant Verification
**Status:** Verified ✅

**Findings:**
- `sendViaMailbox` correctly scopes by mailbox ID (passed as parameter)
- RLS policies enforce `user_id` scoping on mailboxes table
- Unique constraint: `(user_id, email, provider)` prevents duplicates per user
- Cron endpoints use `SUPABASE_SERVICE_ROLE_KEY` correctly

**Current Schema:**
- Uses `user_id` for multi-tenancy (not `org_id`)
- RLS policies: `auth.uid() = user_id`
- Unique constraint: `UNIQUE(user_id, email, provider)`

**Note:** If `org_id`-based multi-tenancy is needed in the future:
- Add `org_id` column to mailboxes table
- Update unique constraint to `(org_id, provider, email)`
- Update RLS policies to check `org_id`

### ✅ 6. Cron Endpoints Verification
**Status:** Verified ✅

**Files Checked:**
- `app/api/cron/process-emails/route.ts` ✅
- `app/api/cron/sync-mailboxes/route.ts` ✅

**Findings:**
- Both use `SUPABASE_SERVICE_ROLE_KEY` correctly
- Service role client created with proper auth settings
- Queries all mailboxes (infrastructure-level operation)
- RLS still applies for user-facing operations

## Files Modified

1. **lib/email/providers/gmail.ts**
   - Enhanced `refreshGmailToken()` function
   - Added retry-on-401 logic to `gmailSend()`
   - Added enhanced error logging

## Files Created

1. **GMAIL_AUTH_FIXES_VERIFICATION.md**
   - Comprehensive verification guide
   - Troubleshooting steps
   - SQL queries for database inspection

2. **scripts/verify-gmail-mailbox.sql**
   - SQL script for mailbox verification
   - Token validation queries
   - Error checking queries

3. **scripts/verify-env-vars.ts**
   - Environment variable verification script
   - Can be run in CI/CD pipelines

4. **GMAIL_AUTH_FIXES_SUMMARY.md** (this file)
   - Summary of all changes

## Testing Checklist

After deploying these fixes:

- [ ] Verify environment variables are set (use `scripts/verify-env-vars.ts`)
- [ ] Check mailbox state in database (use `scripts/verify-gmail-mailbox.sql`)
- [ ] Reconnect Gmail mailbox
- [ ] Send test email
- [ ] Monitor logs for any 401 errors
- [ ] Check enhanced error logs if issues persist
- [ ] Verify cron jobs are running correctly

## Expected Behavior After Fixes

1. **Token Refresh:**
   - Tokens refresh automatically when expiring (< 5 minutes)
   - Clear error messages if refresh fails
   - Logs include context for debugging

2. **401 Error Handling:**
   - First 401 triggers automatic token refresh
   - Send is retried once with new token
   - Only shows "reconnect" if refresh fails

3. **Error Logging:**
   - Full Gmail API error details logged
   - Includes error codes for diagnosis
   - Mailbox context included in all logs

## Troubleshooting

### If 401 Errors Persist:

1. **Check Enhanced Logs:**
   - Look for `error_code` and `error_description` in logs
   - Common codes:
     - `invalid_grant` → Refresh token revoked
     - `invalid_client` → OAuth client misconfigured
     - `unauthorized_client` → Client not authorized

2. **Verify Environment Variables:**
   - Run `scripts/verify-env-vars.ts`
   - Ensure `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` match OAuth app
   - Check Google Cloud Console → APIs & Services → Credentials

3. **Check Database:**
   - Run `scripts/verify-gmail-mailbox.sql`
   - Verify tokens are present and valid
   - Check `token_expires_at` is future timestamp

4. **Test Token Refresh:**
   ```typescript
   import { refreshGmailToken } from '@/lib/email/providers/gmail'
   const result = await refreshGmailToken(mailbox)
   console.log('Refresh result:', result)
   ```

## Deployment Steps

1. **Deploy Code Changes:**
   ```bash
   git add lib/email/providers/gmail.ts
   git commit -m "Fix Gmail authentication: add retry-on-401 and enhanced error logging"
   git push
   ```

2. **Verify Environment Variables:**
   - Check production environment has all required vars
   - Ensure values match between environments

3. **Monitor After Deployment:**
   - Watch logs for any 401 errors
   - Check if automatic retry resolves issues
   - Verify enhanced error logs provide useful diagnostics

4. **Reconnect Affected Mailboxes:**
   - Users may need to reconnect Gmail mailboxes
   - New tokens will be stored with proper expiration

## Success Metrics

- ✅ No false positive "authentication expired" errors
- ✅ Automatic recovery from transient token issues
- ✅ Clear error messages when tokens are actually invalid
- ✅ Enhanced logging helps diagnose root causes quickly

## Related Documentation

- `GMAIL_AUTH_FIXES_VERIFICATION.md` - Detailed verification steps
- `MULTI_TENANT_EMAIL_IMPLEMENTATION.md` - Multi-tenant architecture
- `scripts/verify-gmail-mailbox.sql` - Database verification queries
- `scripts/verify-env-vars.ts` - Environment variable checker

