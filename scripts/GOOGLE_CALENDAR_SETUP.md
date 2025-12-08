# Google Calendar Integration Setup Guide

This guide will walk you through setting up Google Calendar OAuth integration for your LeadMap application.

## Required Environment Variables

You need to set the following environment variables:

```env
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
NEXT_PUBLIC_APP_URL=https://your-domain.com  # or http://localhost:3000 for local dev
```

## Step-by-Step Setup

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click on the project dropdown at the top
3. Click **"New Project"**
4. Enter a project name (e.g., "LeadMap Calendar")
5. Click **"Create"**
6. Wait for the project to be created and select it

### 2. Enable Google Calendar API

1. In the Google Cloud Console, go to **"APIs & Services"** > **"Library"**
2. Search for **"Google Calendar API"**
3. Click on **"Google Calendar API"**
4. Click **"Enable"**
5. Wait for the API to be enabled

### 3. Configure OAuth Consent Screen

1. Go to **"APIs & Services"** > **"OAuth consent screen"**
2. **IMPORTANT**: Select **"External"** (NOT "Internal")
   - "Internal" only works for users in your Google Workspace organization
   - "External" allows any Google user to sign in
3. Click **"Create"**
4. Fill in the required information:
   - **App name**: NextDeal (or your app name)
   - **User support email**: Your email address (e.g., `david@growyourdigitalleverage.com`)
   - **Developer contact information**: Your email address
   - **App logo**: (Optional) Upload your app logo
   - **Application home page**: `https://www.growyourdigitalleverage.com`
   - **Application privacy policy link**: `https://www.growyourdigitalleverage.com/privacy` ⚠️ **Required for verification**
   - **Application terms of service link**: `https://www.growyourdigitalleverage.com/terms` ⚠️ **Required for verification**
   - **Authorized domains**: Add `growyourdigitalleverage.com`
   
   > **Note**: Privacy Policy and Terms of Service links are required if you want to verify your app with Google later. Users can still use the app without verification, but they'll see a warning.
5. Click **"Save and Continue"**
6. On the **"Scopes"** page, click **"Add or Remove Scopes"**
7. Add the following scopes:
   - `https://www.googleapis.com/auth/calendar`
   - `https://www.googleapis.com/auth/calendar.events`
   - `https://www.googleapis.com/auth/userinfo.email`
8. Click **"Update"** then **"Save and Continue"**
9. On the **"Test users"** page:
   - **If your app is in "Testing" mode**: Add all email addresses that need to test the app
   - **To publish your app** (recommended for production):
     - Click **"PUBLISH APP"** button at the top
     - Confirm the publishing
     - This allows any Google user to sign in (no test user list needed)
10. Click **"Save and Continue"**
11. Review and click **"Back to Dashboard"**

> **⚠️ Important**: If you see "This app can only be used within this organization", it means:
> - The OAuth consent screen is set to "Internal" instead of "External", OR
> - The app is in "Testing" mode and your email isn't in the test users list
> - **Solution**: Change to "External" and either add test users or publish the app

### 4. Create OAuth 2.0 Credentials

1. Go to **"APIs & Services"** > **"Credentials"**
2. Click **"Create Credentials"** > **"OAuth client ID"**
3. Select **"Web application"** as the application type
4. Give it a name (e.g., "LeadMap Calendar OAuth")
5. **Authorized redirect URIs** - Add the following:
   
   **For Local Development:**
   ```
   http://localhost:3000/api/calendar/oauth/google/callback
   ```
   
   **For Vercel Production (use your actual domain):**
   ```
   https://www.growyourdigitalleverage.com/api/calendar/oauth/google/callback
   ```
   
   > **Important**: 
   - Use your actual production domain (e.g., `https://www.growyourdigitalleverage.com`)
   - Do NOT include a trailing slash in the URL
   - The redirect URI must match exactly (including `https://` and no trailing slash)
   - If you have multiple domains, add each one separately
   
6. Click **"Create"**
7. **Copy the Client ID and Client Secret** - You'll need these for your environment variables
   - ⚠️ **Important**: The Client Secret is only shown once. Copy it immediately!

### 5. Set Environment Variables

#### For Local Development (.env.local)

Create or update `.env.local` in your project root:

```env
# Google Calendar OAuth
GOOGLE_CLIENT_ID=123456789-abcdefghijklmnop.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abcdefghijklmnopqrstuvwxyz

# App URL (must match your redirect URI)
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

#### For Vercel Production

1. Go to your [Vercel Dashboard](https://vercel.com/dashboard)
2. Select your project
3. Go to **"Settings"** > **"Environment Variables"**
4. Add each variable:
   - **Name**: `GOOGLE_CLIENT_ID`
   - **Value**: Your Google Client ID
   - **Environment**: Production, Preview, Development (select all)
   - Click **"Save"**
   
   - **Name**: `GOOGLE_CLIENT_SECRET`
   - **Value**: Your Google Client Secret
   - **Environment**: Production, Preview, Development (select all)
   - Click **"Save"**
   
   - **Name**: `NEXT_PUBLIC_APP_URL`
   - **Value**: `https://www.growyourdigitalleverage.com` (your production domain)
   - ⚠️ **CRITICAL**: Do NOT include a trailing slash (no `/` at the end)
   - **Environment**: Production, Preview, Development (select all)
   - Click **"Save"**

