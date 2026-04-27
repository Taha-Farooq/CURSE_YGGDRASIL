param(
    [string]$TemperamentJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($TemperamentJsonPath)) {
    $TemperamentJsonPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")) "tests\fixtures\phase1-demon-lord-temperament.json"
}
if (-not (Test-Path $TemperamentJsonPath)) { throw "Missing temperament json: $TemperamentJsonPath" }

$profile = Get-Content $TemperamentJsonPath -Raw | ConvertFrom-Json
$t = [string]$profile.temperament
$mod = switch ($t) {
    "hostile" { @{ diplomacyDelta = -30; hostility = "high"; commandStyle = "aggressive" } }
    "friendly" { @{ diplomacyDelta = 20; hostility = "low"; commandStyle = "cooperative" } }
    "pragmatic" { @{ diplomacyDelta = 5; hostility = "medium"; commandStyle = "strategic" } }
    "chaotic" { @{ diplomacyDelta = -10; hostility = "volatile"; commandStyle = "unpredictable" } }
    "lawful" { @{ diplomacyDelta = 10; hostility = "controlled"; commandStyle = "structured" } }
    default { @{ diplomacyDelta = 0; hostility = "unknown"; commandStyle = "neutral" } }
}

$actorSpecies = [string]$profile.actorSpecies
$targetSpecies = [string]$profile.targetSpecies
$sameSpecies = (-not [string]::IsNullOrWhiteSpace($actorSpecies) -and $actorSpecies -eq $targetSpecies)

$actorIncomeTier = [string]$profile.actorProfile.incomeTier
$targetIncomeTier = [string]$profile.targetProfile.incomeTier
$actorHometown = [string]$profile.actorProfile.hometown
$targetHometown = [string]$profile.targetProfile.hometown
$actorAlliances = @($profile.actorProfile.nationalAlliances)
$targetAlliances = @($profile.targetProfile.nationalAlliances)
$actorVendettas = @($profile.actorProfile.personalVendettas) + @($profile.actorProfile.familyVendettas)

$driverBreakdown = @{
    incomeTierDelta = 0
    hometownRivalry = 0
    allianceConflict = 0
    eventsPressure = 0
    vendettaPressure = 0
}

if ($sameSpecies) {
    if (-not [string]::IsNullOrWhiteSpace($actorIncomeTier) -and -not [string]::IsNullOrWhiteSpace($targetIncomeTier) -and $actorIncomeTier -ne $targetIncomeTier) {
        $driverBreakdown.incomeTierDelta = 8
    }
    if (-not [string]::IsNullOrWhiteSpace($actorHometown) -and -not [string]::IsNullOrWhiteSpace($targetHometown) -and $actorHometown -ne $targetHometown) {
        $driverBreakdown.hometownRivalry = 6
    }

    $sharedAlliances = @($actorAlliances | Where-Object { $targetAlliances -contains $_ })
    if (@($actorAlliances).Count -gt 0 -and @($targetAlliances).Count -gt 0 -and @($sharedAlliances).Count -eq 0) {
        $driverBreakdown.allianceConflict = 9
    }

    $eventsPressure = 0
    foreach ($e in @($profile.socialEvents)) {
        $eventType = [string]$e.type
        $impact = [int]$e.impact
        if ($eventType -in @("political", "war", "recent_conflict", "historical_grievance")) {
            $eventsPressure += [Math]::Max(0, $impact)
        }
    }
    $driverBreakdown.eventsPressure = [Math]::Min(20, $eventsPressure)

    $vendettaPressure = 0
    foreach ($v in @($actorVendettas)) {
        if ([string]$v.targetId -eq [string]$profile.targetId) {
            $vendettaPressure += [Math]::Max(0, [int]$v.severity)
        }
    }
    $driverBreakdown.vendettaPressure = [Math]::Min(20, $vendettaPressure)
}

$intraSpeciesPrejudiceScore = [int](
    [int]$driverBreakdown.incomeTierDelta +
    [int]$driverBreakdown.hometownRivalry +
    [int]$driverBreakdown.allianceConflict +
    [int]$driverBreakdown.eventsPressure +
    [int]$driverBreakdown.vendettaPressure
)

$trustDelta = if ($sameSpecies) { -1 * [Math]::Round($intraSpeciesPrejudiceScore * 0.7) } else { 0 }
$obedienceDelta = if ($sameSpecies) { -1 * [Math]::Round($intraSpeciesPrejudiceScore * 0.45) } else { 0 }
$conflictLikelihoodDelta = if ($sameSpecies) { [Math]::Round($intraSpeciesPrejudiceScore * 0.5) } else { 0 }

$reasonCodes = @()
if ($sameSpecies -and $intraSpeciesPrejudiceScore -gt 0) { $reasonCodes += "AUTH-SOC-INTRASPECIES-PREJUDICE-DRIVERS-APPLIED" }
if ($sameSpecies -and $driverBreakdown.vendettaPressure -gt 0) { $reasonCodes += "AUTH-SOC-INTRASPECIES-VENDETTA-PRESSURE-APPLIED" }
if ($sameSpecies -and $driverBreakdown.eventsPressure -gt 0) { $reasonCodes += "AUTH-SOC-INTRASPECIES-POLITICAL-WAR-EVENT-PRESSURE-APPLIED" }

$result = @{
    evaluator = "demon_lord_temperament_profile_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    demonLordId = [string]$profile.demonLordId
    temperament = $t
    modifiers = $mod
    socialBias = @{
        sameSpecies = $sameSpecies
        actorSpecies = $actorSpecies
        targetSpecies = $targetSpecies
        prejudiceScore = $intraSpeciesPrejudiceScore
        drivers = $driverBreakdown
        trustDelta = $trustDelta
        obedienceDelta = $obedienceDelta
        conflictLikelihoodDelta = $conflictLikelihoodDelta
    }
    deterministic = $true
    authorityValidated = $true
    reasonCodes = @($reasonCodes | Select-Object -Unique)
}
$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
