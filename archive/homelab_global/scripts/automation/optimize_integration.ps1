# optimize_integration.ps1
# This script ensures your Desktop-Laptop connection is always robust.
# It uses Tailscale as the persistent anchor and LAN as a speed optimization.

$LaptopName = "hp"
$TailscaleIP = "100.118.214.79"

Write-Host "--- Probing Laptop Connection (Robust Mode) ---" -ForegroundColor Cyan

# 1. Get the current status from Tailscale
# This is the most robust way to find the laptop's current network state
$tsStatus = tailscale status --json | ConvertFrom-Json
$laptop = $tsStatus.Peer | Where-Object { $_.HostName -eq $LaptopName }

if (!$laptop) {
    Write-Host "[ERROR] Laptop '$LaptopName' not found in Tailscale. Is it logged in?" -ForegroundColor Red
    return
}

$BestIP = $TailscaleIP # Default persistent anchor
$IsLAN = $false

# 2. Speed Optimization: Check if we are on the same local network
$lanIP = $laptop.CurAddr.Split(':')[0]
if ($lanIP -match '^192\.168\.|^10\.|^172\.') {
    Write-Host "Detected LAN IP: $lanIP"
    $ping = Test-Connection -ComputerName $lanIP -Count 1 -Quiet -ErrorAction SilentlyContinue
    if ($ping) {
        Write-Host "[SPEED] Using LAN path for maximum performance." -ForegroundColor Green
        $BestIP = $lanIP
        $IsLAN = $true
    }
}

if (!$IsLAN) {
    Write-Host "[MESH] Using persistent Tailscale IP for reliability." -ForegroundColor Yellow
}

# 3. Update RDP Shortcut
$RDPPath = "$HOME\Desktop\Laptop.rdp"
if (Test-Path $RDPPath) {
    $content = Get-Content $RDPPath
    $content = $content -replace "full address:s:.*", "full address:s:$BestIP"
    $content | Set-Content $RDPPath
    Write-Host "Updated RDP shortcut to: $BestIP" -ForegroundColor Cyan
}

# 4. Refresh Autologin (cmdkey)
# We store both so switching is seamless
cmdkey /generic:TERMSRV/$BestIP /user:anguy079 /pass

# 5. Set persistent environment variable
[Environment]::SetEnvironmentVariable("LAPTOP_IP", $BestIP, "User")
$env:LAPTOP_IP = $BestIP

Write-Host "--- Discovery Complete! ---" -ForegroundColor Green
Write-Host "Current Target: $BestIP"
