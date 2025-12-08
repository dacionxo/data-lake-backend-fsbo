# Fix Vercel Routes Manifest Error

## Error Message
```
Error: The file "/vercel/path0/LeadMap-main/lead-map-main/routes-manifest.json" couldn't be found.
```

## Root Cause
This error occurs when Vercel's root directory is misconfigured, causing it to look in the wrong path (`LeadMap-main/lead-map-main` instead of just `LeadMap-main`).

## Solution: Fix Root Directory in Vercel Dashboard

### Step 1: Access Vercel Settings
1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Click on your project: **LeadMap-main**
3. Click **"Settings"** (top menu)
4. Click **"General"** (left sidebar)

### Step 2: Set Root Directory
1. Scroll down to **"Root Directory"** field
2. **Set it to:** `LeadMap-main` (exactly this, no slashes)
3. Click **"Save"**

**Important:**
- ✅ Correct: `LeadMap-main`
- ❌ Wrong: `./LeadMap-main`
- ❌ Wrong: `LeadMap-main/`
- ❌ Wrong: `/LeadMap-main`
- ❌ Wrong: `lead-map-main` (case-sensitive!)
- ❌ Wrong: (empty)

### Step 3: Verify Build Settings
While in Settings → General, verify:
- **Framework Preset**: Next.js
- **Build Command**: `npm run build` (or leave empty for auto)
- **Output Directory**: `.next` (or leave empty for auto)
- **Install Command**: `npm install` (or leave empty for auto)

### Step 4: Redeploy
1. Go to **"Deployments"** tab
2. Click **"..."** (three dots) on the latest deployment
3. Click **"Redeploy"**
4. **UNCHECK** ✅ "Use existing Build Cache"
5. Click **"Redeploy"**

### Step 5: Verify Build
After redeploying, check the build logs:
- ✅ Should see: "Installing dependencies..."
- ✅ Should see: "Running npm run build"
- ✅ Should see: "Build completed successfully"
- ❌ Should NOT see: "routes-manifest.json couldn't be found"

## Alternative: If Root Directory Setting Doesn't Work

If setting the root directory in Vercel doesn't work, you can try updating `vercel.json`:

```json
{
  "buildCommand": "cd LeadMap-main && npm run build",
  "outputDirectory": "LeadMap-main/.next",
  "crons": [
    {
      "path": "/api/calendar/reminders/process",
      "schedule": "*/5 * * * *"
    },
    {
      "path": "/api/calendar/followups/process",
      "schedule": "0 * * * *"
    }
  ]
}
```

**However, the Root Directory setting in Vercel Dashboard is the preferred and more reliable solution.**

## Verification

After fixing, your deployment should:
1. Build successfully without the routes-manifest error
2. Show correct build logs
3. Deploy your application correctly
4. Serve your routes at the correct paths

## Still Having Issues?

If the error persists:
1. **Double-check the Root Directory** - Make sure it's exactly `LeadMap-main` (case-sensitive)
2. **Clear build cache** - Always uncheck "Use existing Build Cache" when redeploying
3. **Check repository structure** - Ensure your GitHub repo has the code in `LeadMap-main/` folder
4. **Contact Vercel support** - If the issue persists, it might be a Vercel platform issue

