# Email System - OAuth Redirect URIs Reference

Quick reference for all OAuth redirect URIs you need to configure.

## 🔗 Your Domains

- **Production:** `https://www.growyourdigitalleverage.com`
- **Local Development:** `http://localhost:3000`

## 📧 Gmail OAuth Redirect URIs

### Production:
```
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback
```

### Local Development:
```
http://localhost:3000/api/mailboxes/oauth/gmail/callback
```

**Where to add:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. **APIs & Services** → **Credentials**
3. Edit your OAuth client
4. Under **Authorized redirect URIs**, add both URIs above
5. Click **Save**

## 📬 Outlook OAuth Redirect URIs

### Production:
```
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback
```

### Local Development:
```
http://localhost:3000/api/mailboxes/oauth/outlook/callback
```

**Where to add:**
1. Go to [Azure Portal](https://portal.azure.com)
2. **Azure Active Directory** → **App registrations**
3. Select your app → **Authentication**
4. Under **Redirect URIs**, add both URIs above
5. Click **Save**

## ✅ Complete Checklist

Copy and paste these exact URIs into your OAuth providers:

### Google Cloud Console
- [ ] `http://localhost:3000/api/mailboxes/oauth/gmail/callback`
- [ ] `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback`

### Azure Portal (if using Outlook)
- [ ] `http://localhost:3000/api/mailboxes/oauth/outlook/callback`
- [ ] `https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback`

## ⚠️ Important Notes

1. **No trailing slashes** - Don't add `/` at the end
2. **Exact match required** - URIs must match exactly (case-sensitive)
3. **HTTP vs HTTPS** - Local uses `http://`, production uses `https://`
4. **Add both** - Add both local and production URIs to test locally and in production

## 🔍 Verify Configuration

After adding redirect URIs:

1. **Test locally:**
   - Start dev server: `npm run dev`
   - Go to `http://localhost:3000/dashboard/email/mailboxes`
   - Click "Connect Gmail" or "Connect Outlook"
   - Should redirect to OAuth provider and back

2. **Test production:**
   - Go to `https://www.growyourdigitalleverage.com/dashboard/email/mailboxes`
   - Click "Connect Gmail" or "Connect Outlook"
   - Should redirect to OAuth provider and back

## 🐛 Troubleshooting

### "redirect_uri_mismatch" Error

**Problem:** The redirect URI doesn't match what's configured.

**Solution:**
1. Check the exact URI shown in the error message
2. Verify it matches exactly in Google Cloud Console / Azure Portal
3. Ensure no extra spaces or characters
4. Check for trailing slashes (remove them)

### OAuth Works Locally But Not in Production

**Problem:** Local redirect URI works, but production doesn't.

**Solution:**
1. Verify production redirect URI is added in OAuth provider
2. Check `NEXT_PUBLIC_APP_URL` is set to `https://www.growyourdigitalleverage.com`
3. Ensure no trailing slash in `NEXT_PUBLIC_APP_URL`
4. Redeploy your Vercel application after adding environment variables

---

**Quick Copy-Paste List:**

```
http://localhost:3000/api/mailboxes/oauth/gmail/callback
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/gmail/callback
http://localhost:3000/api/mailboxes/oauth/outlook/callback
https://www.growyourdigitalleverage.com/api/mailboxes/oauth/outlook/callback
```

