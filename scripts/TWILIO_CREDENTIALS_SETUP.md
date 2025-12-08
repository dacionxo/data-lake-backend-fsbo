# Your Twilio Credentials Setup

## Your Twilio Credentials

I've noted your Twilio credentials. Here's what you need to add to your `.env.local` file:

## Step 1: Create/Update .env.local

Create a file named `.env.local` in the `LeadMap-main` directory (if it doesn't exist) and add the following:

```bash
# Supabase (add your existing values)
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Twilio Core (YOUR CREDENTIALS - REPLACE WITH YOUR ACTUAL VALUES)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_auth_token_here
TWILIO_SMS_NUMBER=+1234567890

# Twilio Conversations (GET THESE FROM TWILIO CONSOLE - see steps below)
TWILIO_CONVERSATIONS_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Security (generate random strings)
TWILIO_WEBHOOK_AUTH_TOKEN=generate-random-string-here
CRON_SECRET=generate-another-random-string-here

# App URL
NEXT_PUBLIC_APP_URL=http://localhost:3000
# Or for production:
# NEXT_PUBLIC_APP_URL=https://your-domain.com
```

## Step 2: Get Your Conversations Service SID

1. Go to [Twilio Console](https://console.twilio.com)
2. Navigate to **Messaging** → **Conversations** → **Services**
3. If you don't have a service yet:
   - Click **Create Service** (or **+** button)
   - Name it: `LeadMapProd` (or any name you prefer)
   - Click **Create**
4. Copy the **Service SID** (starts with `IS...`)
5. Replace `TWILIO_CONVERSATIONS_SERVICE_SID` in `.env.local` with this value

## Step 3: Get Your Messaging Service SID

1. In Twilio Console, go to **Messaging** → **Services** → **Messaging Services**
2. If you don't have one yet:
   - Click **Create Messaging Service**
   - Name it: `LeadMapMessaging` (or any name)
   - Click **Create**
3. Add your phone number to the service:
   - Go to **Sender Pool** tab
   - Click **Add Senders**
   - Select **Phone Numbers**
   - Check your number: `+18664127112`
   - Click **Add Senders**
4. Copy the **Service SID** (starts with `MG...`)
5. Replace `TWILIO_MESSAGING_SERVICE_SID` in `.env.local` with this value

## Step 4: Link Messaging Service to Conversations Service

1. Go back to **Messaging** → **Conversations** → **Services**
2. Click on your Conversations Service
3. Go to **Configuration** tab
4. Under **Default Messaging Service**, select your Messaging Service
5. Click **Save**

## Step 5: Generate Security Tokens

Generate two random strings for security:

**Option A: Use PowerShell (Windows)**
```powershell
# Generate TWILIO_WEBHOOK_AUTH_TOKEN
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# Generate CRON_SECRET
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

**Option B: Use Online Generator**
- Go to https://www.random.org/strings/
- Generate two 32-character random strings
- Use one for `TWILIO_WEBHOOK_AUTH_TOKEN`
- Use one for `CRON_SECRET`

**Option C: Use Node.js**
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

## Step 6: Configure Webhook

1. In Twilio Console, go to your Conversations Service
2. Click **Webhooks** tab
3. Click **Add Webhook**
4. Configure:
   - **Event Type**: Select:
     - ✅ `onMessageAdded`
     - ✅ `onDeliveryUpdated`
     - ✅ `onConversationAdded`
   - **URL**: 
     - For local: `http://localhost:3000/api/twilio/conversations/webhook` (use ngrok for testing)
     - For production: `https://your-domain.com/api/twilio/conversations/webhook`
   - **Method**: `POST`
5. Click **Save**

## Step 7: Verify .env.local

Your final `.env.local` should look like this (with your actual values):

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJxxxxx
SUPABASE_SERVICE_ROLE_KEY=eyJxxxxx

# Twilio (REPLACE WITH YOUR ACTUAL VALUES)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_auth_token_here
TWILIO_CONVERSATIONS_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_SMS_NUMBER=+18664127112

# Security
TWILIO_WEBHOOK_AUTH_TOKEN=your-generated-random-string-32-chars
CRON_SECRET=your-generated-random-string-32-chars

# App
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

## Next Steps

Once you've completed the above:

1. ✅ Run the SMS schema in Supabase (see `PHASE_0_SETUP_GUIDE.md` Step 1)
2. ✅ Set up the cron job (see `PHASE_0_SETUP_GUIDE.md` Step 7)
3. ✅ Test sending/receiving SMS (see `PHASE_0_SETUP_GUIDE.md` Step 8)

## Security Reminder

⚠️ **IMPORTANT**: 
- Never commit `.env.local` to git (it's already in `.gitignore`)
- Never share your Auth Token publicly
- Keep your credentials secure
- In production, consider using environment variable management (Vercel, AWS Secrets Manager, etc.)

## Quick Reference

- **Account SID**: `ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` (replace with your actual SID) ✅
- **Auth Token**: `d1870edada7ea381685657506854f95c` ✅
- **Phone Number**: `+18664127112` ✅
- **Conversations Service SID**: Get from Twilio Console ⏳
- **Messaging Service SID**: Get from Twilio Console ⏳


