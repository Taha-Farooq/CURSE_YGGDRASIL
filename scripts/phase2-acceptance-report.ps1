param(
    [string]$RepoRoot = "",
    [switch]$WriteReport,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$tempDir = Join-Path $RepoRoot "reports\temp"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
$runToken = (Get-Date -Format "yyyyMMddHHmmssfff") + "-" + $PID

$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
if (-not (Test-Path $tasksPath)) { throw "Missing backlog/tasks.json" }

$tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
$phase2 = @($tasks | Where-Object { $_.type -eq "phase2" })

$checks = @()
function Add-Check([string]$taskId, [string]$name, [bool]$passed, [string]$details) {
    $script:checks += @{
        taskId = $taskId
        check = $name
        passed = $passed
        details = $details
    }
}

function Invoke-Json([scriptblock]$Block) {
    $out = & $Block
    return ($out | ConvertFrom-Json)
}

# Task 1 runtime checks
$eligiblePath = Join-Path $RepoRoot "tests\fixtures\phase2-mind-dungeon-player-eligible.json"
$ineligiblePath = Join-Path $RepoRoot "tests\fixtures\phase2-mind-dungeon-player-ineligible.json"
$gateScript = Join-Path $RepoRoot "engine\progression\mind-dungeon\mind-dungeon-gate-evaluator.ps1"
$profileScript = Join-Path $RepoRoot "engine\progression\mind-dungeon\adaptive-encounter-profile-selector.ps1"

$gateEligible = Invoke-Json { & $gateScript -RepoRoot $RepoRoot -InputJsonPath $eligiblePath }
$gateIneligible = Invoke-Json { & $gateScript -RepoRoot $RepoRoot -InputJsonPath $ineligiblePath }
$profileEligible = Invoke-Json { & $profileScript -RepoRoot $RepoRoot -InputJsonPath $eligiblePath }
$profileIneligible = Invoke-Json { & $profileScript -RepoRoot $RepoRoot -InputJsonPath $ineligiblePath }

Add-Check "TASK-PHASE2-01-MIND-DUNGEON-GATE-RUNTIME-V1" "eligible_gate_allows" ([bool]$gateEligible.allowed) "eligible fixture should be allowed"
Add-Check "TASK-PHASE2-01-MIND-DUNGEON-GATE-RUNTIME-V1" "ineligible_gate_denies" (-not [bool]$gateIneligible.allowed) "ineligible fixture should be denied"
Add-Check "TASK-PHASE2-01-MIND-DUNGEON-GATE-RUNTIME-V1" "profile_adapts_by_progression" ([string]$profileEligible.selectedProfile -ne [string]$profileIneligible.selectedProfile) "eligible/ineligible map to different encounter profiles"

# Task 2 runtime checks
$logisticsInput = Join-Path $RepoRoot "tests\fixtures\phase2-logistics-shock-input.json"
$logisticsShockScript = Join-Path $RepoRoot "engine\economy\logistics-shock-propagation\logistics-shock-propagation-service.ps1"
$marketStatePath = Join-Path $RepoRoot "tests\fixtures\phase2-market-state.json"
$shockEventsPath = Join-Path $tempDir ("phase2-logistics-shock-events-" + $runToken + ".json")
$economyPressureScript = Join-Path $RepoRoot "engine\economy\pressure-update\economy-pressure-update-service.ps1"

$shock = Invoke-Json { & $logisticsShockScript -RepoRoot $RepoRoot -InputJsonPath $logisticsInput }
$shock | ConvertTo-Json -Depth 12 | Set-Content -Path $shockEventsPath -Encoding UTF8
$pressure = Invoke-Json { & $economyPressureScript -RepoRoot $RepoRoot -ShockEventsJsonPath $shockEventsPath -MarketStateJsonPath $marketStatePath }

$hasSupplyDelta = (@($shock.events | Where-Object { [double]$_.supplyDelta -lt 0 }).Count -ge 1)
$allReplayTagged = (@($shock.events | Where-Object { -not [bool]$_.replayEvidence.required }).Count -eq 0)
$pressureChanged = (@($pressure.regions | Where-Object { [double]$_.pressure -gt [double]$_.basePressure }).Count -ge 1)

Add-Check "TASK-PHASE2-02-ECONOMY-LOGISTICS-SHOCK-PROPAGATION-V1" "shock_generates_supply_delta" $hasSupplyDelta "at least one route applies negative supply delta"
Add-Check "TASK-PHASE2-02-ECONOMY-LOGISTICS-SHOCK-PROPAGATION-V1" "shock_replay_audit_tags" $allReplayTagged "all shock events require replay evidence"
Add-Check "TASK-PHASE2-02-ECONOMY-LOGISTICS-SHOCK-PROPAGATION-V1" "pressure_updates_from_shock" $pressureChanged "market pressure increases after route disruption"

# Task 3 runtime checks
$policyHighPath = Join-Path $RepoRoot "tests\fixtures\phase2-policy-state.json"
$policyLowPath = Join-Path $RepoRoot "tests\fixtures\phase2-policy-state-low-stability.json"
$castHighTierPath = Join-Path $RepoRoot "tests\fixtures\phase2-cast-request.json"
$castLowTierPath = Join-Path $RepoRoot "tests\fixtures\phase2-cast-request-low-tier.json"
$couplerScript = Join-Path $RepoRoot "engine\governance\policy-magic-stability\policy-magic-stability-coupler.ps1"
$stabilityGateScript = Join-Path $RepoRoot "engine\governance\policy-magic-stability\magic-stability-gate.ps1"
$policyHighOutPath = Join-Path $tempDir ("phase2-policy-stability-output-" + $runToken + "-high.json")
$policyLowOutPath = Join-Path $tempDir ("phase2-policy-stability-output-" + $runToken + "-low.json")

$policyHigh = Invoke-Json { & $couplerScript -RepoRoot $RepoRoot -InputJsonPath $policyHighPath }
$policyLow = Invoke-Json { & $couplerScript -RepoRoot $RepoRoot -InputJsonPath $policyLowPath }
$policyHigh | ConvertTo-Json -Depth 12 | Set-Content -Path $policyHighOutPath -Encoding UTF8
$policyLow | ConvertTo-Json -Depth 12 | Set-Content -Path $policyLowOutPath -Encoding UTF8

$gateHigh = Invoke-Json { & $stabilityGateScript -RepoRoot $RepoRoot -CouplerOutputJsonPath $policyHighOutPath -CastRequestJsonPath $castHighTierPath }
$gateLowTier = Invoke-Json { & $stabilityGateScript -RepoRoot $RepoRoot -CouplerOutputJsonPath $policyLowOutPath -CastRequestJsonPath $castLowTierPath }
$gateBlocked = Invoke-Json { & $stabilityGateScript -RepoRoot $RepoRoot -CouplerOutputJsonPath $policyLowOutPath -CastRequestJsonPath $castHighTierPath }

$stabilityDifferentiates = ([double]$policyHigh.stabilityScore -gt [double]$policyLow.stabilityScore)
$highAllowsHighCast = [bool]$gateHigh.allowed
$lowBlocksHighCast = (-not [bool]$gateBlocked.allowed -and (@($gateBlocked.reasonCodes) -contains "AUTH-POLICY-STABILITY-TIER-BLOCKED"))
$lowStillAllowsLowTier = [bool]$gateLowTier.allowed

Add-Check "TASK-PHASE2-03-POLICY-TO-MAGIC-STABILITY-COUPLER-V1" "policy_changes_stability_state" $stabilityDifferentiates "high-trust polity should exceed low-trust stability score"
Add-Check "TASK-PHASE2-03-POLICY-TO-MAGIC-STABILITY-COUPLER-V1" "high_stability_allows_high_tier_cast" $highAllowsHighCast "high stability should allow tier 11 request"
Add-Check "TASK-PHASE2-03-POLICY-TO-MAGIC-STABILITY-COUPLER-V1" "low_stability_blocks_high_tier_cast" $lowBlocksHighCast "low stability should reject tier 11 with reason code"
Add-Check "TASK-PHASE2-03-POLICY-TO-MAGIC-STABILITY-COUPLER-V1" "low_stability_allows_low_tier_cast" $lowStillAllowsLowTier "low stability should still allow low tier cast"

# Task 4 runtime checks
$npcValidSpec = Join-Path $RepoRoot "tests\fixtures\phase2-npc-runtime-spec-valid.json"
$npcOverbudgetSpec = Join-Path $RepoRoot "tests\fixtures\phase2-npc-runtime-spec-overbudget.json"
$npcSpawnScript = Join-Path $RepoRoot "engine\entities\npc-creator\npc-runtime-spawn-activation.ps1"
$npcBudgetGuardScript = Join-Path $RepoRoot "engine\entities\npc-creator\npc-runtime-budget-guard.ps1"

$npcSpawn = Invoke-Json { & $npcSpawnScript -RepoRoot $RepoRoot -InputJsonPath $npcValidSpec }
$npcBudgetPass = Invoke-Json { & $npcBudgetGuardScript -RepoRoot $RepoRoot -InputJsonPath $npcValidSpec -RuntimeBudgetCap 120 }
$npcBudgetBlocked = Invoke-Json { & $npcBudgetGuardScript -RepoRoot $RepoRoot -InputJsonPath $npcOverbudgetSpec -RuntimeBudgetCap 120 }

$spawnHasLineage = (-not [string]::IsNullOrWhiteSpace([string]$npcSpawn.lineage.creatorId) -and -not [string]::IsNullOrWhiteSpace([string]$npcSpawn.lineage.packageId))
$overbudgetBlocked = (-not [bool]$npcBudgetBlocked.passed -and (@($npcBudgetBlocked.reasonCodes) -contains "NPC-RUNTIME-BUDGET-BLOCKED"))

Add-Check "TASK-PHASE2-04-NPC-CREATOR-RUNTIME-SPAWN-PATH-V1" "valid_spec_spawns" ([bool]$npcSpawn.activationAllowed -and [bool]$npcSpawn.spawned) "valid NPC spec should spawn"
Add-Check "TASK-PHASE2-04-NPC-CREATOR-RUNTIME-SPAWN-PATH-V1" "spawn_includes_audit_lineage" $spawnHasLineage "spawn payload includes creator/package lineage"
Add-Check "TASK-PHASE2-04-NPC-CREATOR-RUNTIME-SPAWN-PATH-V1" "budget_guard_allows_valid_spec" ([bool]$npcBudgetPass.passed) "budget guard allows valid runtime spec"
Add-Check "TASK-PHASE2-04-NPC-CREATOR-RUNTIME-SPAWN-PATH-V1" "budget_guard_blocks_overbudget_spec" $overbudgetBlocked "budget guard blocks over-budget runtime spec"

# Task 5 runtime checks
$domainStatePath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-domain-state.json"
$demonTemperamentPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-lord-temperament.json"
$demonCommandPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-lord-command.json"
$domainExpandScript = Join-Path $RepoRoot "engine\entities\demon-lord\domain-expansion-scheduler.ps1"
$domainEffectScript = Join-Path $RepoRoot "engine\entities\demon-lord\domain-effect-propagation.ps1"
$domainExpansionOutPath = Join-Path $tempDir ("phase2-demon-domain-expansion-event-" + $runToken + ".json")

$domainExpansion = Invoke-Json { & $domainExpandScript -RepoRoot $RepoRoot -DomainStateJsonPath $domainStatePath -TemperamentJsonPath $demonTemperamentPath -CommandJsonPath $demonCommandPath }
$domainExpansion | ConvertTo-Json -Depth 12 | Set-Content -Path $domainExpansionOutPath -Encoding UTF8
$domainEffects = Invoke-Json { & $domainEffectScript -RepoRoot $RepoRoot -ExpansionEventJsonPath $domainExpansionOutPath }

$controlIncreased = ([double]$domainExpansion.newControl -gt [double]$domainExpansion.previousControl)
$effectsApplied = (@($domainEffects.effectsApplied).Count -ge 1)
$ledgerTagged = ([string]$domainEffects.ledgerRecord.category -eq "demon_domain" -and [bool]$domainEffects.ledgerRecord.replayRequired)

Add-Check "TASK-PHASE2-05-DEMON-LORD-DOMAIN-EXPANSION-LOOP-V1" "domain_expansion_increases_control" $controlIncreased "domain control should increase after valid expansion command"
Add-Check "TASK-PHASE2-05-DEMON-LORD-DOMAIN-EXPANSION-LOOP-V1" "domain_effects_propagate" $effectsApplied "domain effects should propagate to downstream subsystems"
Add-Check "TASK-PHASE2-05-DEMON-LORD-DOMAIN-EXPANSION-LOOP-V1" "domain_events_have_ledger_replay_tags" $ledgerTagged "domain expansion emits ledger/replay metadata"

# Task 6 runtime checks
$apexRegistryPath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-archetypes.json"
$apexRegionStatePath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-region-state.json"
$apexOwnershipPath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-dimension-ownership.json"
$apexInjectorScript = Join-Path $RepoRoot "engine\entities\apex\apex-encounter-injector.ps1"
$apexOwnershipEnforcerScript = Join-Path $RepoRoot "engine\entities\apex\apex-dimension-ownership-enforcer.ps1"
$apexInjectionOutPath = Join-Path $tempDir ("phase2-apex-injection-event-" + $runToken + ".json")

$apexInjection = Invoke-Json { & $apexInjectorScript -RepoRoot $RepoRoot -RegistryJsonPath $apexRegistryPath -RegionStateJsonPath $apexRegionStatePath -OwnershipJsonPath $apexOwnershipPath }
$apexInjection | ConvertTo-Json -Depth 12 | Set-Content -Path $apexInjectionOutPath -Encoding UTF8
$apexOwnershipEnforced = Invoke-Json { & $apexOwnershipEnforcerScript -RepoRoot $RepoRoot -OwnershipJsonPath $apexOwnershipPath -InjectionEventJsonPath $apexInjectionOutPath }

$apexInjected = [bool]$apexInjection.injected
$apexOwnerMatch = [bool]$apexOwnershipEnforced.allowed
$apexReplayTagged = [bool]$apexInjection.replayEvidence.required

Add-Check "TASK-PHASE2-06-APEX-ENCOUNTER-INJECTION-V1" "apex_injection_selects_eligible_entity" $apexInjected "apex injection should select eligible entity under threat budget"
Add-Check "TASK-PHASE2-06-APEX-ENCOUNTER-INJECTION-V1" "apex_dimension_ownership_enforced" $apexOwnerMatch "ownership enforcer should validate injected dimension ownership"
Add-Check "TASK-PHASE2-06-APEX-ENCOUNTER-INJECTION-V1" "apex_injection_replay_metadata" $apexReplayTagged "injected encounter should require replay evidence"

# Task 7 runtime checks
$canaryStatePath = Join-Path $RepoRoot "tests\fixtures\phase2-entity-canary-state.json"
$canaryFailStatePath = Join-Path $RepoRoot "tests\fixtures\phase2-entity-canary-state-failing.json"
$entityRollbackPath = Join-Path $RepoRoot "tests\fixtures\phase2-entity-rollback.json"
$canaryControllerScript = Join-Path $RepoRoot "engine\live-content\entity-package-canary-controller.ps1"
$rollbackPolicyScript = Join-Path $RepoRoot "engine\live-content\entity-package-rollback-trigger-policy.ps1"

$canaryHealthy = Invoke-Json { & $canaryControllerScript -RepoRoot $RepoRoot -CanaryJsonPath $canaryStatePath }
$rollbackPolicy = Invoke-Json { & $rollbackPolicyScript -RepoRoot $RepoRoot -CanaryJsonPath $canaryFailStatePath -RollbackJsonPath $entityRollbackPath }

$canaryProgressed = ([string]$canaryHealthy.nextPhase -eq "full" -and [bool]$canaryHealthy.promotionAllowed)
$rollbackTriggered = ([bool]$rollbackPolicy.rollbackTriggered)
$rollbackRestored = ([string]$rollbackPolicy.restoredPackageId -eq "pkg-entity-phase2-beta")

Add-Check "TASK-PHASE2-07-LIVE-ENTITY-PACKAGE-CANARY-CONTROLLER-V1" "canary_state_progression" $canaryProgressed "healthy canary should progress to full rollout"
Add-Check "TASK-PHASE2-07-LIVE-ENTITY-PACKAGE-CANARY-CONTROLLER-V1" "rollback_trigger_on_failure" $rollbackTriggered "failing canary should trigger rollback policy"
Add-Check "TASK-PHASE2-07-LIVE-ENTITY-PACKAGE-CANARY-CONTROLLER-V1" "rollback_restores_previous_package" $rollbackRestored "rollback should restore previous known-good package"

# Task 8 runtime checks
$routeSignalsPath = Join-Path $RepoRoot "tests\fixtures\phase2-route-clearability-signals.json"
$routeIngestedPath = Join-Path $tempDir ("phase2-route-clearability-ingested-" + $runToken + ".json")
$routeIngestorScript = Join-Path $RepoRoot "engine\routing\clearability\route-clearability-signal-ingestor.ps1"
$routeRiskScorerScript = Join-Path $RepoRoot "engine\routing\clearability\weighted-route-risk-scorer.ps1"

$routeIngested = Invoke-Json { & $routeIngestorScript -RepoRoot $RepoRoot -InputJsonPath $routeSignalsPath }
$routeIngested | ConvertTo-Json -Depth 12 | Set-Content -Path $routeIngestedPath -Encoding UTF8
$routeRisk = Invoke-Json { & $routeRiskScorerScript -RepoRoot $RepoRoot -SignalsJsonPath $routeIngestedPath }
$routeSignalsNeutralInputPath = Join-Path $tempDir ("phase2-route-clearability-signals-neutral-" + $runToken + ".json")
$routeIngestedNeutralPath = Join-Path $tempDir ("phase2-route-clearability-ingested-neutral-" + $runToken + ".json")
$routeSignalsNeutralPayload = @{
    signals = @($routeIngested.signals | ForEach-Object {
            @{
                routeId = [string]$_.routeId
                regionId = [string]$_.regionId
                clearabilityScore = [double]$_.clearabilityScore
                frictionScore = [double]$_.frictionScore
                failureRate = [double]$_.failureRate
                diplomacyFriction = 0.0
                socialBiasTrustDelta = 0
                sourceReport = [string]$_.sourceReport
            }
        })
}
$routeSignalsNeutralPayload | ConvertTo-Json -Depth 10 | Set-Content -Path $routeSignalsNeutralInputPath -Encoding UTF8
$routeIngestedNeutral = Invoke-Json { & $routeIngestorScript -RepoRoot $RepoRoot -InputJsonPath $routeSignalsNeutralInputPath }
$routeIngestedNeutral | ConvertTo-Json -Depth 12 | Set-Content -Path $routeIngestedNeutralPath -Encoding UTF8
$routeRiskNeutral = Invoke-Json { & $routeRiskScorerScript -RepoRoot $RepoRoot -SignalsJsonPath $routeIngestedNeutralPath }

$signalsIngested = (@($routeIngested.signals).Count -ge 3)
$highRiskRanked = (@($routeRisk.topRiskRoutes).Count -ge 1 -and [double]$routeRisk.topRiskRoutes[0].riskScore -ge [double]$routeRisk.topRiskRoutes[-1].riskScore)
$traceableSource = (@($routeRisk.rankedRoutes | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.sourceReport) }).Count -eq 0)

