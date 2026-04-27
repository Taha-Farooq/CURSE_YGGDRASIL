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

# 8) Class systems.
$hasClassHeading = ($req -match [regex]::Escape("## 8) Class Systems"))
$hasBattleClassRule = ($req -match [regex]::Escape("- Battle classes: minimum 24 total."))
$hasTechnicalClassRule = ($req -match [regex]::Escape("- Technical classes: minimum 20 focused on automation, unit creation, infrastructure, devices, vehicles, and production."))
$hasMultiClassRule = ($req -match [regex]::Escape("- Players can combine up to 6 classes over progression with controlled loadout limits."))
$hasGrowthTreeRule = ($req -match [regex]::Escape("- Playstyle-driven/custom growth trees must emerge from actual behavior."))

# 11) Base autonomy and units.
$hasBaseHeading = ($req -match [regex]::Escape("## 11) Base Autonomy and Units"))
$hasBaseAutonomyRule = ($req -match [regex]::Escape("- Bases must run autonomously after task initiation:"))
$hasRemoteCommandRule = ($req -match [regex]::Escape("- Users can command remotely."))
$hasUnitCapRule = ($req -match [regex]::Escape("- Unit caps can exceed 1,000,000 only via abstraction tiers:"))

# 14) Civilization and world structure.
$hasCivilizationHeading = ($req -match [regex]::Escape("## 14) Civilization and World Structure"))
$hasCivilizationScopeRule = ($req -match [regex]::Escape("- Civilization scope:"))
$hasCohesionVariationRule = ($req -match [regex]::Escape("- Social cohesion varies by civilization/species branch."))
$hasSpacefaringRule = ($req -match [regex]::Escape("- Only 20 spacefaring civilizations exist at macro tier."))
$hasGeopoliticsRule = ($req -match [regex]::Escape("- Geopolitics includes multi-alliance long-term conflict, broker profiteering, and uplift suppression."))

# 18) Companion creatures.
$hasCompanionHeading = ($req -match [regex]::Escape("## 18) Companion Creatures"))
$hasElementalCreatureRule = ($req -match [regex]::Escape("- Include widely distributed cute elemental creatures."))
$hasElementalBalanceRule = ($req -match [regex]::Escape("- Elemental balance chart and spell-learning by type."))
$hasCaptureTrainRule = ($req -match [regex]::Escape("- Creatures can be captured, trained, assigned to combat/labor roles."))
$hasWelfareRule = ($req -match [regex]::Escape("- Welfare/obedience systems required to prevent pure exploit loops."))

Add-Check "class_systems_heading_defined" $hasClassHeading "requirements define class systems section"
Add-Check "class_systems_core_rules_defined" ($hasBattleClassRule -and $hasTechnicalClassRule -and $hasMultiClassRule -and $hasGrowthTreeRule) "requirements define battle/technical class counts, multiclass limits, and behavior-driven growth trees"

Add-Check "base_autonomy_units_heading_defined" $hasBaseHeading "requirements define base autonomy and units section"
Add-Check "base_autonomy_units_core_rules_defined" ($hasBaseAutonomyRule -and $hasRemoteCommandRule -and $hasUnitCapRule) "requirements define autonomous base operations, remote command, and abstraction-tier unit cap rules"

Add-Check "civilization_world_structure_heading_defined" $hasCivilizationHeading "requirements define civilization and world structure section"
Add-Check "civilization_world_structure_core_rules_defined" ($hasCivilizationScopeRule -and $hasCohesionVariationRule -and $hasSpacefaringRule -and $hasGeopoliticsRule) "requirements define civilization scale, cohesion variance, macro spacefaring cap, and geopolitical dynamics"

Add-Check "companion_creatures_heading_defined" $hasCompanionHeading "requirements define companion creatures section"
Add-Check "companion_creatures_core_rules_defined" ($hasElementalCreatureRule -and $hasElementalBalanceRule -and $hasCaptureTrainRule -and $hasWelfareRule) "requirements define elemental companion roster, learning balance, roles, and welfare/obedience safeguards"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "foundational_world_systems_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
