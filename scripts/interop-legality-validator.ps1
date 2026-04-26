param(
    [string]$RepoRoot = "",
    [string]$ActionJsonPath = "",
    [switch]$FailOnInvalid
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

if ([string]::IsNullOrWhiteSpace($ActionJsonPath)) {
    $ActionJsonPath = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json"
}

if (-not (Test-Path $ActionJsonPath)) {
    throw "Action JSON not found: $ActionJsonPath"
}

$action = Get-Content $ActionJsonPath -Raw | ConvertFrom-Json

$reasonCodes = @()
$checks = @()

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$ReasonCode
    )

    $checks += @{
        check = $Name
        passed = $Passed
        reasonCode = $(if ($Passed) { "" } else { $ReasonCode })
    }

    if (-not $Passed) {
        $script:reasonCodes += $ReasonCode
    }
}

Add-Check "action_identity" (-not [string]::IsNullOrWhiteSpace($action.actionId) -and -not [string]::IsNullOrWhiteSpace($action.actorId)) "INT-LEG-001-MISSING_IDENTITY"
Add-Check "action_type" ($action.actionType -in @("magic", "tech", "hybrid")) "INT-LEG-002-INVALID_ACTION_TYPE"
Add-Check "scope_authority" ($null -ne $action.scope -and $action.scope.authorityScope -in @("personal", "party", "faction", "jurisdiction")) "INT-LEG-003-INVALID_SCOPE"
Add-Check "fact_access" (($null -ne $action.worldFactsRead -and $action.worldFactsRead.Count -gt 0) -and ($null -ne $action.worldFactsWrite -and $action.worldFactsWrite.Count -gt 0)) "INT-LEG-004-FACT_ACCESS_EMPTY"
Add-Check "replay_required" ($null -ne $action.replay -and $action.replay.required -eq $true) "INT-LEG-005-REPLAY_REQUIRED"

$hasTelemetry = $null -ne $action.telemetry -and $null -ne $action.telemetry.tags
$hasInteropTags = $hasTelemetry -and (@($action.telemetry.tags) -contains "magic") -and (@($action.telemetry.tags) -contains "tech")
Add-Check "telemetry_interop_tags" $hasInteropTags "INT-LEG-006-MISSING_INTEROP_TAGS"

$hasResourceCosts = $null -ne $action.resourceCosts
$hasMagicCost = $hasResourceCosts -and (($null -ne $action.resourceCosts.mana -and $action.resourceCosts.mana -gt 0) -or ($null -ne $action.resourceCosts.hpRisk -and $action.resourceCosts.hpRisk -gt 0))
$hasTechCost = $hasResourceCosts -and (($null -ne $action.resourceCosts.materials -and $action.resourceCosts.materials -gt 0) -or ($null -ne $action.resourceCosts.energy -and $action.resourceCosts.energy -gt 0))

if ($action.actionType -eq "hybrid") {
    Add-Check "hybrid_dual_channel_costs" ($hasMagicCost -and $hasTechCost) "INT-LEG-007-HYBRID_COST_CHANNELS_MISSING"
} else {
    Add-Check "non_hybrid_cost_presence" ($hasMagicCost -or $hasTechCost) "INT-LEG-008-NO_COST_CHANNEL"
}

$hasBudget = $null -ne $action.simBudget -and $null -ne $action.simBudget.estimatedCost -and $null -ne $action.simBudget.maxAllowedCost
Add-Check "sim_budget_declared" $hasBudget "INT-LEG-009-MISSING_SIM_BUDGET"
if ($hasBudget) {
    Add-Check "sim_budget_within_bounds" ($action.simBudget.estimatedCost -le $action.simBudget.maxAllowedCost) "INT-LEG-010-SIM_BUDGET_EXCEEDED"
}

$passed = $reasonCodes.Count -eq 0
$result = @{
    validator = "interop_legality_validator_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    actionId = $action.actionId
    passed = $passed
    reasonCodes = @($reasonCodes)
    checks = @($checks)
}

$resultJson = $result | ConvertTo-Json -Depth 8
Write-Output $resultJson

if ($FailOnInvalid -and -not $passed) {
    exit 1
}

exit 0