Add-Check "TASK-PHASE2-08-ROUTE-CLEARABILITY-SIGNAL-INTEGRATION-V1" "clearability_signals_ingested" $signalsIngested "route signals should be ingested from source reports"
Add-Check "TASK-PHASE2-08-ROUTE-CLEARABILITY-SIGNAL-INTEGRATION-V1" "high_risk_routes_ranked" $highRiskRanked "high-risk routes should be ranked by risk score"
Add-Check "TASK-PHASE2-08-ROUTE-CLEARABILITY-SIGNAL-INTEGRATION-V1" "risk_signals_traceable" $traceableSource "ranked routes should preserve source report traceability"

# Task 9 runtime checks
$dashboardPath = Join-Path $RepoRoot "dashboard\index.html"
$dashboardServerPath = Join-Path $RepoRoot "scripts\dashboard-server.ps1"
$dashboardHtml = Get-Content $dashboardPath -Raw
$dashboardServer = Get-Content $dashboardServerPath -Raw

$phase2CardPresent = ($dashboardHtml -match [regex]::Escape("Phase 2 Acceptance") -and $dashboardHtml -match [regex]::Escape("phase2AcceptanceBox"))
$canaryCardPresent = ($dashboardHtml -match [regex]::Escape("Canary / Rollback State") -and $dashboardHtml -match [regex]::Escape("canaryRollbackBox"))
$socialBiasCardPresent = ($dashboardHtml -match [regex]::Escape("Social Bias Runtime") -and $dashboardHtml -match [regex]::Escape("socialBiasRuntimeBox"))
$phase2EndpointPresent = ($dashboardServer -match [regex]::Escape("/api/phase2-acceptance"))
$canaryEndpointPresent = ($dashboardServer -match [regex]::Escape("/api/canary-rollback-state"))
$socialBiasEndpointPresent = ($dashboardServer -match [regex]::Escape("/api/social-bias-runtime"))

