# PowerShell script to push to GitHub
# This script handles pushing your PulseChain Archive Node Installer to GitHub

# Set error action preference to stop on any error
$ErrorActionPreference = "Stop"

# Display banner
Write-Host "=================================================" -ForegroundColor Green
Write-Host "    PulseChain Archive Node - GitHub Push Tool    " -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green
Write-Host ""

# Function to check git status
function Check-GitStatus {
    Write-Host "Checking Git status..." -ForegroundColor Yellow
    $status = git status
    Write-Host $status -ForegroundColor Gray
    Write-Host ""
}

# Function to push to GitHub
function Push-ToGitHub {
    param (
        [string]$token
    )
    
    Write-Host "Attempting to push to GitHub..." -ForegroundColor Yellow
    
    # Set the remote URL with the token
    $remoteUrl = "https://${token}@github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer.git"
    git remote set-url origin $remoteUrl
    
    # Push to GitHub
    git push -u origin master
    
    # Reset the URL to not contain the token (for security)
    git remote set-url origin "https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer.git"
    
    Write-Host "Push completed!" -ForegroundColor Green
}

# Main script execution
try {
    # Check current git status
    Check-GitStatus
    
    # Ask for GitHub Personal Access Token
    Write-Host "To push to GitHub, you need a Personal Access Token." -ForegroundColor Yellow
    Write-Host "You can create one at: https://github.com/settings/tokens" -ForegroundColor Yellow
    Write-Host "Ensure it has 'repo' permissions." -ForegroundColor Yellow
    Write-Host ""
    $token = Read-Host "Enter your GitHub Personal Access Token" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    # Push to GitHub
    Push-ToGitHub -token $plainToken
    
    # Clean up - zero out the token variable
    $plainToken = "0" * $plainToken.Length
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    Write-Host ""
    Write-Host "GitHub push completed successfully!" -ForegroundColor Green
    Write-Host "Visit your repository at: https://github.com/MaximCincinnatis/PulseChain-ArchiveNode-Installer" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual Push Instructions:" -ForegroundColor Yellow
    Write-Host "1. Open a terminal outside of Cursor" -ForegroundColor Yellow
    Write-Host "2. Navigate to: C:\Users\jbajb\CurserProjects\PulseNodeLittle" -ForegroundColor Yellow
    Write-Host "3. Run: git push -u origin master" -ForegroundColor Yellow
    Write-Host "4. Enter your GitHub credentials when prompted" -ForegroundColor Yellow
}
finally {
    # Ensure we don't leave any token info in the script
    if ($plainToken) { $plainToken = "0" * $plainToken.Length }
    if ($token) { $token = $null }
    if ($BSTR) { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) }
    
    # Force garbage collection
    [System.GC]::Collect()
} 