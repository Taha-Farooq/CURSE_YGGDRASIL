param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-route-clearability-signals.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing route clearability signals json: $InputJsonPath" }

$payload = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$signals = @($payload.signals)

$normalized = @()
foreach ($s in $signals) {
    $clearability = [double]$s.clearabilityScore
    if ($clearability -lt 0.0) { $clearability = 0.0 }
    if ($clearability -gt 1.0) { $clearability = 1.0 }

    $friction = [double]$s.frictionScore
    if ($friction -lt 0.0) { $friction = 0.0 }
    if ($friction -gt 1.0) { $friction = 1.0 }

    $normalized += @{
        routeId = [string]$s.routeId
        regionId = [string]$s.regionId
        clearabilityScore = [math]::Round($clearability, 3)
        frictionScore = [math]::Round($friction, 3)
        failureRate = [double]$s.failureRate
        diplomacyFriction = [math]::Round([double]$s.diplomacyFriction, 3)
        socialBiasTrustDelta = [int]$s.socialBiasTrustDelta
        sourceReport = [string]$s.sourceReport
        trace = @{
            signalSource = "route_clearability_signal_ingestor_v1"
            replayRequired = $true
        }
    }
}

$result = @{
    service = "route_clearability_signal_ingestor_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    signalCount = @($normalized).Count
    weights = $payload.weights
    signals = $normalized
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
