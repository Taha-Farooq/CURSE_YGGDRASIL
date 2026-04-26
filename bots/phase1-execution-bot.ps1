param(
    [string]$RepoRoot = "",
    [int]$MaxRecommendations = 6
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[phase1-execution-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "phase1-execution-bot-$timestamp.json"

$snapshotDir = Join-Path $RepoRoot "reports"
$latestSnapshotFile = Get-ChildItem -Path $snapshotDir -Filter "release-readiness-snapshot-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$snapshot = $null
if ($latestSnapshotFile) {
    try { $snapshot = Get-Content $latestSnapshotFile.FullName -Raw | ConvertFrom-Json } catch { $snapshot = $null }
}

$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
$phase1 = @()
if (Test-Path $tasksPath) {
    try {
        $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
        $phase1 = @($tasks | Where-Object { $_.type -eq "phase1" })
    } catch {}
}

$checks = @()
$recommendations = @()
$passed = $true

if ($null -eq $snapshot) {
    $passed = $false
    $checks += @{ check = "snapshot_available"; status = "fail"; details = "No release-readiness snapshot found." }
} else {
    $checks += @{ check = "snapshot_available"; status = "pass"; details = $latestSnapshotFile.Name }
}

if (@($phase1).Count -eq 0) {
    $passed = $false
    $checks += @{ check = "phase1_tasks_available"; status = "fail"; details = "No phase1 tasks in backlog/tasks.json" }
} else {
    $checks += @{ check = "phase1_tasks_available"; status = "pass"; details = ("count=" + @($phase1).Count) }
}

if ($null -ne $snapshot -and $null -ne $snapshot.contractCoverage) {
    $coverage = $snapshot.contractCoverage
    $weak = @($coverage.topWeakDomains)
    foreach ($w in $weak) {
        if ([double]$w.functionalPct -lt 100) {
            $recommendations += @{
                priority = "high"
                type = "stub_conversion"
                domain = $w.domain
                action = ("Convert at least one " + $w.domain + " stub bot to functional test this cycle.")
            }
        }
    }

    $stubList = @($coverage.stub | Select-Object -First $MaxRecommendations)
    foreach ($s in $stubList) {
        $recommendations += @{
            priority = "medium"
            type = "targeted_stub"
            id = $s.id
            action = ("Implement functional logic for " + $s.id + " in " + $s.bot)
        }
    }
}

if (@($phase1).Count -gt 0) {
    $inProgress = @($phase1 | Where-Object { $_.status -eq "in_progress" })
    if (@($inProgress).Count -eq 0) {
        $recommendations += @{
            priority = "high"
            type = "planning"
            action = "Move at least one Phase 1 task to in_progress with clear owner + acceptance evidence."
        }
    }
}

$recommendations = @($recommendations | Select-Object -First $MaxRecommendations)

$result = @{
    bot = "phase1-execution-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
    recommendationCount = @($recommendations).Count
    recommendations = $recommendations
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[phase1-execution-bot] Report: $output"
exit 0
