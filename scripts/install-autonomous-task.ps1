param(
    [string]$TaskName = "CURSE-Autonomous-Loop"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$runScript = Join-Path $repoRoot "scripts\run-autonomous.ps1"

if (-not (Test-Path $runScript)) {
    throw "Missing script: $runScript"
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runScript`" -Once -Strict"
# Task Scheduler rejects extremely large durations; use a long but valid window.
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 20)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "Runs CURSE autonomous dev/test loop every 30 minutes" -Force -ErrorAction Stop | Out-Null
Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop | Out-Null
Write-Host "Installed scheduled task successfully: $TaskName"
Write-Host "Use Task Scheduler to inspect status/history."

