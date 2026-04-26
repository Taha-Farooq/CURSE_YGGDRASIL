param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reportsDir = Join-Path $RepoRoot "reports"
$botReportsDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$snapshotPath = Join-Path $reportsDir "release-readiness-snapshot-$timestamp.json"

function Get-LatestOrNull([string]$pattern) {
    if (-not (Test-Path $botReportsDir)) { return $null }
    $f = Get-ChildItem -Path $botReportsDir -Filter $pattern | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $f) { return $null }
    try {
        return (Get-Content $f.FullName -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

$coverage = $null
$criticalGuard = $null
$freshness = $null
$qualityGatePassed = $true

try { $coverage = & (Join-Path $RepoRoot "scripts\check-test-contract-coverage.ps1") -RepoRoot $RepoRoot | ConvertFrom-Json } catch { $qualityGatePassed = $false }
try { $criticalGuard = & (Join-Path $RepoRoot "scripts\check-critical-regressions.ps1") -RepoRoot $RepoRoot | ConvertFrom-Json } catch { $qualityGatePassed = $false }
try { $freshness = & (Join-Path $RepoRoot "scripts\check-test-freshness.ps1") -RepoRoot $RepoRoot | ConvertFrom-Json } catch { $qualityGatePassed = $false }

$latestValidation = Get-LatestOrNull "validation-bot-*.json"
$latestDrift = Get-LatestOrNull "autonomous-drift-report-bot-*.json"
$latestOrchestrator = Get-LatestOrNull "orchestrator-run-*.json"

$snapshot = [ordered]@{
    snapshot = "release_readiness_v1"
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    qualityGateStatus = @{
        passed = $qualityGatePassed
    }
    contractCoverage = $coverage
    criticalRegressionGuard = $criticalGuard
    freshnessPolicy = $freshness
    latestValidationBot = $latestValidation
    latestAutonomousDriftReport = $latestDrift
    latestOrchestratorRun = $latestOrchestrator
}

$snapshot | ConvertTo-Json -Depth 10 | Set-Content -Path $snapshotPath -Encoding UTF8
Write-Output $snapshotPath
exit 0
