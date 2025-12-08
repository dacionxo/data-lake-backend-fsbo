# Gmail Token Verification Checklist

This checklist helps you systematically verify and test the Gmail token authentication fixes.

## ✅ Completed Code Verification Tasks

- [x] **Task 1:** refreshGmailToken implementation verified
- [x] **Task 2:** Retry-on-401 logic verified  
- [x] **Task 3:** Token persistence verified
- [x] **Task 9:** Enhanced error logging verified
- [x] **Task 10:** Multi-tenant scoping verified
- [x] **Task 11:** Cron endpoints verified

## 📋 Manual Verification Tasks

### Task 4: Check Supabase Mailboxes Table

**Action:** Run SQL query to verify mailbox state

**Steps:**
1. Open Supabase SQL Editor
2. Run `scripts/verify-gmail-mailbox.sql` (Step 1 to see all mailboxes)
3. Find the failing Gmail mailbox
4. Verify:
   - [ ] `provider = 'gmail'`
   - [ ] `access_token` is non-empty (length > 20)
   - [ ] `refresh_token` is non-empty (length > 20)
   - [ ] `token_expires_at` is a future timestamp
   - [ ] `user_id` is correctly set
   - [ ] `active = true` if mailbox should be active

**If issues found:**
- Empty tokens → Reconnect mailbox
- Expired token_expires_at → Token refresh may have failed
- Wrong user_id → Multi-tenant issue

---

### Task 5: Verify Environment Variables

**Action:** Check all required env vars are set

**Steps:**
1. Run: `npx tsx scripts/verify-env-vars.ts`
2. Or manually check:
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
- [ ] Gmail connection UI (OAuth flow)
- [ ] Backend sending/cron jobs

**Mismatch Symptom:** Tokens work in connection but fail with 401 in sending

---

### Task 6: Verify OAuth Client Credentials Match

**Action:** Ensure same OAuth client used everywhere

**Steps:**
1. Check Google Cloud Console: https://console.cloud.google.com/apis/credentials
2. Note the OAuth 2.0 Client ID
3. Verify it matches:
   - [ ] `GOOGLE_CLIENT_ID` in connection UI code
   - [ ] `GOOGLE_CLIENT_ID` in backend env vars
   - [ ] `GOOGLE_CLIENT_ID` in cron/worker env vars
4. Verify `GOOGLE_CLIENT_SECRET` matches in all locations

**Test:**
```bash
# Check connection UI uses same client
grep -r "GOOGLE_CLIENT_ID" app/api/auth/gmail

# Check backend uses same client
echo $GOOGLE_CLIENT_ID
```

---

### Task 7: Test Token Decryption

**Action:** Verify tokens can be decrypted correctly

**Steps:**
1. Get mailbox ID from Supabase
2. Run: `npx tsx scripts/test-token-decryption.ts <mailbox_id>`
3. Verify output shows:
   - [ ] Decryption successful
   - [ ] Decrypted tokens have reasonable length (> 20 chars)
   - [ ] Tokens look valid (no spaces, contains dots for access token)

**If decryption fails:**
- Check `EMAIL_ENCRYPTION_KEY` is correct
- Verify key hasn't changed since tokens were encrypted
- Check if tokens are actually encrypted (may be plain text)

---

### Task 8: Check Token Expiration Logic

**Action:** Verify expiration comparison works correctly

**Steps:**
1. Get mailbox ID from Supabase
2. Run: `npx tsx scripts/test-token-expiration.ts <mailbox_id>`
3. Verify output shows:
   - [ ] Correct time until expiry calculation
   - [ ] Date comparisons work (both methods match)
   - [ ] Timezone doesn't cause issues
   - [ ] 5-minute threshold logic is correct

**If issues found:**
- Timezone mismatch → Check server timezone
- Date comparison fails → Check Date parsing
- Wrong threshold → Verify 5-minute calculation

---

### Task 12: Test Gmail Reconnection

