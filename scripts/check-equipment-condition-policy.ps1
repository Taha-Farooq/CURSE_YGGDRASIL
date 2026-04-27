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

$hasCustomizationRule = ($req -match [regex]::Escape("All equipment must carry custom variation from at least: construction item tiers, durability state, craftsmanship quality, age, and maintenance condition."))
$hasEffectivenessRule = ($req -match [regex]::Escape("Equipment effectiveness/value must deterministically reflect those factors (newer, well-kept, well-crafted items perform better than degraded equivalents at same base tier)."))
$hasLootCraftFlowRule = ($req -match [regex]::Escape("Loot generation and crafting outputs must both emit these condition factors at runtime for downstream systems."))
$hasEconomyCombatFlowRule = ($req -match [regex]::Escape("Combat effectiveness and market pricing must directly consume condition factors/multipliers during runtime resolution."))
$hasTemporaryEnchantRule = ($req -match [regex]::Escape("Items must support temporary enchantments with explicit duration/expiry and deterministic runtime activation/deactivation."))
$hasPermanentEnchantRule = ($req -match [regex]::Escape("Items must support permanent enchantments that persist until explicitly removed or replaced by valid authority workflows."))
$hasRuneRule = ($req -match [regex]::Escape("Items must support rune sockets/attachments that contribute deterministic modifier effects and legality constraints."))
$hasIntegratedScriptRule = ($req -match [regex]::Escape("Items may embed integrated magic scripts for automation or complex magical equipment behavior (for example bombs, drones, chained triggers) through authority-validated script manifests."))
$hasContextualModifierRule = ($req -match [regex]::Escape("Item modifiers must support logical bonuses/decrements gated by context including magical state, set membership, environment, user profile, class, race, subclass, and item condition bands."))
$hasModifierDeterminismRule = ($req -match [regex]::Escape("Modifier stacking, conflict resolution, and final outputs must remain deterministic, authority-validated, and replay-auditable with explicit reason codes."))
$hasQualifiedMintRule = ($req -match [regex]::Escape("Restoring equipment to true mint condition requires repair by a qualified craftsman profile; non-qualified repairs may restore function but cannot certify mint."))
$hasAuthorityAuditRule = ($req -match [regex]::Escape("Condition updates and mint-restoration outcomes must be authority-validated, replay-auditable, and emitted with explicit reason codes."))

Add-Check "equipment_customization_variation_rule_defined" $hasCustomizationRule "requirements define mandatory equipment variation dimensions"
Add-Check "equipment_condition_effectiveness_rule_defined" $hasEffectivenessRule "requirements define deterministic performance/value effects from condition factors"
Add-Check "equipment_loot_crafting_condition_flow_rule_defined" $hasLootCraftFlowRule "requirements define condition propagation from loot and crafting runtime outputs"
Add-Check "equipment_economy_combat_condition_flow_rule_defined" $hasEconomyCombatFlowRule "requirements define direct runtime condition impact on market pricing and combat"
Add-Check "equipment_temporary_enchantments_rule_defined" $hasTemporaryEnchantRule "requirements define temporary enchantment duration and deterministic activation/deactivation"
Add-Check "equipment_permanent_enchantments_rule_defined" $hasPermanentEnchantRule "requirements define persistent permanent enchantments"
Add-Check "equipment_runes_rule_defined" $hasRuneRule "requirements define rune socket/attachment modifier behavior"
Add-Check "equipment_integrated_magic_scripts_rule_defined" $hasIntegratedScriptRule "requirements define authority-validated integrated magic scripts for complex equipment behaviors"
Add-Check "equipment_contextual_modifiers_rule_defined" $hasContextualModifierRule "requirements define contextual bonus/decrement gates across environment/profile/class/race/subclass/condition"
Add-Check "equipment_modifier_determinism_rule_defined" $hasModifierDeterminismRule "requirements define deterministic stacking/conflict resolution with explicit reason codes"
Add-Check "equipment_mint_requires_qualified_craftsman_rule_defined" $hasQualifiedMintRule "requirements define qualified-craftsman requirement for true mint restoration"
Add-Check "equipment_condition_authority_audit_rule_defined" $hasAuthorityAuditRule "requirements define authority/replay auditability and reason codes for equipment condition changes"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "equipment_condition_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
