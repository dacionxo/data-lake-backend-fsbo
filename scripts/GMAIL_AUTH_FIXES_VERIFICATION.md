# Gmail Authentication Fixes - Verification Guide

This document provides verification steps for all 8 items in the Gmail authentication fix to-do list.

## ✅ Completed Code Fixes

### 1. ✅ refreshGmailToken Function (Item 1)
**Location:** `lib/email/providers/gmail.ts`

**Improvements Made:**
- ✅ Clear error messages for missing refresh token
- ✅ Validates GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET env vars
- ✅ Uses correct Google OAuth endpoint (`https://oauth2.googleapis.com/token`)
- ✅ Returns proper `{success, accessToken, error}` format
- ✅ Enhanced error logging with mailbox context

### 2. ✅ Retry-on-401 Logic (Item 2)
**Location:** `lib/email/providers/gmail.ts` - `gmailSend` function

**Improvements Made:**
- ✅ Detects 401 response from Gmail API
- ✅ Automatically attempts token refresh if refresh_token exists
- ✅ Retries send exactly once with new token
- ✅ Only shows "reconnect mailbox" error if refresh fails

### 3. ✅ Enhanced Error Logging (Item 8)
**Location:** `lib/email/providers/gmail.ts`

**Improvements Made:**
- ✅ Logs full errorData from Gmail API response on 401 failures
- ✅ Includes error_code, error_message, error_description
- ✅ Logs mailbox_id and mailbox_email for context
- ✅ Helps diagnose if refresh token is revoked vs misconfigured OAuth client

---

## Verification Tasks

### Item 3: Verify Environment Variables

**Required Environment Variables:**
- `GOOGLE_CLIENT_ID` - Google OAuth Client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth Client Secret
- `MAILBOX_ENCRYPTION_KEY` - Key for encrypting mailbox tokens (if encryption enabled)
- `SUPABASE_SERVICE_ROLE_KEY` - For cron jobs

**Verification Steps:**

1. **Local Development (.env file):**
   ```bash
   # Check .env file exists and has required vars
   grep -E "GOOGLE_CLIENT_ID|GOOGLE_CLIENT_SECRET|MAILBOX_ENCRYPTION_KEY|SUPABASE_SERVICE_ROLE_KEY" .env
   ```

2. **Vercel/Production:**
   - Go to Vercel Dashboard → Your Project → Settings → Environment Variables
   - Verify all required variables are set for Production, Preview, and Development environments
   - Ensure values match between environments

3. **Cron/Worker Runtime:**
   - If using separate workers (e.g., Vercel Cron, Supabase Edge Functions), ensure env vars are set there too
   - Check Vercel Cron environment variables match main app

4. **Quick Test Script:**
   ```typescript
   // scripts/verify-env-vars.ts
   const required = [
     'GOOGLE_CLIENT_ID',
     'GOOGLE_CLIENT_SECRET',
     'SUPABASE_SERVICE_ROLE_KEY'
   ]
   
   const missing = required.filter(key => !process.env[key])
   if (missing.length) {
     console.error('Missing env vars:', missing)
     process.exit(1)
   }
   console.log('✅ All required env vars are set')
   ```

---

### Item 4: Inspect Supabase Mailboxes Table

**SQL Query to Check Gmail Mailbox:**
```sql
-- Replace 'YOUR_MAILBOX_ID' or 'YOUR_EMAIL' with actual values
SELECT 
  id,
  user_id,
  provider,
  email,
  display_name,
  active,
  -- Check token fields
  CASE 
    WHEN access_token IS NULL OR access_token = '' THEN '❌ MISSING'
    WHEN LENGTH(access_token) < 20 THEN '⚠️ SUSPICIOUS (too short)'
    ELSE '✅ PRESENT'
  END as access_token_status,
  CASE 
    WHEN refresh_token IS NULL OR refresh_token = '' THEN '❌ MISSING'
    WHEN LENGTH(refresh_token) < 20 THEN '⚠️ SUSPICIOUS (too short)'
    ELSE '✅ PRESENT'
  END as refresh_token_status,
  token_expires_at,
  CASE 
    WHEN token_expires_at IS NULL THEN '❌ MISSING'
    WHEN token_expires_at < NOW() THEN '⚠️ EXPIRED'
    WHEN token_expires_at < NOW() + INTERVAL '5 minutes' THEN '⚠️ EXPIRING SOON'
    ELSE '✅ VALID'
  END as token_expires_status,
  created_at,
  updated_at,
  last_error
FROM mailboxes
WHERE provider = 'gmail'
  AND email = 'YOUR_EMAIL@example.com'  -- Replace with actual email
  -- OR use: AND id = 'YOUR_MAILBOX_ID'
ORDER BY updated_at DESC;
```

