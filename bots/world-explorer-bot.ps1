param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[world-explorer-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "world-explorer-bot-$timestamp.json"

$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$matrix = Get-Content $matrixPath -Raw

$scenarios = @("SCN-001", "SCN-002", "SCN-003", "SCN-004")
$results = @()
$allPass = $true

foreach ($scn in $scenarios) {
    $exists = $matrix -match [regex]::Escape($scn)
    if ($exists) {
        $results += @{ scenario = $scn; status = "pass"; note = "Scenario mapped in matrix" }
    } else {
        $allPass = $false
        $results += @{ scenario = $scn; status = "fail"; note = "Scenario missing from matrix mapping" }
    }
}

$result = @{
    bot = "world-explorer-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $allPass
    checks = $results
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[world-explorer-bot] Report: $output"
if (-not $allPass) { exit 1 }
exit 0

