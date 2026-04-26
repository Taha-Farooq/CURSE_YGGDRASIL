param(
    [string]$RepoRoot = "",
    [int]$MaxAllowedCriticalFindings = 0
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[error-checker-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "error-checker-bot-$timestamp.json"

$criticalFindings = @()
$warnings = @()

$reportRoot = Join-Path $RepoRoot "reports"
if (Test-Path $reportRoot) {
    $jsonReports = Get-ChildItem -Path $reportRoot -Recurse -Filter "*.json" -ErrorAction SilentlyContinue
    foreach ($file in $jsonReports) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match '"status"\s*:\s*"fail"') {
            $warnings += "Fail status found in $($file.Name)"
        }
        if ($content -match '"passed"\s*:\s*false') {
            $warnings += "Passed=false found in $($file.Name)"
        }
    }
}

if (-not (Test-Path (Join-Path $RepoRoot "REQUIREMENTS.md"))) {
    $criticalFindings += "Missing REQUIREMENTS.md"
}
if (-not (Test-Path (Join-Path $RepoRoot "FEEDBACK_SCHEMA.json"))) {
    $criticalFindings += "Missing FEEDBACK_SCHEMA.json"
}

$criticalCount = $criticalFindings.Count
$passed = $criticalCount -le $MaxAllowedCriticalFindings

$result = @{
    bot = "error-checker-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    maxAllowedCriticalFindings = $MaxAllowedCriticalFindings
    criticalFindings = $criticalFindings
    warnings = $warnings
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[error-checker-bot] Report: $output"
if (-not $passed) { exit 1 }
exit 0

