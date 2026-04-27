param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-policy-state.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing policy state input: $InputJsonPath" }

$policy = Get-Content $InputJsonPath -Raw | ConvertFrom-Json

$ethics = [double]$policy.ethicalMaturityIndex
$cohesion = [double]$policy.socialCohesionIndex
$castePressure = [double]$policy.casteSuppressionIndex
$arcaneLiteracy = [double]$policy.arcaneLiteracyIndex
$wartime = [bool]$policy.wartimeEmergencyPowers

$baseStability = (($ethics * 0.35) + ($cohesion * 0.25) + ($arcaneLiteracy * 0.4)) - ($castePressure * 0.45)
if ($wartime) { $baseStability -= 0.2 }
$stabilityScore = [math]::Round([math]::Max(0.0, [math]::Min(1.0, $baseStability)), 3)

$tierCap = 8
if ($stabilityScore -ge 0.85) { $tierCap = 11 }
elseif ($stabilityScore -ge 0.7) { $tierCap = 10 }
elseif ($stabilityScore -ge 0.5) { $tierCap = 9 }

$result = @{
    service = "policy_magic_stability_coupler_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    polityId = [string]$policy.polityId
    stabilityScore = $stabilityScore
    maxAllowedCastTier = $tierCap
    drivers = @{
        ethicalMaturityIndex = $ethics
        socialCohesionIndex = $cohesion
        casteSuppressionIndex = $castePressure
        arcaneLiteracyIndex = $arcaneLiteracy
        wartimeEmergencyPowers = $wartime
    }
    audit = @{
        reasonCode = "POL-STABILITY-001"
        source = "policy_magic_stability_coupler_v1"
    }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
