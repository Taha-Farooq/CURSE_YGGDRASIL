param(
    [string]$RepoRoot = "",
    [string]$CanaryJsonPath = "",
    [string]$RollbackJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}
if ([string]::IsNullOrWhiteSpace($CanaryJsonPath)) {
    $CanaryJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-entity-canary-state-failing.json"
}
if ([string]::IsNullOrWhiteSpace($RollbackJsonPath)) {
    $RollbackJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-entity-rollback.json"
}
if (-not (Test-Path $CanaryJsonPath)) { throw "Missing canary state json: $CanaryJsonPath" }
if (-not (Test-Path $RollbackJsonPath)) { throw "Missing rollback json: $RollbackJsonPath" }

$state = Get-Content $CanaryJsonPath -Raw | ConvertFrom-Json
$rb = Get-Content $RollbackJsonPath -Raw | ConvertFrom-Json

$errorRate = [double]$state.errorRatePct
$latency = [double]$state.p95LatencyMs
$thresholdErr = [double]$state.thresholds.maxErrorRatePct
$thresholdP95 = [double]$state.thresholds.maxP95LatencyMs

$triggered = ($errorRate -gt $thresholdErr -or $latency -gt $thresholdP95)
$canRollback = (-not [string]::IsNullOrWhiteSpace([string]$rb.previousPackageId) -and -not [string]::IsNullOrWhiteSpace([string]$rb.currentPackageId))
$restoredPackageId = ""
if ($triggered -and $canRollback) { $restoredPackageId = [string]$rb.previousPackageId }

$result = @{
    service = "entity_package_rollback_trigger_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    packageId = [string]$state.packageId
    rollbackTriggered = $triggered
    canRollback = $canRollback
    restoredPackageId = $restoredPackageId
    reasonCodes = @(
        $(if ($triggered -and $errorRate -gt $thresholdErr) { "CANARY-ERROR-RATE-EXCEEDED" }),
        $(if ($triggered -and $latency -gt $thresholdP95) { "CANARY-LATENCY-EXCEEDED" }),
        $(if ($triggered -and -not $canRollback) { "ROLLBACK-PACKAGE-MISSING" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if ($triggered -and -not $canRollback) { exit 1 }
exit 0