5. **Redeploy** your application for the changes to take effect
   - Go to **"Deployments"** tab
   - Click **"..."** on the latest deployment
   - Click **"Redeploy"**
   - Uncheck **"Use existing Build Cache"**
   - Click **"Redeploy"**

### 6. Verify the Setup

1. Start your local development server:
   ```bash
   npm run dev
   ```

2. Navigate to your calendar page: `http://localhost:3000/dashboard/crm/calendar`

3. Click **"Connect calendar"** button

4. Enter a Gmail address (e.g., `yourname@gmail.com`)

5. You should be redirected to Google's OAuth consent screen

6. After authorizing, you should be redirected back to your calendar page

## Troubleshooting

### Error: "Google OAuth not configured"
- **Solution**: Make sure `GOOGLE_CLIENT_ID` is set in your environment variables
- Restart your development server after adding environment variables

### Error: "redirect_uri_mismatch" or "doesn't comply with Google's OAuth 2.0 policy"
- **Solution**: 
  1. Go back to Google Cloud Console > Credentials
  2. Edit your OAuth 2.0 Client ID
  3. Make sure the redirect URI exactly matches: 
     - Local: `http://localhost:3000/api/calendar/oauth/google/callback`
     - Production: `https://www.growyourdigitalleverage.com/api/calendar/oauth/google/callback`
  4. **Critical points**:
     - The URI must match exactly (case-sensitive)
     - No trailing slash after the domain
     - Must use `https://` for production (not `http://`)
     - The path must be exactly `/api/calendar/oauth/google/callback`
  5. Also verify `NEXT_PUBLIC_APP_URL` in Vercel has no trailing slash:
     - ✅ Correct: `https://www.growyourdigitalleverage.com`
     - ❌ Wrong: `https://www.growyourdigitalleverage.com/`

### Error: "invalid_client"
- **Solution**: 
  - Verify your `GOOGLE_CLIENT_SECRET` is correct
  - Make sure there are no extra spaces or quotes in your environment variables
  - For Vercel, ensure you've redeployed after adding the variables

### Error: "This app can only be used within this organization" or "NextDeal can only be used within this organization"
- **Solution**: 
  1. Go to Google Cloud Console > APIs & Services > OAuth consent screen
  2. Check the **User Type**:
     - If it says **"Internal"**: Click **"EDIT APP"** and change it to **"External"**
     - Save the changes
  3. Check the **Publishing status**:
     - If it says **"Testing"**: You have two options:
       - **Option A (Recommended for production)**: Click **"PUBLISH APP"** button to allow all Google users
       - **Option B (For testing)**: Add your email address to the **"Test users"** list
  4. After making changes, wait 5-10 minutes for changes to propagate
  5. Try the OAuth flow again

### Warning: "Google hasn't verified this app"
- **What it means**: 
  - This warning appears because your app requests sensitive scopes (like Calendar access)
  - It's normal for apps that haven't completed Google's verification process
  - Users can still use the app by clicking "Advanced" → "Go to NextDeal (unsafe)"

- **Solutions**:

  **Option 1: For Testing/Development (Quick Fix)**
  - Add test users in OAuth consent screen settings
  - Test users won't see the verification warning
  - Go to: APIs & Services > OAuth consent screen > Test users
  - Add email addresses of users who need to test

  **Option 2: For Production (Recommended Long-term)**
  - Complete Google's OAuth verification process
  - This removes the warning for all users
  - Process takes 4-6 weeks and requires:
    - Privacy Policy URL (must be accessible)
    - Terms of Service URL (must be accessible)
    - Video demonstration of app functionality
    - Detailed explanation of why you need each scope
    - Security assessment (for sensitive scopes)
  - Start verification: APIs & Services > OAuth consent screen > "PUBLISH APP" → "Request verification"

  **Option 3: Use Less Sensitive Scopes (If Possible)**
  - Consider if you really need all the scopes you're requesting
  - Some scopes are less sensitive and don't trigger verification warnings
  - However, Calendar access typically requires verification

- **For Now (Immediate Use)**:
  - Users can click "Advanced" → "Go to NextDeal (unsafe)" to proceed
  - The app will work, but users will see the warning each time
  - This is acceptable for development and early production use

### Token Refresh Issues
- **Solution**: 
  - Make sure `access_type=offline` is set (already configured in the code)
  - The first authorization must include `prompt=consent` to get a refresh token
  - This is already configured in the code

## Security Best Practices

1. **Never commit** `.env.local` to version control (it should be in `.gitignore`)
2. **Rotate secrets** if they're accidentally exposed
3. **Restrict OAuth credentials** in Google Cloud Console:
   - Go to your OAuth 2.0 Client ID settings
   - Add HTTP referrer restrictions if possible
4. **Use different credentials** for development and production
5. **Monitor API usage** in Google Cloud Console to detect unusual activity

## Additional Resources

- [Google Calendar API Documentation](https://developers.google.com/calendar/api)
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Vercel Environment Variables Guide](https://vercel.com/docs/concepts/projects/environment-variables)

## Support

If you encounter issues:
1. Check the browser console for errors
2. Check your server logs for detailed error messages
3. Verify all environment variables are set correctly
4. Ensure the redirect URI matches exactly in Google Cloud Console

