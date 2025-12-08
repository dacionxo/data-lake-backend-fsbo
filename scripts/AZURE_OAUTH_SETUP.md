# Azure OAuth Setup Guide (Step-by-Step)

This guide will walk you through setting up Microsoft/Azure OAuth for your LeadMap application.

## 📋 Prerequisites

- An Azure account (free account works)
- A Supabase project
- Your Supabase project reference (e.g., `bqkucdaefpfkunceftye`)

---

## Step 1: Register Application in Azure Portal

### 1.1 Go to Azure Portal

1. Visit [portal.azure.com](https://portal.azure.com)
2. Sign in with your Microsoft account
3. If you don't have an Azure account, you can create a free one at [azure.microsoft.com/free](https://azure.microsoft.com/free)

### 1.2 Navigate to App Registrations

1. In the Azure Portal, search for **"Azure Active Directory"** in the top search bar
   - Or look for **"Microsoft Entra ID"** (newer name)
2. Click on **Azure Active Directory** (or **Microsoft Entra ID**)
3. In the left sidebar, click **App registrations**

### 1.3 Create New Registration

1. Click **+ New registration** button (top left)
2. Fill in the registration form:

   **Name:**
   - Enter: `LeadMap` (or your app name)

   **Supported account types:**
   - Select: **"Accounts in any organizational directory and personal Microsoft accounts"**
   - This allows both:
     - Work/school accounts (Azure AD)
     - Personal Microsoft accounts (Hotmail, Outlook, etc.)

   **Redirect URI:**
   - Platform: Select **Web**
   - URI: Enter your Supabase callback URL:
     ```
     https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
     ```
     - Replace `YOUR_PROJECT_REF` with your actual Supabase project reference
     - Example: `https://bqkucdaefpfkunceftye.supabase.co/auth/v1/callback`
     - ⚠️ **Important**: Make sure it's exactly this format (no trailing slash, no double https)

3. Click **Register**

### 1.4 Copy Your Application (Client) ID

After registration, you'll see the **Overview** page:

1. **Copy the Application (client) ID**
   - This is a long string of characters (looks like: `12345678-1234-1234-1234-123456789abc`)
   - **Save this** - you'll need it for Supabase configuration
   - This is your **Client ID**

---

## Step 2: Create Client Secret

### 2.1 Navigate to Certificates & Secrets

1. In your app registration, click **Certificates & secrets** in the left sidebar
2. You'll see two tabs: **Certificates** and **Client secrets**

### 2.2 Create New Client Secret

1. Click **+ New client secret**
2. Fill in the form:
   - **Description**: Enter `LeadMap OAuth Secret` (or any description)
   - **Expires**: Choose an expiration date
     - Recommended: **24 months** (or your preferred duration)
     - ⚠️ **Note**: You'll need to create a new secret when this expires
3. Click **Add**

### 2.3 Copy the Secret Value

1. **IMPORTANT**: Copy the **Value** column immediately
   - It will look like: `abc123~XYZ789...`
   - ⚠️ **You can only see this once!** After you leave this page, you won't be able to see it again
   - If you lose it, you'll need to create a new secret
2. **Save this securely** - you'll need it for Supabase configuration
   - This is your **Client Secret**

---

## Step 3: Configure API Permissions (Optional but Recommended)

### 3.1 Navigate to API Permissions

1. Click **API permissions** in the left sidebar
2. You'll see a list of permissions (may be empty)

### 3.2 Add Microsoft Graph Permissions

1. Click **+ Add a permission**
2. Select **Microsoft Graph**
3. Select **Delegated permissions**
4. Search for and select:
   - ✅ **User.Read** - Sign in and read user profile
   - This allows reading basic user information (name, email, etc.)
5. Click **Add permissions**

### 3.3 Grant Admin Consent (If Needed)

- If you see a warning about admin consent:
  - For personal Microsoft accounts: You can ignore this
  - For organizational accounts: Your admin may need to grant consent
  - For testing: You can grant consent yourself if you're the admin

---

## Step 4: Configure in Supabase Dashboard

### 4.1 Go to Supabase Dashboard

1. Visit [app.supabase.com](https://app.supabase.com)
2. Sign in to your account
3. Select your project

### 4.2 Navigate to Authentication Providers

1. In the left sidebar, click **Authentication**
2. Click **Providers** (under Authentication)
3. You'll see a list of authentication providers

### 4.3 Enable Azure Provider

1. Find **Azure** in the provider list
2. Toggle the switch to **ON** (enable it)
3. Fill in the configuration:

   **Client ID (Application ID):**
   - Paste the **Application (client) ID** you copied from Azure Portal
   - Example: `12345678-1234-1234-1234-123456789abc`

   **Client Secret:**
   - Paste the **Value** of the client secret you copied from Azure Portal
   - Example: `abc123~XYZ789...`

   **Tenant ID:**
   - **Leave this empty** for multi-tenant (allows all Microsoft accounts)
   - Or enter your Azure AD Tenant ID if you want to restrict to your organization only
   - For most use cases, **leave it empty**

4. Click **Save**

---

## Step 5: Configure Redirect URLs in Supabase

### 5.1 Navigate to URL Configuration

1. In Supabase Dashboard, go to **Authentication** > **URL Configuration**
2. You'll see settings for Site URL and Redirect URLs

### 5.2 Set Site URL

**For Development:**
```
http://localhost:3000
```

**For Production (Vercel):**
```
https://your-app.vercel.app
```

### 5.3 Add Redirect URLs

Add these redirect URLs:

**For Development:**
```
http://localhost:3000/api/auth/callback
```

**For Production (Vercel):**
```
https://your-app.vercel.app/api/auth/callback
```

Click **Save**

---

## Step 6: Test Azure OAuth

### 6.1 Start Your Development Server

```bash
npm run dev
```

### 6.2 Test the OAuth Flow

1. Go to `http://localhost:3000`
2. Click **"Sign up with Microsoft"** or **"Log in with Microsoft"**
3. You should be redirected to Microsoft's sign-in page
4. Sign in with your Microsoft account
5. Grant permissions if prompted
6. You should be redirected back to your app
7. You should be logged in and redirected to the dashboard

---

## 🔍 Troubleshooting

### Issue: "Redirect URI mismatch" Error

**Problem:** The redirect URI in Azure doesn't match Supabase's callback URL.

**Solution:**
1. Check your redirect URI in Azure Portal:
   - Should be: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
   - Make sure there's no `https://https://` (double https)
   - Make sure there's no trailing slash
2. Verify in Supabase Dashboard that Azure provider is enabled
3. Wait 1-2 minutes for changes to propagate

### Issue: "Invalid client" or "Invalid credentials" Error

**Problem:** Client ID or Client Secret is incorrect.

**Solution:**
1. Double-check you copied the entire Client ID and Secret
2. Make sure there are no extra spaces or line breaks
3. For the Secret: Make sure you copied the **Value** column, not the Secret ID
4. If you lost the secret, create a new one in Azure Portal

### Issue: "AADSTS50011: The reply URL specified in the request does not match"

**Problem:** The redirect URI doesn't match what's configured in Azure.

**Solution:**
1. Go to Azure Portal > App registrations > Your app > Authentication
2. Check all redirect URIs listed
3. Make sure you have exactly: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
4. Remove any incorrect URIs
5. Add the correct one if it's missing

### Issue: User Profile Not Created After OAuth

**Problem:** User signs in with Azure but profile isn't created.

**Solution:**
1. Check browser console for errors
2. Verify `SUPABASE_SERVICE_ROLE_KEY` is set in your `.env.local`
3. Check Supabase logs in Dashboard > Logs
4. The callback route (`/api/auth/callback`) should automatically create the profile

---

## 📋 Quick Checklist

Before testing, make sure you have:

- [ ] Created app registration in Azure Portal
- [ ] Copied Application (client) ID
- [ ] Created client secret and copied the Value
- [ ] Added redirect URI: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
- [ ] Enabled Azure provider in Supabase Dashboard
- [ ] Pasted Client ID in Supabase
- [ ] Pasted Client Secret in Supabase
- [ ] Left Tenant ID empty (or set if needed)
- [ ] Saved configuration in Supabase
- [ ] Set Site URL in Supabase (localhost for dev, Vercel URL for prod)
- [ ] Added redirect URLs in Supabase

---

## 🎯 Quick Reference

### Your Azure App Registration Details

**Where to find:**
- Azure Portal > Azure Active Directory > App registrations > Your app

**What you need:**
- **Application (client) ID**: Found in Overview page
- **Client Secret Value**: Found in Certificates & secrets (copy immediately!)

### Your Supabase Configuration

**Redirect URI for Azure:**
```
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

**Example:**
```
https://bqkucdaefpfkunceftye.supabase.co/auth/v1/callback
```

### Your App Configuration

**Site URL (Development):**
```
http://localhost:3000
```

**Site URL (Production - Vercel):**
```
https://your-app.vercel.app
```

**Redirect URL (Development):**
```
http://localhost:3000/api/auth/callback
```

**Redirect URL (Production - Vercel):**
```
https://your-app.vercel.app/api/auth/callback
```

---

## 🚀 For Vercel Deployment

When deploying to Vercel:

1. **Azure Portal**: No changes needed - the Supabase callback URL stays the same
2. **Supabase Dashboard**: Update Site URL to your Vercel domain
3. **Supabase Dashboard**: Add your Vercel redirect URL

The OAuth flow works like this:
```
User → Microsoft → Supabase → Your Vercel App
```

The redirect URI in Azure (`https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`) never changes - it always goes to Supabase first, then Supabase redirects to your app.

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ Clicking "Sign in with Microsoft" redirects to Microsoft sign-in page
2. ✅ After signing in, you're redirected back to your app
3. ✅ You're automatically logged in
4. ✅ User profile is created in your database
5. ✅ You can access the dashboard

---

## 📚 Additional Resources

- [Azure AD App Registration Docs](https://docs.microsoft.com/azure/active-directory/develop/quickstart-register-app)
- [Supabase Azure Provider Docs](https://supabase.com/docs/guides/auth/social-login/auth-azure)
- [Microsoft Identity Platform](https://docs.microsoft.com/azure/active-directory/develop/)

---

## 💡 Pro Tips

1. **Save your credentials securely** - You'll need them if you need to reconfigure
2. **Set secret expiration** - Set it to 24 months so you don't have to update frequently
3. **Test in development first** - Make sure it works locally before deploying
4. **Monitor Azure Portal** - Check for any warnings or errors in your app registration
5. **Use environment variables** - Never commit secrets to Git

---

That's it! Your Azure OAuth should now be set up and working. 🎉

