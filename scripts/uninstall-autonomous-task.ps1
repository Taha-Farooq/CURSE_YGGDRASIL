param(
    [string]$TaskName = "CURSE-Autonomous-Loop"
)

$ErrorActionPreference = "Stop"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
Write-Host "Removed scheduled task: $TaskName"