Add-Check "TASK-PHASE2-09-PHASE-2-DASHBOARD-CONTROLS-V1" "phase2_acceptance_card_present" $phase2CardPresent "dashboard should include phase2 acceptance card and renderer"
Add-Check "TASK-PHASE2-09-PHASE-2-DASHBOARD-CONTROLS-V1" "canary_rollback_card_present" $canaryCardPresent "dashboard should include canary/rollback state card"
Add-Check "TASK-PHASE2-09-PHASE-2-DASHBOARD-CONTROLS-V1" "social_bias_runtime_card_present" $socialBiasCardPresent "dashboard should include social bias runtime card and renderer"
Add-Check "TASK-PHASE2-09-PHASE-2-DASHBOARD-CONTROLS-V1" "phase2_dashboard_endpoints_present" ($phase2EndpointPresent -and $canaryEndpointPresent -and $socialBiasEndpointPresent) "dashboard server should expose phase2/canary/social-bias endpoints"

# Supplemental runtime checks: summon affinity triangle with level-dominant weighting.
$summonAffinityLevelDominatesPath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-affinity-level-dominates.json"
$summonAffinityTriangleEdgePath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-affinity-triangle-edge.json"
$summonAffinityResolverScript = Join-Path $RepoRoot "engine\combat\summons\summon-affinity-triangle-resolver.ps1"
$summonControlPrecomputedPath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-control-precomputed.json"
$summonControlInsufficientControllersPath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-control-insufficient-controllers.json"
$summonControlInsufficientPrecomputePath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-control-insufficient-precompute.json"
$summonPartyPlanInputPath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-party-plan-input.json"
$summonControlValidatorScript = Join-Path $RepoRoot "engine\combat\summons\summon-control-complexity-validator.ps1"
$summonPartyPlannerScript = Join-Path $RepoRoot "engine\combat\summons\summon-party-planner.ps1"
$multikeyCastValidPath = Join-Path $RepoRoot "tests\fixtures\phase2-realtime-multikey-cast-valid.json"
$multikeyCastInvalidPath = Join-Path $RepoRoot "tests\fixtures\phase2-realtime-multikey-cast-invalid.json"
$multikeyCastEnemyPath = Join-Path $RepoRoot "tests\fixtures\phase2-realtime-multikey-cast-enemy.json"
$multikeyCastValidatorScript = Join-Path $RepoRoot "engine\combat\spells\realtime-multikey-cast-validator.ps1"
$bossEnhancementValidPath = Join-Path $RepoRoot "tests\fixtures\phase2-boss-enhancement-valid.json"
$bossEnhancementInvalidPath = Join-Path $RepoRoot "tests\fixtures\phase2-boss-enhancement-invalid.json"
$bossEnhancementResolverScript = Join-Path $RepoRoot "engine\combat\bosses\boss-enhancement-resolver.ps1"
$equipmentConditionValidPath = Join-Path $RepoRoot "tests\fixtures\phase2-equipment-condition-valid.json"
$equipmentConditionInvalidPath = Join-Path $RepoRoot "tests\fixtures\phase2-equipment-condition-invalid.json"
$equipmentConditionResolverScript = Join-Path $RepoRoot "engine\items\equipment-condition-resolver.ps1"
$itemMagicModifierValidPath = Join-Path $RepoRoot "tests\fixtures\phase2-item-magic-modifier-valid.json"
$itemMagicModifierInvalidPath = Join-Path $RepoRoot "tests\fixtures\phase2-item-magic-modifier-invalid.json"
$itemMagicModifierResolverScript = Join-Path $RepoRoot "engine\items\item-magic-modifier-resolver.ps1"
$temperamentIntraSpeciesPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-lord-temperament-intraspecies.json"
$temperamentCrossSpeciesPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-lord-temperament-crossspecies.json"
$temperamentProfileScript = Join-Path $RepoRoot "engine\entities\demon-lord\temperament-profile-evaluator.ps1"
$demonCommandInterfaceScript = Join-Path $RepoRoot "engine\entities\demon-lord\minion-command-interface.ps1"
$lootConditionRollInputPath = Join-Path $RepoRoot "tests\fixtures\phase2-loot-condition-roll-input.json"
$craftedConditionInputPath = Join-Path $RepoRoot "tests\fixtures\phase2-crafted-equipment-condition-input.json"
$lootConditionRollScript = Join-Path $RepoRoot "engine\items\loot-condition-roll-service.ps1"
$craftedConditionServiceScript = Join-Path $RepoRoot "engine\crafting\crafted-equipment-condition-service.ps1"
$marketPricingWithConditionScript = Join-Path $RepoRoot "engine\economy\market-pricing-with-condition-service.ps1"
$combatEffectivenessWithConditionScript = Join-Path $RepoRoot "engine\combat\equipment-combat-effectiveness-service.ps1"

