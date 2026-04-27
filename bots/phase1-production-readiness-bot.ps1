param(
    [string]$RepoRoot = "",
    [double]$MinFunctionalCoveragePct = 30.0,
    [double]$MinInteropPassRatePct = 100.0,
    [int]$MinPhase1InProgress = 2
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[phase1-production-readiness-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "phase1-production-readiness-bot-$timestamp.json"

$script = Join-Path $RepoRoot "scripts\check-phase1-production-readiness.ps1"
$readiness = & $script -RepoRoot $RepoRoot -MinFunctionalCoveragePct $MinFunctionalCoveragePct -MinInteropPassRatePct $MinInteropPassRatePct -MinPhase1InProgress $MinPhase1InProgress | ConvertFrom-Json

$result = @{
    bot = "phase1-production-readiness-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = [bool]$readiness.passed
    readiness = $readiness
}

$result | ConvertTo-Json -Depth 10 | Set-Content -Path $output -Encoding UTF8
Write-Host "[phase1-production-readiness-bot] Report: $output"
if (-not [bool]$readiness.passed) { exit 1 }
exit 0
