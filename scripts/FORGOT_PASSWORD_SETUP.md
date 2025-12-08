# Forgot Password Setup Guide

This guide will help you set up the secure forgot password system for your NextDeal application.

## ✅ Features Implemented

- **Zero user enumeration** - Never reveals if an email exists
- **Token hashing** - Reset tokens are hashed before storage (bcrypt)
- **Token expiration** - Tokens expire after 15 minutes
- **One-time use** - Tokens are deleted after successful reset
- **Strong password hashing** - Passwords are hashed with bcrypt
- **Clean UX** - Professional UI matching your existing design
- **Email support** - Works with Resend, SendGrid, Mailgun, or generic email APIs

## 📋 Setup Steps

### 1. Install Dependencies

```bash
npm install bcryptjs @types/bcryptjs
```

### 2. Run Database Migration

Execute the SQL migration file to create the `password_reset_tokens` table:

1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy and paste the contents of `supabase/password_reset_tokens.sql`
5. Click **Run** (or press Ctrl+Enter)
6. Wait for "Success" message

The migration creates:
- `password_reset_tokens` table with proper indexes
- RLS policies for security
- Cleanup function for expired tokens

### 3. Configure Email Service

Add one of the following to your `.env.local` file:

#### Option 1: Resend (Recommended)
```env
RESEND_API_KEY=re_xxxxxxxxxxxxx
RESEND_FROM_EMAIL=NextDeal <noreply@nextdeal.com>
```

#### Option 2: SendGrid
```env
SENDGRID_API_KEY=SG.xxxxxxxxxxxxx
SENDGRID_FROM_EMAIL=noreply@nextdeal.com
```

#### Option 3: Mailgun
```env
MAILGUN_API_KEY=xxxxxxxxxxxxx
MAILGUN_DOMAIN=mg.nextdeal.com
```

#### Option 4: Generic Email API
```env
EMAIL_SERVICE_URL=https://api.example.com/send
EMAIL_SERVICE_API_KEY=xxxxxxxxxxxxx
EMAIL_FROM=noreply@nextdeal.com
```

### 4. Set App URL

Add to your `.env.local`:

```env
NEXT_PUBLIC_APP_URL=http://localhost:3000
# Or for production:
# NEXT_PUBLIC_APP_URL=https://yourdomain.com
```

### 5. Verify Environment Variables

Make sure these are set in your `.env.local`:

```env
# Required
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Email (at least one required)
RESEND_API_KEY=your_resend_key
# OR
SENDGRID_API_KEY=your_sendgrid_key
# OR
MAILGUN_API_KEY=your_mailgun_key
# OR
EMAIL_SERVICE_URL=your_email_service_url
EMAIL_SERVICE_API_KEY=your_email_service_key
```

## 🚀 How It Works

### Forgot Password Flow

1. User clicks "Forgot password?" on login page
2. User enters email address
3. System checks if email exists (without revealing result)
4. If exists:
   - Deletes old tokens for the user
   - Generates secure random token (32 bytes)
   - Hashes token with bcrypt (12 rounds)
   - Stores hashed token + expiration (15 minutes)
   - Sends email with reset link
5. User receives email with reset link
6. User clicks link → redirected to `/reset-password?token=...`

### Reset Password Flow

1. User lands on reset password page with token
2. User enters new password (twice for confirmation)
3. System:
   - Validates token (compares hash)
   - Checks expiration
   - Updates password via Supabase Admin API
   - Deletes used token
4. User is redirected to login page with success message

## 🔒 Security Features

### Token Hashing
- Tokens are hashed with bcrypt (12 rounds) before storage
- Even if database is compromised, tokens cannot be used
- Industry-standard security practice

### No User Enumeration
- Always returns the same message regardless of email existence
- Prevents attackers from discovering valid email addresses

### Token Expiration
- Tokens expire after 15 minutes
- Expired tokens are automatically rejected

### One-Time Use
- Tokens are deleted immediately after successful password reset
- Prevents token reuse attacks

### Password Validation
- Minimum 6 characters (Supabase requirement)
- Password confirmation required
- Strong password hashing via Supabase

## 📁 Files Created

- `supabase/password_reset_tokens.sql` - Database migration
- `lib/sendEmail.ts` - Email sending utility
- `app/api/auth/forgot-password/route.ts` - Forgot password API endpoint
- `app/api/auth/reset-password/route.ts` - Reset password API endpoint
- `app/forgot-password/page.tsx` - Forgot password UI page
- `app/reset-password/page.tsx` - Reset password UI page

## 🧪 Testing

### Test Forgot Password

1. Go to `/login`
2. Click "Forgot password?"
3. Enter a valid email address
4. Check email inbox for reset link
5. Click reset link
6. Enter new password
7. Log in with new password

### Test Security

1. Try with non-existent email - should get same message
2. Try expired token - should be rejected
3. Try using same token twice - should fail (one-time use)

## 🐛 Troubleshooting

### "Server configuration error"
- Check that `SUPABASE_SERVICE_ROLE_KEY` is set correctly
- Verify `NEXT_PUBLIC_SUPABASE_URL` is set

### "No email service configured"
- Add at least one email service API key to `.env.local`
- Restart dev server after adding environment variables

### "Invalid or expired token"
- Token may have expired (15 minutes)
- Token may have already been used (one-time use)
- Request a new password reset

### Email not sending
- Check email service API key is correct
- Check spam folder
- Verify email service is properly configured
- Check server logs for email service errors

### Database errors
- Ensure migration was run successfully
- Check Supabase dashboard for table existence
- Verify RLS policies are set correctly

## 📝 Optional: Cleanup Expired Tokens

You can set up a cron job in Supabase to automatically clean up expired tokens:

1. Go to Supabase Dashboard → Database → Cron Jobs
2. Create new cron job:
   - Name: `cleanup_expired_password_reset_tokens`
   - Schedule: `0 * * * *` (every hour)
   - SQL: `SELECT cleanup_expired_password_reset_tokens();`

This is optional - expired tokens are checked on use anyway.

## ✅ Checklist

- [ ] Installed `bcryptjs` and `@types/bcryptjs`
- [ ] Ran database migration (`password_reset_tokens.sql`)
- [ ] Configured email service (Resend/SendGrid/Mailgun/Generic)
- [ ] Set `NEXT_PUBLIC_APP_URL` in `.env.local`
- [ ] Verified `SUPABASE_SERVICE_ROLE_KEY` is set
- [ ] Tested forgot password flow
- [ ] Tested reset password flow
- [ ] Verified email is received
- [ ] Tested with expired token (should fail)
- [ ] Tested with invalid token (should fail)

## 🎉 You're Done!

The forgot password system is now fully integrated and ready to use. Users can reset their passwords securely through the `/forgot-password` page.

