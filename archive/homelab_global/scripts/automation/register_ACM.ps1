# register_ACM.ps1
# Purpose: Register the ACM background service to start automatically on login.

$ScriptPath = "$PSScriptRoot\ACM.ps1"
$TaskName = "Antigravity-Laptop-ACM"

Write-Host "Registering ACM Background Service..." -ForegroundColor Cyan

# 1. Action: Run PowerShell with the ACM script hidden
$Action = New-ScheduledTaskAction -Execute 'pwsh.exe' `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

# 2. Trigger: On User Logon
$Trigger = New-ScheduledTaskTrigger -AtLogon

# 3. Principal: Run with the highest privileges (optional, but good for cmdkey/registry)
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

# 4. Settings: Allow running if on battery, don't stop after 3 days
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 1000)

# Register the task
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force

Write-Host "Success! The Autonomous Connection Manager will now run in the background upon login." -ForegroundColor Green
Write-Host "Starting ACM now..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $TaskName
