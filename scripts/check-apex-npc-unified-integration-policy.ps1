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

# 26.2 Unified contracts.
$hasUnifiedContractsHeading = ($req -match [regex]::Escape("### 26.2) Unified Data and Runtime Contracts"))
$hasSharedIdsRule = ($req -match [regex]::Escape("- Shared IDs and schemas for actors, factions, items, regions, and jobs."))
$hasSharedLegalityRule = ($req -match [regex]::Escape("- Shared legality validation path for player actions, AI actions, and live-authored content."))
$hasSharedBudgetRule = ($req -match [regex]::Escape("- Shared budget framework (CPU/memory/sim cost) across combat, AI, world jobs, and live content."))
$hasSharedTelemetryRule = ($req -match [regex]::Escape("- Shared telemetry and replay instrumentation across all subsystems."))

# 27.3 Integration scenarios.
$hasIntegrationScenariosHeading = ($req -match [regex]::Escape("### 27.3) Integration Scenarios (Must Exist in Test Suite)"))
$hasMilitaryLogisticsScenario = ($req -match [regex]::Escape("- Military conflict interrupts logistics, and shortages alter combat readiness and political stability."))
$hasDungeonEconomyScenario = ($req -match [regex]::Escape("- Dungeon control shifts regional economy, faction pressure, and guild contract demand."))
$hasSocialPolicyScenario = ($req -match [regex]::Escape("- Social policy changes alter NPC behavior, migration, diplomacy, and high-tier magic stability gates."))
$hasLiveAuthoredScenario = ($req -match [regex]::Escape("- New live-authored spell/device impacts combat, economy, and legality validators without bypassing authority."))

# 29 Apex and Demon Lord systems.
$hasApexHeading = ($req -match [regex]::Escape("## 29) Apex Entity and Demon Lord Systems"))
$hasDemonLordEmpowerRule = ($req -match [regex]::Escape("- Add a Demon Lord mechanic that can empower selected evil-aligned creatures."))
$hasDemonLordCommandRule = ($req -match [regex]::Escape("- Demon Lords must be able to command large minion domains with leadership bonuses, command behaviors, and territory effects."))
$hasApexCategoryRule = ($req -match [regex]::Escape("- Add special apex categories with custom rule sets:"))
$hasInterdimensionalDemonRule = ($req -match [regex]::Escape("  - Interdimensional Demons"))

# 30 Advanced NPC creator.
$hasNpcCreatorHeading = ($req -match [regex]::Escape("## 30) Advanced NPC Creator (High-Power Custom Forging)"))
$hasNpcDefinitionRule = ($req -match [regex]::Escape("- Provide a user-facing NPC creation system that allows deep definition of:"))
$hasNpcCrossClassRule = ($req -match [regex]::Escape("- Users should be able to define rare cross-class combinations unlikely through normal progression."))
$hasNpcSafetyRule = ($req -match [regex]::Escape("- NPC Creator outputs must pass strict safety and balance validation:"))
$hasNpcTraceabilityRule = ($req -match [regex]::Escape("- High-power custom NPCs must be traceable to creator, version, and content package for rollback/governance."))

Add-Check "unified_data_runtime_contracts_heading_defined" $hasUnifiedContractsHeading "requirements define unified data/runtime contracts section"
Add-Check "unified_data_runtime_contracts_rules_defined" ($hasSharedIdsRule -and $hasSharedLegalityRule -and $hasSharedBudgetRule -and $hasSharedTelemetryRule) "requirements define shared ids/legality/budgets/telemetry contracts"

Add-Check "integration_scenarios_heading_defined" $hasIntegrationScenariosHeading "requirements define integration scenarios section"
Add-Check "integration_scenarios_rules_defined" ($hasMilitaryLogisticsScenario -and $hasDungeonEconomyScenario -and $hasSocialPolicyScenario -and $hasLiveAuthoredScenario) "requirements define required cross-system integration scenarios"

Add-Check "apex_demon_lord_systems_heading_defined" $hasApexHeading "requirements define apex entity and demon lord systems section"
Add-Check "apex_demon_lord_systems_rules_defined" ($hasDemonLordEmpowerRule -and $hasDemonLordCommandRule -and $hasApexCategoryRule -and $hasInterdimensionalDemonRule) "requirements define demon lord empowerment, command domains, and apex categories"

Add-Check "advanced_npc_creator_heading_defined" $hasNpcCreatorHeading "requirements define advanced NPC creator section"
Add-Check "advanced_npc_creator_rules_defined" ($hasNpcDefinitionRule -and $hasNpcCrossClassRule -and $hasNpcSafetyRule -and $hasNpcTraceabilityRule) "requirements define deep creator input, safety validation, and traceability"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "apex_npc_unified_integration_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
