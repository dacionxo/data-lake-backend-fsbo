# PowerShell Script to Create GitHub Repository and Push Code
# For: Data Lake Backend

Write-Host "🚀 Creating GitHub Repository and Pushing Code..." -ForegroundColor Green
Write-Host ""

# Repository details
$repoName = "data-lake-backend"
$repoDescription = "A comprehensive backend system for real estate lead data collection, enrichment, and storage"
$username = "dacionxo"  # From LeadMap-main remote
$projectDir = "D:\Downloads\Data Lake Backend"

# Change to project directory
Set-Location $projectDir

# Check if GitHub token is available
$token = $env:GITHUB_TOKEN
if (-not $token) {
    Write-Host "⚠️  GITHUB_TOKEN environment variable not found." -ForegroundColor Yellow
    Write-Host "You need a GitHub Personal Access Token with 'repo' scope." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To create a token:" -ForegroundColor Cyan
    Write-Host "1. Go to: https://github.com/settings/tokens" -ForegroundColor Cyan
    Write-Host "2. Click 'Generate new token (classic)'" -ForegroundColor Cyan
    Write-Host "3. Select 'repo' scope" -ForegroundColor Cyan
    Write-Host "4. Copy the token" -ForegroundColor Cyan
    Write-Host ""
    $token = Read-Host "Enter your GitHub Personal Access Token (or press Enter to create repo manually)"
    
    if ([string]::IsNullOrWhiteSpace($token)) {
        Write-Host ""
        Write-Host "📝 Manual Repository Creation:" -ForegroundColor Cyan
        Write-Host "1. Go to: https://github.com/new" -ForegroundColor Cyan
        Write-Host "2. Repository name: $repoName" -ForegroundColor Cyan
        Write-Host "3. Description: $repoDescription" -ForegroundColor Cyan
        Write-Host "4. Choose Public or Private" -ForegroundColor Cyan
        Write-Host "5. DO NOT initialize with README, .gitignore, or license" -ForegroundColor Yellow
        Write-Host "6. Click 'Create repository'" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "After creating, run these commands:" -ForegroundColor Green
        Write-Host "  git remote add origin https://github.com/$username/$repoName.git" -ForegroundColor White
        Write-Host "  git branch -M main" -ForegroundColor White
        Write-Host "  git push -u origin main" -ForegroundColor White
        exit 0
    }
}

# Create repository via GitHub API
Write-Host "📦 Creating repository on GitHub..." -ForegroundColor Cyan
$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

$body = @{
    name = $repoName
    description = $repoDescription
    private = $false
    auto_init = $false
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $body -ContentType "application/json"
    Write-Host "✅ Repository created successfully!" -ForegroundColor Green
    Write-Host "   URL: $($response.html_url)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Error creating repository:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    # Check if repository already exists
    if ($_.Exception.Response.StatusCode -eq 422) {
        Write-Host ""
        Write-Host "⚠️  Repository may already exist. Continuing with push..." -ForegroundColor Yellow
    } else {
        exit 1
    }
}

# Setup git remote
Write-Host ""
Write-Host "🔗 Setting up git remote..." -ForegroundColor Cyan
$remoteUrl = "https://github.com/$username/$repoName.git"

# Check if remote already exists
$existingRemote = git remote get-url origin 2>$null
if ($existingRemote) {
    Write-Host "Remote 'origin' already exists: $existingRemote" -ForegroundColor Yellow
    $update = Read-Host "Update it to $remoteUrl? (y/n)"
    if ($update -eq "y") {
        git remote set-url origin $remoteUrl
        Write-Host "✅ Remote updated!" -ForegroundColor Green
    }
} else {
    git remote add origin $remoteUrl
    Write-Host "✅ Remote added!" -ForegroundColor Green
}

# Check current branch name
$currentBranch = git branch --show-current
Write-Host "Current branch: $currentBranch" -ForegroundColor Cyan

# Rename branch to main if needed
if ($currentBranch -ne "main") {
    Write-Host "Renaming branch to 'main'..." -ForegroundColor Cyan
    git branch -M main
}

# Push to GitHub
Write-Host ""
Write-Host "📤 Pushing code to GitHub..." -ForegroundColor Cyan
try {
    git push -u origin main
    Write-Host ""
    Write-Host "✅ Successfully pushed to GitHub!" -ForegroundColor Green
    Write-Host "🌐 Repository: https://github.com/$username/$repoName" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "❌ Error pushing to GitHub:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "You may need to authenticate. Try running:" -ForegroundColor Yellow
    Write-Host "  git push -u origin main" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "✨ Done! Your code is now on GitHub!" -ForegroundColor Green



