param(
    [string]$TaskName = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$projectName = Split-Path $repoRoot -Leaf
if ([string]::IsNullOrWhiteSpace($TaskName)) {
    $TaskName = "Yggdrasil-$projectName-Autonomous-Loop"
}
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
Write-Host "Removed scheduled task: $TaskName"