$summonLevelDominates = Invoke-Json { & $summonAffinityResolverScript -RepoRoot $RepoRoot -InputJsonPath $summonAffinityLevelDominatesPath }
$summonTriangleEdge = Invoke-Json { & $summonAffinityResolverScript -RepoRoot $RepoRoot -InputJsonPath $summonAffinityTriangleEdgePath }
$summonControlPrecomputed = Invoke-Json { & $summonControlValidatorScript -RepoRoot $RepoRoot -InputJsonPath $summonControlPrecomputedPath }
$summonControlInsufficientControllers = Invoke-Json { & $summonControlValidatorScript -RepoRoot $RepoRoot -InputJsonPath $summonControlInsufficientControllersPath }
$summonControlInsufficientPrecompute = Invoke-Json { & $summonControlValidatorScript -RepoRoot $RepoRoot -InputJsonPath $summonControlInsufficientPrecomputePath }
$summonPartyPlan = Invoke-Json { & $summonPartyPlannerScript -RepoRoot $RepoRoot -InputJsonPath $summonPartyPlanInputPath }
$multikeyCastValid = Invoke-Json { & $multikeyCastValidatorScript -RepoRoot $RepoRoot -InputJsonPath $multikeyCastValidPath }
$multikeyCastInvalid = Invoke-Json { & $multikeyCastValidatorScript -RepoRoot $RepoRoot -InputJsonPath $multikeyCastInvalidPath }
$multikeyCastEnemy = Invoke-Json { & $multikeyCastValidatorScript -RepoRoot $RepoRoot -InputJsonPath $multikeyCastEnemyPath }
$bossEnhancementValid = Invoke-Json { & $bossEnhancementResolverScript -RepoRoot $RepoRoot -InputJsonPath $bossEnhancementValidPath }
$bossEnhancementInvalid = Invoke-Json { & $bossEnhancementResolverScript -RepoRoot $RepoRoot -InputJsonPath $bossEnhancementInvalidPath }
$equipmentConditionValid = Invoke-Json { & $equipmentConditionResolverScript -RepoRoot $RepoRoot -InputJsonPath $equipmentConditionValidPath }
$equipmentConditionInvalid = Invoke-Json { & $equipmentConditionResolverScript -RepoRoot $RepoRoot -InputJsonPath $equipmentConditionInvalidPath }
$itemMagicModifierValid = Invoke-Json { & $itemMagicModifierResolverScript -RepoRoot $RepoRoot -InputJsonPath $itemMagicModifierValidPath }
$itemMagicModifierInvalid = Invoke-Json { & $itemMagicModifierResolverScript -RepoRoot $RepoRoot -InputJsonPath $itemMagicModifierInvalidPath }
$temperamentIntraSpecies = Invoke-Json { & $temperamentProfileScript -TemperamentJsonPath $temperamentIntraSpeciesPath }
$temperamentCrossSpecies = Invoke-Json { & $temperamentProfileScript -TemperamentJsonPath $temperamentCrossSpeciesPath }
$demonCommandAcceptedLowBias = Invoke-Json { & $demonCommandInterfaceScript -CommandJsonPath $demonCommandPath -TemperamentJsonPath $demonTemperamentPath }
$demonCommandBlockedHighBias = Invoke-Json { & $demonCommandInterfaceScript -CommandJsonPath $demonCommandPath -TemperamentJsonPath $temperamentIntraSpeciesPath }
$lootConditionRoll = Invoke-Json { & $lootConditionRollScript -RepoRoot $RepoRoot -InputJsonPath $lootConditionRollInputPath }
$craftedCondition = Invoke-Json { & $craftedConditionServiceScript -RepoRoot $RepoRoot -InputJsonPath $craftedConditionInputPath }

