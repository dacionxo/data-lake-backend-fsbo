# Bring Your Own Twilio (BYO) Implementation Guide

This document provides a comprehensive checklist for implementing multi-tenant SMS functionality where each user can connect their own Twilio account.

## Overview

The BYO Twilio feature allows each LeadMap user to:
- Connect their own Twilio account
- Use their own SMS numbers
- Have isolated conversations and campaigns
- Maintain their own Twilio billing

## Implementation Phases

### Phase 0: Verify Baseline SMS Works ✅

Before implementing BYO, ensure the single-account SMS system is fully functional.

**Tasks:**
1. ✅ Run `supabase/sms_schema.sql` in Supabase SQL editor
2. ✅ Add Twilio environment variables to `.env.local`
3. ✅ Create Twilio Conversations Service in Twilio Console
4. ✅ Provision SMS number and create Messaging Service
5. ✅ Link Messaging Service to Conversations Service
6. ✅ Configure webhook URL in Twilio Conversations Service
7. ✅ Set up cron job for `/api/sms/drip/run`
8. ✅ Test sending/receiving SMS from conversations page

**Verification:**
- Conversations page shows conversations
- Can send SMS messages
- Inbound messages appear via webhook
- Delivery status updates work

---

### Phase 1: Add Per-User Twilio Settings Table

Create database schema to store Twilio credentials per user.

**Database Schema:**
```sql
CREATE TABLE user_twilio_settings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Twilio credentials & config
  account_sid TEXT NOT NULL,
  auth_token TEXT NOT NULL, -- In production, encrypt or use vault
  conversations_service_sid TEXT NOT NULL,
  messaging_service_sid TEXT NOT NULL,
  sms_number TEXT NOT NULL,
  
  status TEXT NOT NULL DEFAULT 'active', -- active | disabled
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE (user_id)
);

ALTER TABLE user_twilio_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own Twilio settings"
ON user_twilio_settings
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

**Tasks:**
1. Add `user_twilio_settings` table to `supabase/sms_schema.sql`
2. Add RLS policies for the table
3. Run the schema in Supabase SQL editor

---

### Phase 2: Refactor lib/twilio.ts to be Per-User

Update the Twilio helper library to support per-user configuration.

**Key Changes:**
- Add `UserTwilioConfig` interface
- Implement `getTwilioConfigForUser(userId)` function
- Implement `getTwilioClient(config)` factory with caching
- Refactor `getOrCreateConversationForLead()` to use per-user config
- Refactor `sendConversationMessage()` to use per-user config

**Tasks:**
1. Add `UserTwilioConfig` interface type
2. Add fallback Twilio env vars (for master account)
3. Implement `getTwilioConfigForUser(userId)` function
4. Implement `getTwilioClient(config)` factory with caching
5. Refactor `getOrCreateConversationForLead()` to use per-user config
6. Refactor `sendConversationMessage()` to use per-user config
7. Update any other functions using global `twilioClient`

**Code Structure:**
```typescript
export interface UserTwilioConfig {
  accountSid: string
  authToken: string
  conversationsServiceSid: string
  messagingServiceSid: string
  smsNumber: string
}

export async function getTwilioConfigForUser(
  userId: string
): Promise<UserTwilioConfig> {
  // Load from user_twilio_settings table
  // Fallback to env vars if not found
}

