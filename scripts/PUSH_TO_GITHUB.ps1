# PowerShell Script to Push LeadMap to GitHub
# Run this script to push your code to GitHub

Write-Host "🚀 Pushing LeadMap to GitHub..." -ForegroundColor Green

# Navigate to project directory
Set-Location "D:\Downloads\LeadMap-main\LeadMap-main"

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Host "❌ Error: Not a git repository!" -ForegroundColor Red
    exit 1
}

# Show current status
Write-Host "`n📊 Current Git Status:" -ForegroundColor Cyan
git status

# Show remote configuration
Write-Host "`n🔗 Remote Configuration:" -ForegroundColor Cyan
git remote -v

# Check if there are uncommitted changes
$status = git status --porcelain
if ($status) {
    Write-Host "`n⚠️  Warning: You have uncommitted changes!" -ForegroundColor Yellow
    Write-Host "Files:" -ForegroundColor Yellow
    git status --short
    $response = Read-Host "Do you want to commit these changes? (y/n)"
    if ($response -eq "y") {
        git add -A
        $commitMessage = Read-Host "Enter commit message (or press Enter for default)"
        if ([string]::IsNullOrWhiteSpace($commitMessage)) {
            $commitMessage = "Update LeadMap project files"
        }
        git commit -m $commitMessage
        Write-Host "✅ Changes committed!" -ForegroundColor Green
    }
}

# Check if we're ahead of remote
$localCommits = git log origin/main..HEAD --oneline 2>$null
if ($localCommits) {
    Write-Host "`n📤 Local commits to push:" -ForegroundColor Cyan
    git log origin/main..HEAD --oneline
    
    Write-Host "`n🔄 Pushing to GitHub..." -ForegroundColor Yellow
    try {
        git push -u origin main
        Write-Host "`n✅ Successfully pushed to GitHub!" -ForegroundColor Green
        Write-Host "`n🌐 Your repository: https://github.com/dacionxo/LeadMap-main" -ForegroundColor Cyan
    } catch {
        Write-Host "`n❌ Error pushing to GitHub!" -ForegroundColor Red
        Write-Host "Possible issues:" -ForegroundColor Yellow
        Write-Host "  1. Repository doesn't exist on GitHub - Create it first at github.com" -ForegroundColor Yellow
        Write-Host "  2. Authentication failed - Check your GitHub credentials" -ForegroundColor Yellow
        Write-Host "  3. Permission denied - Make sure you have access to the repository" -ForegroundColor Yellow
        Write-Host "`nSee GITHUB_DEPLOYMENT.md for detailed instructions." -ForegroundColor Cyan
    }
} else {
    Write-Host "`n✅ Everything is up to date! No commits to push." -ForegroundColor Green
}

Write-Host "`n✨ Done!" -ForegroundColor Green

