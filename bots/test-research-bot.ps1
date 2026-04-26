param(
    [string]$RepoRoot = "",
    [int]$MaxRecommendationsPerRun = 40
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[test-research-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
$researchDir = Join-Path $RepoRoot "automation\research"
$handoffDir = Join-Path $RepoRoot "automation\handoff"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
if (-not (Test-Path $researchDir)) { New-Item -ItemType Directory -Path $researchDir -Force | Out-Null }
if (-not (Test-Path $handoffDir)) { New-Item -ItemType Directory -Path $handoffDir -Force | Out-Null }

$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$reqPath = Join-Path $RepoRoot "REQUIREMENTS.md"
$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
$reportPath = Join-Path $researchDir "test-recommendations-latest.json"
$handoffPath = Join-Path $handoffDir "bot-maker-requests.json"
$output = Join-Path $botDir "test-research-bot-$timestamp.json"

if (-not (Test-Path $matrixPath)) { throw "Missing INTERACTION_MATRIX.md" }
if (-not (Test-Path $reqPath)) { throw "Missing REQUIREMENTS.md" }

$matrix = Get-Content $matrixPath -Raw
$req = Get-Content $reqPath -Raw
$tasks = @()
if (Test-Path $tasksPath) {
    $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
}

$recommendations = @()

# 1) Derive integration tests from matrix IDs
$intMatches = [regex]::Matches($matrix, "IT-[A-Z]+-\d+")
$itIds = @{}
foreach ($m in $intMatches) { $itIds[$m.Value] = $true }
foreach ($id in $itIds.Keys) {
    if ($recommendations.Count -ge $MaxRecommendationsPerRun) { break }
    $recommendations += @{
        testId = $id
        type = "integration"
        reason = "Referenced in INTERACTION_MATRIX.md"
        priority = "high"
    }
}

# 1b) Derive scenario tests from matrix IDs
$scnMatches = [regex]::Matches($matrix, "SCN-\d+")
$scnIds = @{}
foreach ($m in $scnMatches) { $scnIds[$m.Value] = $true }
foreach ($id in $scnIds.Keys) {
    if ($recommendations.Count -ge $MaxRecommendationsPerRun) { break }
    $recommendations += @{
        testId = $id
        type = "scenario"
        reason = "Scenario mapping in INTERACTION_MATRIX.md"
        priority = "high"
    }
}

# 2) Add required test families based on requirements sections
$families = @(
    @{ key = "authority"; req = "## 3) Networking and Authority"; testPrefix = "IT-AUTH"; priority = "critical" },
    @{ key = "replay"; req = "## 4) Replay and Dispute Record"; testPrefix = "IT-RPL"; priority = "critical" },
    @{ key = "sim"; req = "## 5) World Simulation Continuity"; testPrefix = "IT-SIM"; priority = "critical" },
    @{ key = "live"; req = "## 24) Live Content Authoring and AI-Assisted Generation"; testPrefix = "IT-LIVE"; priority = "high" },
    @{ key = "bots"; req = "## 25) Autonomous Bot Framework"; testPrefix = "IT-BOT"; priority = "high" }
)

foreach ($f in $families) {
    if ($recommendations.Count -ge $MaxRecommendationsPerRun) { break }
    if ($req -match [regex]::Escape($f.req)) {
        $recommendations += @{
            testId = "$($f.testPrefix)-BASE-001"
            type = "suite-seed"
            reason = "Mandatory requirement section present: $($f.req)"
            priority = $f.priority
        }
    }
}

# 3) derive from backlog task volume
$todoCount = @($tasks | Where-Object { $_.status -eq "todo" }).Count
if ($todoCount -gt 20 -and $recommendations.Count -lt $MaxRecommendationsPerRun) {
    $recommendations += @{
        testId = "IT-REG-LOAD-001"
        type = "regression"
        reason = "High todo count indicates growing change surface; add load regression suite"
        priority = "high"
    }
}

$recommendations = $recommendations | Select-Object -First $MaxRecommendationsPerRun
$recommendations | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8

# Handoff requests for bot-maker
$requests = @()
foreach ($r in $recommendations) {
    if ($r.type -eq "integration" -or $r.type -eq "suite-seed" -or $r.type -eq "scenario") {
        $requests += @{
            requestId = "REQ-" + $r.testId
            kind = "create_test_bot_stub"
            name = ("test-bot-" + ($r.testId.ToLower() -replace "[^a-z0-9]+","-"))
            targetTestId = $r.testId
            reason = $r.reason
            priority = $r.priority
        }
    }
}
$requests | ConvertTo-Json -Depth 8 | Set-Content -Path $handoffPath -Encoding UTF8

$result = @{
    bot = "test-research-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    recommendations = $recommendations.Count
    reportPath = $reportPath
    handoffPath = $handoffPath
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-research-bot] Report: $output"
exit 0