**What to Check:**
- ✅ `provider` = 'gmail'
- ✅ `access_token` is non-empty and reasonable length (>20 chars)
- ✅ `refresh_token` is non-empty and reasonable length (>20 chars)
- ✅ `token_expires_at` is a future timestamp (at least 5 minutes from now)
- ✅ `user_id` is set correctly
- ✅ `active` = true if mailbox should be active

**If tokens look encrypted:**
- Verify `MAILBOX_ENCRYPTION_KEY` is set correctly
- Check that `getDecryptedMailbox()` in code can decrypt them
- Test decryption manually if needed

---

### Item 5: Verify Multi-Tenant Email Handling

**Current Implementation:**
- ✅ `sendViaMailbox` accepts mailbox object (already scoped by mailbox ID)
- ✅ RLS policies enforce user_id scoping on mailboxes table
- ✅ Unique constraint: `(user_id, email, provider)` prevents duplicates per user

**Verification Steps:**

1. **Check sendViaMailbox.ts:**
   - ✅ Function accepts `mailbox: Mailbox` parameter (already scoped)
   - ✅ No direct user_id queries - uses mailbox object passed in
   - ✅ For transactional providers, fetches credentials by `mailbox.user_id`

2. **Check RLS Policies:**
   ```sql
   -- Verify RLS is enabled
   SELECT tablename, rowsecurity 
   FROM pg_tables 
   WHERE tablename = 'mailboxes';
   
   -- Check policies exist
   SELECT * FROM pg_policies 
   WHERE tablename = 'mailboxes';
   ```

3. **Check Unique Constraint:**
   ```sql
   -- Verify unique constraint exists
   SELECT 
     conname as constraint_name,
     pg_get_constraintdef(oid) as constraint_definition
   FROM pg_constraint
   WHERE conrelid = 'mailboxes'::regclass
     AND contype = 'u';  -- 'u' = unique constraint
   ```

4. **Test Multi-Tenant Isolation:**
   - Create two test users in different organizations
   - Connect same Gmail account to both (should be allowed per current schema)
   - Verify each user can only see their own mailbox via RLS
   - Send email from each mailbox - should work independently

**Note:** Current schema uses `user_id` for multi-tenancy. If you need `org_id`-based multi-tenancy:
- Add `org_id` column to mailboxes table
- Update unique constraint to `(org_id, provider, email)`
- Update RLS policies to check `org_id` instead of just `user_id`

---

### Item 6: Verify Cron Endpoints Use Service Role Key

**Files to Check:**
- `app/api/cron/process-emails/route.ts`
- `app/api/cron/sync-mailboxes/route.ts`

**Verification:**

1. **process-emails/route.ts:**
   ```typescript
   // ✅ Should use SUPABASE_SERVICE_ROLE_KEY
   const supabase = createClient(supabaseUrl, supabaseServiceKey, {
     auth: { autoRefreshToken: false, persistSession: false }
   })
   ```
   - ✅ Line 55-66: Uses `SUPABASE_SERVICE_ROLE_KEY`
   - ✅ Queries all mailboxes regardless of tenant (infrastructure-level)
   - ✅ RLS still applies for user-facing operations

2. **sync-mailboxes/route.ts:**
   ```typescript
   // ✅ Should use SUPABASE_SERVICE_ROLE_KEY
   const supabase = createClient(supabaseUrl, supabaseServiceKey, {
     auth: { autoRefreshToken: false, persistSession: false }
   })
   ```
   - ✅ Line 40-45: Uses `SUPABASE_SERVICE_ROLE_KEY`
   - ✅ Queries all active mailboxes (infrastructure-level)
   - ✅ Handles token refresh for all mailboxes

