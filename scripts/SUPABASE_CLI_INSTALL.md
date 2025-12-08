# Installing Supabase CLI on Windows

## Method 1: Using Scoop (Recommended)

### Step 1: Install Scoop
Open PowerShell and run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

### Step 2: Install Supabase CLI
```powershell
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
```

### Step 3: Verify Installation
```powershell
supabase --version
```

---

## Method 2: Using Chocolatey

If you have Chocolatey installed:
```powershell
choco install supabase
```

---

## Method 3: Manual Installation (Direct Download)

1. Go to: https://github.com/supabase/cli/releases/latest
2. Download: `supabase_windows_amd64.zip` (or appropriate version for your system)
3. Extract the zip file
4. Add the extracted folder to your PATH environment variable
5. Restart your terminal

---

## Method 4: Using npx (No Installation Required)

You can use Supabase CLI without installing it globally:
```powershell
npx supabase --version
npx supabase db execute -f supabase/migrations/calendar_time_handling.sql
```

Note: This downloads the CLI each time, but works without installation.

---

## After Installation: Link Your Project

Once Supabase CLI is installed, link to your project:

```powershell
cd d:\Downloads\LeadMap-main\LeadMap-main
supabase link --project-ref bqkucdaefpfkunceftye
```

You'll need your Supabase access token. Get it from:
https://supabase.com/dashboard/account/tokens

---

## Run the Migration

After linking, run the migration:

```powershell
supabase db execute -f supabase/migrations/calendar_time_handling.sql
```

Or use the Supabase Dashboard (no CLI needed):
1. Go to https://supabase.com/dashboard
2. Select your project
3. SQL Editor → New Query
4. Copy/paste the migration SQL
5. Run

