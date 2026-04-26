param(
    [string]$RepoRoot = "",
    [double]$MinScore = 0.75
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[route-clearability-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "route-clearability-bot-$timestamp.json"

$matrix = Get-Content (Join-Path $RepoRoot "INTERACTION_MATRIX.md") -Raw

# Heuristic seed: each required scenario mapped counts as clearability confidence.
$required = @("SCN-001", "SCN-002", "SCN-003", "SCN-004")
$found = 0
foreach ($s in $required) {
    if ($matrix -match [regex]::Escape($s)) { $found++ }
}
$score = [Math]::Round(($found / $required.Count), 2)
$pass = $score -ge $MinScore

$result = @{
    bot = "route-clearability-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    minScore = $MinScore
    clearabilityScore = $score
    passed = $pass
    detail = "Seed heuristic. Replace with runtime traversal metrics when game executable is available."
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[route-clearability-bot] Report: $output"
if (-not $pass) { exit 1 }
exit 0

