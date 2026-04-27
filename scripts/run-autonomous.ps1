param(
    [switch]$Once,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$configPath = Join-Path $repoRoot "automation\automation-config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$interval = [int]$config.loopIntervalMinutes

function RunCycle {
    Write-Host "[run-autonomous] Cycle started at $(Get-Date -Format s)"
    & (Join-Path $repoRoot "scripts\ensure-program-exes.ps1")
    if (-not $?) { throw "ensure-program-exes failed." }

    & (Join-Path $repoRoot "scripts\dev-loop.ps1") -Strict:$Strict
    if (-not $?) { throw "dev-loop failed." }

    try {
        & (Join-Path $repoRoot "scripts\autonomous-readiness-report.ps1") -RepoRoot $repoRoot -WriteReport | Out-Null
        Write-Host "[run-autonomous] Updated autonomous readiness report."
    }
    catch {
        Write-Host "[run-autonomous] Readiness report generation warning: $($_.Exception.Message)"
    }
}

if ($Once) {
    RunCycle
    Write-Host "[run-autonomous] One-shot run completed."
    exit 0
}

Write-Host "[run-autonomous] Continuous mode every $interval minutes."
while ($true) {
    try {
        RunCycle
    }
    catch {
        Write-Host "[run-autonomous] ERROR: $($_.Exception.Message)"
        try {
            Write-Host "[run-autonomous] Running auto-heal sequence..."
            & (Join-Path $repoRoot "scripts\auto-heal-on-failure.ps1") -RepoRoot $repoRoot -Strict:$Strict
        }
        catch {
            Write-Host "[run-autonomous] Auto-heal failed: $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds ($interval * 60)
}

