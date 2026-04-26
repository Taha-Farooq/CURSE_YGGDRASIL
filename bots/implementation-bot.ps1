param(
    [string]$RepoRoot = "",
    [string]$Mode = "scaffold_only",
    [int]$MaxFileChangesPerRun = 20
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[implementation-bot] Starting in mode: $Mode"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
$plansDir = Join-Path $RepoRoot "implementation-plans"
$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
if (-not (Test-Path $plansDir)) { New-Item -ItemType Directory -Path $plansDir -Force | Out-Null }
$output = Join-Path $botDir "implementation-bot-$timestamp.json"

$tasks = @()
if (Test-Path $tasksPath) {
    $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
}

$todo = @($tasks | Where-Object { $_.status -eq "todo" } | Select-Object -First ([Math]::Min(5, $MaxFileChangesPerRun)))
$planned = @()
foreach ($t in $todo) {
    $planFile = Join-Path $plansDir ($t.id + ".md")
    if (-not (Test-Path $planFile)) {
        $text = @"
# $($t.id) - $($t.title)

## Goal
Implement this requirement in a safe, testable, incremental way.

## Steps
1. Define interfaces and data schema.
2. Add validator and authority checks.
3. Add telemetry and replay events.
4. Add tests and matrix updates.

## Acceptance
- Quality gate pass
- Bot orchestrator pass
- Integration tests linked in matrix
"@
        Set-Content -Path $planFile -Value $text -Encoding UTF8
        $planned += $t.id
    }
}

$result = @{
    bot = "implementation-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    mode = $Mode
    planFilesCreated = $planned
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[implementation-bot] Report: $output"
exit 0

