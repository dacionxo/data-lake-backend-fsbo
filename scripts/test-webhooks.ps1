# Email Webhook Testing Script (PowerShell)
# This script tests all webhook event types

# Configuration - UPDATE THESE VALUES
$APP_URL = if ($env:APP_URL) { $env:APP_URL } else { "http://localhost:3000" }
$WEBHOOK_SECRET = if ($env:EMAIL_WEBHOOK_SECRET) { $env:EMAIL_WEBHOOK_SECRET } else { "" }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Email Webhook Testing Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "App URL: $APP_URL" -ForegroundColor Yellow
Write-Host "Webhook Secret: $(if ($WEBHOOK_SECRET) { 'Set' } else { 'Not set' })" -ForegroundColor Yellow
Write-Host ""

# Check if email ID is provided
if (-not $env:EMAIL_ID) {
    Write-Host "⚠️  EMAIL_ID not set." -ForegroundColor Yellow
    Write-Host "Please provide an email ID from your emails table."
    Write-Host ""
    Write-Host "To get an email ID, run this in Supabase SQL Editor:"
    Write-Host "  SELECT id, to_email, created_at FROM emails ORDER BY created_at DESC LIMIT 1;" -ForegroundColor Gray
    Write-Host ""
    $EMAIL_ID = Read-Host "Enter email ID (or press Enter to skip)"
    if (-not $EMAIL_ID) {
        Write-Host "❌ Email ID required. Exiting." -ForegroundColor Red
        exit 1
    }
} else {
    $EMAIL_ID = $env:EMAIL_ID
}

$RECIPIENT_EMAIL = if ($env:RECIPIENT_EMAIL) { $env:RECIPIENT_EMAIL } else { "test@example.com" }
Write-Host "Using Email ID: $EMAIL_ID" -ForegroundColor Green
Write-Host "Using Recipient Email: $RECIPIENT_EMAIL" -ForegroundColor Green
Write-Host ""

# Function to test webhook
function Test-Webhook {
    param(
        [string]$EventType,
        [string]$Payload,
        [string]$Description
    )
    
    Write-Host "Testing: $Description" -ForegroundColor Yellow
    
    $headers = @{
        "Content-Type" = "application/json"
        "x-provider" = "generic"
    }
    
    if ($WEBHOOK_SECRET) {
        $headers["x-webhook-secret"] = $WEBHOOK_SECRET
    }
    
    try {
        $response = Invoke-RestMethod -Uri "$APP_URL/api/webhooks/email/providers" `
            -Method Post `
            -Headers $headers `
            -Body $Payload `
            -ErrorAction Stop
        
        Write-Host "✅ Success" -ForegroundColor Green
        Write-Host "Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Gray
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "❌ Failed (HTTP $statusCode)" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# Test 1: Delivered Event
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test 1: Delivered Event" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
$deliveredPayload = @{
    eventType = "delivered"
    emailId = $EMAIL_ID
    recipientEmail = $RECIPIENT_EMAIL
    providerMessageId = "test-delivered-$(Get-Date -Format 'yyyyMMddHHmmss')"
} | ConvertTo-Json -Compress
Test-Webhook -EventType "delivered" -Payload $deliveredPayload -Description "Delivered Event"

Start-Sleep -Seconds 1

# Test 2: Bounced Event (Hard)
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test 2: Bounced Event (Hard Bounce)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
$bouncedPayload = @{
    eventType = "bounced"
    emailId = $EMAIL_ID
    recipientEmail = $RECIPIENT_EMAIL
    providerMessageId = "test-bounced-$(Get-Date -Format 'yyyyMMddHHmmss')"
    bounceType = "hard"
    bounceReason = "550 Mailbox not found"
} | ConvertTo-Json -Compress
Test-Webhook -EventType "bounced" -Payload $bouncedPayload -Description "Hard Bounce Event"

Start-Sleep -Seconds 1

# Test 3: Bounced Event (Soft)
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test 3: Bounced Event (Soft Bounce)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
$softBouncePayload = @{
    eventType = "bounced"
    emailId = $EMAIL_ID
    recipientEmail = $RECIPIENT_EMAIL
    providerMessageId = "test-soft-bounce-$(Get-Date -Format 'yyyyMMddHHmmss')"
    bounceType = "soft"
    bounceReason = "Mailbox temporarily unavailable"
} | ConvertTo-Json -Compress
Test-Webhook -EventType "bounced" -Payload $softBouncePayload -Description "Soft Bounce Event"

Start-Sleep -Seconds 1

# Test 4: Complaint Event
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Test 4: Complaint Event (Spam)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
$complaintPayload = @{
    eventType = "complaint"
    emailId = $EMAIL_ID
    recipientEmail = $RECIPIENT_EMAIL
    providerMessageId = "test-complaint-$(Get-Date -Format 'yyyyMMddHHmmss')"
    complaintType = "spam"
} | ConvertTo-Json -Compress
Test-Webhook -EventType "complaint" -Payload $complaintPayload -Description "Complaint Event"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Testing Complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Check the email_events table in Supabase:"
Write-Host "   SELECT * FROM email_events WHERE email_id = '$EMAIL_ID' ORDER BY event_timestamp DESC;" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Check the analytics dashboard:"
Write-Host "   $APP_URL/dashboard/marketing/analytics" -ForegroundColor Gray
Write-Host ""