export function getTwilioClient(config: UserTwilioConfig) {
  // Return cached or new Twilio client
}
```

---

### Phase 3: Make Webhook Multi-Tenant

Update the webhook handler to support multiple Twilio accounts.

**Key Changes:**
- Extract `AccountSid` from webhook params
- Lookup user by `AccountSid` in `user_twilio_settings`
- Validate signature using user-specific `auth_token`
- Pass `user_id` to event handlers

**Tasks:**
1. Update webhook POST handler to extract `AccountSid`
2. Add lookup logic to find `user_twilio_settings` by `account_sid`
3. Update signature validation to use user-specific `auth_token`
4. Update `handleMessageAdded()` to accept optional `userId`
5. Update `handleConversationAdded()` to accept optional `userId`
6. Update `createSkeletonConversation()` to accept optional `userId`
7. Pass `userId` from webhook handler to all event handlers

**Webhook Flow:**
```
1. Receive webhook → Extract AccountSid
2. Lookup user_twilio_settings by account_sid
3. Validate signature with user's auth_token
4. Route to handler with user_id
5. Handler processes event with user context
```

---

### Phase 4: Add "Connect Your Twilio" UI + Status

Build UI for users to connect their Twilio accounts and show connection status.

**API Endpoints:**
- `GET /api/twilio/settings` - Retrieve user's Twilio settings
- `POST /api/twilio/settings` - Save/update Twilio settings with verification
- `GET /api/twilio/status` - Check if Twilio is connected and working

**UI Components:**
- Settings page: `app/dashboard/settings/sms/page.tsx`
- Status indicator in conversations page header

**Tasks:**
1. Create `GET /api/twilio/settings` endpoint
2. Create `POST /api/twilio/settings` endpoint with credential verification
3. Create `GET /api/twilio/status` endpoint
4. Create settings page UI (`app/dashboard/settings/sms/page.tsx`)
5. Add form fields (Account SID, Auth Token, etc.)
6. Add form validation and "Test & Save" button
7. Wire form submission to POST endpoint
8. Update conversations page to fetch real Twilio status
9. Replace static "Twilio Connected" with dynamic status indicator
10. Disable message composer if Twilio not connected
11. Add link to settings when Twilio not connected

**Settings Page Form Fields:**
- Account SID
- Auth Token
- Conversations Service SID
- Messaging Service SID
- SMS Number

**Status Indicator:**
- Green dot + "Twilio Connected" (when connected)
- Red dot + "Twilio Not Connected" (when not connected)
- Gray dot + "Checking Twilio..." (when loading)

---

### Phase 5: Power Dialer Features (Optional)

Enhance the SMS system with power dialer capabilities.

**Features:**
- Manual Actions queue UI
- Click-to-call via Twilio Voice
- Auto-advance in task queue

**Tasks:**
1. Create `manual_actions` table schema
2. Build Manual Actions tab UI in conversations page
3. Create `voice_calls` table schema
4. Create `/api/twilio/voice/dial` endpoint
5. Add "Call" button in conversation panel
6. Implement auto-advance feature in queue

---

## Testing Checklist

### Functional Tests
- [ ] Users can connect their own Twilio accounts via settings page
- [ ] SMS messages are sent using user-specific Twilio credentials
- [ ] Webhooks work correctly with multiple user Twilio accounts
- [ ] Conversations are isolated per user (user A cannot see user B's conversations)
- [ ] Fallback to master account works when user has no Twilio settings
- [ ] Status indicator shows correct connection state
- [ ] Message composer is disabled when Twilio not connected
- [ ] Settings page validates and saves Twilio credentials correctly

### Security Tests
- [ ] RLS policies prevent users from accessing other users' Twilio settings
- [ ] Webhook signature validation works with user-specific auth tokens
- [ ] Auth tokens are stored securely (consider encryption in production)

### Integration Tests
- [ ] Drip campaigns work with per-user Twilio accounts
- [ ] Campaign enrollments are isolated per user
- [ ] Analytics and events are correctly attributed to users

---

## Migration Path

### For Existing Users
1. Existing conversations continue to work with master account
2. Users can optionally connect their own Twilio account
3. New conversations use user's Twilio if configured, otherwise fallback to master

### For New Users
1. Users must connect their Twilio account to use SMS features
2. Or use master account if provided by platform

---

## Environment Variables

### Master Account (Fallback)
```bash
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_CONVERSATIONS_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_SMS_NUMBER=+1xxxxxxxxxx
```

### Per-User Settings
Stored in `user_twilio_settings` table (encrypted in production).

---

## Security Considerations

1. **Auth Token Storage**: In production, encrypt `auth_token` in database or use a secrets vault
2. **RLS Policies**: Ensure users can only access their own settings
3. **Webhook Validation**: Always validate Twilio signatures with user-specific tokens
4. **Credential Verification**: Test credentials before saving to database

---

## Next Steps After BYO Implementation

1. Add encryption for auth tokens in database
2. Implement Twilio Voice for click-to-call
3. Build Manual Actions queue UI
4. Add analytics dashboard for per-user SMS metrics
5. Implement rate limiting per user
6. Add webhook retry logic for failed deliveries

---

## Support & Troubleshooting

### Common Issues

**Issue**: Webhook validation fails
- **Solution**: Ensure `AccountSid` is correctly extracted and user settings are found

**Issue**: Messages sent from wrong account
- **Solution**: Verify `getTwilioConfigForUser()` is being called with correct `userId`

**Issue**: Settings page shows "Failed to verify"
- **Solution**: Check that credentials are correct and Conversations Service exists

---

## Success Criteria

✅ Users can connect their own Twilio accounts
✅ SMS messages use user-specific credentials
✅ Webhooks work with multiple accounts
✅ Conversations are isolated per user
✅ Status indicator shows real connection state
✅ Settings page validates and saves credentials
✅ Fallback to master account works when needed

---

## References

- [Twilio Conversations API Docs](https://www.twilio.com/docs/conversations/api)
- [Twilio Webhook Security](https://www.twilio.com/docs/usage/webhooks/webhooks-security)
- [Supabase RLS Policies](https://supabase.com/docs/guides/auth/row-level-security)






