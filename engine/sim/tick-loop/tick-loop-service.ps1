param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = "",
    [int]$Ticks = 1
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ($Ticks -lt 1) { throw "Ticks must be >= 1" }

if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase1-seed-world-state.json"
}
if (-not (Test-Path $InputJsonPath)) {
    throw "Missing input state json: $InputJsonPath"
}

$state = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$actorIds = @($state.actors | ForEach-Object { [string]$_.actorId } | Sort-Object)
$jobIds = @($state.jobs | ForEach-Object { [string]$_.jobId } | Sort-Object)
$regionIds = @($state.regions | ForEach-Object { [string]$_.regionId } | Sort-Object)

$tickResults = @()
for ($i = 0; $i -lt $Ticks; $i++) {
    $tickIndex = $i + 1
    $tickResults += @{
        tick = $tickIndex
        activeActors = @($actorIds).Count
        activeJobs = @($jobIds).Count
        activeRegions = @($regionIds).Count
    }
}

# Deterministic world hash uses canonical sorted identity lists.
$canonical = @{
    worldId = [string]$state.worldId
    actorIds = $actorIds
    jobIds = $jobIds
    regionIds = $regionIds
    ticks = $Ticks
} | ConvertTo-Json -Depth 8 -Compress
$hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonical))
$worldStateHash = ([BitConverter]::ToString($hashBytes) -replace "-", "").ToLowerInvariant()

$result = @{
    service = "core_tick_loop_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    worldId = [string]$state.worldId
    ticksExecuted = $Ticks
    tickResults = $tickResults
    worldStateHash = $worldStateHash
}

$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
