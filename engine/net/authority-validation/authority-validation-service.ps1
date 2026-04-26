param(
    [string]$RepoRoot = "",
    [string]$ActionJsonPath = "",
    [switch]$FailOnReject
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($ActionJsonPath)) {
    $ActionJsonPath = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json"
}

$interopValidator = Join-Path $RepoRoot "scripts\interop-legality-validator.ps1"
if (-not (Test-Path $interopValidator)) {
    throw "Missing interop validator: $interopValidator"
}
if (-not (Test-Path $ActionJsonPath)) {
    throw "Missing action json: $ActionJsonPath"
}

$interop = (& $interopValidator -RepoRoot $RepoRoot -ActionJsonPath $ActionJsonPath) | ConvertFrom-Json
$action = Get-Content $ActionJsonPath -Raw | ConvertFrom-Json

$map = @{
    "INT-LEG-001-MISSING_IDENTITY" = "AUTH-INPUT-001"
    "INT-LEG-002-INVALID_ACTION_TYPE" = "AUTH-INPUT-002"
    "INT-LEG-003-INVALID_SCOPE" = "AUTH-SCOPE-001"
    "INT-LEG-004-FACT_ACCESS_EMPTY" = "AUTH-INTEROP-001"
    "INT-LEG-005-REPLAY_REQUIRED" = "AUTH-INTEROP-002"
    "INT-LEG-006-MISSING_INTEROP_TAGS" = "AUTH-INTEROP-003"
    "INT-LEG-007-HYBRID_COST_CHANNELS_MISSING" = "AUTH-INTEROP-004"
    "INT-LEG-008-NO_COST_CHANNEL" = "AUTH-BUDGET-002"
    "INT-LEG-009-MISSING_SIM_BUDGET" = "AUTH-BUDGET-001"
    "INT-LEG-010-SIM_BUDGET_EXCEEDED" = "AUTH-BUDGET-001"
}

$authReasonCodes = @()
foreach ($code in @($interop.reasonCodes)) {
    if ($map.ContainsKey($code)) {
        $authReasonCodes += $map[$code]
    } else {
        $authReasonCodes += "AUTH-STATE-001"
    }
}

$decision = @{
    service = "authority_validation_service_v1"
    validatorVersion = "v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    actionId = $action.actionId
    actorId = $action.actorId
    allowed = [bool]$interop.passed
    reasonCodes = @($authReasonCodes)
    rawInteropReasonCodes = @($interop.reasonCodes)
    replayMetadata = @{
        required = ($null -ne $action.replay -and $action.replay.required -eq $true)
        authorityDecisionId = "$($action.actionId):authority:v1"
        eventTags = @("authority", "validation", "$($action.actionType)")
    }
}

$decisionJson = $decision | ConvertTo-Json -Depth 8
Write-Output $decisionJson

if ($FailOnReject -and -not $decision.allowed) {
    exit 1
}
exit 0
