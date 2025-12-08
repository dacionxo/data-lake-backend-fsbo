# How to Create a User in Supabase

## User Details
- **Email**: tyquanwilkerson1118345@gmail.com
- **Password**: Flower12!

## Method 1: Supabase Dashboard (Easiest - Recommended)

1. Go to your [Supabase Dashboard](https://app.supabase.com)
2. Select your project
3. Navigate to **Authentication** → **Users** in the left sidebar
4. Click the **"Add user"** button (top right)
5. Select **"Create new user"**
6. Fill in the form:
   - **Email**: `tyquanwilkerson1118345@gmail.com`
   - **Password**: `Flower12!`
   - **Auto Confirm User**: ✅ Enable this (skips email verification)
7. Click **"Create user"**

The user will be created and a profile will automatically be added to the `public.users` table via the `handle_new_user()` trigger.

---

## Method 2: Using Supabase CLI

If you have the Supabase CLI installed:

```bash
# Install Supabase CLI (if not already installed)
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Create user (this will prompt for password)
supabase auth users create tyquanwilkerson1118345@gmail.com --password Flower12! --email-confirm
```

---

## Method 3: Using Management API (Node.js)

1. Install dependencies:
```bash
npm install @supabase/supabase-js
```

2. Create a file with this code (or use `scripts/create_user.js`):

```javascript
const { createClient } = require('@supabase/supabase-js')

const supabaseUrl = 'YOUR_SUPABASE_URL'
const supabaseServiceKey = 'YOUR_SERVICE_ROLE_KEY' // From Dashboard → Settings → API

const supabase = createClient(supabaseUrl, supabaseServiceKey, {
  auth: { autoRefreshToken: false, persistSession: false }
})

async function createUser() {
  const { data, error } = await supabase.auth.admin.createUser({
    email: 'tyquanwilkerson1118345@gmail.com',
    password: 'Flower12!',
    email_confirm: true
  })
  
  if (error) {
    console.error('Error:', error)
  } else {
    console.log('User created:', data.user.id)
  }
}

createUser()
```

3. Run:
```bash
node scripts/create_user.js
```

**To get your credentials:**
- Go to Supabase Dashboard → Settings → API
- Copy your **Project URL** (SUPABASE_URL)
- Copy your **service_role** key (SUPABASE_SERVICE_ROLE_KEY) - ⚠️ Keep this secret!

---

## Method 4: Using Management API (Python)

1. Install dependencies:
```bash
pip install supabase
```

2. Use the provided script:
```bash
export SUPABASE_URL="your-project-url"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
python scripts/create_user.py
```

---

## Method 5: Direct SQL (Not Recommended)

⚠️ **Warning**: This method requires superuser access and bypasses Supabase Auth security. Only use in development.

Direct SQL insertion into `auth.users` is complex and not recommended. Use one of the methods above instead.

---

## After Creating the User

Once the user is created:

1. **Automatic Profile Creation**: The `handle_new_user()` trigger will automatically create a record in the `public.users` table
2. **User can log in**: The user can immediately log in with their email and password
3. **User-specific data**: All user-specific tables (imports, trash, tasks, contacts, deals, lists) will be accessible to this user via RLS policies

---

## Verify User Creation

To verify the user was created:

1. **In Dashboard**: Check Authentication → Users
2. **In SQL Editor**: Run:
```sql
SELECT id, email, created_at 
FROM auth.users 
WHERE email = 'tyquanwilkerson1118345@gmail.com';

SELECT id, email, name, role 
FROM public.users 
WHERE email = 'tyquanwilkerson1118345@gmail.com';
```

---

## Troubleshooting

- **"User already exists"**: The email is already registered. Use a different email or reset the password.
- **"Invalid password"**: Ensure password meets requirements (usually min 6 characters).
- **"Permission denied"**: You need admin/service role access to create users programmatically.

