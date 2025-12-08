# Comprehensive Copy Script - LeadMap-main to Data Lake Backend
# This script copies all required files from LeadMap-main to Data Lake Backend

$ErrorActionPreference = "Stop"

# Define paths
$LeadMapRoot = "d:\Downloads\LeadMap-main\LeadMap-main"
$DataLakeRoot = "D:\Downloads\Data Lake Backend"

Write-Host "📦 Copying files from LeadMap-main to Data Lake Backend" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $LeadMapRoot" -ForegroundColor Yellow
Write-Host "Destination: $DataLakeRoot" -ForegroundColor Yellow
Write-Host ""

# Verify source exists
if (-not (Test-Path $LeadMapRoot)) {
    Write-Error "LeadMap-main not found at: $LeadMapRoot"
    exit 1
}

# Create destination directories if they don't exist
$directories = @(
    "$DataLakeRoot\scripts",
    "$DataLakeRoot\scripts\redfin-scraper",
    "$DataLakeRoot\supabase",
    "$DataLakeRoot\supabase\functions",
    "$DataLakeRoot\supabase\functions\geocode-new-listings",
    "$DataLakeRoot\supabase\migrations",
    "$DataLakeRoot\docs"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "📁 Created directory: $dir" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Starting file copy operations..." -ForegroundColor Cyan
Write-Host ""

$copied = 0
$skipped = 0
$errors = 0

# Function to copy files with progress
function Copy-FileWithProgress {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Description
    )
    
    if (Test-Path $Source) {
        try {
            $destDir = Split-Path $Destination -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            
            Copy-Item -Path $Source -Destination $Destination -Force
            Write-Host "   ✅ $Description" -ForegroundColor Green
            return 1
        } catch {
            Write-Host "   ❌ Error copying $Description : $_" -ForegroundColor Red
            return 0
        }
    } else {
        Write-Host "   ⚠️  Source not found: $Source" -ForegroundColor Yellow
        return 0
    }
}

# 1. Copy Redfin Scraper files
Write-Host "1️⃣  Copying Redfin Scraper files..." -ForegroundColor Cyan
$redfinFiles = @(
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\FSBO.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\FSBO.py"; Desc = "FSBO.py"},
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\Enrichment.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\Enrichment.py"; Desc = "Enrichment.py"},
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\supabase_client.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\supabase_client.py"; Desc = "supabase_client.py"},
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\orchestrator.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\orchestrator.py"; Desc = "orchestrator.py"},
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\worker.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\worker.py"; Desc = "worker.py"},
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\aws_lambda_proxy.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\aws_lambda_proxy.py"; Desc = "aws_lambda_proxy.py"},
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\aws_setup.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\aws_setup.py"; Desc = "aws_setup.py"},
    @{Source = "$LeadMapRoot\scripts\redfin-scraper\test_enrichment.py"; Dest = "$DataLakeRoot\scripts\redfin-scraper\test_enrichment.py"; Desc = "test_enrichment.py"}
)

