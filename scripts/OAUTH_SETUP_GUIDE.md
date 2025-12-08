# OAuth Setup Guide for Google and Microsoft

This guide will walk you through setting up OAuth authentication with Google and Microsoft (Azure AD) for your LeadMap application.

## Prerequisites

- A Supabase project (get one at [supabase.com](https://supabase.com))
- A Google Cloud account (for Google OAuth)
- An Azure account (for Microsoft OAuth)

## Overview

Your application already has OAuth buttons implemented. You just need to:
1. Create OAuth apps in Google Cloud Console and Azure Portal
2. Configure the credentials in Supabase Dashboard
3. Set up redirect URLs

---

## Part 1: Google OAuth Setup

### Step 1: Create OAuth Credentials in Google Cloud Console

1. **Go to Google Cloud Console**
   - Visit [Google Cloud Console](https://console.cloud.google.com)
   - Sign in with your Google account

2. **Create or Select a Project**
   - Click the project dropdown at the top
   - Click **New Project** or select an existing one
   - Give it a name (e.g., "LeadMap OAuth")
   - Click **Create**

3. **Enable Google+ API** (Optional - newer projects may not need this)
   - Go to **APIs & Services** > **Library**
   - Search for "Google+ API" (or "Google Identity Services API")
   - Click on it and click **Enable** if not already enabled

4. **Configure OAuth Consent Screen**
   - Go to **APIs & Services** > **OAuth consent screen**
   - Choose **External** (unless you have a Google Workspace account)
   - Click **Create**
   - Fill in the required information:
     - **App name**: LeadMap (or your app name)
     - **User support email**: Your email
     - **Developer contact information**: Your email
   - Click **Save and Continue**
   - On **Scopes** page, click **Save and Continue**
   - On **Test users** page (if external), add test emails if needed
   - Click **Save and Continue**

5. **Create OAuth 2.0 Client ID**
   - Go to **APIs & Services** > **Credentials**
   - Click **+ Create Credentials** > **OAuth client ID**
   - Choose **Web application** as the application type
   - Give it a name (e.g., "LeadMap Web Client")
   - **Authorized redirect URIs**: Add this URL:
     ```
     https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
     ```
     - Replace `YOUR_PROJECT_REF` with your Supabase project reference
     - You can find your project reference in your Supabase project URL:
       - Example: If your Supabase URL is `https://abcdefghijklmnop.supabase.co`
       - Then your project reference is `abcdefghijklmnop`
   - Click **Create**
   - **IMPORTANT**: Copy the **Client ID** and **Client Secret** immediately
     - You'll need these in the next step
     - The secret won't be shown again!

### Step 2: Configure Google OAuth in Supabase

1. **Go to Supabase Dashboard**
   - Visit [app.supabase.com](https://app.supabase.com)
   - Select your project

2. **Enable Google Provider**
   - Navigate to **Authentication** > **Providers**
   - Find **Google** in the list
   - Toggle it **ON**
   - Paste your **Client ID** from Google Cloud Console
   - Paste your **Client Secret** from Google Cloud Console
   - Click **Save**

---

## Part 2: Microsoft (Azure AD) OAuth Setup

### Step 1: Register Application in Azure Portal

1. **Go to Azure Portal**
   - Visit [portal.azure.com](https://portal.azure.com)
   - Sign in with your Microsoft account

2. **Register a New Application**
   - Navigate to **Azure Active Directory** (or **Microsoft Entra ID**)
   - Click **App registrations** in the left sidebar
   - Click **+ New registration**
   - Fill in the form:
     - **Name**: LeadMap (or your app name)
     - **Supported account types**: 
       - Select **Accounts in any organizational directory and personal Microsoft accounts**
       - This allows both work/school accounts and personal Microsoft accounts
     - **Redirect URI**:
       - Platform: **Web**
       - URI: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
       - Replace `YOUR_PROJECT_REF` with your Supabase project reference
   - Click **Register**

3. **Get Client ID and Secret**
   - After registration, you'll see the **Overview** page
   - **Copy the Application (client) ID** - this is your Client ID
   - Go to **Certificates & secrets** in the left sidebar
   - Click **+ New client secret**
   - Add a description (e.g., "LeadMap OAuth Secret")
   - Choose an expiration (recommended: 24 months)
   - Click **Add**
   - **IMPORTANT**: Copy the **Value** of the secret immediately
     - This is your Client Secret
     - You won't be able to see it again after leaving this page!

4. **Configure API Permissions** (Optional but Recommended)
   - Go to **API permissions** in the left sidebar
   - Click **+ Add a permission**
   - Select **Microsoft Graph**
   - Select **Delegated permissions**
   - Add **User.Read** (this allows reading basic user profile)
   - Click **Add permissions**
   - If you see a warning about admin consent, you can ignore it for now (unless you're using organizational accounts)

### Step 2: Configure Microsoft OAuth in Supabase

1. **Go to Supabase Dashboard**
   - Visit [app.supabase.com](https://app.supabase.com)
   - Select your project

2. **Enable Azure Provider**
   - Navigate to **Authentication** > **Providers**
   - Find **Azure** in the list
   - Toggle it **ON**
   - Paste your **Client ID** (Application ID from Azure)
   - Paste your **Client Secret** (the Value you copied from Azure)
   - **Tenant ID**: 
     - Leave empty for multi-tenant (allows all Microsoft accounts)
     - Or enter your Azure AD Tenant ID if you want to restrict to your organization only
   - Click **Save**

---

## Part 3: Configure Redirect URLs

### In Supabase Dashboard

1. **Set Site URL and Redirect URLs**
   - Go to **Authentication** > **URL Configuration**
   - **Site URL**: 
     - Development: `http://localhost:3000`
     - Production: `https://yourdomain.com`
   - **Redirect URLs**: Add these:
     ```
     http://localhost:3000/api/auth/callback
     https://yourdomain.com/api/auth/callback
     ```
   - Click **Save**

### For Production

When you deploy to production, make sure to:

1. **Update Google Cloud Console**
   - Add your production redirect URI:
     ```
     https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
     ```
   - (This should already be set, but verify it)

2. **Update Azure Portal**
   - Add your production redirect URI in the app registration:
     ```
     https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
     ```

3. **Update Supabase Dashboard**
   - Update Site URL to your production domain
   - Add production redirect URL

---

## Part 4: Testing OAuth

### Test Google OAuth

1. **Start your development server**
   ```bash
   npm run dev
   ```

2. **Test the flow**
   - Go to `http://localhost:3000`
   - Click "Sign up with Google" or "Log in with Google"
   - You should be redirected to Google's sign-in page
   - Sign in with your Google account
   - Grant permissions if prompted
   - You should be redirected back to your app
   - You should be logged in and redirected to the dashboard

### Test Microsoft OAuth

1. **Test the flow**
   - Click "Sign up with Microsoft" or "Log in with Microsoft"
   - You should be redirected to Microsoft's sign-in page
   - Sign in with your Microsoft account
   - Grant permissions if prompted
   - You should be redirected back to your app
   - You should be logged in and redirected to the dashboard

---

## Troubleshooting

### Common Issues

#### 1. "Redirect URI mismatch" Error

**Problem**: The redirect URI in your OAuth provider doesn't match Supabase's callback URL.

**Solution**:
- Verify the redirect URI in Google Cloud Console / Azure Portal is exactly:
  ```
  https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
  ```
- Check for:
  - Trailing slashes (should NOT have one)
  - Protocol (must be `https://`)
  - Exact spelling of your project reference

#### 2. "Invalid client" or "Invalid credentials" Error

**Problem**: Client ID or Client Secret is incorrect.

**Solution**:
- Double-check you copied the entire Client ID and Secret
- Make sure there are no extra spaces or line breaks
- For Azure: Make sure you copied the **Value** of the secret, not the Secret ID
- Regenerate the secret if needed (but update Supabase with the new value)

#### 3. "Access blocked: This app's request is invalid" (Google)

**Problem**: OAuth consent screen is not properly configured or app is in testing mode.

**Solution**:
- Go to Google Cloud Console > OAuth consent screen
- Make sure you've completed all required fields
- If in testing mode, add your email as a test user
- Or publish the app (if ready for production)

#### 4. User Profile Not Created After OAuth

**Problem**: User signs in with OAuth but profile isn't created in the `users` table.

**Solution**:
- Check browser console for errors
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set in your `.env.local`
- Check Supabase logs in Dashboard > Logs
- The callback route (`/api/auth/callback`) should automatically create the profile

#### 5. OAuth Works But User Stays on Callback Page

**Problem**: Redirect after OAuth isn't working.

**Solution**:
- Check that redirect URLs are configured in Supabase Dashboard
- Verify the callback route is working (check browser console)
- Make sure `NEXT_PUBLIC_SUPABASE_URL` is set correctly

---

## Security Best Practices

1. **Never commit secrets to Git**
   - Keep Client IDs and Secrets in environment variables
   - Use `.env.local` for local development
   - Use environment variables in your hosting platform (Vercel, etc.)

2. **Use HTTPS in Production**
   - OAuth requires HTTPS for production
   - Make sure your production domain has SSL/TLS enabled

3. **Rotate Secrets Regularly**
   - Update OAuth secrets every 6-12 months
   - Update Supabase configuration when you rotate

4. **Limit Redirect URIs**
   - Only add redirect URIs you actually use
   - Remove old/unused redirect URIs

---

## Quick Reference

### Where to Find Your Supabase Project Reference

1. Go to your Supabase Dashboard
2. Click on your project
3. Go to **Settings** > **API**
4. Your project URL will be: `https://YOUR_PROJECT_REF.supabase.co`
5. The part before `.supabase.co` is your project reference

### Required Redirect URI Format

For both Google and Microsoft, use:
```
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

### Environment Variables Needed

You should already have these in your `.env.local`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

The OAuth credentials are configured in Supabase Dashboard, not in environment variables.

---

## Need Help?

- **Supabase Docs**: [supabase.com/docs/guides/auth](https://supabase.com/docs/guides/auth)
- **Google OAuth Docs**: [developers.google.com/identity/protocols/oauth2](https://developers.google.com/identity/protocols/oauth2)
- **Microsoft OAuth Docs**: [docs.microsoft.com/azure/active-directory/develop](https://docs.microsoft.com/azure/active-directory/develop)

