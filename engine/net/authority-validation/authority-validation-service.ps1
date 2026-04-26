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

$reasonCodeContractPath = Join-Path $RepoRoot "systems\networking\AUTHORITY_REASON_CODES.json"
if (-not (Test-Path $reasonCodeContractPath)) {
    throw "Missing authority reason-code contract: $reasonCodeContractPath"
}
$reasonCodeContract = Get-Content $reasonCodeContractPath -Raw | ConvertFrom-Json
$map = $reasonCodeContract.interopCodeMapping
$fallbackCode = $reasonCodeContract.fallbackCode

$authReasonCodes = @()
foreach ($code in @($interop.reasonCodes)) {
    if ($null -ne $map.$code) {
        $authReasonCodes += $map.$code
    } else {
        $authReasonCodes += $fallbackCode
    }
}

$decision = @{
    service = "authority_validation_service_v1"
    validatorVersion = "v1"
    reasonCodeContractVersion = $reasonCodeContract.version
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
