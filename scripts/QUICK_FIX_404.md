# Quick Fix for 404 Error on Vercel

## Immediate Steps to Fix

### 1. Check Your Vercel Project Settings

Go to your Vercel dashboard → Your Project → **Settings** → **General**

**Critical Settings:**
- **Root Directory**: 
  - If your code is in `LeadMap-main/` folder → Set to `LeadMap-main`
  - If code is at root → Leave **EMPTY** (don't set to `./`)
  
- **Framework Preset**: Should be **Next.js**

- **Build Command**: Leave empty (auto) OR set to `npm run build`

- **Output Directory**: Leave empty (auto) OR set to `.next`

- **Install Command**: Leave empty (auto) OR set to `npm install`

---

### 2. Verify Environment Variables

Go to **Settings** → **Environment Variables**

**Minimum Required (App won't work without these):**
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
NEXT_PUBLIC_APP_URL=https://growyourdigitalleverage.com
```

**Important:**
- Make sure each variable is set for **Production**, **Preview**, AND **Development**
- After adding variables, you MUST redeploy

---

### 3. Check Build Logs

1. Go to **Deployments** tab
2. Click on the latest deployment
3. Click **"Build Logs"** tab
4. Look for errors

**Common Errors:**
- `Error: Cannot find module` → Missing dependency
- `Error: Environment variable not found` → Missing env var
- `Type error` → TypeScript error
- `Build failed` → Check the specific error message

---

### 4. Force Redeploy with Cleared Cache

1. Go to **Deployments** tab
2. Click **"..."** on latest deployment
3. Click **"Redeploy"**
4. **UNCHECK** "Use existing Build Cache"
5. Click **"Redeploy"**

---

### 5. Test Build Locally First

Before deploying, test if build works:

```powershell
cd LeadMap-main
npm install
npm run build
```

If this fails locally, fix those errors first.

---

## Most Common Causes of 404

### Cause 1: Wrong Root Directory
**Fix:** Check Root Directory in Vercel settings

### Cause 2: Build Failed Silently
**Fix:** Check build logs for errors

### Cause 3: Missing Environment Variables
**Fix:** Add all required env vars and redeploy

### Cause 4: TypeScript/Build Errors
**Fix:** Fix errors locally, then redeploy

---

## Quick Checklist

Run through this checklist:

- [ ] Root Directory is set correctly (or empty if code is at root)
- [ ] All environment variables are added
- [ ] Environment variables are set for Production environment
- [ ] Build logs show no errors
- [ ] Local build succeeds (`npm run build`)
- [ ] Redeployed with cleared cache
- [ ] `vercel.json` file exists (I created this for you)

---

## Still Getting 404?

1. **Share your build logs** - Copy the full build log output
2. **Check the Functions tab** - Go to Deployment → Functions tab
3. **Test a specific route** - Try `https://growyourdigitalleverage.com/login`

---

## Need More Help?

If you're still stuck, please share:
1. Screenshot of your Vercel project settings (Root Directory)
2. Build logs from the latest deployment
3. Any error messages you see