$lootPricingInputPath = Join-Path $tempDir ("phase2-market-pricing-loot-" + $runToken + ".json")
$craftedPricingInputPath = Join-Path $tempDir ("phase2-market-pricing-crafted-" + $runToken + ".json")
$lootCombatInputPath = Join-Path $tempDir ("phase2-combat-condition-loot-" + $runToken + ".json")
$craftedCombatInputPath = Join-Path $tempDir ("phase2-combat-condition-crafted-" + $runToken + ".json")

@{
    basePrice = 1200
    conditionValueMultiplier = [double]$lootConditionRoll.condition.valueMultiplier
    marketPressure = 1.3
    demandScalar = 1.5
} | ConvertTo-Json -Depth 6 | Set-Content -Path $lootPricingInputPath -Encoding UTF8
@{
    basePrice = 1200
    conditionValueMultiplier = [double]$craftedCondition.condition.valueMultiplier
    marketPressure = 1.3
    demandScalar = 1.5
} | ConvertTo-Json -Depth 6 | Set-Content -Path $craftedPricingInputPath -Encoding UTF8
@{
    baseAttack = 120
    baseDefense = 88
    conditionEffectivenessMultiplier = [double]$lootConditionRoll.condition.effectivenessMultiplier
} | ConvertTo-Json -Depth 6 | Set-Content -Path $lootCombatInputPath -Encoding UTF8
@{
    baseAttack = 120
    baseDefense = 88
    conditionEffectivenessMultiplier = [double]$craftedCondition.condition.effectivenessMultiplier
} | ConvertTo-Json -Depth 6 | Set-Content -Path $craftedCombatInputPath -Encoding UTF8

$lootMarketPrice = Invoke-Json { & $marketPricingWithConditionScript -RepoRoot $RepoRoot -InputJsonPath $lootPricingInputPath }
$craftedMarketPrice = Invoke-Json { & $marketPricingWithConditionScript -RepoRoot $RepoRoot -InputJsonPath $craftedPricingInputPath }
$locationCurrencyPricingPath = Join-Path $RepoRoot "tests\fixtures\phase2-market-pricing-location-currency-input.json"
$locationCurrencyMarketPrice = Invoke-Json { & $marketPricingWithConditionScript -RepoRoot $RepoRoot -InputJsonPath $locationCurrencyPricingPath }
$lootCombatEffectiveness = Invoke-Json { & $combatEffectivenessWithConditionScript -RepoRoot $RepoRoot -InputJsonPath $lootCombatInputPath }
$craftedCombatEffectiveness = Invoke-Json { & $combatEffectivenessWithConditionScript -RepoRoot $RepoRoot -InputJsonPath $craftedCombatInputPath }

