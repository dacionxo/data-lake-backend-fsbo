# Gmail Token Authentication - Comprehensive Diagnostic Guide

This guide provides a systematic approach to diagnosing and fixing Gmail authentication token issues.

## Current Implementation Status

✅ **Already Implemented:**
- Enhanced `refreshGmailToken` with proper error handling
- Retry-on-401 logic in `gmailSend`
- Token persistence to database after refresh
- Enhanced error logging for 401 failures
- Verification scripts and documentation

## Diagnostic Checklist

### Phase 1: Code Verification

#### ✅ Task 1: Verify refreshGmailToken Implementation
**Location:** `lib/email/providers/gmail.ts`

**Check:**
- [ ] Function handles token decryption via `getDecryptedMailbox`
- [ ] Validates `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` env vars
- [ ] Uses correct Google OAuth endpoint: `https://oauth2.googleapis.com/token`
- [ ] Returns proper format: `{ success, accessToken, expiresIn, error }`
- [ ] Handles missing refresh token with clear error
- [ ] Logs errors with mailbox context

**Current Status:** ✅ Implemented (lines 226-310)

#### ✅ Task 2: Verify Retry-on-401 Logic
**Location:** `lib/email/providers/gmail.ts` - `gmailSend` function

**Check:**
- [ ] Detects 401 response from Gmail API
- [ ] Attempts token refresh if `refresh_token` exists
- [ ] Retries send exactly once with new token
- [ ] Only shows "reconnect mailbox" if refresh fails
- [ ] Saves refreshed token to database

**Current Status:** ✅ Implemented (lines 120-171)

#### ✅ Task 3: Verify Token Persistence
**Location:** `lib/email/providers/gmail.ts` - `gmailSend` function

**Check:**
- [ ] Refreshed tokens are saved after proactive refresh (lines 53-81)
- [ ] Refreshed tokens are saved after 401 retry (lines 135-161)
- [ ] Tokens are encrypted before saving (if encryption enabled)
- [ ] `token_expires_at` is calculated from Google's `expires_in` response
- [ ] Database update includes `updated_at` timestamp

**Current Status:** ✅ Implemented

---

### Phase 2: Environment & Configuration

#### Task 4: Check Supabase Mailboxes Table
**SQL Query:** Use `scripts/verify-gmail-mailbox.sql`

**Verify:**
- [ ] `provider = 'gmail'`
- [ ] `access_token` is non-empty (check length > 20 chars)
- [ ] `refresh_token` is non-empty (check length > 20 chars)
- [ ] `token_expires_at` is a future timestamp
- [ ] `user_id` is correctly set
- [ ] `active = true` if mailbox should be active

**Common Issues:**
- Tokens appear encrypted but decryption fails → Check `EMAIL_ENCRYPTION_KEY`
- `token_expires_at` is NULL → Token was never set or refresh failed
- Tokens are empty strings → Connection process didn't save tokens

#### Task 5: Verify Environment Variables
**Script:** Run `scripts/verify-env-vars.ts`

**Required Variables:**
- [ ] `GOOGLE_CLIENT_ID` - Set in all environments
- [ ] `GOOGLE_CLIENT_SECRET` - Set in all environments
- [ ] `EMAIL_ENCRYPTION_KEY` or `ENCRYPTION_KEY` - If encryption enabled
- [ ] `SUPABASE_SERVICE_ROLE_KEY` - For cron jobs

**Check Locations:**
- [ ] Local `.env` file
- [ ] Vercel production environment
- [ ] Vercel preview environment
- [ ] Any cron/worker runtimes
- [ ] Edge function environments

**Critical:** Ensure same `GOOGLE_CLIENT_ID/SECRET` used in:
- Gmail connection UI (OAuth flow)
- Backend sending/cron jobs

**Mismatch Symptom:** Tokens work in connection but fail with 401 in sending

#### Task 6: Verify OAuth Client Configuration
**Google Cloud Console:** https://console.cloud.google.com/apis/credentials

