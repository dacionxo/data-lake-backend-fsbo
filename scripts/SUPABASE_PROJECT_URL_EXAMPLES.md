# Supabase Project URL Examples

This guide shows you exactly what your Supabase project URL looks like and where to find it.

## 📍 What a Supabase Project URL Looks Like

### Format
```
https://YOUR_PROJECT_REF.supabase.co
```

### Real Examples

**Example 1:**
```
https://abcdefghijklmnop.supabase.co
```
- Project Reference: `abcdefghijklmnop`
- OAuth Callback URL: `https://abcdefghijklmnop.supabase.co/auth/v1/callback`

**Example 2:**
```
https://bqkucdaefpfkunceftye.supabase.co
```
- Project Reference: `bqkucdaefpfkunceftye`
- OAuth Callback URL: `https://bqkucdaefpfkunceftye.supabase.co/auth/v1/callback`

**Example 3:**
```
https://xyz123abc456def789.supabase.co
```
- Project Reference: `xyz123abc456def789`
- OAuth Callback URL: `https://xyz123abc456def789.supabase.co/auth/v1/callback`

## 🔍 How to Find Your Project URL

### Method 1: Supabase Dashboard (Easiest)

1. **Go to Supabase Dashboard**
   - Visit [app.supabase.com](https://app.supabase.com)
   - Sign in to your account

2. **Select Your Project**
   - Click on your project from the project list

3. **Go to Settings**
   - Click **Settings** in the left sidebar
   - Click **API** under Project Settings

4. **Find Your Project URL**
   - Look for **Project URL** or **API URL**
   - It will look like: `https://YOUR_PROJECT_REF.supabase.co`
   - Copy this entire URL

### Method 2: From Your Environment Variables

If you already have your project set up, check your `.env.local` file:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
```

The value after `=` is your project URL.

### Method 3: From Your Supabase Dashboard URL

When you're viewing your project in the Supabase Dashboard, look at the browser URL:

```
https://app.supabase.com/project/YOUR_PROJECT_REF
```

The `YOUR_PROJECT_REF` part is your project reference, so your project URL would be:
```
https://YOUR_PROJECT_REF.supabase.co
```

## 🎯 Important URLs for OAuth Setup

Once you have your project URL, here are the URLs you'll need:

### 1. OAuth Callback URL (for Google & Microsoft)
```
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

**Example:**
```
https://abcdefghijklmnop.supabase.co/auth/v1/callback
```

### 2. API URL (for API calls)
```
https://YOUR_PROJECT_REF.supabase.co
```

**Example:**
```
https://abcdefghijklmnop.supabase.co
```

### 3. Database Connection URL (for direct database access)
```
postgresql://postgres:[PASSWORD]@db.YOUR_PROJECT_REF.supabase.co:5432/postgres
```

**Example:**
```
postgresql://postgres:mypassword@db.abcdefghijklmnop.supabase.co:5432/postgres
```

## 📝 Quick Reference

### Your Project Reference
- **What it is**: A unique identifier for your Supabase project
- **Format**: Usually 20-30 characters (letters and numbers)
- **Example**: `abcdefghijklmnop`, `bqkucdaefpfkunceftye`, `xyz123abc456def789`

### Your Project URL
- **Format**: `https://YOUR_PROJECT_REF.supabase.co`
- **Example**: `https://abcdefghijklmnop.supabase.co`

### OAuth Redirect URI
- **Format**: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
- **Example**: `https://abcdefghijklmnop.supabase.co/auth/v1/callback`
- **Used in**: Google Cloud Console and Azure Portal

## ✅ Checklist

When setting up OAuth, make sure you have:

- [ ] Your Supabase Project URL: `https://YOUR_PROJECT_REF.supabase.co`
- [ ] Your Project Reference: `YOUR_PROJECT_REF` (the part before `.supabase.co`)
- [ ] OAuth Callback URL: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`

## 🚨 Common Mistakes to Avoid

1. **Don't include `/api` or `/v1` in the base URL**
   - ❌ Wrong: `https://YOUR_PROJECT_REF.supabase.co/api`
   - ✅ Correct: `https://YOUR_PROJECT_REF.supabase.co`

2. **Don't forget `https://`**
   - ❌ Wrong: `YOUR_PROJECT_REF.supabase.co`
   - ✅ Correct: `https://YOUR_PROJECT_REF.supabase.co`

3. **Don't add a trailing slash**
   - ❌ Wrong: `https://YOUR_PROJECT_REF.supabase.co/`
   - ✅ Correct: `https://YOUR_PROJECT_REF.supabase.co`

4. **OAuth callback must be exact**
   - ❌ Wrong: `https://YOUR_PROJECT_REF.supabase.co/auth/callback`
   - ✅ Correct: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`

## 📸 Visual Guide

### In Supabase Dashboard (Settings > API):

```
┌─────────────────────────────────────────────────┐
│ Project Settings > API                          │
├─────────────────────────────────────────────────┤
│                                                 │
│ Project URL                                     │
│ https://abcdefghijklmnop.supabase.co           │
│                                                 │
│ Project Reference                              │
│ abcdefghijklmnop                                │
│                                                 │
│ anon public                                    │
│ eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...       │
│                                                 │
│ service_role                                    │
│ eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...       │
│                                                 │
└─────────────────────────────────────────────────┘
```

### In Google Cloud Console (OAuth Credentials):

```
┌─────────────────────────────────────────────────┐
│ OAuth 2.0 Client IDs                             │
├─────────────────────────────────────────────────┤
│                                                 │
│ Authorized redirect URIs:                       │
│                                                 │
│ https://abcdefghijklmnop.supabase.co/auth/v1/callback
│                                                 │
└─────────────────────────────────────────────────┘
```

### In Azure Portal (App Registration):

```
┌─────────────────────────────────────────────────┐
│ Redirect URIs                                    │
├─────────────────────────────────────────────────┤
│                                                 │
│ Platform: Web                                   │
│ URI: https://abcdefghijklmnop.supabase.co/auth/v1/callback
│                                                 │
└─────────────────────────────────────────────────┘
```

## 💡 Pro Tip

**Save your project reference** in a safe place! You'll need it for:
- OAuth setup (Google & Microsoft)
- Database connections
- API configurations
- Environment variables

You can find it anytime in: **Supabase Dashboard > Settings > API > Project Reference**

