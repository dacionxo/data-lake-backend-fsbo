# How to Grant Pub/Sub Permissions for Gmail Webhooks

## Important: Automatic Permission Granting

**Good News:** If you're getting a "Domain Restricted Sharing" error, you don't need to manually grant permissions! 

When you call the Gmail Watch API (via `POST /api/mailboxes/{id}/watch`), Google **automatically grants** the necessary permissions to `gmail-api-push@system.gserviceaccount.com`. This bypasses organization policy restrictions.

**Skip to Step 3 below if you're getting domain restriction errors.**

---

## Why Permissions Are Needed

When you set up Gmail Watch, Google's Gmail service needs permission to publish notifications to your Pub/Sub topic. Without this permission, Gmail cannot send push notifications when new emails arrive.

**However**, Gmail Watch API automatically grants these permissions when you set up the watch - you typically don't need to do it manually.

## Quick Steps

1. **Grant permission on your Pub/Sub topic** to Google's service account: `gmail-api-push@system.gserviceaccount.com`
2. **Role needed**: `Pub/Sub Publisher` (or `roles/pubsub.publisher`)

---

## Detailed Instructions

### Method 1: Grant via Topic Permissions (Recommended)

This is the easiest and most straightforward method:

1. **Open Google Cloud Console**
   - Go to [https://console.cloud.google.com/](https://console.cloud.google.com/)

2. **Navigate to Pub/Sub Topics**
   - In the left sidebar, expand **Pub/Sub** (under "Integration")
   - Click on **Topics**
   - Or use this direct link: [https://console.cloud.google.com/cloudpubsub/topic/list](https://console.cloud.google.com/topics/list)

3. **Select Your Topic**
   - Click on the topic you created (e.g., `gmail-notifications`)

4. **Open Permissions Tab**
   - At the top of the page, click the **PERMISSIONS** tab
   - This shows all principals (users/service accounts) with access to this topic

5. **Grant Access**
   - Click the **GRANT ACCESS** button (or **+ GRANT ACCESS** button)
   - A dialog will appear

6. **Add the Service Account**
   - In the **New principals** field, enter:
     ```
     gmail-api-push@system.gserviceaccount.com
     ```
   - **Important:** Type this exactly as shown (case-sensitive)

7. **Select the Role**
   - Click the **Select a role** dropdown
   - Search for or select: **Pub/Sub Publisher**
   - The role identifier is: `roles/pubsub.publisher`

8. **Save**
   - Click **SAVE**
   - You should see a success message

9. **Verify**
   - The permissions list should now show:
     - **Principal**: `gmail-api-push@system.gserviceaccount.com`
     - **Role**: `Pub/Sub Publisher`

---

### Method 2: Grant via IAM (Project-Level)

If you prefer to grant permissions at the project level:

1. **Open IAM & Admin**
   - Go to [https://console.cloud.google.com/iam-admin/iam](https://console.cloud.google.com/iam-admin/iam)
   - Or: Left sidebar → **IAM & Admin** → **IAM**

2. **Grant Access**
   - Click the **+ GRANT ACCESS** button at the top

3. **Add Principal**
   - In the **New principals** field, enter:
     ```
     gmail-api-push@system.gserviceaccount.com
     ```

4. **Select Role**
   - Click **Select a role** dropdown
   - Search for: **Pub/Sub Publisher**
   - Select: `roles/pubsub.publisher`

5. **Save**
   - Click **SAVE**

**Note:** This grants permission project-wide. For better security, prefer Method 1 (topic-level permissions).

---

## Verification

To verify the permission was granted correctly:

1. Go to your Pub/Sub topic's **PERMISSIONS** tab
2. Look for `gmail-api-push@system.gserviceaccount.com`
3. Verify it has the **Pub/Sub Publisher** role

---

## Common Issues

### Issue: "Service account not found"

**Solution:** This is normal! `gmail-api-push@system.gserviceaccount.com` is Google's system account. You cannot view it in IAM, but you can still grant it permissions. Just type the email exactly as shown and grant the role - it will work.

### Issue: "Permission denied" when setting up Gmail Watch

**Solution:** Make sure you've granted the permission to the correct topic:
- Check the topic name matches what you're using
- Verify the service account email is spelled correctly
- Try removing and re-adding the permission
- Wait a few minutes for permissions to propagate

### Issue: "Role not found"

**Solution:** Make sure you're selecting the correct role:
- Full role name: `Pub/Sub Publisher`
- Role identifier: `roles/pubsub.publisher`
- If you can't find it, you may need to enable the Pub/Sub API first

---

## Alternative: Grant via gcloud CLI

If you prefer using the command line:

```bash
# Grant Pub/Sub Publisher role to Gmail service account
gcloud pubsub topics add-iam-policy-binding gmail-notifications \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher" \
  --project=YOUR_PROJECT_ID
```

Replace:
- `gmail-notifications` with your topic name
- `YOUR_PROJECT_ID` with your Google Cloud project ID

---

## Why This Service Account?

`gmail-api-push@system.gserviceaccount.com` is Google's managed service account that:
- Publishes Gmail push notifications to your Pub/Sub topic
- Is automatically created/managed by Google
- Cannot be viewed in your IAM console (it's a system account)
- Must be explicitly granted permission to publish to your topic

---

## Domain Restricted Sharing Error - Solution

If you're getting this error:
```
The 'Domain Restricted Sharing' organization policy is enforced. 
Only principals in allowed domains can be added as principals in the policy.
```

**Solution: Skip manual permission granting!**

Gmail Watch API automatically handles permissions. Just:

1. ✅ Create your Pub/Sub topic and subscription
2. ✅ Set the environment variable: `GMAIL_PUBSUB_TOPIC_NAME`
3. ✅ Call `POST /api/mailboxes/{id}/watch` - permissions are granted automatically
4. ✅ Test by sending yourself an email

The Gmail Watch API will automatically grant the necessary permissions when you set up the watch, bypassing organization policy restrictions.

---

## Next Steps

1. ✅ **If no domain restrictions**: Manually grant permissions (optional but recommended)
2. ✅ **If domain restrictions exist**: Skip manual permissions - Gmail Watch handles it automatically
3. ✅ Continue with Step 4: Set Environment Variable
4. ✅ Set up Gmail Watch via `POST /api/mailboxes/{id}/watch`
5. ✅ Test by sending yourself an email

---

## Additional Resources

- [Google Cloud Pub/Sub IAM Documentation](https://cloud.google.com/pubsub/docs/access-control)
- [Gmail API Push Notifications Guide](https://developers.google.com/gmail/api/guides/push)
- [Pub/Sub Topics Permissions](https://console.cloud.google.com/cloudpubsub/topic/list)

