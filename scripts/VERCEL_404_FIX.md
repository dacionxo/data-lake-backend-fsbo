# Fix Vercel 404 NOT_FOUND Error

## Error: `404: NOT_FOUND`

This error typically means the build succeeded but Vercel can't find your routes. Here's how to fix it:

---

## Step 1: Check Build Logs in Vercel

1. Go to your Vercel dashboard
2. Click on your project
3. Go to **Deployments** tab
4. Click on the latest deployment
5. Check the **Build Logs** for any errors

**Common Build Errors:**
- Missing environment variables
- TypeScript errors
- Missing dependencies
- Build timeout

---

## Step 2: Verify Root Directory in Vercel

The 404 error often happens when Vercel is looking in the wrong directory.

1. Go to **Project Settings** → **General**
2. Check **Root Directory**:
   - If your code is in `LeadMap-main/` folder: Set to `LeadMap-main`
   - If your code is in root: Leave empty or set to `./`

**To Fix:**
- If your GitHub repo has the code in a subfolder, set Root Directory to that folder
- If code is at root level, Root Directory should be empty

---

## Step 3: Verify Environment Variables

Make sure ALL required environment variables are set in Vercel:

### Required Variables (Minimum):

```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
NEXT_PUBLIC_APP_URL=https://growyourdigitalleverage.com
```

### Recommended Variables (For Full Functionality):

```
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=your_stripe_publishable_key
STRIPE_SECRET_KEY=your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=your_stripe_webhook_secret
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
NEXT_PUBLIC_STRIPE_STARTER_PRICE_ID=your_starter_price_id
NEXT_PUBLIC_STRIPE_PRO_PRICE_ID=your_pro_price_id
STRIPE_STARTER_PRICE_ID=your_starter_price_id
STRIPE_PRO_PRICE_ID=your_pro_price_id
```

**To Add/Check:**
1. Go to **Project Settings** → **Environment Variables**
2. Make sure all variables are added
3. Make sure they're set for **Production**, **Preview**, and **Development**
4. **Redeploy** after adding variables

---

## Step 4: Check Next.js Configuration

I've created a `vercel.json` file for you. Make sure it's committed to your repo:

```json
{
  "buildCommand": "npm run build",
  "devCommand": "npm run dev",
  "installCommand": "npm install",
  "framework": "nextjs",
  "regions": ["iad1"]
}
```

---

## Step 5: Test Build Locally

Test if your build works locally:

```bash
cd LeadMap-main
npm install
npm run build
```

If the build fails locally, fix those errors first.

---

## Step 6: Verify Project Structure

Make sure your project has this structure:

```
LeadMap-main/
├── app/
│   ├── page.tsx          ← Home page (required)
│   ├── layout.tsx        ← Root layout (required)
│   └── ...
├── package.json
├── next.config.js
├── tsconfig.json
└── vercel.json
```

---

## Step 7: Force Redeploy

1. Go to **Deployments** tab
2. Click **"..."** on latest deployment
3. Click **"Redeploy"**
4. Make sure **"Use existing Build Cache"** is **UNCHECKED**

---

## Step 8: Check Vercel Project Settings

1. **Framework Preset**: Should be **Next.js** (auto-detected)
2. **Build Command**: Should be `npm run build` (or leave empty for auto)
3. **Output Directory**: Should be `.next` (or leave empty for auto)
4. **Install Command**: Should be `npm install` (or leave empty for auto)

---

## Common Issues & Solutions

### Issue: Build Succeeds but 404 on All Routes

**Solution:**
- Check Root Directory setting
- Verify `app/page.tsx` exists
- Check if build output shows routes being generated

### Issue: Build Fails with Missing Module

**Solution:**
- Make sure `package.json` has all dependencies
- Check if `node_modules` is in `.gitignore` (it should be)
- Vercel will run `npm install` automatically

### Issue: Environment Variables Not Working

**Solution:**
- Make sure variables start with `NEXT_PUBLIC_` for client-side access
- Redeploy after adding variables
- Check variable names match exactly (case-sensitive)

### Issue: TypeScript Errors

**Solution:**
- Fix TypeScript errors locally first
- Run `npm run build` locally to catch errors
- Make sure `tsconfig.json` is correct

---

## Quick Fix Checklist

- [ ] Build logs show no errors
- [ ] Root Directory is set correctly
- [ ] All environment variables are added
- [ ] Environment variables are set for Production
- [ ] `vercel.json` is committed to repo
- [ ] `app/page.tsx` exists
- [ ] `app/layout.tsx` exists
- [ ] `package.json` has all dependencies
- [ ] Local build succeeds (`npm run build`)
- [ ] Redeployed with cleared cache

---

## Still Not Working?

1. **Check Vercel Function Logs:**
   - Go to **Deployments** → Click deployment → **Functions** tab
   - Look for runtime errors

2. **Check Browser Console:**
   - Visit your domain
   - Open browser DevTools (F12)
   - Check Console and Network tabs for errors

3. **Verify Domain Configuration:**
   - Go to **Settings** → **Domains**
   - Make sure domain is properly configured
   - Check DNS propagation

4. **Contact Support:**
   - Vercel has great support
   - Share your deployment URL and build logs

---

## Test Your Deployment

After fixing, test these URLs:
- `https://growyourdigitalleverage.com` - Should show landing page
- `https://growyourdigitalleverage.com/login` - Should show login page
- `https://growyourdigitalleverage.com/pricing` - Should show pricing page

If these work, your deployment is successful! 🎉

