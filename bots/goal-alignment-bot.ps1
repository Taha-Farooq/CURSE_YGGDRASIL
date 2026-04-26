param(
    [string]$RepoRoot = "",
    [string]$GoalPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}
if ([string]::IsNullOrWhiteSpace($GoalPath)) {
    $GoalPath = Join-Path $RepoRoot "automation\goals\current-direction.json"
}

Write-Host "[goal-alignment-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "goal-alignment-bot-$timestamp.json"

$reqPath = Join-Path $RepoRoot "REQUIREMENTS.md"
$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
$testRecsPath = Join-Path $RepoRoot "automation\research\test-recommendations-latest.json"

if (-not (Test-Path $GoalPath)) { throw "Missing goal profile: $GoalPath" }
if (-not (Test-Path $reqPath)) { throw "Missing REQUIREMENTS.md" }

$goal = Get-Content $GoalPath -Raw | ConvertFrom-Json
$req = Get-Content $reqPath -Raw
$tasks = @()
if (Test-Path $tasksPath) { $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json }
$testRecs = @()
if (Test-Path $testRecsPath) { $testRecs = Get-Content $testRecsPath -Raw | ConvertFrom-Json }

$checks = @()
$passed = $true

# Requirements coverage
foreach ($kw in $goal.requiredKeywordsInRequirements) {
    $hit = $req -match [regex]::Escape($kw)
    $checks += @{
        area = "requirements"
        key = $kw
        status = $(if ($hit) { "pass" } else { "fail" })
    }
    if (-not $hit) { $passed = $false }
}

# Backlog coverage
$taskText = ($tasks | ForEach-Object { "$($_.id) $($_.title)" }) -join "`n"
foreach ($signal in $goal.requiredBacklogSignals) {
    $hit = $taskText -match [regex]::Escape($signal)
    $checks += @{
        area = "backlog"
        key = $signal
        status = $(if ($hit) { "pass" } else { "fail" })
    }
    if (-not $hit) { $passed = $false }
}

# Test signal coverage
$testText = ($testRecs | ForEach-Object { "$($_.testId) $($_.reason)" }) -join "`n"
foreach ($signal in $goal.requiredTestSignals) {
    $hit = $testText -match [regex]::Escape($signal)
    $checks += @{
        area = "tests"
        key = $signal
        status = $(if ($hit) { "pass" } else { "fail" })
    }
    if (-not $hit) { $passed = $false }
}

$result = @{
    bot = "goal-alignment-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    goal = $goal.name
    checks = $checks
    recommendation = "If failures exist, add targeted requirements/tasks/tests for missing goal signals."
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[goal-alignment-bot] Report: $output"
if (-not $passed) { exit 1 }
exit 0

