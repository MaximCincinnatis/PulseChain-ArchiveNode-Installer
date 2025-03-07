# Simple PowerShell script to push to GitHub
# This script directly pushes to GitHub without prompts
# USAGE: .\push-direct.ps1 YOUR_TOKEN_HERE

param (
    [Parameter(Mandatory=$true)]
    [string]$Token
)

# Display initial message
Write-Host "Starting GitHub push..." -ForegroundColor Green

# First, add any untracked files
Write-Host "Adding untracked files..." -ForegroundColor Yellow
git add .

# Commit any changes if needed
$status = git status --porcelain
if ($status) {
    Write-Host "Committing changes..." -ForegroundColor Yellow
    git commit -m "Update files for GitHub push"
}

# Set the remote URL with the token
$remoteUrl = "https://$Token@github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer.git"
Write-Host "Setting GitHub remote URL..." -ForegroundColor Yellow
git remote set-url origin $remoteUrl

# Push to GitHub
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push -u origin master

# Reset the URL to not contain the token (for security)
git remote set-url origin "https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer.git"

# Success message
Write-Host "GitHub push completed!" -ForegroundColor Green
Write-Host "Repository: https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer" -ForegroundColor Green

# Clean up by clearing the token from memory
$Token = "0" * $Token.Length 