**Test Cron Endpoints:**
```bash
# Test process-emails
curl -X POST https://your-domain.com/api/cron/process-emails \
  -H "Authorization: Bearer YOUR_CRON_SECRET" \
  -H "Content-Type: application/json"

# Test sync-mailboxes
curl -X POST https://your-domain.com/api/cron/sync-mailboxes \
  -H "Authorization: Bearer YOUR_CRON_SECRET" \
  -H "Content-Type: application/json"
```

---

### Item 7: Test Gmail Reconnection

**Steps to Test:**

1. **Reconnect Gmail Mailbox:**
   - Go to email settings/mailboxes page
   - Disconnect existing Gmail mailbox
   - Reconnect Gmail mailbox (OAuth flow)
   - Verify connection succeeds

2. **Verify Database State:**
   ```sql
   -- Check mailbox after reconnection
   SELECT 
     id,
     email,
     provider,
     active,
     LENGTH(access_token) as access_token_len,
     LENGTH(refresh_token) as refresh_token_len,
     token_expires_at,
     NOW() as current_time,
     token_expires_at > NOW() + INTERVAL '30 minutes' as token_valid
   FROM mailboxes
   WHERE id = 'YOUR_MAILBOX_ID';
   ```

3. **Send Test Email:**
   - Use email compose UI or API
   - Send test email via the reconnected mailbox
   - Check email status in `emails` table
   - Verify no 401 errors in logs

4. **Monitor Logs:**
   - Check application logs for any Gmail API errors
   - Look for "Gmail authentication expired" messages
   - Should see successful sends or clear error messages

5. **Test Campaign Send:**
   - Create a test campaign
   - Send to 1-2 test recipients
   - Verify emails are sent successfully
   - Check `emails` table for `status = 'sent'`

---

## Troubleshooting

### If 401 Errors Persist After Fixes:

1. **Check Gmail API Response:**
   - Look for enhanced error logs (Item 8)
   - Check `error_code` and `error_description` in logs
   - Common codes:
     - `invalid_grant` - Refresh token revoked/invalid
     - `invalid_client` - OAuth client misconfigured
     - `unauthorized_client` - Client not authorized for this token

2. **Verify OAuth Client Configuration:**
   - Ensure `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` match the OAuth app used for connection
   - Check Google Cloud Console → APIs & Services → Credentials
   - Verify OAuth consent screen is configured
   - Check redirect URIs match your app

3. **Check Token Encryption:**
   - If using encryption, verify `MAILBOX_ENCRYPTION_KEY` is correct
   - Test decryption manually:
     ```typescript
     import { decryptMailboxTokens } from '@/lib/email/encryption'
     const decrypted = decryptMailboxTokens({
       access_token: mailbox.access_token,
       refresh_token: mailbox.refresh_token
     })
     console.log('Decrypted tokens:', decrypted)
     ```

4. **Test Token Refresh Manually:**
   ```typescript
   import { refreshGmailToken } from '@/lib/email/providers/gmail'
   const result = await refreshGmailToken(mailbox)
   console.log('Refresh result:', result)
   ```

---

## Summary Checklist

- [x] Item 1: refreshGmailToken function improved
- [x] Item 2: Retry-on-401 logic added
- [ ] Item 3: Environment variables verified (manual step)
- [ ] Item 4: Supabase mailboxes table inspected (manual step)
- [x] Item 5: Multi-tenant handling verified (code review)
- [x] Item 6: Cron endpoints verified (code review)
- [ ] Item 7: Gmail reconnection tested (manual step)
- [x] Item 8: Enhanced error logging added

---

## Next Steps

1. Deploy code changes to staging/production
2. Verify environment variables are set correctly
3. Reconnect Gmail mailbox and test
4. Monitor logs for any remaining 401 errors
5. If issues persist, use enhanced error logs to diagnose root cause