**Check:**
- [ ] OAuth 2.0 Client ID exists and matches `GOOGLE_CLIENT_ID`
- [ ] Authorized redirect URIs include your app's callback URL
- [ ] OAuth consent screen is configured correctly
- [ ] App is in correct state (Testing/Production)
- [ ] Required scopes are requested:
  - `https://www.googleapis.com/auth/gmail.send`
  - `https://www.googleapis.com/auth/gmail.readonly` (if syncing)

**Common Issues:**
- Redirect URI mismatch → Connection fails or tokens invalid
- App in Testing mode with users not added → Tokens work but expire quickly
- Missing scopes → Tokens work but API calls fail with 403

---

### Phase 3: Token Decryption & Encryption

#### Task 7: Test Token Decryption
**Check if encryption is enabled:**
```typescript
// Check if tokens look encrypted (long hex strings)
// Encrypted format: [64 hex chars salt][32 hex chars IV][32 hex chars tag][variable hex chars]
```

**Verify:**
- [ ] `EMAIL_ENCRYPTION_KEY` or `ENCRYPTION_KEY` is set if tokens are encrypted
- [ ] `getDecryptedMailbox()` successfully decrypts tokens
- [ ] Decrypted tokens are valid (not garbage/corrupted)

**Test Decryption:**
```typescript
import { decryptMailboxTokens } from '@/lib/email/encryption'
const decrypted = decryptMailboxTokens({
  access_token: mailbox.access_token,
  refresh_token: mailbox.refresh_token
})
console.log('Decrypted access_token length:', decrypted.access_token?.length)
console.log('Decrypted refresh_token length:', decrypted.refresh_token?.length)
```

**Common Issues:**
- Wrong encryption key → Decryption returns garbage → Gmail rejects with 401
- Key changed after tokens encrypted → Can't decrypt old tokens
- Tokens not encrypted but code expects encryption → Works but inconsistent

#### Task 8: Check Token Expiration Logic
**Location:** `lib/email/providers/gmail.ts` lines 38-49

**Verify:**
- [ ] `token_expires_at` is parsed correctly (Date object)
- [ ] 5-minute threshold is correct: `fiveMinutesFromNow = now + 5 * 60 * 1000`
- [ ] Timezone issues don't affect comparison
- [ ] Comparison works: `expiresAt < fiveMinutesFromNow`

**Test:**
```typescript
const expiresAt = new Date(mailbox.token_expires_at)
const now = new Date()
const fiveMinutesFromNow = new Date(now.getTime() + 5 * 60 * 1000)
console.log('Expires at:', expiresAt)
console.log('Five minutes from now:', fiveMinutesFromNow)
console.log('Needs refresh:', expiresAt < fiveMinutesFromNow)
```

**Common Issues:**
- Timezone mismatch → Token appears expired when it's not (or vice versa)
- Date parsing fails → `expiresAt` is invalid → Refresh always triggered
- Clock skew → Server time different from Google's time

---

### Phase 4: Error Logging & Diagnostics

#### Task 9: Enhanced Error Logging
**Location:** `lib/email/providers/gmail.ts` lines 181-190

**Verify logs include:**
- [ ] `error_data` - Full Gmail API error response
- [ ] `error_code` - Google error code (e.g., 401, 403)
- [ ] `error_message` - Human-readable error message
- [ ] `error_description` - Detailed error description
- [ ] `has_refresh_token` - Whether refresh token exists
- [ ] `mailbox_id` and `mailbox_email` - For context

**Common Google Error Codes:**
- `invalid_grant` → Refresh token revoked or expired
- `invalid_client` → OAuth client misconfigured
- `unauthorized_client` → Client not authorized for this token
- `access_denied` → User revoked access

#### Task 10: Monitor Logs for Patterns
**Check application logs for:**
- [ ] "Gmail send returned 401" messages
- [ ] "Gmail token refreshed successfully" messages
- [ ] "Saved refreshed Gmail token to database" messages
- [ ] "Gmail authentication failed after retry" messages
- [ ] Frequency of token refreshes
- [ ] Patterns in failures (specific mailboxes, times, etc.)

