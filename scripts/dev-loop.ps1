param(
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
Write-Host "[dev-loop] Running one-person team loop..."

function Step($name, [scriptblock]$action) {
    Write-Host ("[dev-loop] STEP: " + $name)
    & $action
}

Step "Quality Gate" { & "$PSScriptRoot\quality-gate.ps1" @PSBoundParameters }
Step "Bot Orchestrator" { & "$PSScriptRoot\..\bots\orchestrator.ps1" @PSBoundParameters }

Step "Generate Daily Summary" {
    $now = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $outDir = Join-Path $PSScriptRoot "..\reports"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
    $reportPath = Join-Path $outDir "daily-summary-$now.md"

    $content = @"
# Daily Summary ($now)

## Status
- Quality gate: PASS

## Next Actions
- Review new feedback items (if any) against FEEDBACK_SCHEMA.
- Prioritize top 3 issues by impact + recurrence + thematic damage.
- Run targeted playtest for changed systems.
- Update INTERACTION_MATRIX.md for any cross-system changes.
"@
    Set-Content -Path $reportPath -Value $content -Encoding UTF8
    Write-Host "[dev-loop] Wrote $reportPath"
}

Step "Release Readiness Snapshot" {
    $snapshotScript = Join-Path $PSScriptRoot "generate-release-readiness-snapshot.ps1"
    $snapshotPath = & $snapshotScript
    Write-Host "[dev-loop] Wrote $snapshotPath"
}

Write-Host "[dev-loop] COMPLETE"
exit 0

