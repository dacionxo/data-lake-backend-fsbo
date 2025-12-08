# Street View Setup Guide

This guide will help you set up Google Street View for your LeadMap application. Street View is already implemented in the codebase and will automatically display in property detail modals.

## Overview

Street View is currently implemented using **Google Street View Static API** and appears in:
- Property detail modals (LeadDetailModal component)
- Shows actual street-level photos of properties
- Automatically falls back to static maps or property photos if Street View is unavailable

## Setup Steps

### 1. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **API Key**
5. Copy your API key

### 2. Enable Street View Static API

1. In Google Cloud Console, go to **APIs & Services** > **Library**
2. Search for "Street View Static API"
3. Click on **Street View Static API**
4. Click **Enable**

**Important:** You must enable this API for Street View to work!

### 3. (Optional) Enable Maps Static API (for fallback)

The code automatically falls back to static maps if Street View is unavailable. To enable this:

1. In Google Cloud Console, go to **APIs & Services** > **Library**
2. Search for "Maps Static API"
3. Click on **Maps Static API**
4. Click **Enable**

### 4. Configure API Key Restrictions (Recommended)

For security, restrict your API key:

1. Go to **APIs & Services** > **Credentials**
2. Click on your API key
3. Under **API restrictions**, select **Restrict key**
4. Check:
   - ✅ **Street View Static API**
   - ✅ **Maps Static API** (if you enabled it)
5. Under **Application restrictions**, you can restrict by:
   - **HTTP referrers** (for web apps) - Add your domain
   - **IP addresses** (for server-side)
6. Click **Save**

### 5. Add API Key to Environment Variables

Add your Google Street View API key to your `.env.local` file:

```env
# Street View API Key (used specifically for Street View in property modals)
NEXT_PUBLIC_GOOGLE_STREET_VIEW_API_KEY=your_google_street_view_api_key_here

# General Google Maps API Key (used for static maps fallback)
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
```

**Note:** The component will use `NEXT_PUBLIC_GOOGLE_STREET_VIEW_API_KEY` if available, otherwise it falls back to `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`.

**For production (Vercel):**
1. Go to your Vercel project settings
2. Navigate to **Environment Variables**
3. Add:
   - **Name:** `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY`
   - **Value:** Your API key
   - **Environment:** Production, Preview, Development (select all)

### 6. Restart Your Development Server

After adding the environment variable:

```bash
npm run dev
```

## How It Works

The Street View implementation follows this priority:

1. **Google Street View** (if API key is set and address is available)
   - Uses: `https://maps.googleapis.com/maps/api/streetview?size=640x480&location={address}&key={key}`
   
2. **Google Static Map** (fallback if Street View fails)
   - Uses coordinates if available
   - Shows a map with a marker at the property location
   
3. **Property Photos** (fallback if no maps available)
   - Uses `photos_json` array if available
   - Falls back to `photos` field
   
4. **No Image Available** (final fallback)
   - Shows a placeholder with map icon

## Code Location

Street View is implemented in:
- **File:** `app/dashboard/prospect-enrich/components/LeadDetailModal.tsx`
- **Component:** `MapPreview` function (lines 1226-1308)

## Testing

1. Open a property detail modal
2. Check the left panel - you should see:
   - Street View image (if available for that address)
   - Or static map (if Street View unavailable)
   - Or property photo (if no maps available)

## Pricing

Google Street View Static API pricing:
- **Free tier:** $200 credit per month (covers ~28,500 requests)
- **After free tier:** $7 per 1,000 requests
- **Maps Static API:** $2 per 1,000 requests

**Note:** The free tier is usually sufficient for development and small-scale production use.

## Troubleshooting

### Street View Not Showing

1. **Check API key is set:**
   ```bash
   echo $NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
   ```

2. **Verify API is enabled:**
   - Go to Google Cloud Console > APIs & Services > Enabled APIs
   - Ensure "Street View Static API" is listed

3. **Check browser console:**
   - Open browser DevTools (F12)
   - Look for errors in Console tab
   - Check Network tab for failed API requests

4. **Verify address format:**
   - Street View requires a valid address
   - Format: "Street, City, State ZIP"
   - Example: "123 Main St, Orlando, FL 32801"

5. **Check API restrictions:**
   - Ensure your domain/IP is allowed if you set restrictions
   - For local development, you may need to allow `localhost`

### Common Errors

**"This API project is not authorized to use this API"**
- Enable Street View Static API in Google Cloud Console

**"RefererNotAllowedMapError"**
- Add your domain to HTTP referrer restrictions
- Or remove referrer restrictions for testing

**"REQUEST_DENIED"**
- Check API key is correct
- Verify billing is enabled (required even for free tier)

## Alternative: Using Mapbox Static Images

If you prefer to use Mapbox instead of Google Maps for Street View:

**Note:** Mapbox doesn't have Street View, but you can use:
- **Mapbox Static Images API** - Shows a map view
- **Mapbox GL JS** - Interactive map (already implemented)

To use Mapbox Static Images, you would need to modify the `MapPreview` component to use Mapbox's Static Images API instead of Google Street View.

## Support

For more information:
- [Google Street View Static API Documentation](https://developers.google.com/maps/documentation/streetview)
- [Google Maps Platform Pricing](https://developers.google.com/maps/billing-and-pricing/pricing)
- [Google Cloud Console](https://console.cloud.google.com/)

