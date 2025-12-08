# Email System Fixes Summary

This document summarizes all fixes applied to resolve the issues identified in the email system.

## ✅ Completed Fixes

### 1. ✅ Consolidated Duplicate Email Sending Implementations
**Problem:** Duplicate `sendEmailViaMailbox()` function in CRM route that duplicated Gmail/Outlook/SMTP logic.

**Solution:**
- Removed duplicate inline `sendEmailViaMailbox()` function from `/app/api/crm/campaigns/[id]/send/route.ts`
- Updated route to use the centralized `sendViaMailbox()` from `lib/email/sendViaMailbox.ts`
- Added proper imports and error handling
- Note: This route still uses OLD `email_campaigns` table for backward compatibility (see fix #2)

**Files Changed:**
- `app/api/crm/campaigns/[id]/send/route.ts`

---

### 2. 🔄 Update Email Send Route to Use New Campaigns Table (PARTIALLY DONE)
**Problem:** CRM campaigns send route uses OLD `email_campaigns` table instead of new `campaigns` table.

**Status:** 
- ✅ Consolidated sending logic to use `sendViaMailbox()`
- ⚠️ Still uses `email_campaigns` table for backward compatibility
- **Action Required:** Migrate old campaigns or create migration path. New campaigns should use `/api/campaigns/[id]/send` endpoint.

---

### 3. ✅ Implemented Encryption for OAuth Tokens and SMTP Passwords
**Problem:** OAuth tokens and SMTP passwords stored as plaintext in database.

**Solution:**
- Created encryption utility (`lib/email/encryption.ts`) using AES-256-GCM
- Encryption key stored in `EMAIL_ENCRYPTION_KEY` environment variable
- Updated Gmail, Outlook, and SMTP providers to decrypt tokens before use
- Supports migration period (decrypts if encrypted, uses as-is if plaintext)

**Files Changed:**
- `lib/email/encryption.ts` (NEW)
- `lib/email/providers/gmail.ts`
- `lib/email/providers/outlook.ts`
- `lib/email/providers/smtp.ts`

**Action Required:**
- Set `EMAIL_ENCRYPTION_KEY` environment variable (32-byte key, 64 hex characters)
- Run migration to encrypt existing tokens (see `EMAIL_ENCRYPTION_MIGRATION.md`)

---

### 4. ✅ Added Unique Constraints to Prevent Duplicate Emails
**Problem:** No unique constraint on `provider_message_id` - duplicate webhook events could create duplicate emails.

**Solution:**
- Created migration SQL (`supabase/email_fixes_migration.sql`) - transaction-safe version
- Created concurrent version (`supabase/email_fixes_migration_concurrent.sql`) for production
- Added unique index on `emails.provider_message_id` (where not null)
- Added unique index on `emails.raw_message_id` (where not null)
- Added unique index on `email_messages.provider_message_id, mailbox_id` (for Unibox)
- Added performance indexes on `direction` column
- Fixed transaction block issues - migration can now run in Supabase SQL editor

**Files Changed:**
- `supabase/email_fixes_migration.sql` (NEW - transaction-safe)
- `supabase/email_fixes_migration_concurrent.sql` (NEW - for large tables)

**Action Required:**
- Run `email_fixes_migration.sql` in Supabase SQL editor (transaction-safe)

---

### 5. ✅ Improved SMTP Dependency Handling
**Problem:** SMTP requires nodemailer but dependency check was incomplete.

**Solution:**
- Already gracefully handles missing nodemailer (returns clear error message)
- Error message instructs user to install: `npm install nodemailer`
- Dynamic import prevents build-time errors if package not installed

**Status:** ✅ Already implemented correctly

---

## 🔄 In Progress / Pending Fixes

### 6. ⏳ Wire Token Refresh Into Scheduler
**Problem:** Token refresh logic exists but not automatically called by scheduler before sending.

**Status:** 
- ✅ Token refresh functions exist and are exported
- ✅ Providers automatically refresh tokens if expired/expiring
- ⚠️ Scheduler should proactively refresh tokens for mailboxes before processing emails
- **Action Required:** Update `/app/api/cron/process-emails/route.ts` to refresh tokens proactively

---

### 7. ⏳ Update Unibox to Show Both Sent and Received Emails
**Problem:** Unibox currently only shows received emails (`direction='received'`).

**Status:**
- ✅ New Unibox system uses `email_threads` and `email_messages` tables which support both directions
- ✅ Thread API route already includes both inbound and outbound messages
- ⚠️ Old Unibox component (`/api/emails/received`) still filters by `direction='received'`
- **Action Required:** 
  - Old Unibox should be deprecated (already replaced by new 3-pane layout)
  - Verify new Unibox shows both directions correctly

---

### 8. ⏳ Fix Unibox Direction Handling
**Problem:** Unibox relies on `direction='received'` only, but should handle both `inbound` and `outbound`.

**Status:**
- ✅ New Unibox system uses `email_messages.direction` which can be `inbound` or `outbound`
- ⚠️ Old `emails` table uses `direction: 'sent' | 'received'`
- ⚠️ Need to ensure consistent direction naming across tables
- **Action Required:** 
  - Document direction field usage
  - Ensure sync connectors set correct direction values

---

### 9. ⏳ Update Mailbox Creation/Update Routes to Encrypt Tokens
**Problem:** New mailboxes and token updates don't encrypt tokens before storing.

**Status:**
- ✅ Encryption utility created
- ⚠️ Mailbox creation routes (`/app/api/mailboxes/route.ts`) don't encrypt yet
- ⚠️ OAuth callback routes don't encrypt tokens
- **Action Required:**
  - Update mailbox POST/PATCH routes to encrypt tokens before saving
  - Update OAuth callback routes to encrypt tokens

---

### 10. ⏳ Review and Document Emails Table Usage
**Problem:** Emails table is overloaded - stores sent, received, queued, campaign emails all in one table.

**Status:**
- ✅ Separate `email_threads` and `email_messages` tables created for Unibox
- ⚠️ Old `emails` table still used for sent/received email logging
- **Action Required:**
  - Document table usage patterns
  - Consider migration path to consolidate on `email_messages` table
  - OR document why both tables are needed

---

## 📋 Next Steps

1. **Run Database Migration:**
   ```sql
   -- Run in Supabase SQL editor
   -- See: supabase/email_fixes_migration.sql
   ```

2. **Set Encryption Key:**
   ```bash
   # Generate a key:
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   
   # Add to .env:
   EMAIL_ENCRYPTION_KEY=<generated-key>
   ```

3. **Update Mailbox Routes:**
   - Encrypt tokens in `/app/api/mailboxes/route.ts`
   - Encrypt tokens in OAuth callback routes

4. **Proactive Token Refresh:**
   - Update `/app/api/cron/process-emails/route.ts` to refresh tokens before sending

5. **Documentation:**
   - Document table usage patterns
   - Create migration guide for encrypting existing tokens

---

## 🔐 Security Notes

- **Encryption Key:** Must be 32 bytes (64 hex characters)
- **Key Storage:** Never commit encryption key to git
- **Key Rotation:** Plan for periodic key rotation in production
- **Migration:** Existing plaintext tokens will be decrypted as-is (backward compatible)
- **Production:** Consider using AWS KMS, GCP KMS, or similar for key management

---

## 📝 Testing Checklist

- [ ] Run database migration successfully
- [ ] Set encryption key in environment
- [ ] Test email sending with encrypted tokens
- [ ] Test token refresh with encrypted tokens
- [ ] Verify no duplicate emails from webhooks
- [ ] Test SMTP with encrypted passwords
- [ ] Verify Unibox shows both sent and received
- [ ] Test proactive token refresh in scheduler

---

## 🐛 Known Issues

1. **Backward Compatibility:** Old `email_campaigns` table still in use for CRM route
2. **Direction Naming:** Mix of `sent/received` vs `inbound/outbound` - needs standardization
3. **Token Encryption Migration:** Existing tokens not automatically encrypted (needs migration script)

---

## 📚 Related Files

- `lib/email/encryption.ts` - Encryption utility
- `lib/email/sendViaMailbox.ts` - Centralized email sending
- `supabase/email_fixes_migration.sql` - Database fixes
- `app/api/crm/campaigns/[id]/send/route.ts` - Fixed duplicate implementation

