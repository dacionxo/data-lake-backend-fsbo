# Quick Deployment Guide - Get LeadMap Live

## Goal: Deploy to Vercel (Free Hosting) in 10 Minutes

Your site will be live at: `https://leadmap.vercel.app` (or your custom domain)

---

## Step 1: Push Code to GitHub (2 minutes)

Your GitHub repo is already set up! Just make sure your latest code is pushed:

```bash
# Check current status
git status

# If you have uncommitted changes, commit them
git add .
git commit -m "Ready for deployment"

# Push to GitHub
git push origin main
```

---

## Step 2: Deploy to Vercel (5 minutes)

### Option A: Deploy via Vercel Dashboard (Easiest)

1. **Go to [vercel.com](https://vercel.com)**
   - Sign up/login with GitHub (free account)

2. **Import Your Repository**
   - Click "Add New..." → "Project"
   - Find "LeadMap" repository
   - Click "Import"

3. **Configure Project**
   - Framework Preset: **Next.js** (auto-detected)
   - Root Directory: `./` (default)
   - Build Command: `npm run build` (default)
   - Output Directory: `.next` (default)
   - Click "Deploy"

4. **Add Environment Variables**
   - After first deploy, go to Project Settings → Environment Variables
   - Add all variables from your `.env.local` file:
   
   ```
   NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
   SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
   NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
   STRIPE_SECRET_KEY=your_stripe_secret_key
   STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret
   NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
   ```

5. **Redeploy**
   - After adding env variables, go to Deployments tab
   - Click "..." on latest deployment → "Redeploy"

### Option B: Deploy via Vercel CLI (Alternative)

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Deploy
vercel

# Follow prompts:
# - Set up and deploy? Yes
# - Which scope? Your account
# - Link to existing project? No
# - Project name? leadmap
# - Directory? ./
# - Override settings? No
```

---

## Step 3: Share the URL (1 minute)

Once deployed, Vercel will give you a URL like:
- `https://leadmap-xyz123.vercel.app`
- Or `https://leadmap.vercel.app` (if you set a custom name)

**Share this URL with your business partner!**

---

## Step 4: Update Stripe Webhook (2 minutes)

1. **Get your Vercel URL**
   - Copy the deployment URL from Vercel dashboard

2. **Update Stripe Webhook**
   - Go to [Stripe Dashboard](https://dashboard.stripe.com) → Webhooks
   - Edit your webhook endpoint
   - Update URL to: `https://your-vercel-url.vercel.app/api/stripe/webhook`
   - Save

---

## ✅ You're Live!

Your site is now accessible at your Vercel URL. Every time you push to GitHub, Vercel will automatically redeploy.

---

## Quick Commands Reference

```bash
# Deploy new changes
git add .
git commit -m "Update description"
git push origin main
# Vercel auto-deploys!

# Check deployment status
# Go to vercel.com/dashboard
```

---

## Troubleshooting

### Site shows "Error" or blank page?
- Check Environment Variables in Vercel dashboard
- Make sure all required variables are set
- Check Vercel deployment logs

### Authentication not working?
- Verify Supabase URL and keys are correct
- Check Supabase project is active
- Verify redirect URLs in Supabase dashboard

### Maps not showing?
- Verify Google Maps API key is set
- Check API key restrictions in Google Cloud Console
- Make sure Maps JavaScript API is enabled

---

## Free Tier Limits (Vercel)

✅ **Free tier includes:**
- Unlimited deployments
- 100GB bandwidth/month
- Automatic HTTPS
- Custom domains
- Perfect for your use case!

---

## Next Steps

1. ✅ Deploy to Vercel (follow steps above)
2. ✅ Share URL with business partner
3. ✅ Set up custom domain (optional)
4. ✅ Enable automatic deployments

**Your site will be live and accessible to your business partner!** 🚀

