param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reqPath = Join-Path $RepoRoot "REQUIREMENTS.md"
if (-not (Test-Path $reqPath)) {
    throw "Missing REQUIREMENTS.md"
}

$req = Get-Content $reqPath -Raw
$checks = @()
function Add-Check([string]$name, [bool]$passed, [string]$details) {
    $script:checks += @{
        check = $name
        passed = $passed
        details = $details
    }
}

$hasMultikeyRule = ($req -match [regex]::Escape("Spellcasting input model must support intuitive multi-key execution during active combat:"))
$hasSequenceRule = ($req -match [regex]::Escape("Casting requires a compact multi-key sequence/chord (not single-key spam) for meaningful expression."))
$hasErgonomicRule = ($req -match [regex]::Escape("The sequence must be short and ergonomically viable under real-time movement/aim pressure."))
$hasParityRule = ($req -match [regex]::Escape("Input windows and recovery timings must keep magical users competitive with non-magical users in the same real-time encounter tempo."))
$hasSafeFailureRule = ($req -match [regex]::Escape("Partial or incorrect sequences must fail safely with deterministic authority validation and explicit reason codes."))
$hasHighTierPrecompiledRule = ($req -match [regex]::Escape("High-level spells cast mid-fight must use precompiled execution aids (for example: prepared scroll logic, complex item-combo activators, auto-spellcasting pipelines, or approved spell macros)."))
$hasNoRawHighTierAssemblyRule = ($req -match [regex]::Escape("Raw full-logic assembly for high-level spells during live combat input is disallowed when precompiled aids are required."))
$hasPrecompiledAuditRule = ($req -match [regex]::Escape("Precompiled aids must remain authority-validated and replay-auditable."))
$hasVeryHighTierTomeRule = ($req -match [regex]::Escape("Very high-level spells may require full tomes to cast, and tome requirements must be enforced by authority validation."))
$hasHighestTierCasterItemRule = ($req -match [regex]::Escape("Some highest-tier spells may only be cast by max-level casters using specific world items that construct/instantiate that spell."))
$hasComplexSpellRule = ($req -match [regex]::Escape("Magic runtime must support complex composed spells with multiple staged logic components resolved in deterministic order."))
$hasMultidimensionalRule = ($req -match [regex]::Escape("Magic runtime must support multidimensional spell operations (cross-plane or non-Euclidean context) with explicit legality gates."))
$hasParallelCastRule = ($req -match [regex]::Escape("Magic runtime must support parallel cast execution when budgets and legality checks pass, while preserving deterministic authoritative outcomes."))
$hasConcurrentDifficultyScalingRule = ($req -match [regex]::Escape("Concurrent/parallel casting difficulty must scale with spell complexity, spell level/tier, element interactions, and parallel branch count."))
$hasConcurrentCasterFactorsRule = ($req -match [regex]::Escape("Concurrent/parallel casting validation must include caster state and progression factors: caster level, magic experience, class/subclass affinity, current MP, current HP, active build, set bonuses, and item bonuses."))
$hasElementConflictSynergyRule = ($req -match [regex]::Escape("Element conflict/synergy rules are mandatory for concurrent casting:")) `
    -and ($req -match [regex]::Escape("Opposing elements (for example water with fire) weaken each other when no enhancement bridge is present.")) `
    -and ($req -match [regex]::Escape("Compatible enhancement pairs (for example healing plus earth) may synthesize into a larger combined spell type (for example wood) when synthesis legality gates pass."))
$hasLowResourceBuildExceptionRule = ($req -match [regex]::Escape("Certain builds may reduce multicast cost/difficulty under low-resource states (low HP/MP), and these exceptions must remain deterministic and authority-validated."))
$hasCompoundMulticastSequenceRule = ($req -match [regex]::Escape("Compound multicasting must support multiple spell input sequences casting simultaneously, with deterministic authority validation of per-sequence correctness and shared simultaneity windows."))
$hasEnemyMulticastEffectivenessRule = ($req -match [regex]::Escape("Enemies may specialize in advanced multicasting and use it effectively according to their profile, budgets, and authority validation."))
$hasPlayerItemlessAffinityGateRule = ($req -match [regex]::Escape("Players attempting efficient itemless multicasting before high-level progression must meet high affinity and experience thresholds in the specific spell types/elements being combined."))

Add-Check "spellcasting_multikey_rule_defined" $hasMultikeyRule "requirements define intuitive multi-key spellcasting model"
Add-Check "spellcasting_sequence_rule_defined" $hasSequenceRule "requirements define compact multi-key sequence requirement"
Add-Check "spellcasting_ergonomic_rule_defined" $hasErgonomicRule "requirements define real-time ergonomic viability requirement"
Add-Check "spellcasting_parity_rule_defined" $hasParityRule "requirements define parity expectation versus non-magical users"
Add-Check "spellcasting_safe_failure_rule_defined" $hasSafeFailureRule "requirements define deterministic safe failure behavior for invalid sequences"
Add-Check "high_tier_spell_precompiled_aids_rule_defined" $hasHighTierPrecompiledRule "requirements define high-tier mid-fight precompiled aid requirement"
Add-Check "high_tier_raw_assembly_disallowed_rule_defined" $hasNoRawHighTierAssemblyRule "requirements disallow raw high-tier full-logic assembly in live combat"
Add-Check "precompiled_aids_audit_rule_defined" $hasPrecompiledAuditRule "requirements define authority/replay auditability for precompiled aids"
Add-Check "very_high_tier_tome_requirement_defined" $hasVeryHighTierTomeRule "requirements define very-high-tier tome requirement"
Add-Check "highest_tier_max_level_world_item_requirement_defined" $hasHighestTierCasterItemRule "requirements define highest-tier max-level plus specific world-item requirement"
Add-Check "complex_composed_spell_rule_defined" $hasComplexSpellRule "requirements define complex composed spell support"
Add-Check "multidimensional_spell_rule_defined" $hasMultidimensionalRule "requirements define multidimensional spell support"
Add-Check "parallel_cast_rule_defined" $hasParallelCastRule "requirements define parallel cast support with deterministic authority outcomes"
Add-Check "concurrent_cast_difficulty_scaling_rule_defined" $hasConcurrentDifficultyScalingRule "requirements define concurrent cast difficulty scaling factors"
Add-Check "concurrent_cast_caster_factor_rule_defined" $hasConcurrentCasterFactorsRule "requirements define concurrent cast caster/build/resource factors"
Add-Check "concurrent_cast_element_conflict_synergy_rule_defined" $hasElementConflictSynergyRule "requirements define concurrent cast element conflict and synthesis behavior"
Add-Check "concurrent_cast_low_resource_build_exception_rule_defined" $hasLowResourceBuildExceptionRule "requirements define low-resource multicast build exception rules"
Add-Check "compound_multicast_sequence_rule_defined" $hasCompoundMulticastSequenceRule "requirements define compound simultaneous multicasting sequence validation"
Add-Check "enemy_multicast_effectiveness_rule_defined" $hasEnemyMulticastEffectivenessRule "requirements define enemy advanced multicasting effectiveness"
Add-Check "player_itemless_multicast_affinity_gate_rule_defined" $hasPlayerItemlessAffinityGateRule "requirements define player affinity/experience gate for itemless pre-high-level multicasting"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "spellcasting_flow_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
