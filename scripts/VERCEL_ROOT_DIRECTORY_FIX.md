# Fix 404 Error - Root Directory Issue

## 🎯 Most Likely Cause: Root Directory Setting

The 404 error is **almost always** caused by Vercel looking in the wrong directory.

---

## Step 1: Check Your GitHub Repository Structure

Your code is in: `LeadMap-main/` folder in the GitHub repo.

**Check this:**
1. Go to: https://github.com/dacionxo/LeadMap-main
2. Look at the file structure
3. Is `package.json` at the root? Or in a subfolder?

---

## Step 2: Fix Root Directory in Vercel

### Option A: If `package.json` is at GitHub repo root

1. Go to Vercel Dashboard → Your Project
2. Click **Settings** → **General**
3. Find **Root Directory**
4. Set it to: **EMPTY** (leave blank) or `./`
5. Click **Save**
6. Go to **Deployments** → Click **"..."** → **Redeploy**
7. **UNCHECK** "Use existing Build Cache"
8. Click **Redeploy**

### Option B: If `package.json` is in `LeadMap-main/` subfolder

1. Go to Vercel Dashboard → Your Project
2. Click **Settings** → **General**
3. Find **Root Directory**
4. Set it to: `LeadMap-main` (without leading slash)
5. Click **Save**
6. Go to **Deployments** → Click **"..."** → **Redeploy**
7. **UNCHECK** "Use existing Build Cache"
8. Click **Redeploy**

---

## Step 3: Verify Build Logs

After redeploying:

1. Go to **Deployments** tab
2. Click on the latest deployment
3. Check **Build Logs**
4. Look for:
   - ✅ "Build completed successfully"
   - ✅ "Compiled successfully"
   - ❌ Any errors (TypeScript, missing modules, etc.)

---

## Step 4: Check Environment Variables

Make sure these are set in Vercel:

1. Go to **Settings** → **Environment Variables**
2. Verify these exist:
   ```
   NEXT_PUBLIC_SUPABASE_URL
   NEXT_PUBLIC_SUPABASE_ANON_KEY
   SUPABASE_SERVICE_ROLE_KEY
   NEXT_PUBLIC_APP_URL
   ```
3. Make sure they're set for **Production**, **Preview**, AND **Development**

---

## Step 5: Test the Deployment

After fixing Root Directory and redeploying:

1. Wait for deployment to complete (2-5 minutes)
2. Visit: `https://growyourdigitalleverage.com`
3. Should see your landing page (not 404)

---

## Quick Diagnostic Commands

Run these locally to verify structure:

```powershell
cd D:\Downloads\LeadMap-main\LeadMap-main

# Check if package.json exists
Test-Path package.json

# Check if app folder exists
Test-Path app

# Check if main page exists
Test-Path app\page.tsx

# Try building locally
npm run build
```

If local build works, the issue is definitely the Root Directory setting in Vercel.

---

## Common Mistakes

❌ **Wrong:**
- Root Directory: `./LeadMap-main/` (with trailing slash)
- Root Directory: `/LeadMap-main` (with leading slash)
- Root Directory: `LeadMap-main/` (with trailing slash)

✅ **Correct:**
- Root Directory: `LeadMap-main` (no slashes)
- Root Directory: `` (empty, if code is at repo root)

---

## Still Getting 404?

1. **Share a screenshot** of your Vercel Settings → General page (showing Root Directory)
2. **Copy the build logs** from the latest deployment
3. **Check the Functions tab** in the deployment for runtime errors

---

## Alternative: Update vercel.json

If Root Directory setting doesn't work, we can try updating `vercel.json`:

```json
{
  "buildCommand": "cd LeadMap-main && npm run build",
  "outputDirectory": "LeadMap-main/.next"
}
```

But **first try the Root Directory setting** - it's the proper way to fix this.


