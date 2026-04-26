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
    & (Join-Path $repoRoot "scripts\dev-loop.ps1") -Strict:$Strict
    if ($LASTEXITCODE -ne 0) { throw "dev-loop failed with code $LASTEXITCODE" }
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
    }
    Start-Sleep -Seconds ($interval * 60)
}

