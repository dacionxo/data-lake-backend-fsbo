# PowerShell script to help set up .env.local
# Run this script to create a template .env.local file

$envFile = ".env.local"
$template = @"
# Supabase (add your existing values)
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Twilio Core (REPLACE WITH YOUR ACTUAL VALUES)
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=your_twilio_auth_token_here
TWILIO_SMS_NUMBER=+1234567890

# Twilio Conversations (GET THESE FROM TWILIO CONSOLE)
TWILIO_CONVERSATIONS_SERVICE_SID=ISxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_MESSAGING_SERVICE_SID=MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Security (randomly generated)
TWILIO_WEBHOOK_AUTH_TOKEN=$(-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_}))
CRON_SECRET=$(-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_}))

# App URL
NEXT_PUBLIC_APP_URL=http://localhost:3000
# For production: NEXT_PUBLIC_APP_URL=https://your-domain.com
"@

if (Test-Path $envFile) {
    Write-Host "⚠️  .env.local already exists!"
    Write-Host "Please update it manually with your Twilio credentials."
    Write-Host "See TWILIO_CREDENTIALS_SETUP.md for instructions."
} else {
    $template | Out-File -FilePath $envFile -Encoding utf8
    Write-Host "✅ Created .env.local file with your Twilio credentials!"
    Write-Host ""
    Write-Host "📝 Next steps:"
    Write-Host "1. Get your Conversations Service SID from Twilio Console"
    Write-Host "2. Get your Messaging Service SID from Twilio Console"
    Write-Host "3. Update .env.local with those values"
    Write-Host "4. Add your Supabase credentials if not already present"
    Write-Host ""
    Write-Host "See TWILIO_CREDENTIALS_SETUP.md for detailed instructions."
}