**Action:** Reconnect mailbox and verify tokens are saved correctly

**Steps:**
1. Disconnect existing Gmail mailbox (if any)
2. Reconnect Gmail mailbox via OAuth flow
3. Verify in database:
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
4. Verify:
   - [ ] Tokens are non-empty
   - [ ] `token_expires_at` is future timestamp
   - [ ] Tokens are properly encrypted (if encryption enabled)
5. Test decryption: `npx tsx scripts/test-token-decryption.ts <mailbox_id>`

---

### Task 13: Send Test Email/Campaign

**Action:** Send test email and verify no 401 errors

**Steps:**
1. Send test email via reconnected mailbox
2. Check email status in `emails` table:
   ```sql
   SELECT id, to_email, subject, status, error, sent_at
   FROM emails
   WHERE mailbox_id = 'YOUR_MAILBOX_ID'
   ORDER BY created_at DESC
   LIMIT 5;
   ```
3. Check application logs for:
   - [ ] No 401 errors
   - [ ] "Saved refreshed Gmail token" messages (if refresh occurred)
   - [ ] "Gmail token refreshed successfully" messages
4. Verify `token_expires_at` updated in database (if refresh occurred)

**If 401 errors occur:**
- Check enhanced error logs for specific Google error code
- Run diagnostic scripts to identify root cause
- See Task 18 for error code interpretation

---

### Task 14: Monitor Logs for Token Refresh Patterns

**Action:** Monitor application logs to identify patterns

**Steps:**
1. Check logs for token refresh activity:
   - [ ] "Saved refreshed Gmail token to database" - Proactive refresh
   - [ ] "Gmail send returned 401, attempting token refresh" - 401-triggered refresh
   - [ ] "Gmail token refreshed successfully, retrying send" - Successful retry
   - [ ] "Gmail authentication failed after retry" - Refresh failed

2. Identify patterns:
   - [ ] Tokens refreshing too frequently → Expiration calculation wrong
   - [ ] 401 errors without refresh attempts → Refresh token missing
   - [ ] Refresh succeeds but 401 persists → Token not being saved
   - [ ] Consistent failures for specific mailboxes → Token corruption

3. Document findings for further investigation

---

### Task 15: Check for Race Conditions

**Action:** Verify concurrent sends don't cause conflicts

**Steps:**
1. Send multiple emails simultaneously (5-10 emails)
2. Monitor logs for:
   - [ ] Multiple token refresh attempts for same mailbox
   - [ ] Database update conflicts
   - [ ] Inconsistent token states
3. Check database after sends:
   ```sql
   SELECT 
     id, email,
     token_expires_at,
     updated_at,
     last_error
   FROM mailboxes
   WHERE id = 'YOUR_MAILBOX_ID';
   ```
4. Verify:
   - [ ] Only one token refresh per mailbox (or coordinated refreshes)
   - [ ] Database has consistent state
   - [ ] No duplicate refresh attempts

**If race conditions found:**
- Add locking mechanism for token refresh
- Use database transactions for atomic updates
- Implement refresh coordination

---

### Task 16: Verify Refresh Token Validity

**Action:** Test if refresh tokens work with Google API

**Steps:**
1. Get mailbox ID from Supabase
2. Run: `npx tsx scripts/test-manual-token-refresh.ts <mailbox_id>`
3. Verify output shows:
   - [ ] Token refresh successful
   - [ ] New access token received
   - [ ] Expiration time returned

**If refresh fails:**
- Check error code:
  - `invalid_grant` → Refresh token revoked, user needs to reconnect
  - `invalid_client` → OAuth client misconfigured
  - `unauthorized_client` → Client not authorized for this token
- Check Google Cloud Console for revoked tokens
- Verify OAuth client is active

**Alternative Test (curl):**
```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "refresh_token=YOUR_REFRESH_TOKEN" \
  -d "grant_type=refresh_token"
```

---

