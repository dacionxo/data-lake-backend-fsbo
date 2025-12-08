# Google Maps API Key Setup Guide

This guide will walk you through setting up a Google Maps API key for geocoding addresses in your application.

## Prerequisites

1. **Google Account**: You need a Google account (Gmail account works)
2. **Billing Account**: Google Maps requires a billing account, but offers a free tier
3. **Google Cloud Project**: You'll create or use an existing project

## Step-by-Step Setup

### 1. Create or Select a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top
3. Click "New Project" or select an existing project
4. If creating new:
   - Enter a project name (e.g., "LeadMap Geocoding")
   - Click "Create"
   - Wait for the project to be created

### 2. Enable Billing

**Important**: Google Maps APIs require billing to be enabled, even though you get free credits.

1. In the Google Cloud Console, go to **Billing** (hamburger menu → Billing)
2. Click **Link a billing account**
3. If you don't have one:
   - Click **Create billing account**
   - Fill in your payment information
   - Google provides $200 in free credits per month for Maps, Routes, and Places
   - You won't be charged unless you exceed the free tier

### 3. Enable Required APIs

You need to enable the **Geocoding API**:

1. In Google Cloud Console, go to **APIs & Services** → **Library**
2. Search for "Geocoding API"
3. Click on **Geocoding API**
4. Click **Enable**

**Optional but recommended**:
- **Maps JavaScript API** (for the map display)
- **Places API** (for address autocomplete)
- **Street View Static API** (for Street View)

### 4. Create an API Key

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **API key**
3. Your API key will be created and displayed
4. **Copy the key immediately** - you'll need it for your `.env.local` file

### 5. Restrict Your API Key (Recommended for Security)

**Important**: Restricting your API key prevents unauthorized usage.

#### A. Application Restrictions

For server-side geocoding (backfill script), choose one:

**Option 1: No restrictions** (easiest, less secure)
- Select "None" under Application restrictions
- ⚠️ Only use this for testing/development

**Option 2: IP restrictions** (more secure)
- Select "IP addresses (web servers, cron jobs, etc.)"
- Add your server's IP address(es)
- For local development, you can add your public IP

**Option 3: HTTP referrer restrictions** (for browser use only)
- Select "HTTP referrers (web sites)"
- Add your domain(s): `https://yourdomain.com/*`
- ⚠️ This won't work for server-side scripts

#### B. API Restrictions

1. Select **"Restrict key"**
2. Under "API restrictions", select **"Restrict key"**
3. Check the following APIs:
   - ✅ **Geocoding API** (required)
   - ✅ **Maps JavaScript API** (if using maps)
   - ✅ **Places API** (if using autocomplete)
   - ✅ **Street View Static API** (if using Street View)
4. Click **Save**

### 6. Add API Key to Your Project

1. Open your `.env.local` file in the project root
2. Add or update the following line:

```bash
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_api_key_here
```

3. Replace `your_api_key_here` with the actual API key you copied
4. Save the file
5. **Restart your development server** if it's running

### 7. Test Your API Key

Run the backfill script to test:

```bash
npm run backfill-geocodes
```

The script will:
1. Test the API key with a sample address
2. Show clear error messages if something is wrong
3. Only proceed if the API key is valid

## Free Tier Limits

Google Maps provides generous free credits:

- **$200 free credit per month**
- **Geocoding API**: 
  - $5.00 per 1,000 requests
  - Free tier covers ~40,000 requests/month
- **Maps JavaScript API**:
  - $7.00 per 1,000 map loads
  - Free tier covers ~28,000 map loads/month

**Note**: You'll only be charged if you exceed the free tier. Most small to medium applications stay within the free tier.

## Troubleshooting

### Error: "The provided API key is invalid"

**Solutions**:
1. ✅ Verify the key is copied correctly (no extra spaces)
2. ✅ Check that Geocoding API is enabled
3. ✅ Ensure billing is enabled
4. ✅ Check API key restrictions (should allow server-side usage)

### Error: "This API project is not authorized to use this API"

**Solution**:
- Go to APIs & Services → Library
- Search for "Geocoding API"
- Click "Enable"

### Error: "Requests from referer are not allowed"

**Solution**:
- If using HTTP referrer restrictions, add your domain
- Or change to "IP addresses" restriction for server-side scripts
- Or set to "None" for development

### Error: "Billing has not been enabled"

**Solution**:
- Go to Billing in Google Cloud Console
- Link a billing account
- Even with billing enabled, you get $200/month free

### Rate Limiting / Quota Exceeded

**Solutions**:
1. The script includes rate limiting (150ms delay between requests)
2. If you hit quota limits, wait a few minutes and retry
3. Check your usage in Google Cloud Console → APIs & Services → Dashboard

## Security Best Practices

1. **Never commit API keys to Git**
   - ✅ Already in `.gitignore` (`.env.local`)
   - ✅ Use environment variables

2. **Restrict your API key**
   - Use IP restrictions for server-side scripts
   - Use HTTP referrer restrictions for browser-only APIs

3. **Monitor usage**
   - Set up billing alerts in Google Cloud Console
   - Monitor API usage in the Dashboard

4. **Rotate keys if compromised**
   - If a key is exposed, delete it and create a new one
   - Update `.env.local` with the new key

## Additional Resources

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [Geocoding API Documentation](https://developers.google.com/maps/documentation/geocoding)
- [API Key Best Practices](https://developers.google.com/maps/api-security-best-practices)
- [Pricing Information](https://developers.google.com/maps/billing-and-pricing/pricing)

## Quick Checklist

- [ ] Google Cloud project created
- [ ] Billing account linked
- [ ] Geocoding API enabled
- [ ] API key created
- [ ] API key restricted (recommended)
- [ ] API key added to `.env.local`
- [ ] Test script runs successfully

---

**Need Help?** If you encounter issues, check the error messages from the backfill script - they now provide specific guidance for common problems.

