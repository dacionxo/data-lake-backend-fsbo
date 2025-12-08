# Password Security Information

## ✅ Passwords are NOT Logged

**Supabase does NOT log, store, or transmit passwords in plain text.**

### How Supabase Handles Passwords:

1. **Hashing**: Passwords are hashed using bcrypt before being stored
2. **Storage**: Passwords are stored in the `auth.users` table (managed by Supabase Auth)
3. **Encryption**: The password field is encrypted and cannot be read directly
4. **No Plain Text**: Passwords are never stored, logged, or accessible in plain text
5. **API Access**: The password field is not accessible via any API endpoint

### What Gets Stored:

- **In `auth.users` table**: Hashed password (bcrypt hash)
- **In `public.users` table**: NO password field exists
- **In logs**: NO passwords are logged

### Security Features:

- ✅ Passwords are hashed with bcrypt (industry standard)
- ✅ Password field is encrypted at rest
- ✅ No password field in your custom `users` table
- ✅ Passwords cannot be retrieved or viewed
- ✅ Password reset requires email verification

### Verification:

You can verify this by:
1. Checking your `public.users` table - no password column exists
2. Checking Supabase logs - no password values appear
3. Checking your application logs - passwords are never logged

## Conclusion

**Your passwords are secure and are NOT being logged.** Supabase follows industry best practices for password security.

