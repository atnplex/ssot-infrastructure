# Deploy-RemoteIntegration.ps1
# Purpose: Universal, zero-touch setup for Remote Integration (RDP, SSH, Power).
# This script is the SSOT for establishing "Charge and Forget" nodes.

Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Target", "Source")]
    [string]$Mode,

    [string]$PeerHostname = "hp",
    [string]$PeerTailscaleIP = "100.118.214.79",
    [string]$Username = $env:USERNAME,
    [switch]$ForceAdmin = $true
)

# 1. Self-Elevation
if ($ForceAdmin -and -not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting elevation..." -ForegroundColor Cyan
    Start-Process pwsh -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode -PeerHostname $PeerHostname -PeerTailscaleIP $PeerTailscaleIP -Username $Username" -Verb RunAs
    exit
}

Write-Host "--- Starting Remote Integration Device Setup ($Mode) ---" -ForegroundColor Cyan

if ($Mode -eq "Target") {
    # --- TARGET CONFIGURATION (LAPTOP/HEADLESS) ---
    Write-Host "[TARGET] Configuring Headless Persistence & Services..." -ForegroundColor Yellow

    # Lid & Power Actions
    powercfg /setacvalueindex SCHEME_CURRENT 4f971721-4551-4470-baee-c3194711a1d3 5ca73305-924a-4830-9712-89c922052a30 0
    powercfg /setdcvalueindex SCHEME_CURRENT 4f971721-4551-4470-baee-c3194711a1d3 5ca73305-924a-4830-9712-89c922052a30 0
    powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONNECTIVITYINSTANDBY 1
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_NONE CONNECTIVITYINSTANDBY 1
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_BATTERY BATLEVELCRIT 25
    powercfg /setdcvalueindex SCHEME_CURRENT SUB_BATTERY BATACTIONCRIT 1
    powercfg /setactive SCHEME_CURRENT

    # RDP & UAC
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 0

    # OpenSSH (Manual Bypass)
    $installPath = "C:\Program Files\OpenSSH-Win64"
    if (-not (Test-Path $installPath)) {
        Write-Host "Downloading OpenSSH Binaries..."
        $url = "https://github.com/PowerShell/Win32-OpenSSH/releases/latest/download/OpenSSH-Win64.zip"
        $tempZip = "$env:TEMP\OpenSSH.zip"
        Invoke-WebRequest -Uri $url -OutFile $tempZip
        Expand-Archive -Path $tempZip -DestinationPath "C:\Program Files\" -Force
    }
    & "$installPath\install-sshd.ps1"
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
    New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (TCP-In)" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow -ErrorAction SilentlyContinue
}
else {
    # --- SOURCE CONFIGURATION (DESKTOP) ---
    Write-Host "[SOURCE] Configuring Connection Manager & Credentials..." -ForegroundColor Yellow

    # 1. Register ACM
    $acmRegisterScript = Join-Path $PSScriptRoot "register_ACM.ps1"
    if (Test-Path $acmRegisterScript) {
        & pwsh -ExecutionPolicy Bypass -File $acmRegisterScript
    }

    # 2. Cache Credentials for RDP (Zero-Touch)
    Write-Host "Caching credentials for $PeerHostname ($PeerTailscaleIP)..."
    cmdkey /generic:TERMSRV/$PeerTailscaleIP /user:$Username /pass
}

# Universal: Set Network Category to Private (Ensure Tailscale/LAN reachability)
Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq "Public" } | Set-NetConnectionProfile -NetworkCategory Private

Write-Host "--- Setup Complete! ($Mode Mode) ---" -ForegroundColor Green
