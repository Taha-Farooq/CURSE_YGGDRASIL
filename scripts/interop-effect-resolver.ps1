param(
    [string]$ActionJsonPath = "",
    [string]$EnvironmentJsonPath = "",
    [switch]$FailOnInvalid
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ActionJsonPath)) {
    throw "ActionJsonPath is required."
}
if ([string]::IsNullOrWhiteSpace($EnvironmentJsonPath)) {
    throw "EnvironmentJsonPath is required."
}
if (-not (Test-Path $ActionJsonPath)) {
    throw "Action JSON not found: $ActionJsonPath"
}
if (-not (Test-Path $EnvironmentJsonPath)) {
    throw "Environment JSON not found: $EnvironmentJsonPath"
}

$action = Get-Content $ActionJsonPath -Raw | ConvertFrom-Json
$envState = Get-Content $EnvironmentJsonPath -Raw | ConvertFrom-Json

$reasonCodes = @()
$checks = @()

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$ReasonCode
    )

    $script:checks += @{
        check = $Name
        passed = $Passed
        reasonCode = $(if ($Passed) { "" } else { $ReasonCode })
    }
    if (-not $Passed) {
        $script:reasonCodes += $ReasonCode
    }
}

Add-Check "action_id_present" (-not [string]::IsNullOrWhiteSpace($action.actionId)) "INT-RES-001-MISSING_ACTION_ID"
Add-Check "effect_profile_present" ($null -ne $action.effectProfile -and $null -ne $action.effectProfile.basePower) "INT-RES-002-MISSING_EFFECT_PROFILE"
Add-Check "replay_required" ($null -ne $action.replay -and $action.replay.required -eq $true) "INT-RES-003-REPLAY_REQUIRED"
Add-Check "environment_context_present" ($null -ne $envState.environmentId) "INT-RES-004-MISSING_ENVIRONMENT_ID"

$passed = $reasonCodes.Count -eq 0
$basePower = if ($passed) { [double]$action.effectProfile.basePower } else { 0.0 }
$multiplier = 1.0
$modifiers = @()

if ($passed) {
    if ($envState.techSuppressionField -eq $true) {
        $multiplier *= 0.6
        $modifiers += "tech_suppression"
    }
    if ($null -ne $envState.leylineIntensity) {
        $leylineFactor = [double]$envState.leylineIntensity
        if ($leylineFactor -lt 0.5) { $leylineFactor = 0.5 }
        if ($leylineFactor -gt 2.0) { $leylineFactor = 2.0 }
        $multiplier *= $leylineFactor
        $modifiers += "leyline_intensity"
    }
    if ($null -ne $envState.stormChargeBonus) {
        $basePower += [double]$envState.stormChargeBonus
        $modifiers += "storm_charge_bonus"
    }
}

$resolvedPower = [math]::Round(($basePower * $multiplier), 2)
$status = if ($passed) { "applied" } else { "rejected" }
$replayEvidence = @{
    replayRequired = ($null -ne $action.replay -and $action.replay.required -eq $true)
    replayFrameToken = $(if ($passed) { "$($action.actionId):$($envState.environmentId):frame-001" } else { "" })
    replayEventCount = $(if ($passed) { 3 } else { 0 })
}

$result = @{
    resolver = "interop_effect_resolver_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    actionId = $action.actionId
    environmentId = $envState.environmentId
    passed = $passed
    status = $status
    resolvedPower = $resolvedPower
    modifiers = $modifiers
    reasonCodes = @($reasonCodes)
    checks = @($checks)
    replayEvidence = $replayEvidence
}

$resultJson = $result | ConvertTo-Json -Depth 8
Write-Output $resultJson

if ($FailOnInvalid -and -not $passed) {
    exit 1
}
exit 0
