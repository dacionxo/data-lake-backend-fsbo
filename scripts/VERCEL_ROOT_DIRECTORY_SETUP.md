# Vercel Root Directory Setup - Nested Folder Structure

## Your Repository Structure

Your GitHub repository has this structure:

```
LeadMap-main/                    ← GitHub repo root
└── LeadMap-main/                ← Your actual project (subfolder)
    ├── package.json             ← Here!
    ├── app/                      ← Here!
    ├── next.config.js
    ├── vercel.json
    └── ...
```

## Solution: Set Root Directory in Vercel

### Step 1: Go to Vercel Settings

1. Go to: https://vercel.com/dashboard
2. Click on your project: **LeadMap-main**
3. Click **"Settings"** (top menu)
4. Click **"General"** (left sidebar)

### Step 2: Set Root Directory

1. Scroll down to find **"Root Directory"** field
2. **Set it to:** `LeadMap-main` (exactly this, no slashes, no dots)
3. Click **"Save"**

**Important:**
- ✅ Correct: `LeadMap-main`
- ❌ Wrong: `./LeadMap-main`
- ❌ Wrong: `LeadMap-main/`
- ❌ Wrong: `/LeadMap-main`
- ❌ Wrong: (empty)

### Step 3: Verify Other Settings

While you're in Settings → General, also verify:

- **Framework Preset**: Should be **Next.js**
- **Build Command**: `npm run build` (or leave empty for auto)
- **Output Directory**: `.next` (or leave empty for auto)
- **Install Command**: `npm install` (or leave empty for auto)

### Step 4: Redeploy

1. Go to **"Deployments"** tab
2. Click **"..."** (three dots) on the latest deployment
3. Click **"Redeploy"**
4. **UNCHECK** ✅ "Use existing Build Cache"
5. Click **"Redeploy"**

### Step 5: Check Build Logs

After redeploying, your build log should show:

✅ "Installing dependencies..." (takes 30-60 seconds)
✅ "Running npm run build"
✅ Next.js compilation output
✅ Build time: 30-60 seconds (NOT 159ms!)

---

## Expected Build Log (After Fix)

```
Cloning github.com/dacionxo/LeadMap-main...
Cloning completed: 265ms

Installing dependencies...
npm install
[Lots of npm output - 30+ seconds]
Dependencies installed

Running "npm run build"
> leadmap@0.1.0 build
> next build

[Next.js build output]
✓ Compiled successfully
✓ Linting and checking validity of types
✓ Collecting page data
✓ Generating static pages

Build Completed in /vercel/output [45.2s]

Deploying outputs...
Deployment completed
```

---

## Visual Guide

In Vercel Dashboard:

```
Settings → General
├── Project Name: LeadMap-main
├── Framework Preset: Next.js
├── Root Directory: LeadMap-main    ← SET THIS!
├── Build Command: npm run build
├── Output Directory: .next
└── Install Command: npm install
```

---

## Troubleshooting

### If Build Still Completes in 159ms

1. **Double-check Root Directory:**
   - Go back to Settings → General
   - Make sure it says exactly: `LeadMap-main`
   - No leading/trailing slashes
   - No dots

2. **Verify in GitHub:**
   - Go to: https://github.com/dacionxo/LeadMap-main
   - Click into the `LeadMap-main/` folder
   - Verify you can see `package.json` and `app/` folder

3. **Try Alternative:**
   - If `LeadMap-main` doesn't work, try: `./LeadMap-main`
   - But `LeadMap-main` should work

### If You Get "Cannot find package.json"

- Make sure Root Directory is set to `LeadMap-main` (not empty)
- Verify the folder name matches exactly (case-sensitive)

---

## Quick Checklist

- [ ] Root Directory set to: `LeadMap-main`
- [ ] Framework Preset: Next.js
- [ ] Redeployed with cleared cache
- [ ] Build log shows proper build process (30+ seconds)
- [ ] Build log shows "Installing dependencies"
- [ ] Build log shows "Running npm run build"

---

## After Fixing

Once Root Directory is set correctly:
- ✅ Build will take 30-60 seconds (not 159ms)
- ✅ You'll see npm install output
- ✅ You'll see Next.js compilation
- ✅ Your site will work at `growyourdigitalleverage.com`

---

**The key is setting Root Directory to `LeadMap-main` (the subfolder where your package.json is located)!**


