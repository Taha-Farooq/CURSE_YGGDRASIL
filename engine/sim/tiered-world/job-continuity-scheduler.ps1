param(
    [string]$RepoRoot = "",
    [string]$JobsJsonPath = "",
    [bool]$LocalCombatActive = $false
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($JobsJsonPath)) {
    $JobsJsonPath = Join-Path $RepoRoot "tests\fixtures\phase1-tiered-world-jobs.json"
}
if (-not (Test-Path $JobsJsonPath)) {
    throw "Missing jobs fixture: $JobsJsonPath"
}

$rawJobs = Get-Content $JobsJsonPath -Raw | ConvertFrom-Json
$jobs = @()
if ($rawJobs -is [System.Array]) {
    $jobs = @($rawJobs)
} elseif ($null -ne $rawJobs -and $rawJobs.PSObject.Properties.Name -contains "jobId" -and @($rawJobs.jobId).Count -gt 1) {
    $count = @($rawJobs.jobId).Count
    for ($i = 0; $i -lt $count; $i++) {
        $jobs += @{
            jobId = @($rawJobs.jobId)[$i]
            tier = @($rawJobs.tier)[$i]
            progress = @($rawJobs.progress)[$i]
        }
    }
} else {
    $jobs = @($rawJobs)
}
$updated = @()
foreach ($job in $jobs) {
    $tier = [string]$job.tier
    $progressDelta = switch ($tier) {
        "Hot" { 5 }
        "Warm" { 3 }
        "Cold" { 2 }
        "Archive" { 1 }
        default { 1 }
    }

    # Local combat can reduce near-field throughput, but distant jobs still progress.
    if ($LocalCombatActive -and ($tier -eq "Hot" -or $tier -eq "Warm")) {
        $progressDelta = [math]::Max(1, $progressDelta - 2)
    }

    $currentProgress = [int]([double](@($job.progress)[0]))
    $newProgress = $currentProgress + $progressDelta
    if ($newProgress -gt 100) { $newProgress = 100 }

    $updated += @{
        jobId = [string]$job.jobId
        tier = $tier
        progressed = ($newProgress -gt $currentProgress)
        previousProgress = $currentProgress
        progress = $newProgress
        status = $(if ($newProgress -ge 100) { "completed" } else { "running" })
    }
}

$result = @{
    scheduler = "tiered_world_job_continuity_scheduler_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    localCombatActive = $LocalCombatActive
    jobs = $updated
}

$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