$levelDominantOutcome = (
    [string]$summonLevelDominates.relation -eq "advantage" -and
    [double]$summonLevelDominates.multipliers.level -gt [double]$summonLevelDominates.multipliers.affinity -and
    [string]$summonLevelDominates.dominantDriver -eq "level"
)
$triangleAffectsOutcome = (
    [string]$summonTriangleEdge.relation -eq "advantage" -and
    [double]$summonTriangleEdge.multipliers.affinity -gt 1.0 -and
    [double]$summonTriangleEdge.multipliers.combined -gt 1.0
)
$deterministicAuthority = ([bool]$summonLevelDominates.deterministic -and [bool]$summonLevelDominates.authorityValidated)
$precomputedAllowsAutomatic = (
    [bool]$summonControlPrecomputed.eligibility.allowed -and
    [string]$summonControlPrecomputed.eligibility.runtimeMode -eq "automatic"
)
$insufficientControllersBlocked = (
    -not [bool]$summonControlInsufficientControllers.eligibility.allowed -and
    (@($summonControlInsufficientControllers.reasonCodes) -contains "AUTH-SUMMON-CONTROL-THRESHOLD-NOT-MET")
)
$insufficientPrecomputeBlocked = (
    -not [bool]$summonControlInsufficientPrecompute.eligibility.allowed -and
    (@($summonControlInsufficientPrecompute.reasonCodes) -contains "AUTH-SUMMON-COMPLEXITY-PRECOMPUTE-INSUFFICIENT")
)
$partyPlannerBuildsViableTeam = (
    [bool]$summonPartyPlan.plan.viable -and
    @($summonPartyPlan.plan.selectedControllers).Count -ge [int]$summonPartyPlan.requirements.requiredControllers
)
$partyPlannerSupportsAutomaticRuntime = (
    [string]$summonPartyPlan.plan.runtimeMode -eq "automatic" -and
    [int]$summonPartyPlan.plan.precomputeComplexity -ge [int]$summonPartyPlan.requirements.requiredPrecomputeComplexity
)
$partyPlannerDeterministicAuthority = ([bool]$summonPartyPlan.deterministic -and [bool]$summonPartyPlan.authorityValidated)
$multikeyValidAllowed = (
    [bool]$multikeyCastValid.allowed -and
    [bool]$multikeyCastValid.timing.parityCadence -and
    [bool]$multikeyCastValid.timing.withinWindow
)
$multikeyInvalidBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-MULTIKEY-SEQUENCE-MISMATCH")
)
$multikeyDeterministicAuthority = ([bool]$multikeyCastValid.deterministic -and [bool]$multikeyCastValid.authorityValidated)
$highTierPrecompiledAidRequired = (
    [bool]$multikeyCastValid.delivery.requiresPrecompiledAid -and
    [bool]$multikeyCastValid.delivery.hasPrecompiledAid -and
    [bool]$multikeyCastValid.delivery.valid
)
$highTierRawAssemblyBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-HIGH-TIER-RAW-ASSEMBLY-DISALLOWED")
)
$veryHighTierTomeEnforced = (
    [bool]$multikeyCastValid.delivery.requiresFullTome -and
    [bool]$multikeyCastValid.delivery.fullTomeEquipped -and
    [bool]$multikeyCastValid.allowed
)
$veryHighTierMissingTomeBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-VERY-HIGH-TIER-TOME-REQUIRED")
)
$highestTierMaxLevelAndWorldItemEnforced = (
    [bool]$multikeyCastValid.delivery.requiresMaxLevelCasterAndWorldItems -and
    [int]$multikeyCastValid.casterLevel -ge 9999 -and
    [bool]$multikeyCastValid.delivery.hasRequiredWorldItems
)
$highestTierMissingLevelOrItemBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (
        (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-HIGHEST-TIER-MAX-LEVEL-REQUIRED") -or
        (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-HIGHEST-TIER-WORLD-ITEM-REQUIRED")
    )
)
$complexSpellCompositionValid = (
    [bool]$multikeyCastValid.composition.isComplexSpell -and
    [bool]$multikeyCastValid.composition.valid
)
$complexSpellInvalidBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-COMPLEX-STAGE-ORDER-INVALID")
)
$multidimensionalValid = (
    [bool]$multikeyCastValid.dimensions.isMultidimensional -and
    [bool]$multikeyCastValid.dimensions.valid
)
$multidimensionalInvalidBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-MULTIDIMENSIONAL-LEGALITY-FAILED")
)
$parallelCastValid = (
    [int]$multikeyCastValid.parallel.requested -gt 1 -and
    [bool]$multikeyCastValid.parallel.valid
)
$parallelCastInvalidBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-PARALLEL-BUDGET-OR-LEGALITY-FAILED")
)
$concurrentDifficultyValid = (
    [bool]$multikeyCastValid.concurrentCasting.score.valid -and
    ([int]$multikeyCastValid.concurrentCasting.score.capacity -ge [int]$multikeyCastValid.concurrentCasting.score.difficulty)
)
$concurrentDifficultyInvalidBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-CONCURRENT-DIFFICULTY-EXCEEDS-CAPACITY")
)
$waterFireConflictAppliedWhenUnenhanced = (
    [bool]$multikeyCastInvalid.concurrentCasting.conflict.waterFirePresent -and
    -not [bool]$multikeyCastInvalid.concurrentCasting.conflict.bridgePresent -and
    [int]$multikeyCastInvalid.concurrentCasting.conflict.penalty -gt 0
)
$elementSynthesisApplied = (
    [bool]$multikeyCastValid.concurrentCasting.synthesis.applied -and
    (@($multikeyCastValid.concurrentCasting.synthesis.combinedSpells | Where-Object { [string]$_.resultElement -eq "wood" }).Count -ge 1)
)
$compoundMulticastValid = (
    [bool]$multikeyCastValid.compoundMulticast.requested -and
    [bool]$multikeyCastValid.compoundMulticast.valid -and
    [bool]$multikeyCastValid.compoundMulticast.simultaneous
)
$compoundMulticastInvalidBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-COMPOUND-SEQUENCE-INVALID") -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-COMPOUND-NOT-SIMULTANEOUS")
)
$playerItemlessAffinityGateBlocked = (
    -not [bool]$multikeyCastInvalid.allowed -and
    (@($multikeyCastInvalid.reasonCodes) -contains "AUTH-CAST-PLAYER-AFFINITY-EXPERIENCE-INSUFFICIENT-FOR-ITEMLESS-MULTICAST")
)
$enemyMulticastEffective = (
    [bool]$multikeyCastEnemy.allowed -and
    (@($multikeyCastEnemy.reasonCodes) -contains "AUTH-CAST-ENEMY-MULTICAST-PROFICIENCY-APPLIED")
)
$bossHighHealthAndGearValid = (
    [bool]$bossEnhancementValid.allowed -and
    [bool]$bossEnhancementValid.health.valid -and
    [bool]$bossEnhancementValid.gear.valid
)
$bossEnhancementRewardScalingValid = (
    [bool]$bossEnhancementValid.enhancements.valid -and
    [bool]$bossEnhancementValid.rewards.valid -and
    [int]$bossEnhancementValid.rewards.scaledTier -ge [int]$bossEnhancementValid.rewards.baseTier -and
    [int]$bossEnhancementValid.rewards.scaledQuantity -ge [int]$bossEnhancementValid.rewards.baseQuantity
)
$bossInvalidBlocked = (
    -not [bool]$bossEnhancementInvalid.allowed -and
    (@($bossEnhancementInvalid.reasonCodes) -contains "AUTH-BOSS-HEALTH-POOL-INSUFFICIENT") -and
    (@($bossEnhancementInvalid.reasonCodes) -contains "AUTH-BOSS-LEGENDARY-GEAR-TIER-INSUFFICIENT")
)
$equipmentCustomizationProfilePresent = (
    [bool]$equipmentConditionValid.allowed -and
    @($equipmentConditionValid.customization.constructionItemTiers).Count -ge 1 -and
    [double]$equipmentConditionValid.customization.durabilityPct -ge 0 -and
    [double]$equipmentConditionValid.customization.craftsmanshipQuality -ge 0 -and
    [double]$equipmentConditionValid.customization.ageYears -ge 0 -and
    [double]$equipmentConditionValid.customization.maintenanceCondition -ge 0
)
$equipmentMintRequiresQualifiedCraftsman = (
    [bool]$equipmentConditionValid.repair.mintAchieved -and
    [bool]$equipmentConditionValid.repair.qualifiedCraftsman -and
    -not [bool]$equipmentConditionInvalid.repair.mintAchieved -and
    (@($equipmentConditionInvalid.reasonCodes) -contains "AUTH-EQUIP-MINT-REPAIR-QUALIFIED-CRAFTER-REQUIRED")
)
$equipmentConditionDeterministicAuthority = (
    [bool]$equipmentConditionValid.deterministic -and
    [bool]$equipmentConditionValid.authorityValidated
)
$lootAndCraftingEmitConditionMultipliers = (
    [double]$lootConditionRoll.condition.valueMultiplier -gt 0 -and
    [double]$lootConditionRoll.condition.effectivenessMultiplier -gt 0 -and
    [double]$craftedCondition.condition.valueMultiplier -gt 0 -and
    [double]$craftedCondition.condition.effectivenessMultiplier -gt 0
)
$conditionImpactsMarketPricing = (
    [double]$craftedCondition.condition.valueMultiplier -gt [double]$lootConditionRoll.condition.valueMultiplier -and
    [double]$craftedMarketPrice.pricing.finalPrice -gt [double]$lootMarketPrice.pricing.finalPrice -and
    (@($craftedMarketPrice.reasonCodes) -contains "AUTH-ECON-PRICE-CONDITION-APPLIED")
)
$economyVariesByLocationKingdomCurrency = (
    [string]$locationCurrencyMarketPrice.pricing.storeCurrencyCode -ne [string]$locationCurrencyMarketPrice.pricing.baseCurrencyCode -and
    [double]$locationCurrencyMarketPrice.pricing.locationDemandMultiplier -gt 1.0 -and
    [double]$locationCurrencyMarketPrice.pricing.taxMultiplier -gt 1.0 -and
    (@($locationCurrencyMarketPrice.reasonCodes) -contains "AUTH-ECON-PRICE-LOCATION-KINGDOM-APPLIED") -and
    (@($locationCurrencyMarketPrice.reasonCodes) -contains "AUTH-ECON-PRICE-CURRENCY-CONVERSION-APPLIED")
)
$conditionImpactsCombatEffectiveness = (
    [double]$craftedCondition.condition.effectivenessMultiplier -gt [double]$lootConditionRoll.condition.effectivenessMultiplier -and
    [double]$craftedCombatEffectiveness.combat.adjustedAttack -gt [double]$lootCombatEffectiveness.combat.adjustedAttack -and
    (@($craftedCombatEffectiveness.reasonCodes) -contains "AUTH-COMBAT-EQUIP-CONDITION-APPLIED")
)
$equipmentFlowDeterministicAuthorityValidated = (
    [bool]$lootConditionRoll.deterministic -and [bool]$lootConditionRoll.authorityValidated -and
    [bool]$craftedCondition.deterministic -and [bool]$craftedCondition.authorityValidated -and
    [bool]$lootMarketPrice.deterministic -and [bool]$lootMarketPrice.authorityValidated -and
    [bool]$craftedMarketPrice.deterministic -and [bool]$craftedMarketPrice.authorityValidated -and
    [bool]$lootCombatEffectiveness.deterministic -and [bool]$lootCombatEffectiveness.authorityValidated -and
    [bool]$craftedCombatEffectiveness.deterministic -and [bool]$craftedCombatEffectiveness.authorityValidated
)
$temporaryAndPermanentEnchantmentsSupported = (
    [bool]$itemMagicModifierValid.allowed -and
    [int]$itemMagicModifierValid.enchantments.temporary.active -ge 1 -and
    [int]$itemMagicModifierValid.enchantments.permanent.total -ge 1 -and
    (@($itemMagicModifierValid.reasonCodes) -contains "AUTH-ITEM-TEMP-ENCHANT-ACTIVE") -and
    (@($itemMagicModifierValid.reasonCodes) -contains "AUTH-ITEM-PERM-ENCHANT-APPLIED")
)
$runesAndIntegratedScriptsSupported = (
    [int]$itemMagicModifierValid.runes.total -ge 1 -and
    [int]$itemMagicModifierValid.integratedScripts.total -ge 1 -and
    [int]$itemMagicModifierValid.integratedScripts.automationScore -gt 0 -and
    (@($itemMagicModifierValid.reasonCodes) -contains "AUTH-ITEM-RUNES-APPLIED") -and
    (@($itemMagicModifierValid.reasonCodes) -contains "AUTH-ITEM-INTEGRATED-SCRIPT-ACTIVE")
)
$contextualModifiersApplied = (
    @($itemMagicModifierValid.contextualModifiers | Where-Object { [bool]$_.applies }).Count -ge 1 -and
    (@($itemMagicModifierValid.reasonCodes) -contains "AUTH-ITEM-CONTEXT-MODIFIERS-APPLIED")
)
$invalidItemMagicModifierBlocked = (
    -not [bool]$itemMagicModifierInvalid.allowed -and
    (@($itemMagicModifierInvalid.reasonCodes) -contains "AUTH-ITEM-TEMP-ENCHANT-DURATION-INVALID") -and
    (@($itemMagicModifierInvalid.reasonCodes) -contains "AUTH-ITEM-INTEGRATED-SCRIPT-NOT-APPROVED") -and
    (@($itemMagicModifierInvalid.reasonCodes) -contains "AUTH-ITEM-CONTEXT-MODIFIER-TARGET-INVALID")
)
$itemMagicModifierDeterministicAuthority = (
    [bool]$itemMagicModifierValid.deterministic -and
    [bool]$itemMagicModifierValid.authorityValidated
)
$intraSpeciesPrejudiceDriversApplied = (
    [bool]$temperamentIntraSpecies.socialBias.sameSpecies -and
    [int]$temperamentIntraSpecies.socialBias.prejudiceScore -gt 0 -and
    [int]$temperamentIntraSpecies.socialBias.drivers.incomeTierDelta -gt 0 -and
    [int]$temperamentIntraSpecies.socialBias.drivers.hometownRivalry -gt 0 -and
    [int]$temperamentIntraSpecies.socialBias.drivers.allianceConflict -gt 0 -and
    [int]$temperamentIntraSpecies.socialBias.drivers.eventsPressure -gt 0 -and
    [int]$temperamentIntraSpecies.socialBias.drivers.vendettaPressure -gt 0 -and
    (@($temperamentIntraSpecies.reasonCodes) -contains "AUTH-SOC-INTRASPECIES-PREJUDICE-DRIVERS-APPLIED")
)
$intraSpeciesPrejudiceAffectsBehavior = (
    [int]$temperamentIntraSpecies.socialBias.trustDelta -lt 0 -and
    [int]$temperamentIntraSpecies.socialBias.obedienceDelta -lt 0 -and
    [int]$temperamentIntraSpecies.socialBias.conflictLikelihoodDelta -gt 0
)
$crossSpeciesDoesNotTriggerIntraSpeciesModel = (
    -not [bool]$temperamentCrossSpecies.socialBias.sameSpecies -and
    [int]$temperamentCrossSpecies.socialBias.prejudiceScore -eq 0
)
$intraSpeciesBiasDeterministicAuthority = (
    [bool]$temperamentIntraSpecies.deterministic -and
    [bool]$temperamentIntraSpecies.authorityValidated
)
$intraspeciesBiasCanBlockCommandAcceptance = (
    [bool]$demonCommandAcceptedLowBias.applied -and
    -not [bool]$demonCommandBlockedHighBias.applied -and
    (@($demonCommandBlockedHighBias.reasonCodes) -contains "AUTH-CMD-OBEDIENCE-BLOCKED-INTRASPECIES-BIAS")
)
$diplomacyAndBiasIncreaseRouteRisk = (
    [double]$routeRisk.topRiskRoutes[0].riskScore -gt [double]$routeRiskNeutral.topRiskRoutes[0].riskScore -and
    [double]$routeRisk.topRiskRoutes[0].socialBiasPenalty -gt 0
)

Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "level_dominates_affinity_weight" $levelDominantOutcome "level multiplier remains the dominant driver when both level and affinity apply"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "triangle_still_influences_matchup" $triangleAffectsOutcome "triangle advantage still contributes as a secondary multiplier"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "summon_affinity_is_deterministic_authority_validated" $deterministicAuthority "resolver output marks deterministic and authority validated"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "precomputed_quicksummon_allows_automatic_runtime" $precomputedAllowsAutomatic "quicksummon precompute plus assist items allows automatic summon runtime"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "single_controller_cannot_control_equivalent_target" $insufficientControllersBlocked "single equivalent-level controller cannot take control alone"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "insufficient_precompute_blocks_automatic_control" $insufficientPrecomputeBlocked "runtime blocks when complexity precompute prerequisites are insufficient"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "party_planner_builds_viable_control_team" $partyPlannerBuildsViableTeam "planner selects sufficient equitable-level controllers for target control"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "party_planner_targets_automatic_execution" $partyPlannerSupportsAutomaticRuntime "planner assembles precompute budget for automatic runtime execution"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "party_planner_deterministic_authority_validated" $partyPlannerDeterministicAuthority "planner output is deterministic and authority validated"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "multikey_cast_allows_realtime_tempo_parity" $multikeyValidAllowed "valid compact multikey sequence remains within cast window and tempo parity"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "multikey_cast_blocks_partial_or_wrong_sequence" $multikeyInvalidBlocked "partial or wrong multikey sequence is blocked with explicit reason code"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "multikey_cast_deterministic_authority_validated" $multikeyDeterministicAuthority "multikey cast validator output is deterministic and authority validated"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "high_tier_cast_uses_precompiled_delivery_aids" $highTierPrecompiledAidRequired "high-tier mid-fight casting requires prepared scroll/item/macro/auto-cast aid"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "high_tier_raw_logic_assembly_blocked" $highTierRawAssemblyBlocked "high-tier raw full-logic assembly during live input is blocked"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "very_high_tier_cast_requires_full_tome" $veryHighTierTomeEnforced "very-high-tier spells enforce full tome requirement"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "very_high_tier_missing_tome_blocked" $veryHighTierMissingTomeBlocked "very-high-tier cast without full tome is blocked"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "highest_tier_cast_requires_max_level_and_world_items" $highestTierMaxLevelAndWorldItemEnforced "highest-tier spells require max-level caster and required world-item constructor set"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "highest_tier_missing_level_or_world_item_blocked" $highestTierMissingLevelOrItemBlocked "highest-tier cast missing level or world items is blocked"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "complex_spell_composition_supported" $complexSpellCompositionValid "complex composed spell with staged deterministic order is supported"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "invalid_complex_spell_composition_blocked" $complexSpellInvalidBlocked "invalid complex staged composition is blocked"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "multidimensional_spell_legality_supported" $multidimensionalValid "multidimensional spell is allowed when legality gates pass"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "invalid_multidimensional_spell_blocked" $multidimensionalInvalidBlocked "multidimensional spell is blocked when legality gates fail"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "parallel_cast_supported_under_budget" $parallelCastValid "parallel casts are supported when budget and legality pass"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "invalid_parallel_cast_blocked" $parallelCastInvalidBlocked "parallel casts are blocked when budget or legality fails"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "concurrent_cast_difficulty_scales_and_validates" $concurrentDifficultyValid "concurrent cast difficulty remains within caster capacity on valid fixture"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "concurrent_cast_over_capacity_blocked" $concurrentDifficultyInvalidBlocked "concurrent cast is blocked when difficulty exceeds caster capacity"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "water_fire_unenhanced_conflict_penalized" $waterFireConflictAppliedWhenUnenhanced "water and fire concurrent casting incurs deterministic conflict penalty without enhancement bridge"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "element_synthesis_creates_combined_spell_type" $elementSynthesisApplied "compatible enhancement pair synthesizes combined spell type (healing + earth => wood)"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "compound_multicast_sequences_can_cast_simultaneously" $compoundMulticastValid "compound multicast validates multiple sequence branches in the shared simultaneity window"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "invalid_compound_multicast_sequences_blocked" $compoundMulticastInvalidBlocked "compound multicast is blocked for invalid branch sequence and non-simultaneous timing"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "player_itemless_multicast_requires_high_affinity_experience" $playerItemlessAffinityGateBlocked "player itemless pre-high-level multicast is blocked when element affinity/experience thresholds are not met"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "enemy_multicast_profile_effectiveness_supported" $enemyMulticastEffective "enemy multicast profile can apply proficiency and still pass deterministic authority checks"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "boss_and_area_boss_high_health_with_specialized_gear" $bossHighHealthAndGearValid "boss and area-boss entities validate high health pools and higher-tier specialized gear"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "boss_enhancement_stack_scales_power_and_rewards" $bossEnhancementRewardScalingValid "stacked enhancements increase deterministic power and reward scaling"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "invalid_boss_profile_blocked" $bossInvalidBlocked "invalid boss profile with weak health/gear is blocked by authority checks"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "equipment_customization_profile_includes_condition_dimensions" $equipmentCustomizationProfilePresent "equipment carries construction tier, durability, quality, age, and maintenance customization dimensions"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "equipment_mint_restore_requires_qualified_craftsman" $equipmentMintRequiresQualifiedCraftsman "mint restoration is allowed only with a qualified craftsman; non-qualified attempts are blocked"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "equipment_condition_updates_are_deterministic_authority_validated" $equipmentConditionDeterministicAuthority "equipment condition resolution remains deterministic and authority validated"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "loot_and_crafting_flows_emit_condition_multipliers" $lootAndCraftingEmitConditionMultipliers "loot and crafted equipment both carry runtime condition multipliers"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "equipment_condition_directly_changes_market_pricing" $conditionImpactsMarketPricing "condition multipliers deterministically affect final market price outputs"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "economy_varies_by_location_kingdom_currency" $economyVariesByLocationKingdomCurrency "market pricing varies deterministically by location, kingdom policy, and currency conversion"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "equipment_condition_directly_changes_combat_effectiveness" $conditionImpactsCombatEffectiveness "condition multipliers deterministically affect runtime combat effectiveness outputs"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "equipment_condition_flow_deterministic_authority_validated" $equipmentFlowDeterministicAuthorityValidated "loot/crafting/economy/combat condition flow remains deterministic and authority validated"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "item_temporary_and_permanent_enchantments_supported" $temporaryAndPermanentEnchantmentsSupported "runtime supports temporary and permanent enchantments with deterministic activation and stacking"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "item_runes_and_integrated_magic_scripts_supported" $runesAndIntegratedScriptsSupported "runtime supports rune modifiers and authority-approved integrated magic scripts for automation/equipment logic"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "item_contextual_bonuses_and_decrements_supported" $contextualModifiersApplied "runtime applies logical contextual bonus/decrement modifiers based on environment/profile/class/race/subclass/set/condition"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "invalid_item_magic_modifier_profiles_blocked" $invalidItemMagicModifierBlocked "invalid enchant duration, unapproved integrated scripts, and invalid modifier targets are blocked"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "item_magic_modifier_resolution_deterministic_authority_validated" $itemMagicModifierDeterministicAuthority "item modifier resolution remains deterministic and authority validated"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "intraspecies_prejudice_drivers_supported" $intraSpeciesPrejudiceDriversApplied "same-species social bias supports income/hometown/alliance/event/vendetta deterministic drivers"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "intraspecies_prejudice_modifies_behavior_outputs" $intraSpeciesPrejudiceAffectsBehavior "intra-species prejudice modifies trust/obedience/conflict likelihood outputs"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "cross_species_profiles_do_not_trigger_intraspecies_driver_model" $crossSpeciesDoesNotTriggerIntraSpeciesModel "intra-species driver model only activates for same-species evaluations"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "intraspecies_bias_resolution_deterministic_authority_validated" $intraSpeciesBiasDeterministicAuthority "intra-species bias resolution is deterministic and authority validated"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "intraspecies_bias_can_block_command_acceptance" $intraspeciesBiasCanBlockCommandAcceptance "command acceptance enforces obedience gate based on intraspecies social bias outputs"
Add-Check "SUPPLEMENTAL-SUMMON-AFFINITY-RULE-V1" "diplomacy_and_bias_signals_raise_route_risk" $diplomacyAndBiasIncreaseRouteRisk "route risk scoring incorporates diplomacy friction and social bias trust penalties"

