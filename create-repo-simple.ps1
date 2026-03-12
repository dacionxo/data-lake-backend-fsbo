# Simple script to create GitHub repo via API
$repoName = "data-lake-backend"
$username = "dacionxo"
$token = Read-Host "Enter GitHub Personal Access Token (or press Enter to skip API creation)"

if ($token) {
    $headers = @{
        "Authorization" = "Bearer $token"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $body = @{
        name = $repoName
        description = "A comprehensive backend system for real estate lead data collection, enrichment, and storage"
        private = $false
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Method Post -Headers $headers -Body $body
        Write-Host "Repository created: $($response.html_url)" -ForegroundColor Green
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response.StatusCode -eq 422) {
            Write-Host "Repository may already exist. Continuing..." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "Skipping API creation. Please create repository manually at: https://github.com/new" -ForegroundColor Yellow
    Write-Host "Repository name should be: $repoName" -ForegroundColor Cyan
}



