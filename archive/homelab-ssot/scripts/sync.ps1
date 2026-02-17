# SSOT Sync Script for Windows (PowerShell)
# Run this to pull latest state from GitHub
# Usage: .\sync.ps1
# For continuous sync: Schedule via Task Scheduler every 60 seconds

$RepoDir = "$PSScriptRoot\.."
$LogFile = "$RepoDir\logs\sync.log"

function Write-SyncLog {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $LogFile
}

try {
    Push-Location $RepoDir
    
    # Fast-forward pull only (no merge conflicts)
    $result = git pull --ff-only origin main 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        if ($result -match "Already up to date") {
            # No changes, silent
        } else {
            Write-SyncLog "Synced: $result"
            Write-Host "[SSOT] Synced successfully" -ForegroundColor Green
        }
    } else {
        Write-SyncLog "ERROR: $result"
        Write-Host "[SSOT] Sync failed: $result" -ForegroundColor Red
    }
} catch {
    Write-SyncLog "EXCEPTION: $_"
    Write-Host "[SSOT] Sync exception: $_" -ForegroundColor Red
} finally {
    Pop-Location
}