foreach ($t in $phase2) {
    Add-Check ([string]$t.id) "task_status_done" ([string]$t.status -eq "done") ("status=" + [string]$t.status)
}

$taskIds = @($checks | ForEach-Object { $_.taskId } | Sort-Object -Unique)
$taskSummaries = @()
foreach ($tid in $taskIds) {
    $rows = @($checks | Where-Object { $_.taskId -eq $tid })
    $taskSummaries += @{
        taskId = $tid
        passed = (@($rows | Where-Object { -not [bool]$_.passed }).Count -eq 0)
        checks = $rows
    }
}

$allPassed = (@($taskSummaries | Where-Object { -not [bool]$_.passed }).Count -eq 0 -and @($phase2).Count -gt 0)
$result = @{
    report = "phase2_acceptance_report_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    phase2TaskCount = @($phase2).Count
    passed = $allPassed
    tasks = $taskSummaries
}

if ($WriteReport) {
    $outDir = Join-Path $RepoRoot "reports"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $path = Join-Path $outDir "phase2-acceptance-report-$stamp.json"
    $result | ConvertTo-Json -Depth 12 | Set-Content -Path $path -Encoding UTF8
    $result["reportPath"] = $path
}

$result | ConvertTo-Json -Depth 12 | Write-Output
if ($Strict -and -not $allPassed) { exit 1 }
exit 0
