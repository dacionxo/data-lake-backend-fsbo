# Fix: Domain Restricted Sharing Error for Gmail Watch

## The Error

```
The 'Domain Restricted Sharing' organization policy (constraints/iam.allowedPolicyMemberDomains) is enforced. 
Only principals in allowed domains can be added as principals in the policy. 
Correct the principal emails and try again.
```

## The Solution: Skip Manual Permissions!

**You don't need to manually grant permissions!** 

The Gmail Watch API automatically grants the necessary permissions to `gmail-api-push@system.gserviceaccount.com` when you call the watch endpoint. This bypasses organization policy restrictions.

## What to Do Instead

### ✅ Correct Approach (No Manual Permissions Needed)

1. **Create Pub/Sub Topic** (Step 1) ✅
2. **Create Pub/Sub Subscription** (Step 2) ✅
3. **Skip Permission Granting** - The error is expected and can be ignored ❌
4. **Set Environment Variable** `GMAIL_PUBSUB_TOPIC_NAME` ✅
5. **Call Gmail Watch API** - Permissions are granted automatically ✅

```bash
POST /api/mailboxes/{mailboxId}/watch
```

When you call this endpoint, Gmail Watch API will:
- Automatically grant `gmail-api-push@system.gserviceaccount.com` permission to your topic
- Bypass organization policy restrictions
- Set up the watch subscription

### ❌ What NOT to Do

Don't try to manually grant permissions if you get the domain restriction error - it won't work and isn't necessary.

## Why This Works

When you call the Gmail Watch API with a valid topic name, Google's system automatically:
1. Verifies you have access to the topic
2. Grants the Gmail service account permission to publish
3. Sets up the watch subscription

This happens behind the scenes and doesn't require manual IAM permission granting.

## Alternative Solutions (If Automatic Granting Fails)

### Option 1: Request Organization Policy Exception

If you have admin access:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **IAM & Admin** → **Organization Policies**
3. Select your organization
4. Find **Domain Restricted Sharing** policy
5. Add an exception for `system.gserviceaccount.com` domain

**Note:** This requires organization admin permissions and may not be possible in all organizations.

### Option 2: Use a Different Project

Create a new Google Cloud project outside your organization that doesn't have domain restrictions:

1. Create a new project (not under your organization)
2. Enable Pub/Sub API
3. Create topic and subscription there
4. Use that topic for Gmail Watch

### Option 3: Use Polling Instead of Push Notifications

If push notifications are blocked, use a polling approach:

1. Create a cron job that runs every 5 minutes
2. Fetch unread emails from Gmail API
3. Log them via `/api/emails/received`

This is simpler but has a 5-minute delay (not real-time).

## Verification

After setting up Gmail Watch (Step 6), verify it worked:

1. Send yourself a test email to your Gmail inbox
2. Wait 1-2 minutes
3. Check Unibox - the email should appear
4. If it doesn't, check:
   - Pub/Sub subscription is active
   - Webhook endpoint is receiving notifications
   - Vercel function logs for errors

## Summary

**The Fix:** Ignore the domain restriction error and proceed directly to setting up Gmail Watch. The API will handle permissions automatically.

**Steps:**
1. ✅ Create topic and subscription
2. ✅ Skip manual permission granting (expect the error)
3. ✅ Set `GMAIL_PUBSUB_TOPIC_NAME` environment variable
4. ✅ Call `POST /api/mailboxes/{id}/watch`
5. ✅ Test with a real email

That's it! Gmail Watch will work even with organization policy restrictions.

