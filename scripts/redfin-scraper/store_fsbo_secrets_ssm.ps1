# One-time: store all FSBO env variables in AWS SSM Parameter Store.
# EC2 with IAM role that has ssm:GetParameter will read these at runtime (bootstrap + start_fsbo_worker.sh).
#
# Usage (PowerShell):
#   $env:AWS_PROFILE = "StackDealFSBO-Scraper"
#   $env:AWS_REGION  = "us-east-1"
#   $env:SUPABASE_SERVICE_ROLE_KEY = "eyJ..."   # your key
#   .\store_fsbo_secrets_ssm.ps1
#
# Or pass the key as the first argument:
#   .\store_fsbo_secrets_ssm.ps1 "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

param(
    [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

$Region = $env:AWS_REGION
if (-not $Region) { $Region = "us-east-1" }

# All FSBO env values (EC2 worker + Supabase)
$params = @{
    "/fsbo/supabase-url"                 = "https://bqkucdaefpfkunceftye.supabase.co"
    "/fsbo/fsbo-sqs-queue-url"           = "https://sqs.us-east-1.amazonaws.com/859217211854/fsbo-listing-jobs"
    "/fsbo/aws-region"                   = "us-east-1"
    "/fsbo/fsbo-worker-concurrency"      = "50"
}

if (-not $ServiceRoleKey) {
    Write-Host "ERROR: Set SUPABASE_SERVICE_ROLE_KEY env var or pass the key as the first argument."
    exit 1
}

Write-Host "Storing all FSBO env variables in SSM (region=$Region)..."

foreach ($name in $params.Keys) {
    $val = $params[$name]
    $result = aws ssm put-parameter --name $name --type String --value $val --overwrite --region $Region 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  $name FAIL: $result"
        exit 1
    }
    Write-Host "  $name OK"
}

$result = aws ssm put-parameter --name "/fsbo/supabase-service-role-key" --type SecureString --value $ServiceRoleKey --overwrite --region $Region 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  /fsbo/supabase-service-role-key FAIL: $result"
    exit 1
}
Write-Host "  /fsbo/supabase-service-role-key OK (SecureString)"

Write-Host ""
Write-Host "Done. EC2 can read these via IAM ssm:GetParameter on /fsbo/*"
exit 0