foreach ($file in $redfinFiles) {
    $result = Copy-FileWithProgress -Source $file.Source -Destination $file.Dest -Description $file.Desc
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 2. Copy Geocoding scripts
Write-Host ""
Write-Host "2️⃣  Copying Geocoding scripts..." -ForegroundColor Cyan
$geocodingFiles = @(
    @{Source = "$LeadMapRoot\scripts\backfill-geocodes.ts"; Dest = "$DataLakeRoot\scripts\backfill-geocodes.ts"; Desc = "backfill-geocodes.ts"},
    @{Source = "$LeadMapRoot\scripts\README-GEOCODING.md"; Dest = "$DataLakeRoot\scripts\README-GEOCODING.md"; Desc = "README-GEOCODING.md"}
)

foreach ($file in $geocodingFiles) {
    $result = Copy-FileWithProgress -Source $file.Source -Destination $file.Dest -Description $file.Desc
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 3. Copy Data Insertion Scripts
Write-Host ""
Write-Host "3️⃣  Copying Data Insertion scripts..." -ForegroundColor Cyan
$dataInsertionFiles = @(
    @{Source = "$LeadMapRoot\scripts\create_user.py"; Dest = "$DataLakeRoot\scripts\create_user.py"; Desc = "create_user.py"},
    @{Source = "$LeadMapRoot\scripts\create_user.js"; Dest = "$DataLakeRoot\scripts\create_user.js"; Desc = "create_user.js"},
    @{Source = "$LeadMapRoot\scripts\create_user_simple.js"; Dest = "$DataLakeRoot\scripts\create_user_simple.js"; Desc = "create_user_simple.js"},
    @{Source = "$LeadMapRoot\scripts\seed-test-data.sql"; Dest = "$DataLakeRoot\scripts\seed-test-data.sql"; Desc = "seed-test-data.sql"},
    @{Source = "$LeadMapRoot\scripts\seed-test-data-safe.sql"; Dest = "$DataLakeRoot\scripts\seed-test-data-safe.sql"; Desc = "seed-test-data-safe.sql"}
)

foreach ($file in $dataInsertionFiles) {
    $result = Copy-FileWithProgress -Source $file.Source -Destination $file.Dest -Description $file.Desc
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 4. Copy all Supabase SQL files
Write-Host ""
Write-Host "4️⃣  Copying Supabase schema files..." -ForegroundColor Cyan
$supabaseFiles = Get-ChildItem -Path "$LeadMapRoot\supabase" -Filter "*.sql" -Recurse -File | 
    Where-Object { 
        $_.FullName -notmatch "\\\.temp\\" -and 
        $_.FullName -notmatch "__pycache__" 
    }

foreach ($file in $supabaseFiles) {
    $relPath = $file.FullName.Replace($LeadMapRoot, "").TrimStart("\")
    $destPath = Join-Path $DataLakeRoot $relPath
    $result = Copy-FileWithProgress -Source $file.FullName -Destination $destPath -Description $relPath
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 5. Copy Supabase Python scripts
Write-Host ""
Write-Host "5️⃣  Copying Supabase Python scripts..." -ForegroundColor Cyan
$supabasePythonFiles = Get-ChildItem -Path "$LeadMapRoot\supabase" -Filter "*.py" -Recurse -File | 
    Where-Object { 
        $_.FullName -notmatch "\\\.temp\\" -and 
        $_.FullName -notmatch "__pycache__" 
    }

foreach ($file in $supabasePythonFiles) {
    $relPath = $file.FullName.Replace($LeadMapRoot, "").TrimStart("\")
    $destPath = Join-Path $DataLakeRoot $relPath
    $result = Copy-FileWithProgress -Source $file.FullName -Destination $destPath -Description $relPath
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 6. Copy Supabase Edge Functions
Write-Host ""
Write-Host "6️⃣  Copying Supabase Edge Functions..." -ForegroundColor Cyan
if (Test-Path "$LeadMapRoot\supabase\functions\geocode-new-listings\index.ts") {
    $result = Copy-FileWithProgress -Source "$LeadMapRoot\supabase\functions\geocode-new-listings\index.ts" -Destination "$DataLakeRoot\supabase\functions\geocode-new-listings\index.ts" -Description "geocode-new-listings/index.ts"
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 7. Copy Supabase PowerShell scripts
Write-Host ""
Write-Host "7️⃣  Copying Supabase PowerShell scripts..." -ForegroundColor Cyan
$supabasePSFiles = Get-ChildItem -Path "$LeadMapRoot\supabase" -Filter "*.ps1" -Recurse -File -ErrorAction SilentlyContinue

foreach ($file in $supabasePSFiles) {
    $relPath = $file.FullName.Replace($LeadMapRoot, "").TrimStart("\")
    $destPath = Join-Path $DataLakeRoot $relPath
    $result = Copy-FileWithProgress -Source $file.FullName -Destination $destPath -Description $relPath
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 8. Copy Supabase README files
Write-Host ""
Write-Host "8️⃣  Copying Supabase documentation..." -ForegroundColor Cyan
if (Test-Path "$LeadMapRoot\supabase\LISTINGS_VIEW_README.md") {
    $result = Copy-FileWithProgress -Source "$LeadMapRoot\supabase\LISTINGS_VIEW_README.md" -Destination "$DataLakeRoot\supabase\LISTINGS_VIEW_README.md" -Description "LISTINGS_VIEW_README.md"
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# 9. Copy all documentation files
Write-Host ""
Write-Host "9️⃣  Copying documentation files..." -ForegroundColor Cyan
$docFiles = Get-ChildItem -Path $LeadMapRoot -Filter "*.md" -File | 
    Where-Object { 
        $_.Name -ne "README.md" -and  # We'll handle README separately
        $_.FullName -notmatch "\\LeadMap-main\\"  # Skip nested LeadMap-main folder
    }

foreach ($file in $docFiles) {
    $destPath = Join-Path "$DataLakeRoot\docs" $file.Name
    $result = Copy-FileWithProgress -Source $file.FullName -Destination $destPath -Description "docs\$($file.Name)"
    if ($result -eq 1) { $copied++ } else { $errors++ }
}

# Summary
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "📊 Copy Summary" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Files copied: $copied" -ForegroundColor Green
if ($errors -gt 0) {
    Write-Host "❌ Errors: $errors" -ForegroundColor Red
}
Write-Host ""
Write-Host "✅ Copy operation complete!" -ForegroundColor Green
