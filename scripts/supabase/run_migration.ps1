# PowerShell script to run Supabase migration using npx
# This avoids needing to install Supabase CLI globally

Write-Host "Running Calendar Time Handling Migration..." -ForegroundColor Green
Write-Host ""

# Get the migration file path
$migrationFile = Join-Path $PSScriptRoot "migrations\calendar_time_handling.sql"

if (-not (Test-Path $migrationFile)) {
    Write-Host "Error: Migration file not found at $migrationFile" -ForegroundColor Red
    exit 1
}

Write-Host "Migration file found: $migrationFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "To apply this migration, you have two options:" -ForegroundColor Yellow
Write-Host ""
Write-Host "OPTION 1: Supabase Dashboard (Recommended)" -ForegroundColor Green
Write-Host "  1. Go to https://supabase.com/dashboard" -ForegroundColor White
Write-Host "  2. Select your project" -ForegroundColor White
Write-Host "  3. Navigate to SQL Editor" -ForegroundColor White
Write-Host "  4. Create a new query" -ForegroundColor White
Write-Host "  5. Copy and paste the contents of:" -ForegroundColor White
Write-Host "     $migrationFile" -ForegroundColor Cyan
Write-Host "  6. Click 'Run'" -ForegroundColor White
Write-Host ""
Write-Host "OPTION 2: Using Supabase CLI (if installed)" -ForegroundColor Green
Write-Host "  Run: supabase db execute -f `"$migrationFile`"" -ForegroundColor White
Write-Host ""
Write-Host "Reading migration file..." -ForegroundColor Cyan
Write-Host ""
Write-Host "=" * 80 -ForegroundColor Gray
Get-Content $migrationFile
Write-Host "=" * 80 -ForegroundColor Gray

