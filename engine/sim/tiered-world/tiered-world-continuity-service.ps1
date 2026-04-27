param(
    [string]$RepoRoot = "",
    [string]$JobsJsonPath = "",
    [bool]$LocalCombatActive = $false
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}

$scheduler = Join-Path $PSScriptRoot "job-continuity-scheduler.ps1"
if (-not (Test-Path $scheduler)) {
    throw "Missing scheduler: $scheduler"
}

$schedResult = & $scheduler -RepoRoot $RepoRoot -JobsJsonPath $JobsJsonPath -LocalCombatActive:$LocalCombatActive | ConvertFrom-Json

$distantTiers = @("Cold", "Archive")
$distant = @($schedResult.jobs | Where-Object { $distantTiers -contains [string]$_.tier })
$distantProgressed = (@($distant | Where-Object { [bool]$_.progressed }).Count -eq @($distant).Count)

$result = @{
    service = "tiered_world_simulation_continuity_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    localCombatActive = $LocalCombatActive
    distantJobsProgressed = $distantProgressed
    scheduler = $schedResult
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
