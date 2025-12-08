# LeadMap Setup Guide

This guide covers all setup procedures for the LeadMap platform, including Google Maps, OAuth authentication, and GitHub repository configuration.

## Table of Contents

1. [Google Maps API Setup](#google-maps-api-setup)
2. [OAuth Authentication Setup](#oauth-authentication-setup)
3. [GitHub Repository Setup](#github-repository-setup)

---

## Google Maps API Setup

This guide will help you set up Google Maps API for your LeadMap application.

### 🚀 Quick Setup

#### 1. Get Google Maps API Key

1. **Go to Google Cloud Console**: https://console.cloud.google.com/
2. **Create a new project** or select existing one
3. **Enable APIs**:
   - Go to "APIs & Services" → "Library"
   - Search and enable these APIs:
     - **Maps JavaScript API** (for the map display)
     - **Geocoding API** (for address-to-coordinates conversion)
     - **Places API** (optional, for enhanced location features)

#### 2. Create API Key

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "API Key"
3. **Copy the API key** (starts with `AIza...`)

#### 3. Secure Your API Key

1. **Restrict the API key**:
   - Click on your API key
   - Under "Application restrictions":
     - Choose "HTTP referrers (web sites)"
     - Add your domains:
       - `http://localhost:3000/*` (for development)
       - `https://yourdomain.com/*` (for production)
   - Under "API restrictions":
     - Select "Restrict key"
     - Choose only the APIs you enabled above

#### 4. Add to Environment Variables

Add your Google Maps API key to your `.env.local` file:

```bash
# Google Maps API (Primary mapping service)
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=AIza_your_actual_api_key_here
```

#### 5. Test the Setup

1. **Start your development server**:
   ```bash
   npm run dev
   ```

2. **Navigate to the Map view** in your app
3. **You should see**:
   - A Google Maps interface
   - Your leads plotted as markers
   - Clickable markers with property details

### 🔧 Advanced Configuration

#### Geocoding Your Data

To get accurate coordinates for your leads, run the geocoding script:

```bash
node scripts/google-maps-geocode-addresses.js
```

This will:
- Read your CSV file
- Geocode each address using Google's Geocoding API
- Update your Supabase database with precise coordinates
- Show progress and results

#### API Quotas & Billing

- **Free tier**: 28,000 map loads per month
- **Geocoding**: 40,000 requests per month free
- **Billing**: Set up billing account for production use
- **Monitoring**: Check usage in Google Cloud Console

### 🛠️ Troubleshooting

#### Common Issues

1. **"Google Maps API Key Required" message**:
   - Check your `.env.local` file has the correct key
   - Restart your development server
   - Verify the key is not restricted to wrong domains

2. **"This page can't load Google Maps correctly"**:
   - Check API restrictions in Google Cloud Console
   - Ensure Maps JavaScript API is enabled
   - Verify billing is set up if you've exceeded free tier

3. **Geocoding fails**:
   - Check Geocoding API is enabled
   - Verify API key has geocoding permissions
   - Check rate limits (script includes delays)

4. **Map not showing**:
   - Check browser console for errors
   - Verify API key format (starts with `AIza`)
   - Check network connectivity

---

## OAuth Authentication Setup

This guide will walk you through setting up Google and Microsoft OAuth authentication in your Supabase project.

### Prerequisites

- Supabase project created
- Google Cloud Console account (for Google OAuth)
- Microsoft Azure account (for Microsoft OAuth)

### Step 1: Configure OAuth in Supabase Dashboard

1. **Go to your Supabase Dashboard**
   - Navigate to [supabase.com](https://supabase.com)
   - Select your project

2. **Navigate to Authentication Settings**
   - Click on **Authentication** in the left sidebar
   - Click on **Providers** tab

### Step 2: Set up Google OAuth

#### In Google Cloud Console:

1. **Create a Project** (if you don't have one)
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Create a new project or select an existing one

2. **Enable Google+ API**
   - Go to **APIs & Services** > **Library**
   - Search for "Google+ API" and enable it

3. **Create OAuth 2.0 Credentials**
   - Go to **APIs & Services** > **Credentials**
   - Click **Create Credentials** > **OAuth client ID**
   - Choose **Web application** as the application type
   - Add authorized redirect URIs:
     ```
     https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
     ```
     Replace `YOUR_PROJECT_REF` with your Supabase project reference (found in your project URL)
   - Click **Create**
   - **Copy the Client ID and Client Secret**

#### In Supabase Dashboard:

1. **Enable Google Provider**
   - In Supabase Dashboard > Authentication > Providers
   - Find **Google** and toggle it **ON**
   - Paste your **Client ID** and **Client Secret** from Google Cloud Console
   - Click **Save**

### Step 3: Set up Microsoft OAuth (Azure AD)

#### In Azure Portal:

1. **Register an Application**
   - Go to [Azure Portal](https://portal.azure.com)
   - Navigate to **Azure Active Directory** > **App registrations**
   - Click **New registration**
   - Enter a name (e.g., "LeadMap")
   - Select **Accounts in any organizational directory and personal Microsoft accounts**
   - Set Redirect URI:
     - Platform: **Web**
     - URI: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
   - Click **Register**

2. **Get Client ID and Secret**
   - After registration, you'll see the **Application (client) ID** - copy this
   - Go to **Certificates & secrets**
   - Click **New client secret**
   - Add a description and set expiration
   - Click **Add**
   - **Copy the secret value immediately** (you won't be able to see it again)

3. **Configure API Permissions** (Optional)
   - Go to **API permissions**
   - Add permissions as needed (usually `User.Read` is sufficient)

#### In Supabase Dashboard:

1. **Enable Azure Provider**
   - In Supabase Dashboard > Authentication > Providers
   - Find **Azure** and toggle it **ON**
   - Paste your **Client ID** (Application ID) from Azure
   - Paste your **Client Secret** from Azure
   - Set **Tenant ID** (optional - leave empty for multi-tenant, or use your Azure AD tenant ID)
   - Click **Save**

### Step 4: Configure Redirect URLs

Make sure your redirect URLs are correctly set:

1. **In Supabase Dashboard**
   - Go to **Authentication** > **URL Configuration**
   - Add your site URL: `http://localhost:3000` (for development)
   - Add your production URL when ready
   - Add redirect URL: `http://localhost:3000/api/auth/callback`

2. **For Production**
   - Update redirect URLs in both Google Cloud Console and Azure Portal
   - Update redirect URLs in Supabase Dashboard
   - Use your production domain instead of `localhost:3000`

### Step 5: Test OAuth Sign-In

1. **Start your development server**
   ```bash
   npm run dev
   ```

2. **Test Google Sign-In**
   - Go to `http://localhost:3000`
   - Click "Sign up with Google"
   - You should be redirected to Google's sign-in page
   - After signing in, you'll be redirected back to your dashboard

3. **Test Microsoft Sign-In**
   - Click "Sign up with Microsoft"
   - You should be redirected to Microsoft's sign-in page
   - After signing in, you'll be redirected back to your dashboard

### Troubleshooting

#### Common Issues:

1. **"Redirect URI mismatch" error**
   - Make sure the redirect URI in your OAuth provider matches exactly:
     `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
   - Check for trailing slashes and protocol (https vs http)

2. **"Invalid client" error**
   - Verify your Client ID and Client Secret are correct
   - Make sure you copied the entire secret (no spaces or line breaks)

3. **User profile not created**
   - Check the browser console for errors
   - Verify the `users` table exists and has the correct schema
   - Check Supabase logs in the dashboard

4. **OAuth provider not showing**
   - Make sure you toggled the provider ON in Supabase Dashboard
   - Refresh the page after saving provider settings

### Security Notes

- **Never commit OAuth secrets to version control**
- Use environment variables for sensitive data
- Regularly rotate your OAuth secrets
- Use HTTPS in production
- Configure proper CORS settings in Supabase

---

## GitHub Repository Setup

This guide will help you set up your LeadMap project on GitHub for collaboration.

### 📋 Current Status

✅ **Git repository initialized** locally  
✅ **Initial commit created** with all project files  
✅ **Ready for GitHub upload**

### 🔗 Step 1: Create GitHub Repository

1. **Go to GitHub.com** and sign in to your account
2. **Click the "+" icon** in the top right corner
3. **Select "New repository"**
4. **Fill in the details:**
   - **Repository name:** `LeadMap` or `leadmap-saas`
   - **Description:** `SaaS platform for real estate agents to discover undervalued property leads`
   - **Visibility:** Choose Private (recommended) or Public
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)

### 🔗 Step 2: Connect Local Repository to GitHub

After creating the GitHub repository, run these commands in your terminal:

```bash
# Add the GitHub repository as remote origin
git remote add origin https://github.com/YOUR_USERNAME/LeadMap.git

# Push your code to GitHub
git branch -M main
git push -u origin main
```

### 👥 Step 3: Add Collaborators

1. **Go to your repository** on GitHub
2. **Click "Settings"** tab
3. **Click "Collaborators"** in the left sidebar
4. **Click "Add people"**
5. **Enter collaborator's GitHub username or email**
6. **Send invitation** with appropriate permissions (Write access recommended)

### 🔄 Real-Time Updates

Once set up, any changes you make can be shared instantly:

```bash
# After making changes
git add .
git commit -m "Description of changes"
git push origin main
```

### 🛡️ Security Considerations

#### Environment Variables
- **Never commit** `.env.local` or `.env` files
- **Use `env.example`** as a template
- **Share API keys** securely (not in GitHub)

#### Sensitive Data
- **Database credentials** - Share via secure channels
- **API keys** - Use environment variables
- **Stripe keys** - Keep private and secure

### 💡 Pro Tips

#### For Collaboration
- **Use meaningful commit messages** to describe changes
- **Create branches** for new features
- **Use pull requests** for code review
- **Keep documentation updated**

#### For Business
- **Share the CHANGELOG** to show development progress
- **Use PROJECT_STRUCTURE** to explain technical details
- **Reference DEPLOYMENT.md** for production setup
- **Keep README.md** updated with latest features

---

## Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Google OAuth Setup](https://developers.google.com/identity/protocols/oauth2)
- [Microsoft Azure AD Setup](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [GitHub Docs](https://docs.github.com)
- [Git Tutorial](https://git-scm.com/docs)

---

**Ready to go!** Once you complete these setup steps, your LeadMap platform will be fully configured! 🚀