### Task 17: Check Google OAuth Consent Screen Configuration

**Action:** Verify OAuth app is configured correctly

**Steps:**
1. Go to Google Cloud Console: https://console.cloud.google.com/apis/credentials/consent
2. Verify:
   - [ ] OAuth consent screen is configured
   - [ ] App is in correct state (Testing/Production)
   - [ ] Test users are added (if in Testing mode)
   - [ ] Required scopes are listed:
     - `https://www.googleapis.com/auth/gmail.send`
     - `https://www.googleapis.com/auth/gmail.readonly` (if syncing)
3. Check Authorized redirect URIs:
   - [ ] Include your app's callback URL
   - [ ] Match exactly (no trailing slashes, correct protocol)
4. Verify OAuth client:
   - [ ] Client ID matches `GOOGLE_CLIENT_ID`
   - [ ] Client is active (not deleted/disabled)

**Common Issues:**
- App in Testing mode with user not added → Tokens work but expire quickly
- Missing scopes → Tokens work but API calls fail with 403
- Redirect URI mismatch → Connection fails or tokens invalid

---

### Task 18: Review Error Logs for Google Error Codes

**Action:** Analyze error logs to identify root cause

**Steps:**
1. Check application logs for 401 errors
2. Look for enhanced error logs with:
   - `error_code` - Google error code
   - `error_message` - Human-readable message
   - `error_description` - Detailed description
   - `error_data` - Full error response

3. Identify error codes:
   - [ ] `invalid_grant` → Refresh token revoked/invalid
     - **Action:** User needs to reconnect mailbox
   - [ ] `invalid_client` → OAuth client misconfigured
     - **Action:** Check `GOOGLE_CLIENT_ID/SECRET` match Google Cloud Console
   - [ ] `unauthorized_client` → Client not authorized for this token
     - **Action:** Token was issued by different OAuth client
   - [ ] `access_denied` → User revoked access
     - **Action:** User needs to re-authorize
   - [ ] `invalid_request` → Malformed request
     - **Action:** Check request format

4. Document findings and take appropriate action

**Example Log Entry:**
```json
{
  "mailbox_id": "abc-123",
  "error_code": 401,
  "error_message": "Invalid Credentials",
  "error_description": "Token has been expired or revoked",
  "has_refresh_token": true
}
```

---

## Quick Reference: Diagnostic Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `verify-env-vars.ts` | Check environment variables | `npx tsx scripts/verify-env-vars.ts` |
| `verify-gmail-mailbox.sql` | Check mailbox state in database | Run in Supabase SQL Editor |
| `test-token-decryption.ts` | Test token decryption | `npx tsx scripts/test-token-decryption.ts <mailbox_id>` |
| `test-token-expiration.ts` | Test expiration logic | `npx tsx scripts/test-token-expiration.ts <mailbox_id>` |
| `test-manual-token-refresh.ts` | Test manual token refresh | `npx tsx scripts/test-manual-token-refresh.ts <mailbox_id>` |

---

## Success Criteria

✅ **All tasks completed when:**
- No 401 errors in logs
- Tokens refresh proactively before expiration
- 401 errors trigger automatic refresh and retry
- Refreshed tokens are saved to database
- Enhanced error logs show clear root causes
- All diagnostic scripts pass

---

## Next Steps After Verification

1. **If all checks pass:** System is working correctly
2. **If issues found:** Use diagnostic scripts to identify root cause
3. **If tokens are revoked:** Users need to reconnect mailboxes
4. **If OAuth client mismatch:** Fix environment variables
5. **If encryption issues:** Fix encryption key and reconnect mailboxes

---

## Related Documentation

- `GMAIL_TOKEN_DIAGNOSTIC_GUIDE.md` - Comprehensive diagnostic guide
- `GMAIL_AUTH_FIXES_SUMMARY.md` - Summary of fixes
- `GMAIL_AUTH_FIXES_VERIFICATION.md` - Verification guide




