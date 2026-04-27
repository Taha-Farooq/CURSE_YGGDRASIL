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

# 2) Engine and Platform.
$hasEngineHeading = ($req -match [regex]::Escape("## 2) Engine and Platform"))
$hasCustomEngineRule = ($req -match [regex]::Escape("- Use a custom engine architecture suitable for:"))
$hasDeterministicEngineRule = ($req -match [regex]::Escape("  - Deterministic authoritative simulation."))
$hasTieredWorldRule = ($req -match [regex]::Escape("  - Tiered world simulation (near/far)."))
$hasRenderPipelineRule = ($req -match [regex]::Escape("- Render pipeline must support:"))

# 7) Evolution System.
$hasEvolutionHeading = ($req -match [regex]::Escape("## 7) Evolution System"))
$hasEvolutionCadenceRule = ($req -match [regex]::Escape("- Every creature type (players/NPCs/mobs) can evolve every 100 levels."))
$hasHybridTraitsRule = ($req -match [regex]::Escape("- Evolution yields hybrid race traits and expanded specialization options."))
$hasCapacityRule = ($req -match [regex]::Escape("- Evolution grants increased magic/technical capacity and ability variety."))
$hasTraitBudgetRule = ($req -match [regex]::Escape("- System must use trait budgets and compatibility constraints to prevent runaway stacking."))

# 22) Initial Engineering Milestones.
$hasMilestonesHeading = ($req -match [regex]::Escape("## 22) Initial Engineering Milestones"))
$hasMilestoneCoreSim = ($req -match [regex]::Escape("1. Core simulation + net authority + replay pipeline."))
$hasMilestoneInterop = ($req -match [regex]::Escape("2. Unified arcane/tech runtime + legality validator."))
$hasMilestoneNpcEconomy = ($req -match [regex]::Escape("4. NPC memory/learning + economy/logistics."))
$hasMilestoneEndgame = ($req -match [regex]::Escape("7. Endgame branches + non-Euclidean progression."))

# 29) Demon Lord and Apex requirements for authority system anchor.
$hasApexHeading = ($req -match [regex]::Escape("## 29) Apex Entity and Demon Lord Systems"))
$hasDemonLordMechanicRule = ($req -match [regex]::Escape("- Add a Demon Lord mechanic that can empower selected evil-aligned creatures."))
$hasDemonLordDomainRule = ($req -match [regex]::Escape("- Demon Lords must be able to command large minion domains with leadership bonuses, command behaviors, and territory effects."))

Add-Check "engine_platform_heading_defined" $hasEngineHeading "requirements define engine and platform section"
Add-Check "engine_platform_core_rules_defined" ($hasCustomEngineRule -and $hasDeterministicEngineRule -and $hasTieredWorldRule -and $hasRenderPipelineRule) "requirements define custom deterministic engine architecture and render pipeline constraints"

Add-Check "evolution_system_heading_defined" $hasEvolutionHeading "requirements define evolution system section"
Add-Check "evolution_system_core_rules_defined" ($hasEvolutionCadenceRule -and $hasHybridTraitsRule -and $hasCapacityRule -and $hasTraitBudgetRule) "requirements define evolution cadence, trait expansion, and anti-runaway constraints"

Add-Check "initial_engineering_milestones_heading_defined" $hasMilestonesHeading "requirements define initial engineering milestones section"
Add-Check "initial_engineering_milestones_core_rules_defined" ($hasMilestoneCoreSim -and $hasMilestoneInterop -and $hasMilestoneNpcEconomy -and $hasMilestoneEndgame) "requirements define core milestone chain from simulation to non-euclidean endgame"

Add-Check "demon_lord_authority_anchor_heading_defined" $hasApexHeading "requirements define apex and demon lord systems section"
Add-Check "demon_lord_authority_anchor_rules_defined" ($hasDemonLordMechanicRule -and $hasDemonLordDomainRule) "requirements define demon lord empowerment and command domain authority behavior"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "engine_evolution_milestones_demonlord_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
