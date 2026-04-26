param(
    [string]$RepoRoot = "",
    [bool]$AutoScaffold = $false
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[system-builder-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
$systemsDir = Join-Path $RepoRoot "systems"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
if (-not (Test-Path $systemsDir)) { New-Item -ItemType Directory -Path $systemsDir -Force | Out-Null }
$output = Join-Path $botDir "system-builder-bot-$timestamp.json"

$targets = @(
    @{ path = "systems/networking/AUTHORITY_VALIDATION_SPEC.md"; title = "Authority Validation Spec" },
    @{ path = "systems/replay/INTERACTION_REPLAY_SPEC.md"; title = "Interaction Replay Spec" },
    @{ path = "systems/simulation/TIERED_WORLD_SIM_SPEC.md"; title = "Tiered World Simulation Spec" },
    @{ path = "systems/magic/ARCANE_RUNTIME_SPEC.md"; title = "Arcane Runtime Spec" },
    @{ path = "systems/ai/NPC_LEARNING_SPEC.md"; title = "NPC Learning Spec" }
)

$created = @()
if ($AutoScaffold) {
    foreach ($t in $targets) {
        $abs = Join-Path $RepoRoot $t.path
        $dir = Split-Path $abs -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if (-not (Test-Path $abs)) {
            $content = @"
# $($t.title)

## Purpose
Define implementation-ready requirements and interfaces for this subsystem.

## Contracts
- Inputs
- Outputs
- Validation path
- Failure modes

## Data Model
- Entity/schema definitions

## Runtime
- Tick/update rules
- Authority model

## Telemetry and Replay
- Required events

## Tests
- Unit tests
- Integration tests
- Regression tests
"@
            Set-Content -Path $abs -Value $content -Encoding UTF8
            $created += $t.path
        }
    }
}

$result = @{
    bot = "system-builder-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    autoScaffold = $AutoScaffold
    createdFiles = $created
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[system-builder-bot] Report: $output"
exit 0

