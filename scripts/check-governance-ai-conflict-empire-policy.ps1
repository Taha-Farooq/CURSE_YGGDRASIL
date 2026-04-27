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

# 15) Politics, law, and institutions.
$hasPoliticsHeading = ($req -match [regex]::Escape("## 15) Politics, Law, and Institutions"))
$hasPoliticalSimulationRule = ($req -match [regex]::Escape("- Political simulation must include:"))
$hasInstitutionSeparationRule = ($req -match [regex]::Escape("- Must include institution separation:"))
$hasContractSystemRule = ($req -match [regex]::Escape("- Contract systems accept diverse backgrounds if job quality conditions are met."))

# 16) NPC/Mob intelligence and memory.
$hasNpcMemoryHeading = ($req -match [regex]::Escape("## 16) NPC/Mob Intelligence and Memory"))
$hasNpcMemoryRule = ($req -match [regex]::Escape("- NPCs must:"))
$hasIntraSpeciesBiasRule = ($req -match [regex]::Escape("- Intra-species social bias/prejudice modeling is mandatory:"))
$hasInnovationTradeRule = ($req -match [regex]::Escape("- NPCs and mobs must be able to:"))
$hasSummonTriangleRule = ($req -match [regex]::Escape("- Most summonable mobs/NPCs must use a race-and-class-driven rock-paper-scissors affinity triangle during combat resolution."))

# 17) Dynamic enemy evolution.
$hasDynamicEnemyHeading = ($req -match [regex]::Escape("## 17) Dynamic Enemy Evolution"))
$hasHighTierEnemyRule = ($req -match [regex]::Escape("- High-tier enemies should:"))
$hasBossArchetypeRule = ($req -match [regex]::Escape("- Boss and area-boss archetypes are mandatory:"))
$hasBossScalingRule = ($req -match [regex]::Escape("  - More stacked enhancements must deterministically increase boss/area-boss combat strength."))
$hasBossRewardRule = ($req -match [regex]::Escape("  - Reward quality/quantity must scale with enhancement count and boss difficulty tier."))

# 19) Kingdom and empire management.
$hasKingdomHeading = ($req -match [regex]::Escape("## 19) Kingdom and Empire Management"))
$hasPlayerDirectionRule = ($req -match [regex]::Escape("- Players can direct:"))
$hasFactoryEmpireRule = ($req -match [regex]::Escape("- Factories/resource empires should convert into:"))
$hasFortificationRule = ($req -match [regex]::Escape("- Fortification, siege defense, and cross-civilization conflict must be supported according to evolution/legal stages."))

Add-Check "politics_law_institutions_heading_defined" $hasPoliticsHeading "requirements define politics/law/institutions section"
Add-Check "politics_law_institutions_core_rules_defined" ($hasPoliticalSimulationRule -and $hasInstitutionSeparationRule -and $hasContractSystemRule) "requirements define political simulation dimensions, institution separation, and contract fairness rule"

Add-Check "npc_mob_intelligence_memory_heading_defined" $hasNpcMemoryHeading "requirements define NPC/mob intelligence and memory section"
Add-Check "npc_mob_intelligence_memory_core_rules_defined" ($hasNpcMemoryRule -and $hasIntraSpeciesBiasRule -and $hasInnovationTradeRule -and $hasSummonTriangleRule) "requirements define memory/learning, intra-species bias, innovation diffusion, and summon triangle constraints"

Add-Check "dynamic_enemy_evolution_heading_defined" $hasDynamicEnemyHeading "requirements define dynamic enemy evolution section"
Add-Check "dynamic_enemy_evolution_core_rules_defined" ($hasHighTierEnemyRule -and $hasBossArchetypeRule -and $hasBossScalingRule -and $hasBossRewardRule) "requirements define high-tier adaptive enemies and deterministic boss enhancement/reward scaling"

Add-Check "kingdom_empire_management_heading_defined" $hasKingdomHeading "requirements define kingdom/empire management section"
Add-Check "kingdom_empire_management_core_rules_defined" ($hasPlayerDirectionRule -and $hasFactoryEmpireRule -and $hasFortificationRule) "requirements define player strategic controls, factory-to-power conversion, and fortified conflict support"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "governance_ai_conflict_empire_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
