param(
    [string]$RepoRoot = "",
    [string]$SignalsJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($SignalsJsonPath)) {
    $SignalsJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-route-clearability-ingested.json"
}
if (-not (Test-Path $SignalsJsonPath)) { throw "Missing ingested signals json: $SignalsJsonPath" }

$payload = Get-Content $SignalsJsonPath -Raw | ConvertFrom-Json
$signals = @($payload.signals)
$weights = $payload.weights
$weightClearability = 0.42
$weightFriction = 0.23
$weightFailure = 0.20
$weightDiplomacy = 0.10
$maxSocialBiasPenalty = 0.20
if ($null -ne $weights) {
    if ($null -ne $weights.clearability) { $weightClearability = [double]$weights.clearability }
    if ($null -ne $weights.friction) { $weightFriction = [double]$weights.friction }
    if ($null -ne $weights.failureRate) { $weightFailure = [double]$weights.failureRate }
    if ($null -ne $weights.diplomacyFriction) { $weightDiplomacy = [double]$weights.diplomacyFriction }
    if ($null -ne $weights.maxSocialBiasPenalty) { $maxSocialBiasPenalty = [double]$weights.maxSocialBiasPenalty }
}

$ranked = @()
foreach ($s in $signals) {
    $clearabilityPenalty = (1.0 - [double]$s.clearabilityScore)
    $friction = [double]$s.frictionScore
    $failure = [double]$s.failureRate
    $diplomacyFriction = [double]$s.diplomacyFriction
    if ($diplomacyFriction -lt 0.0) { $diplomacyFriction = 0.0 }
    if ($diplomacyFriction -gt 1.0) { $diplomacyFriction = 1.0 }
    $socialBiasTrustDelta = [int]$s.socialBiasTrustDelta
    $socialBiasPenalty = [math]::Min($maxSocialBiasPenalty, [math]::Max(0.0, ((-1.0 * $socialBiasTrustDelta) / 100.0)))

    $risk = [math]::Round((($clearabilityPenalty * $weightClearability) + ($friction * $weightFriction) + ($failure * $weightFailure) + ($diplomacyFriction * $weightDiplomacy) + $socialBiasPenalty), 4)

    $ranked += @{
        routeId = [string]$s.routeId
        regionId = [string]$s.regionId
        riskScore = $risk
        clearabilityScore = [double]$s.clearabilityScore
        frictionScore = $friction
        failureRate = $failure
        diplomacyFriction = $diplomacyFriction
        socialBiasTrustDelta = $socialBiasTrustDelta
        socialBiasPenalty = [math]::Round($socialBiasPenalty, 4)
        sourceReport = [string]$s.sourceReport
        trace = @{
            scorer = "weighted_route_risk_scorer_v1"
            replayRequired = $true
        }
    }
}

$ranked = @($ranked | Sort-Object -Property @{ Expression = { $_.riskScore }; Descending = $true })
$highRisk = @($ranked | Where-Object { [double]$_.riskScore -ge 0.5 })

$result = @{
    service = "weighted_route_risk_scorer_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    weights = @{
        clearability = $weightClearability
        friction = $weightFriction
        failureRate = $weightFailure
        diplomacyFriction = $weightDiplomacy
        maxSocialBiasPenalty = $maxSocialBiasPenalty
    }
    routeCount = @($ranked).Count
    highRiskCount = @($highRisk).Count
    topRiskRoutes = @($ranked | Select-Object -First 3)
    rankedRoutes = $ranked
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
