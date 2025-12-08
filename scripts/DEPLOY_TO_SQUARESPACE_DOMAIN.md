# Deploy LeadMap to Your Squarespace Domain

## Important: Squarespace Domain Setup

**Squarespace doesn't host custom Next.js applications**, but you can use your Squarespace domain (`growyourdigitalleverage.com`) with a hosting service like Vercel (free and perfect for Next.js).

This guide will:
1. ✅ Deploy your app to Vercel (free hosting)
2. ✅ Connect your Squarespace domain to Vercel
3. ✅ Make your site live at `growyourdigitalleverage.com`

---

## Step 1: Deploy to Vercel (10 minutes)

### Option A: Deploy via Vercel Dashboard (Recommended)

1. **Go to [vercel.com](https://vercel.com)**
   - Sign up/login with GitHub (free account)
   - Vercel is free for personal projects and perfect for Next.js

2. **Import Your Repository**
   - Click "Add New..." → "Project"
   - Find your "LeadMap" repository
   - Click "Import"

3. **Configure Project**
   - Framework Preset: **Next.js** (auto-detected)
   - Root Directory: `./LeadMap-main` (if your code is in a subfolder)
   - OR `./` (if code is in root)
   - Build Command: `npm run build` (default)
   - Output Directory: `.next` (default)
   - Click "Deploy"

4. **Add Environment Variables**
   - After first deploy, go to **Project Settings** → **Environment Variables**
   - Add all variables from your `.env.local` file:
   
   ```
   NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
   SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
   NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
   STRIPE_SECRET_KEY=your_stripe_secret_key
   STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret
   NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
   NEXT_PUBLIC_APP_URL=https://growyourdigitalleverage.com
   NEXT_PUBLIC_STRIPE_STARTER_PRICE_ID=your_starter_price_id
   NEXT_PUBLIC_STRIPE_PRO_PRICE_ID=your_pro_price_id
   STRIPE_STARTER_PRICE_ID=your_starter_price_id
   STRIPE_PRO_PRICE_ID=your_pro_price_id
   ```

5. **Redeploy**
   - After adding env variables, go to **Deployments** tab
   - Click "..." on latest deployment → "Redeploy"

### Option B: Deploy via Vercel CLI

```bash
# Install Vercel CLI
npm i -g vercel

# Login to Vercel
vercel login

# Navigate to your project
cd LeadMap-main

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

## Step 2: Connect Your Squarespace Domain (15 minutes)

### Method 1: Point Domain from Squarespace to Vercel (Recommended)

1. **Get Vercel Domain Configuration**
   - In Vercel dashboard, go to your project
   - Click **Settings** → **Domains**
   - Click **Add Domain**
   - Enter: `growyourdigitalleverage.com`
   - Vercel will show you DNS records to add

2. **Update DNS in Squarespace**
   - Log into your Squarespace account
   - Go to **Settings** → **Domains** → **growyourdigitalleverage.com**
   - Click **DNS Settings** or **Advanced DNS Settings**
   - You'll need to add/modify these records:

   **For Root Domain (growyourdigitalleverage.com):**
   - Add an **A Record**:
     - Type: `A`
     - Host: `@` or leave blank
     - Points to: `76.76.21.21` (Vercel's IP - Vercel will show you the exact IP)
     - TTL: `3600` or default

   **For WWW Subdomain (www.growyourdigitalleverage.com):**
   - Add a **CNAME Record**:
     - Type: `CNAME`
     - Host: `www`
     - Points to: `cname.vercel-dns.com` (Vercel will show you the exact value)
     - TTL: `3600` or default

3. **Verify in Vercel**
   - Vercel will automatically detect when DNS is configured
   - Wait 5-60 minutes for DNS propagation
   - Vercel will show "Valid Configuration" when ready

### Method 2: Transfer DNS Management to Vercel

If Squarespace allows DNS management transfer:

1. **In Vercel:**
   - Go to **Settings** → **Domains** → Add `growyourdigitalleverage.com`
   - Vercel will provide nameservers

2. **In Squarespace:**
   - Go to **Settings** → **Domains**
   - Update nameservers to Vercel's nameservers
   - This gives Vercel full DNS control

---

## Step 3: Update Supabase Redirect URLs

1. **Go to Supabase Dashboard**
   - Navigate to **Authentication** → **URL Configuration**
   - Add to **Redirect URLs**:
     - `https://growyourdigitalleverage.com/**`
     - `https://www.growyourdigitalleverage.com/**`
   - Add to **Site URL**:
     - `https://growyourdigitalleverage.com`

---

## Step 4: Update Stripe Webhook

1. **Go to Stripe Dashboard**
   - Navigate to **Developers** → **Webhooks**
   - Edit your webhook endpoint
   - Update URL to: `https://growyourdigitalleverage.com/api/stripe/webhook`
   - Save

---

## Step 5: Update Google Maps API Restrictions

1. **Go to Google Cloud Console**
   - Navigate to **APIs & Services** → **Credentials**
   - Click on your Google Maps API key
   - Under **Application restrictions**, add:
     - `growyourdigitalleverage.com`
     - `www.growyourdigitalleverage.com`
   - Save

---

## ✅ Verification Checklist

- [ ] App deployed to Vercel successfully
- [ ] All environment variables added to Vercel
- [ ] Domain added in Vercel dashboard
- [ ] DNS records updated in Squarespace
- [ ] DNS propagation complete (check with `nslookup growyourdigitalleverage.com`)
- [ ] Site accessible at `https://growyourdigitalleverage.com`
- [ ] Supabase redirect URLs updated
- [ ] Stripe webhook URL updated
- [ ] Google Maps API restrictions updated

---

## Troubleshooting

### Domain Not Working?

1. **Check DNS Propagation**
   ```bash
   # In terminal/command prompt
   nslookup growyourdigitalleverage.com
   ```
   - Should show Vercel's IP address

2. **Verify DNS Records in Squarespace**
   - Make sure A record points to Vercel's IP
   - Make sure CNAME for www points to Vercel

3. **Check Vercel Domain Status**
   - Go to Vercel → Settings → Domains
   - Should show "Valid Configuration"

### Site Shows Error?

1. **Check Environment Variables**
   - Verify all variables are set in Vercel
   - Make sure `NEXT_PUBLIC_APP_URL` is set to `https://growyourdigitalleverage.com`

2. **Check Build Logs**
   - Go to Vercel → Deployments
   - Click on latest deployment
   - Check for build errors

### Authentication Not Working?

1. **Verify Supabase URLs**
   - Check Supabase dashboard → Authentication → URL Configuration
   - Make sure your domain is in redirect URLs

2. **Check Environment Variables**
   - Verify `NEXT_PUBLIC_SUPABASE_URL` and keys are correct

---

## Cost Breakdown

- **Vercel**: FREE (Hobby plan includes custom domains)
- **Squarespace Domain**: Your existing domain (no additional cost)
- **Total**: $0/month for hosting

---

## Next Steps After Deployment

1. ✅ Test all features on production domain
2. ✅ Set up monitoring (Vercel provides basic analytics)
3. ✅ Configure automatic deployments (push to GitHub = auto-deploy)
4. ✅ Set up SSL certificate (Vercel does this automatically)

---

## Important Notes

- **Squarespace Website**: If you have an existing Squarespace website, you'll need to decide:
  - Option A: Replace it entirely with your Next.js app
  - Option B: Keep Squarespace site and use a subdomain for the app (e.g., `app.growyourdigitalleverage.com`)

- **DNS Propagation**: Can take 5 minutes to 48 hours (usually 1-2 hours)

- **SSL Certificate**: Vercel automatically provides free SSL certificates

---

## Support

If you encounter issues:
1. Check Vercel deployment logs
2. Check browser console for errors
3. Verify all environment variables are set
4. Check DNS records are correct

Your site will be live at `https://growyourdigitalleverage.com` once DNS propagates! 🚀

