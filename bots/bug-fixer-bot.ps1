param(
    [string]$RepoRoot = "",
    [string]$Mode = "suggest",
    [int]$MaxSuggestionsPerRun = 10
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[bug-fixer-bot] Starting in mode: $Mode"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "bug-fixer-bot-$timestamp.json"

$suggestions = @()

$reportRoot = Join-Path $RepoRoot "reports\bots"
if (Test-Path $reportRoot) {
    $recentReports = Get-ChildItem -Path $reportRoot -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 25
    foreach ($r in $recentReports) {
        if ($suggestions.Count -ge $MaxSuggestionsPerRun) { break }
        $raw = Get-Content $r.FullName -Raw
        if ($raw -match '"passed"\s*:\s*false' -or $raw -match '"status"\s*:\s*"fail"') {
            $suggestions += @{
                sourceReport = $r.Name
                suggestion = "Inspect failing checks and update script/config/docs. Re-run quality gate and orchestrator."
                risk = "low"
            }
        }
    }
}

if ($suggestions.Count -eq 0) {
    $suggestions += @{
        sourceReport = "none"
        suggestion = "No active failures detected. Keep monitoring and add real engine test command when available."
        risk = "none"
    }
}

$result = @{
    bot = "bug-fixer-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    mode = $Mode
    applied = $false
    passed = $true
    suggestions = $suggestions
    note = "Guardrail: bot is suggestion-only by default and does not auto-edit production files."
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[bug-fixer-bot] Report: $output"
exit 0

