# Email System - OAuth Scopes Explained

## 🔐 What is an OAuth Scope?

An **OAuth scope** is a permission that defines what your application can access in a user's account. When a user connects their Gmail or Outlook mailbox, they're granting your app permission to perform specific actions (like sending emails) on their behalf.

Think of scopes like keys:
- Each scope is a "key" that unlocks a specific feature
- Users see what permissions you're requesting
- They can approve or deny access
- Your app can only do what the scopes allow

## 📧 Required Scopes for Email System

### Gmail OAuth Scopes

Your email system requires these **2 scopes** for Gmail:

#### 1. `https://www.googleapis.com/auth/gmail.send`
- **What it does:** Allows sending emails through Gmail API
- **Why needed:** This is the core permission - without it, you can't send emails
- **User sees:** "Send email on your behalf"

#### 2. `https://www.googleapis.com/auth/userinfo.email`
- **What it does:** Allows reading the user's email address
- **Why needed:** To identify which Gmail account is connected
- **User sees:** "See your email address"

**Combined Scopes (as used in code):**
```
https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/userinfo.email
```

### Outlook OAuth Scopes

Your email system requires these **3 scopes** for Outlook:

#### 1. `https://graph.microsoft.com/Mail.Send`
- **What it does:** Allows sending emails through Microsoft Graph API
- **Why needed:** This is the core permission - without it, you can't send emails
- **User sees:** "Send mail"

#### 2. `https://graph.microsoft.com/User.Read`
- **What it does:** Allows reading basic user profile information
- **Why needed:** To identify which Outlook account is connected
- **User sees:** "Sign you in and read your profile"

#### 3. `offline_access`
- **What it does:** Allows refreshing access tokens when they expire
- **Why needed:** Access tokens expire after 1 hour - this scope lets us get a refresh token to get new access tokens automatically
- **User sees:** "Maintain access to data you have given it access to"

**Combined Scopes (as used in code):**
```
https://graph.microsoft.com/Mail.Send https://graph.microsoft.com/User.Read offline_access
```

## ✅ How Scopes Are Configured

### In the Code

Scopes are automatically requested when users connect their mailbox. You don't need to configure them separately - they're already set in:

- **Gmail:** `app/api/mailboxes/oauth/gmail/route.ts` (lines 36-39)
- **Outlook:** `app/api/mailboxes/oauth/outlook/route.ts` (lines 36-40)

### In OAuth Consent Screen

You need to add these scopes to your OAuth consent screen configuration:

#### For Google Cloud Console:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. **APIs & Services** → **OAuth consent screen**
3. Click **"Scopes"** tab (or "Add or Remove Scopes")
4. Add these scopes:
   - ✅ `https://www.googleapis.com/auth/gmail.send`
   - ✅ `https://www.googleapis.com/auth/userinfo.email`
5. Click **Save**

#### For Azure Portal:

1. Go to [Azure Portal](https://portal.azure.com)
2. **Azure Active Directory** → **App registrations**
3. Select your app → **API permissions**
4. Click **Add a permission** → **Microsoft Graph** → **Delegated permissions**
5. Add these permissions:
   - ✅ `Mail.Send`
   - ✅ `User.Read`
   - ✅ `offline_access`
6. Click **Add permissions**

## 🔍 Where to Find Scope Requirements

### In Your Code:

**Gmail Scopes** (`app/api/mailboxes/oauth/gmail/route.ts`):
```typescript
const scopes = [
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/userinfo.email',
].join(' ')
```

**Outlook Scopes** (`app/api/mailboxes/oauth/outlook/route.ts`):
```typescript
const scopes = [
  'https://graph.microsoft.com/Mail.Send',
  'https://graph.microsoft.com/User.Read',
  'offline_access',
].join(' ')
```

## 📝 Quick Reference Table

| Provider | Scope | Purpose | Required? |
|----------|-------|---------|-----------|
| Gmail | `gmail.send` | Send emails | ✅ **Yes** |
| Gmail | `userinfo.email` | Get email address | ✅ **Yes** |
| Outlook | `Mail.Send` | Send emails | ✅ **Yes** |
| Outlook | `User.Read` | Get user profile | ✅ **Yes** |
| Outlook | `offline_access` | Refresh tokens | ✅ **Yes** |

## ⚠️ Important Notes

### Scope Names Must Match Exactly

- Google uses full URLs: `https://www.googleapis.com/auth/gmail.send`
- Microsoft uses resource paths: `https://graph.microsoft.com/Mail.Send`
- **Don't change these** - they must match exactly or OAuth will fail

### What Happens Without Required Scopes

If you remove a required scope:
- ❌ Email sending will fail
- ❌ You'll get permission errors
- ❌ Users will need to reconnect their mailbox

### Adding Additional Scopes

**Can you add more scopes?**

Yes, but:
- ⚠️ Users will see more permissions requested
- ⚠️ May trigger additional verification requirements
- ⚠️ Only add what you actually need

**Example:** If you wanted to read emails (not just send):
- Gmail: Add `https://www.googleapis.com/auth/gmail.readonly`
- Outlook: Add `https://graph.microsoft.com/Mail.Read`

## 🔐 Security Best Practices

1. **Request Minimal Scopes:** Only request what you need
2. **Explain to Users:** Users see what permissions you're requesting - be clear about why
3. **Store Securely:** Access tokens are stored encrypted (should be encrypted in production)
4. **Refresh Tokens:** Use `offline_access` scope to get refresh tokens for long-term access

## 📚 Additional Resources

- [Google OAuth Scopes Documentation](https://developers.google.com/identity/protocols/oauth2/scopes)
- [Microsoft Graph Permissions Reference](https://learn.microsoft.com/en-us/graph/permissions-reference)

---

## ✅ Your Current Configuration

Your email system is already configured with the correct scopes. You just need to:

1. ✅ Add these scopes to your OAuth consent screen (Google/Azure)
2. ✅ Ensure Gmail API is enabled (for Gmail)
3. ✅ Users will see these permissions when connecting mailboxes

**No code changes needed** - the scopes are already correctly configured in your API routes!

