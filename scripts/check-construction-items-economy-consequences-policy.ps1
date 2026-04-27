param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reqPath = Join-Path $RepoRoot "REQUIREMENTS.md"
if (-not (Test-Path $reqPath)) { throw "Missing REQUIREMENTS.md" }
$req = Get-Content $reqPath -Raw

$checks = @()
function Add-Check([string]$name, [bool]$passed, [string]$details) {
    $script:checks += @{ check = $name; passed = $passed; details = $details }
}

# 10) Construction and Building.
$hasConstructionHeading = ($req -match [regex]::Escape("## 10) Construction and Building"))
$hasConstructionGatedRule = ($req -match [regex]::Escape("- Building power is gated by Construction Magic progression."))
$hasConstructionGovernsRule = ($req -match [regex]::Escape("- Construction Magic governs:"))
$hasDeconstructionGapRule = ($req -match [regex]::Escape("- Lower-level deconstruction of higher-level builds is allowed only within limited gap windows (target: approx 5-level complexity gap)."))

# 12) Items and Artifacts.
$hasItemsHeading = ($req -match [regex]::Escape("## 12) Items and Artifacts"))
$hasItemSystemRule = ($req -match [regex]::Escape("- Item system must include:"))
$hasEquipmentConditionRule = ($req -match [regex]::Escape("- Equipment customization and condition are mandatory:"))
$hasArtifactCountRule = ($req -match [regex]::Escape("  - Total exactly 99."))
$hasAntiMagicCounterRule = ($req -match [regex]::Escape("- Non-magic users must have robust anti-magic itemized counters."))

# 13) Economy, Crafting, and Logistics.
$hasEconomyHeading = ($req -match [regex]::Escape("## 13) Economy, Crafting, and Logistics"))
$hasCraftingDepthRule = ($req -match [regex]::Escape("- Crafting depth inspired by complex sandbox crafting ecosystems but not copied."))
$hasLogisticsInventoryRule = ($req -match [regex]::Escape("- Inventory model must support:"))
$hasLocationCurrencyRule = ($req -match [regex]::Escape("- Market pricing must vary by location and kingdom context (for example regional demand, logistics friction, trade risk, and kingdom tax/subsidy policy)."))
$hasCurrencyConversionRule = ($req -match [regex]::Escape("- Economy calculations must support kingdom/local currency differences with deterministic conversion into quoted currencies for audits and cross-store comparison."))

# 20) Consequences and Permanence.
$hasConsequencesHeading = ($req -match [regex]::Escape("## 20) Consequences and Permanence"))
$hasDecisionImpactRule = ($req -match [regex]::Escape("- Small and large decisions must matter."))
$hasDurableImpactRule = ($req -match [regex]::Escape("- Effects can decay selectively, but major actions must have durable world impact."))
$hasHistoricalTraceRule = ($req -match [regex]::Escape("- World state must retain historical memory and cause-effect traceability."))

Add-Check "construction_building_heading_defined" $hasConstructionHeading "requirements define construction and building section"
Add-Check "construction_building_core_rules_defined" ($hasConstructionGatedRule -and $hasConstructionGovernsRule -and $hasDeconstructionGapRule) "requirements define construction progression gate, governed dimensions, and deconstruction gap window"

Add-Check "items_artifacts_heading_defined" $hasItemsHeading "requirements define items and artifacts section"
Add-Check "items_artifacts_core_rules_defined" ($hasItemSystemRule -and $hasEquipmentConditionRule -and $hasArtifactCountRule -and $hasAntiMagicCounterRule) "requirements define item system, condition model, world artifact cap, and anti-magic counters"

Add-Check "economy_crafting_logistics_heading_defined" $hasEconomyHeading "requirements define economy/crafting/logistics section"
Add-Check "economy_crafting_logistics_core_rules_defined" ($hasCraftingDepthRule -and $hasLogisticsInventoryRule -and $hasLocationCurrencyRule -and $hasCurrencyConversionRule) "requirements define crafting depth, logistics inventory model, and deterministic regional/currency pricing rules"

Add-Check "consequences_permanence_heading_defined" $hasConsequencesHeading "requirements define consequences and permanence section"
Add-Check "consequences_permanence_core_rules_defined" ($hasDecisionImpactRule -and $hasDurableImpactRule -and $hasHistoricalTraceRule) "requirements define decision impact, durable world effects, and historical traceability"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "construction_items_economy_consequences_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