**Look for:**
- Tokens refreshing too frequently → Expiration time calculation wrong
- 401 errors after successful refresh → Token not being saved
- Consistent failures for specific mailboxes → Token corruption or revocation

---

### Phase 5: Multi-Tenant Verification

#### Task 11: Verify Multi-Tenant Scoping
**Location:** `lib/email/sendViaMailbox.ts`

**Check:**
- [ ] Function accepts `mailbox: Mailbox` (already scoped by ID)
- [ ] No direct user_id queries - uses mailbox object
- [ ] RLS policies enforce user_id scoping on mailboxes table
- [ ] Unique constraint: `(user_id, email, provider)` prevents duplicates

**SQL Check:**
```sql
-- Verify RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'mailboxes';

-- Check policies
SELECT * FROM pg_policies 
WHERE tablename = 'mailboxes';
```

#### Task 12: Verify Cron Endpoints
**Files:**
- `app/api/cron/process-emails/route.ts`
- `app/api/cron/sync-mailboxes/route.ts`

**Check:**
- [ ] Both use `SUPABASE_SERVICE_ROLE_KEY`
- [ ] Service role client created with proper auth settings
- [ ] Queries all mailboxes (infrastructure-level)
- [ ] RLS still applies for user-facing operations

---

### Phase 6: Testing & Validation

#### Task 13: Test Gmail Reconnection
**Steps:**
1. Disconnect existing Gmail mailbox
2. Reconnect Gmail mailbox (OAuth flow)
3. Verify database state:
   ```sql
   SELECT 
     id, email, provider, active,
     LENGTH(access_token) as access_token_len,
     LENGTH(refresh_token) as refresh_token_len,
     token_expires_at,
     NOW() as current_time,
     token_expires_at > NOW() + INTERVAL '30 minutes' as token_valid
   FROM mailboxes
   WHERE id = 'YOUR_MAILBOX_ID';
   ```
4. Check tokens are properly encrypted (if encryption enabled)

#### Task 14: Send Test Email
**Steps:**
1. Send test email via reconnected mailbox
2. Check email status in `emails` table
3. Verify no 401 errors in logs
4. Check for "Saved refreshed Gmail token" messages
5. Verify `token_expires_at` updated in database

#### Task 15: Monitor Token Refresh Patterns
**Check logs for:**
- [ ] Proactive refreshes (before expiration)
- [ ] 401-triggered refreshes
- [ ] Successful token saves
- [ ] Any refresh failures

**Patterns to identify:**
- Tokens refreshing every send → Expiration time wrong
- 401 errors without refresh attempts → Refresh token missing
- Refresh succeeds but 401 persists → Token not being saved

#### Task 16: Check for Race Conditions
**Verify:**
- [ ] Multiple concurrent sends don't cause conflicts
- [ ] Database updates are atomic
- [ ] Token refresh doesn't overwrite newer tokens

**Test:** Send multiple emails simultaneously and check:
- All succeed or fail gracefully
- No duplicate token refreshes
- Database has consistent state

---

### Phase 7: Google-Specific Checks

#### Task 17: Verify Refresh Token Validity
**Google Cloud Console:** https://console.cloud.google.com/apis/credentials

**Check:**
- [ ] OAuth client is active
- [ ] No recent revocations
- [ ] Test manual token refresh:
  ```bash
  curl -X POST https://oauth2.googleapis.com/token \
    -d "client_id=YOUR_CLIENT_ID" \
    -d "client_secret=YOUR_CLIENT_SECRET" \
    -d "refresh_token=YOUR_REFRESH_TOKEN" \
    -d "grant_type=refresh_token"
  ```

**If manual refresh fails:**
- Refresh token is revoked → User needs to reconnect
- Client credentials wrong → Check env vars
- Token from different client → OAuth client mismatch

#### Task 18: Review Google Error Codes
**From enhanced error logs, identify:**
- [ ] `invalid_grant` → Refresh token revoked/invalid
- [ ] `invalid_client` → OAuth client misconfigured
- [ ] `unauthorized_client` → Client not authorized
- [ ] `access_denied` → User revoked access
- [ ] `invalid_request` → Malformed request

