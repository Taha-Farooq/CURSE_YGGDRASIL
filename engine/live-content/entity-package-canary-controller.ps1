param(
    [string]$RepoRoot = "",
    [string]$CanaryJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}
if ([string]::IsNullOrWhiteSpace($CanaryJsonPath)) {
    $CanaryJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-entity-canary-state.json"
}
if (-not (Test-Path $CanaryJsonPath)) { throw "Missing canary state json: $CanaryJsonPath" }

$state = Get-Content $CanaryJsonPath -Raw | ConvertFrom-Json
$phase = [string]$state.phase
$errorRate = [double]$state.errorRatePct
$latency = [double]$state.p95LatencyMs
$thresholdErr = [double]$state.thresholds.maxErrorRatePct
$thresholdP95 = [double]$state.thresholds.maxP95LatencyMs

$nextPhase = $phase
$promotionAllowed = $false
switch ($phase) {
    "shadow" {
        if ($errorRate -le $thresholdErr -and $latency -le $thresholdP95) { $nextPhase = "canary_10" }
    }
    "canary_10" {
        if ($errorRate -le $thresholdErr -and $latency -le $thresholdP95) { $nextPhase = "canary_50" }
    }
    "canary_50" {
        if ($errorRate -le $thresholdErr -and $latency -le $thresholdP95) {
            $nextPhase = "full"
            $promotionAllowed = $true
        }
    }
    "full" {
        $promotionAllowed = $true
    }
}

$result = @{
    service = "live_entity_package_canary_controller_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    packageId = [string]$state.packageId
    previousPhase = $phase
    nextPhase = $nextPhase
    promotionAllowed = $promotionAllowed
    health = @{
        errorRatePct = $errorRate
        p95LatencyMs = $latency
        thresholdErrorRatePct = $thresholdErr
        thresholdP95LatencyMs = $thresholdP95
    }
    replayEvidence = @{
        required = $true
        tags = @("phase2", "canary_controller")
    }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
