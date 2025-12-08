# Email System - OAuth Redirect URIs Configuration Summary

## 🎯 Quick Reference

Use these **exact** redirect URIs for your OAuth configuration.

## 📧 Gmail OAuth Redirect URIs

Add these to your Google Cloud Console OAuth client:

```
http://localhost:3000/api/mailboxes/oauth/gmail/callback
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback
```

**Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. **APIs & Services** → **Credentials**
3. Edit your OAuth client
4. Add both URIs above to **Authorized redirect URIs**
5. Click **Save**

## 📬 Outlook OAuth Redirect URIs (Optional)

Add these to your Azure App Registration:

```
http://localhost:3000/api/mailboxes/oauth/outlook/callback
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback
```

**Steps:**
1. Go to [Azure Portal](https://portal.azure.com)
2. **Azure Active Directory** → **App registrations**
3. Select your app → **Authentication**
4. Add both URIs above to **Redirect URIs**
5. Click **Save**

## ⚙️ Environment Variable

Set this in Vercel environment variables:

- **Key:** `NEXT_PUBLIC_APP_URL`
- **Value:** `https://www.growyourdigitalleverage.com` (no trailing slash!)

## ✅ Verification

After configuration:

- ✅ Local: Connect mailbox at `http://localhost:3000/dashboard/email/mailboxes`
- ✅ Production: Connect mailbox at `https://www.growyourdigitalleverage.com/dashboard/email/mailboxes`

Both should redirect correctly through OAuth flow.

---

**See [EMAIL_REDIRECT_URIS.md](./EMAIL_REDIRECT_URIS.md) for detailed setup instructions.**

