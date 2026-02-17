# ACM.ps1 - Autonomous Connection Manager
# Purpose: Maintain a robust, zero-touch connection to the Laptop.

$LaptopName = "hp"
$TailscaleAnchor = "100.118.214.79"
$RDPPath = "$HOME\Desktop\Laptop.rdp"
$IntervalSec = 300 # Check every 5 minutes

Function Update-Connection {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Checking Laptop Connectivity..." -ForegroundColor Cyan
    
    # 1. Resolve current state via Tailscale
    $tsStatus = tailscale status --json | ConvertFrom-Json
    $laptop = $tsStatus.Peer | Where-Object { $_.HostName -eq $LaptopName }
    
    if (!$laptop) {
        Write-Warning "Laptop '$LaptopName' not found on Mesh network."
        return
    }

    $BestIP = $TailscaleAnchor
    $lanIP = $laptop.CurAddr.Split(':')[0]

    # 2. Benchmark/Ping check
    if ($lanIP -match '^192\.168\.|^10\.|^172\.') {
        if (Test-Connection -ComputerName $lanIP -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            $BestIP = $lanIP
        }
    }

    # 3. Apply changes if IP has changed
    $CurrentIP = [Environment]::GetEnvironmentVariable("LAPTOP_IP", "User")
    if ($BestIP -ne $CurrentIP) {
        Write-Host "New Optimal Path Detected: $BestIP" -ForegroundColor Green
        
        # Update Environment Variable
        [Environment]::SetEnvironmentVariable("LAPTOP_IP", $BestIP, "User")
        $env:LAPTOP_IP = $BestIP
        
        # Update RDP File
        if (Test-Path $RDPPath) {
            $content = Get-Content $RDPPath
            $content = $content -replace "full address:s:.*", "full address:s:$BestIP"
            $content | Set-Content $RDPPath
        }
        
        # Pre-cache credentials for the new IP
        cmdkey /generic:TERMSRV/$BestIP /user:anguy079 /pass
    } else {
        Write-Host "Connection path is stable: $BestIP" -ForegroundColor DarkGray
    }
}

# Infinite Loop for Background Mode
Write-Host "ACM Background Service Started." -ForegroundColor Green
while ($true) {
    try { Update-Connection } catch { Write-Error $_.Exception.Message }
    Start-Sleep -Seconds $IntervalSec
}
