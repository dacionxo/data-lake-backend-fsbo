# Deploy LeadMap to GitHub Repository

## Current Status

✅ **Git Repository**: Initialized and ready  
✅ **All Files**: Committed to local repository  
✅ **Remote**: Configured to `https://github.com/dacionxo/LeadMap-main.git`

---

## Step 1: Create GitHub Repository (If Not Exists)

### Option A: Create via GitHub Website

1. Go to [github.com](https://github.com) and sign in
2. Click the **"+"** icon in the top right → **"New repository"**
3. Repository settings:
   - **Name**: `LeadMap-main` (or your preferred name)
   - **Description**: "Real Estate Lead Generation Platform - Next.js SaaS Application"
   - **Visibility**: 
     - ✅ **Public** (if you want it visible)
     - ✅ **Private** (if you want it private)
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
4. Click **"Create repository"**

### Option B: Use GitHub CLI (If Installed)

```bash
gh repo create LeadMap-main --public --description "Real Estate Lead Generation Platform"
```

---

## Step 2: Push Code to GitHub

### If Repository Already Exists

Run these commands in your terminal:

```powershell
cd D:\Downloads\LeadMap-main\LeadMap-main

# Verify remote is set
git remote -v

# If remote is wrong, update it:
# git remote set-url origin https://github.com/YOUR_USERNAME/LeadMap-main.git

# Push all code to GitHub
git push -u origin main
```

### If Repository Doesn't Exist Yet

After creating the repository on GitHub, run:

```powershell
cd D:\Downloads\LeadMap-main\LeadMap-main

# Update remote URL (replace YOUR_USERNAME with your GitHub username)
git remote set-url origin https://github.com/YOUR_USERNAME/LeadMap-main.git

# Push all code
git push -u origin main
```

---

## Step 3: Verify Deployment

After pushing, verify:

1. **Check GitHub Repository**:
   - Go to `https://github.com/YOUR_USERNAME/LeadMap-main`
   - Verify all files are present
   - Check that `vercel.json`, `package.json`, `app/` folder are visible

2. **Verify Important Files**:
   - ✅ `package.json` - Dependencies and scripts
   - ✅ `next.config.js` - Next.js configuration
   - ✅ `vercel.json` - Vercel deployment config
   - ✅ `app/` - Next.js app directory
   - ✅ `.gitignore` - Excludes sensitive files

---

## Step 4: Connect to Vercel (If Not Already Done)

1. Go to [vercel.com](https://vercel.com)
2. Click **"Add New..."** → **"Project"**
3. Import your GitHub repository: `LeadMap-main`
4. Configure:
   - **Framework Preset**: Next.js (auto-detected)
   - **Root Directory**: Leave empty (or set to `./` if code is at root)
   - **Build Command**: `npm run build` (auto)
   - **Output Directory**: `.next` (auto)
5. Add environment variables (see below)
6. Click **"Deploy"**

---

## Environment Variables for Vercel

After connecting to Vercel, add these in **Settings** → **Environment Variables**:

### Required (Minimum):
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
NEXT_PUBLIC_APP_URL=https://growyourdigitalleverage.com
```

### Recommended (Full Functionality):
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

---

## Files Included in Repository

✅ **Included**:
- All source code (`app/`, `components/`, `lib/`, etc.)
- Configuration files (`package.json`, `next.config.js`, `tsconfig.json`)
- Documentation files (`.md` files)
- Database schemas (`supabase/` folder)
- Public assets (`public/` folder)

❌ **Excluded** (via `.gitignore`):
- `node_modules/` - Dependencies (installed via `npm install`)
- `.env.local` - Environment variables (add in Vercel)
- `.next/` - Build output (generated during build)
- `.vercel/` - Vercel deployment cache

---

## Quick Commands Reference

```powershell
# Navigate to project
cd D:\Downloads\LeadMap-main\LeadMap-main

# Check status
git status

# Add all changes
git add -A

# Commit changes
git commit -m "Your commit message"

# Push to GitHub
git push origin main

# Check remote
git remote -v

# Update remote URL
git remote set-url origin https://github.com/YOUR_USERNAME/REPO_NAME.git
```

---

## Troubleshooting

### Error: "Repository not found"

**Solution:**
- Verify the repository exists on GitHub
- Check your GitHub username is correct
- Make sure you have access to the repository
- Try creating a new repository on GitHub first

### Error: "Authentication failed"

**Solution:**
- Use GitHub Personal Access Token instead of password
- Or use SSH keys for authentication
- Or use GitHub CLI: `gh auth login`

### Error: "Permission denied"

**Solution:**
- Make sure you own the repository or have write access
- Check if repository is private and you're authenticated

### Files Not Showing on GitHub

**Solution:**
- Make sure files are committed: `git status`
- Make sure files are pushed: `git push origin main`
- Check `.gitignore` isn't excluding them

---

## Next Steps After GitHub Deployment

1. ✅ Code is on GitHub
2. ✅ Connect to Vercel (if not already done)
3. ✅ Add environment variables in Vercel
4. ✅ Deploy to production
5. ✅ Connect custom domain

---

## Repository Structure

Your GitHub repository will have this structure:

```
LeadMap-main/
├── app/                    # Next.js App Router
│   ├── api/               # API routes
│   ├── dashboard/         # Dashboard pages
│   ├── page.tsx          # Home page
│   └── layout.tsx        # Root layout
├── components/            # React components
├── lib/                   # Utilities
├── public/                # Static assets
├── supabase/              # Database schemas
├── package.json           # Dependencies
├── next.config.js         # Next.js config
├── vercel.json            # Vercel config
├── .gitignore            # Git ignore rules
└── README.md             # Project documentation
```

---

## Success Checklist

- [ ] GitHub repository created
- [ ] All code pushed to GitHub
- [ ] Files visible on GitHub
- [ ] Repository connected to Vercel
- [ ] Environment variables added in Vercel
- [ ] Deployment successful
- [ ] Custom domain connected

---

Your LeadMap project is now on GitHub and ready for deployment! 🚀

