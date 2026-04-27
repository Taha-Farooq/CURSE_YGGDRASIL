param(
    [string]$RepoRoot = "",
    [string]$CouplerOutputJsonPath = "",
    [string]$CastRequestJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($CouplerOutputJsonPath)) {
    $CouplerOutputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-policy-stability-output.json"
}
if ([string]::IsNullOrWhiteSpace($CastRequestJsonPath)) {
    $CastRequestJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-cast-request.json"
}
if (-not (Test-Path $CouplerOutputJsonPath)) { throw "Missing coupler output json: $CouplerOutputJsonPath" }
if (-not (Test-Path $CastRequestJsonPath)) { throw "Missing cast request json: $CastRequestJsonPath" }

$stability = Get-Content $CouplerOutputJsonPath -Raw | ConvertFrom-Json
$cast = Get-Content $CastRequestJsonPath -Raw | ConvertFrom-Json

$requestedTier = [int]$cast.requestedTier
$maxTier = [int]$stability.maxAllowedCastTier
$allowed = ($requestedTier -le $maxTier)

$reasonCodes = @()
if (-not $allowed) { $reasonCodes += "AUTH-POLICY-STABILITY-TIER-BLOCKED" }

$result = @{
    service = "magic_stability_gate_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    polityId = [string]$stability.polityId
    castId = [string]$cast.castId
    allowed = $allowed
    requestedTier = $requestedTier
    maxAllowedCastTier = $maxTier
    stabilityScore = [double]$stability.stabilityScore
    reasonCodes = $reasonCodes
    replayEvidence = @{
        required = $true
        tags = @("phase2", "policy_magic_stability", "cast_gate")
    }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $allowed) { exit 1 }
exit 0
