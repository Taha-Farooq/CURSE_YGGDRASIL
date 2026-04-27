param(
    [string]$RepoRoot = "",
    [int]$MinScoreToRecommend = 7,
    [int]$MaxRecommendations = 5
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[backlog-admission-review-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportsDir = Join-Path $RepoRoot "reports\bots"
$handoffDir = Join-Path $RepoRoot "automation\handoff"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
if (-not (Test-Path $handoffDir)) { New-Item -ItemType Directory -Path $handoffDir -Force | Out-Null }

$reportPath = Join-Path $reportsDir "backlog-admission-review-bot-$timestamp.json"
$handoffPath = Join-Path $handoffDir "nice-to-have-backlog-review-latest.json"

$latestInvestigation = Get-ChildItem -Path $reportsDir -Filter "nice-to-have-investigator-bot-*.json" -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
if ($null -eq $latestInvestigation) {
    $result = @{
        bot = "backlog-admission-review-bot"
        timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
        passed = $false
        details = "No investigation report found. Run nice-to-have-investigator-bot first."
        recommendations = @()
    }
    $result | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8
    Write-Host "[backlog-admission-review-bot] Report: $reportPath"
    exit 1
}

$investigation = Get-Content $latestInvestigation.FullName -Raw | ConvertFrom-Json
$candidates = @($investigation.candidates)
$reviews = @()

foreach ($candidate in $candidates) {
    $score = [int]$candidate.desirabilityScore
    $risk = [int]$candidate.risk
    $effort = [int]$candidate.effort
    $recommend = ($score -ge $MinScoreToRecommend -and $risk -le 2 -and $effort -le 3)
    $priority = "medium"
    if ($score -ge ($MinScoreToRecommend + 2)) { $priority = "high" }

    $taskId = "TASK-NTH-" + ([string]$candidate.id)
    $reviews += @{
        id = [string]$candidate.id
        title = [string]$candidate.title
        shouldAddToBacklog = $recommend
        rationale = if ($recommend) { "High value-to-risk ratio and aligned with deterministic authority model." } else { "Lower current payoff or higher risk/effort; keep as parking-lot candidate." }
        suggestedBacklogTask = @{
            id = $taskId
            title = [string]$candidate.title
            source = "nice-to-have-review"
            type = "user-feature"
            priority = $priority
            status = "todo"
        }
        metrics = @{
            desirabilityScore = $score
            impact = [int]$candidate.impact
            effort = $effort
            risk = $risk
        }
    }
}

$recommended = @($reviews | Where-Object { [bool]$_.shouldAddToBacklog } | Sort-Object { [int]$_.metrics.desirabilityScore } -Descending | Select-Object -First $MaxRecommendations)
$deferred = @($reviews | Where-Object { -not [bool]$_.shouldAddToBacklog })

$result = @{
    bot = "backlog-admission-review-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    sourceReport = $latestInvestigation.FullName
    minScoreToRecommend = $MinScoreToRecommend
    recommendationCount = @($recommended).Count
    recommendations = $recommended
    deferred = $deferred
}

$result | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
$result | ConvertTo-Json -Depth 10 | Set-Content -Path $handoffPath -Encoding UTF8
Write-Host "[backlog-admission-review-bot] Report: $reportPath"
Write-Host "[backlog-admission-review-bot] Handoff: $handoffPath"
exit 0
