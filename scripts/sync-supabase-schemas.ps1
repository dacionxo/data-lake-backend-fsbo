# Supabase Schema Synchronization Script
# Syncs Supabase schema files between Data Lake Backend and LeadMap-main repositories
# Usage: .\sync-supabase-schemas.ps1 [-Direction Both|ToLeadMap|ToDataLake] [-WhatIf]

param(
    [ValidateSet("Both", "ToLeadMap", "ToDataLake")]
    [string]$Direction = "Both",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Define paths
$DataLakePath = "D:\Downloads\Data Lake Backend\supabase"
$LeadMapPath = "d:\Downloads\LeadMap-main\LeadMap-main\supabase"

# Verify paths exist
if (-not (Test-Path $DataLakePath)) {
    Write-Error "Data Lake Backend path not found: $DataLakePath"
    exit 1
}

if (-not (Test-Path $LeadMapPath)) {
    Write-Error "LeadMap-main path not found: $LeadMapPath"
    exit 1
}

Write-Host "🔄 Supabase Schema Synchronization" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Data Lake Backend: $DataLakePath" -ForegroundColor Yellow
Write-Host "LeadMap-main:     $LeadMapPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "Direction: $Direction" -ForegroundColor Green
if ($WhatIf) {
    Write-Host "Mode: DRY RUN (no files will be modified)" -ForegroundColor Magenta
}
Write-Host ""

# Function to get all SQL files recursively
function Get-SqlFiles {
    param([string]$Path)
    Get-ChildItem -Path $Path -Filter "*.sql" -Recurse -File | 
        Where-Object { 
            $_.FullName -notmatch "\\\.temp\\" -and 
            $_.FullName -notmatch "__pycache__" 
        }
}

# Function to get relative path from base
function Get-RelativePath {
    param([string]$FullPath, [string]$BasePath)
    $FullPath.Replace($BasePath, "").TrimStart("\")
}

# Function to sync files
function Sync-Files {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$DirectionName
    )
    
    Write-Host "📤 Syncing: $DirectionName" -ForegroundColor Cyan
    Write-Host "   From: $SourcePath" -ForegroundColor Gray
    Write-Host "   To:   $DestPath" -ForegroundColor Gray
    Write-Host ""
    
    $sourceFiles = Get-SqlFiles -Path $SourcePath
    $destFiles = Get-SqlFiles -Path $DestPath
    
    # Create a hashtable of destination files by relative path
    $destFileMap = @{}
    foreach ($file in $destFiles) {
        $relPath = Get-RelativePath -FullPath $file.FullName -BasePath $DestPath
        $destFileMap[$relPath] = $file
    }
    
    $copied = 0
    $created = 0
    $updated = 0
    $skipped = 0
    
    foreach ($sourceFile in $sourceFiles) {
        $relPath = Get-RelativePath -FullPath $sourceFile.FullName -BasePath $SourcePath
        $destFilePath = Join-Path $DestPath $relPath
        $destFile = $destFileMap[$relPath]
        
        # Create directory if it doesn't exist
        $destDir = Split-Path $destFilePath -Parent
        if (-not (Test-Path $destDir)) {
            if (-not $WhatIf) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Write-Host "   📁 Created directory: $relPath" -ForegroundColor Green
        }
        
        # Check if file needs to be copied/updated
        $shouldCopy = $false
        $action = ""
        
        if (-not (Test-Path $destFilePath)) {
            $shouldCopy = $true
            $action = "CREATE"
            $created++
        } elseif ($destFile) {
            # Compare file hashes
            $sourceHash = (Get-FileHash $sourceFile.FullName -Algorithm MD5).Hash
            $destHash = (Get-FileHash $destFile.FullName -Algorithm MD5).Hash
            
            if ($sourceHash -ne $destHash) {
                $shouldCopy = $true
                $action = "UPDATE"
                $updated++
            } else {
                $skipped++
            }
        }
        
        if ($shouldCopy) {
            Write-Host "   $action`: $relPath" -ForegroundColor $(if ($action -eq "CREATE") { "Green" } else { "Yellow" })
            if (-not $WhatIf) {
                Copy-Item -Path $sourceFile.FullName -Destination $destFilePath -Force
                $copied++
            }
        }
    }
    
    Write-Host ""
    Write-Host "   Summary:" -ForegroundColor Cyan
    Write-Host "   - Created: $created" -ForegroundColor Green
    Write-Host "   - Updated: $updated" -ForegroundColor Yellow
    Write-Host "   - Skipped: $skipped" -ForegroundColor Gray
    if (-not $WhatIf) {
        Write-Host "   - Total copied: $copied" -ForegroundColor Green
    }
    Write-Host ""
}

# Sync based on direction
try {
    if ($Direction -eq "Both" -or $Direction -eq "ToLeadMap") {
        Sync-Files -SourcePath $DataLakePath -DestPath $LeadMapPath -DirectionName "Data Lake → LeadMap"
    }
    
    if ($Direction -eq "Both" -or $Direction -eq "ToDataLake") {
        Sync-Files -SourcePath $LeadMapPath -DestPath $DataLakePath -DirectionName "LeadMap → Data Lake"
    }
    
    Write-Host "✅ Synchronization complete!" -ForegroundColor Green
    
    if ($WhatIf) {
        Write-Host ""
        Write-Host "💡 This was a dry run. Run without -WhatIf to apply changes." -ForegroundColor Magenta
    }
} catch {
    Write-Error "❌ Synchronization failed: $_"
    exit 1
}