**Action based on error:**
- `invalid_grant` → Reconnect mailbox
- `invalid_client` → Fix OAuth client configuration
- `unauthorized_client` → Check client ID matches
- `access_denied` → User needs to re-authorize

---

## Quick Diagnostic Commands

### Check Mailbox State
```sql
-- Run scripts/verify-gmail-mailbox.sql
-- Or manually:
SELECT 
  id, email, provider, active,
  LENGTH(access_token) as access_token_len,
  LENGTH(refresh_token) as refresh_token_len,
  token_expires_at,
  last_error
FROM mailboxes
WHERE provider = 'gmail'
ORDER BY updated_at DESC;
```

### Check Environment Variables
```bash
# Run scripts/verify-env-vars.ts
# Or manually check:
echo $GOOGLE_CLIENT_ID
echo $GOOGLE_CLIENT_SECRET
echo $EMAIL_ENCRYPTION_KEY
```

### Test Token Refresh Manually
```typescript
import { refreshGmailToken } from '@/lib/email/providers/gmail'
const result = await refreshGmailToken(mailbox)
console.log('Refresh result:', result)
```

### Check Recent Email Errors
```sql
SELECT 
  id, to_email, subject, status, error, created_at
FROM emails
WHERE mailbox_id = 'YOUR_MAILBOX_ID'
  AND (error LIKE '%401%' 
    OR error LIKE '%authentication expired%'
    OR error LIKE '%Gmail authentication%')
ORDER BY created_at DESC
LIMIT 20;
```

---

## Troubleshooting Decision Tree

```
401 Error Occurs
│
├─ Token Refresh Attempted?
│  ├─ No → Check refresh_token exists
│  │     ├─ Missing → User needs to reconnect
│  │     └─ Exists → Check refreshGmailToken is called
│  │
│  └─ Yes → Check refresh result
│       ├─ Failed → Check error code
│       │   ├─ invalid_grant → Refresh token revoked
│       │   ├─ invalid_client → OAuth client wrong
│       │   └─ Other → Check logs for details
│       │
│       └─ Succeeded → Check if token saved
│           ├─ Not saved → Check supabase client
│           └─ Saved → Check if used in retry
│
└─ Token Not Expired?
   ├─ Yes → Check decryption
   │   ├─ Fails → Check encryption key
   │   └─ Works → Check token format
   │
   └─ No → Check expiration logic
       ├─ Wrong calculation → Fix Date comparison
       └─ Correct → Check timezone
```

---

## Next Steps After Diagnosis

1. **If tokens are corrupted:** Reconnect mailbox
2. **If encryption key is wrong:** Fix key and reconnect mailboxes
3. **If OAuth client mismatch:** Ensure same client ID/secret everywhere
4. **If refresh token revoked:** User needs to reconnect
5. **If expiration logic wrong:** Fix Date comparison
6. **If token not being saved:** Check supabase client and permissions

---

## Success Criteria

✅ **Token refresh works:**
- Tokens refresh proactively before expiration
- 401 errors trigger automatic refresh and retry
- Refreshed tokens are saved to database

✅ **No false positives:**
- "Authentication expired" only shown when refresh fails
- Most 401 errors resolved automatically

✅ **Clear diagnostics:**
- Enhanced error logs show root cause
- Easy to identify if issue is token, client, or configuration

---

## Related Files

- `lib/email/providers/gmail.ts` - Main Gmail provider implementation
- `lib/email/sendViaMailbox.ts` - Mailbox sending wrapper
- `lib/email/encryption.ts` - Token encryption/decryption
- `scripts/verify-gmail-mailbox.sql` - Database verification
- `scripts/verify-env-vars.ts` - Environment variable checker
- `GMAIL_AUTH_FIXES_SUMMARY.md` - Summary of fixes
- `GMAIL_AUTH_FIXES_VERIFICATION.md` - Verification guide

