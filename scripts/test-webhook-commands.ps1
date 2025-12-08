# Ready-to-use cURL commands for testing webhooks
# Replace EMAIL_ID with an actual email ID from your database

# Configuration
$APP_URL = "http://localhost:3000"  # Change if needed
$EMAIL_ID = "REPLACE_WITH_ACTUAL_EMAIL_ID"  # Get from: SELECT id FROM emails ORDER BY created_at DESC LIMIT 1;
$WEBHOOK_SECRET = ""  # Only if EMAIL_WEBHOOK_SECRET is set

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Webhook Test Commands" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if ($EMAIL_ID -eq "REPLACE_WITH_ACTUAL_EMAIL_ID") {
    Write-Host "⚠️  Please set EMAIL_ID first!" -ForegroundColor Red
    Write-Host "Run this SQL in Supabase to get an email ID:" -ForegroundColor Yellow
    Write-Host "  SELECT id, to_email FROM emails ORDER BY created_at DESC LIMIT 1;`n" -ForegroundColor Gray
    Write-Host "Then edit this script and set `$EMAIL_ID = 'your-email-id'`n" -ForegroundColor Yellow
    exit 1
}

# Build headers
$headers = @{
    "Content-Type" = "application/json"
    "x-provider" = "generic"
}
if ($WEBHOOK_SECRET) {
    $headers["x-webhook-secret"] = $WEBHOOK_SECRET
}

# Test 1: Delivered Event
Write-Host "Test 1: Delivered Event" -ForegroundColor Yellow
$deliveredBody = @{
    eventType = "delivered"
    emailId = $EMAIL_ID
    recipientEmail = "test@example.com"
    providerMessageId = "test-delivered-$(Get-Date -Format 'yyyyMMddHHmmss')"
} | ConvertTo-Json -Compress

try {
    $response = Invoke-RestMethod -Uri "$APP_URL/api/webhooks/email/providers" `
        -Method Post -Headers $headers -Body $deliveredBody
    Write-Host "✅ Success: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Start-Sleep -Seconds 1

# Test 2: Bounced Event (Hard)
Write-Host "Test 2: Hard Bounce Event" -ForegroundColor Yellow
$bouncedBody = @{
    eventType = "bounced"
    emailId = $EMAIL_ID
    recipientEmail = "test@example.com"
    providerMessageId = "test-bounced-$(Get-Date -Format 'yyyyMMddHHmmss')"
    bounceType = "hard"
    bounceReason = "550 Mailbox not found"
} | ConvertTo-Json -Compress

try {
    $response = Invoke-RestMethod -Uri "$APP_URL/api/webhooks/email/providers" `
        -Method Post -Headers $headers -Body $bouncedBody
    Write-Host "✅ Success: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

Start-Sleep -Seconds 1

# Test 3: Complaint Event
Write-Host "Test 3: Complaint Event" -ForegroundColor Yellow
$complaintBody = @{
    eventType = "complaint"
    emailId = $EMAIL_ID
    recipientEmail = "test@example.com"
    providerMessageId = "test-complaint-$(Get-Date -Format 'yyyyMMddHHmmss')"
    complaintType = "spam"
} | ConvertTo-Json -Compress

try {
    $response = Invoke-RestMethod -Uri "$APP_URL/api/webhooks/email/providers" `
        -Method Post -Headers $headers -Body $complaintBody
    Write-Host "✅ Success: $($response | ConvertTo-Json)" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Testing Complete!" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Verify results in Supabase:" -ForegroundColor Yellow
Write-Host "  SELECT * FROM email_events WHERE email_id = '$EMAIL_ID' ORDER BY event_timestamp DESC;`n" -ForegroundColor Gray

