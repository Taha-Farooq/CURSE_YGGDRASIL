param(
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
Write-Host "[quality-gate] Starting..."
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Fail($msg) {
    Write-Error $msg
    exit 1
}

function Invoke-ResilientCheck {
    param(
        [scriptblock]$PrimaryCheck,
        [scriptblock]$Remediation,
        [scriptblock]$SecondaryCheck,
        [string]$FailureMessage,
        [string]$RecoveryMessage
    )

    try {
        & $PrimaryCheck
        return
    }
    catch {
        try {
            & $Remediation
            & $SecondaryCheck
            if (-not [string]::IsNullOrWhiteSpace($RecoveryMessage)) {
                Write-Host $RecoveryMessage
            }
        }
        catch {
            Fail ($FailureMessage + " Details: " + $_.Exception.Message)
        }
    }
}

if (-not (Test-Path (Join-Path $repoRoot "FEEDBACK_SCHEMA.json"))) {
    Fail "Missing FEEDBACK_SCHEMA.json"
}

if (-not (Test-Path (Join-Path $repoRoot "INTERACTION_MATRIX.md"))) {
    Fail "Missing INTERACTION_MATRIX.md"
}

if (-not (Test-Path (Join-Path $repoRoot "REQUIREMENTS.md"))) {
    Fail "Missing REQUIREMENTS.md"
}

if (-not (Test-Path (Join-Path $repoRoot "MAGITECH_INTEROP_SPEC.md"))) {
    Fail "Missing MAGITECH_INTEROP_SPEC.md"
}

if (-not (Test-Path (Join-Path $repoRoot "systems\networking\AUTHORITY_REASON_CODES.json"))) {
    Fail "Missing systems/networking/AUTHORITY_REASON_CODES.json"
}

if (-not (Test-Path (Join-Path $repoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"))) {
    Fail "Missing systems/integration/INTERACTION_MATRIX_CONTRACT.json"
}

# Basic JSON parse check
try {
    Get-Content (Join-Path $repoRoot "FEEDBACK_SCHEMA.json") -Raw | ConvertFrom-Json | Out-Null
    Write-Host "[quality-gate] FEEDBACK_SCHEMA.json is valid JSON."
}
catch {
    Fail "Invalid FEEDBACK_SCHEMA.json JSON."
}

# Authority reason-code contract parse and minimum validation
try {
    $reasonContract = Get-Content (Join-Path $repoRoot "systems\networking\AUTHORITY_REASON_CODES.json") -Raw | ConvertFrom-Json
    $requiredAuthCodes = @(
        "AUTH-INPUT-001",
        "AUTH-INPUT-002",
        "AUTH-SCOPE-001",
        "AUTH-BUDGET-001",
        "AUTH-INTEROP-001",
        "AUTH-INTEROP-002",
        "AUTH-INTEROP-003",
        "AUTH-INTEROP-004"
    )
    $presentCodes = @($reasonContract.codes | ForEach-Object { $_.code })
    foreach ($requiredCode in $requiredAuthCodes) {
        if ($presentCodes -notcontains $requiredCode) {
            Fail "Missing required authority reason code in AUTHORITY_REASON_CODES.json: $requiredCode"
        }
    }
    $requiredInteropMappings = @(
        "INT-LEG-004-FACT_ACCESS_EMPTY",
        "INT-LEG-005-REPLAY_REQUIRED",
        "INT-LEG-006-MISSING_INTEROP_TAGS",
        "INT-LEG-007-HYBRID_COST_CHANNELS_MISSING",
        "INT-LEG-010-SIM_BUDGET_EXCEEDED"
    )
    foreach ($interopCode in $requiredInteropMappings) {
        if ($null -eq $reasonContract.interopCodeMapping.$interopCode) {
            Fail "Missing INT->AUTH mapping in AUTHORITY_REASON_CODES.json: $interopCode"
        }
    }
}
catch {
    Fail "Invalid systems/networking/AUTHORITY_REASON_CODES.json contract."
}

# Interaction matrix contract parse and minimum validation
try {
    $matrixContract = Get-Content (Join-Path $repoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json") -Raw | ConvertFrom-Json
    if (@($matrixContract.interactions).Count -lt 1) {
        Fail "INTERACTION_MATRIX_CONTRACT.json has no interactions."
    }
    if (@($matrixContract.scenarios).Count -lt 1) {
        Fail "INTERACTION_MATRIX_CONTRACT.json has no scenarios."
    }
    $interactionIds = @($matrixContract.interactions | ForEach-Object { $_.interactionId })
    $scenarioIds = @($matrixContract.scenarios | ForEach-Object { $_.scenarioId })
    foreach ($requiredInteractionId in @($matrixContract.requiredInteractionIds)) {
        if ($interactionIds -notcontains $requiredInteractionId) {
            Fail "Missing required interaction ID in INTERACTION_MATRIX_CONTRACT.json: $requiredInteractionId"
        }
    }
    foreach ($requiredScenarioId in @($matrixContract.requiredScenarioIds)) {
        if ($scenarioIds -notcontains $requiredScenarioId) {
            Fail "Missing required scenario ID in INTERACTION_MATRIX_CONTRACT.json: $requiredScenarioId"
        }
    }
}
catch {
    Fail "Invalid systems/integration/INTERACTION_MATRIX_CONTRACT.json contract."
}

$syncScript = Join-Path $repoRoot "scripts\sync-authority-reason-codes-doc.ps1"
Invoke-ResilientCheck `
    -PrimaryCheck {
        & $syncScript -RepoRoot $repoRoot -Check
        if ($LASTEXITCODE -ne 0) { throw "sync check exit code: $LASTEXITCODE" }
    } `
    -Remediation {
        & $syncScript -RepoRoot $repoRoot
    } `
    -SecondaryCheck {
        & $syncScript -RepoRoot $repoRoot -Check
        if ($LASTEXITCODE -ne 0) { throw "sync re-check exit code: $LASTEXITCODE" }
    } `
    -FailureMessage "Failed to validate authority reason code doc sync." `
    -RecoveryMessage "[quality-gate] AUTHORITY_REASON_CODES.md required regeneration during validation."

$matrixSyncScript = Join-Path $repoRoot "scripts\sync-interaction-matrix-contract-doc.ps1"
Invoke-ResilientCheck `
    -PrimaryCheck {
        & $matrixSyncScript -RepoRoot $repoRoot -Check
        if ($LASTEXITCODE -ne 0) { throw "matrix sync check exit code: $LASTEXITCODE" }
    } `
    -Remediation {
        & $matrixSyncScript -RepoRoot $repoRoot
    } `
    -SecondaryCheck {
        & $matrixSyncScript -RepoRoot $repoRoot -Check
        if ($LASTEXITCODE -ne 0) { throw "matrix sync re-check exit code: $LASTEXITCODE" }
    } `
    -FailureMessage "Failed to validate interaction matrix contract doc sync." `
    -RecoveryMessage "[quality-gate] INTERACTION_MATRIX_CONTRACT_SUMMARY.md required regeneration during validation."

# Contract coverage check: all contract test/scenario IDs should have bot files.
try {
    $coverageScript = Join-Path $repoRoot "scripts\check-test-contract-coverage.ps1"
    $coverageResult = & $coverageScript -RepoRoot $repoRoot -Strict -WriteReport | ConvertFrom-Json
    if ($coverageResult.missingCount -gt 0) {
        Fail "Contract coverage check failed. Missing bot files: $($coverageResult.missingCount)"
    }
    Write-Host ("[quality-gate] Contract coverage: " + $coverageResult.coveragePct + "%, functional: " + $coverageResult.functionalPct + "%")
}
catch {
    Fail ("Failed to validate test contract coverage. Details: " + $_.Exception.Message)
}

# Critical regression guard: two consecutive failures in key tests should fail gate.
try {
    $criticalGuardScript = Join-Path $repoRoot "scripts\check-critical-regressions.ps1"
    $criticalResult = & $criticalGuardScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not $criticalResult.passed) {
        Fail ("Critical regression guard failed with " + @($criticalResult.criticalFindings).Count + " finding(s).")
    }
}
catch {
    Fail ("Failed to validate critical regression guard. Details: " + $_.Exception.Message)
}

# Real-time combat policy guard: battles/attacks must remain real-time, not turn-based.
try {
    $realtimePolicyScript = Join-Path $repoRoot "scripts\check-real-time-combat-policy.ps1"
    $realtimePolicy = & $realtimePolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$realtimePolicy.passed) {
        Fail "Real-time combat policy check failed."
    }
}
catch {
    Fail ("Failed to validate real-time combat policy. Details: " + $_.Exception.Message)
}

# Healing alignment policy guard: holy/profane healing interaction contract must remain intact.
try {
    $healingPolicyScript = Join-Path $repoRoot "scripts\check-healing-alignment-policy.ps1"
    $healingPolicy = & $healingPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$healingPolicy.passed) {
        Fail "Healing alignment policy check failed."
    }
}
catch {
    Fail ("Failed to validate healing alignment policy. Details: " + $_.Exception.Message)
}

# Summon affinity policy guard: race/class triangle with level-dominant outcomes.
try {
    $summonAffinityPolicyScript = Join-Path $repoRoot "scripts\check-summon-affinity-policy.ps1"
    $summonAffinityPolicy = & $summonAffinityPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$summonAffinityPolicy.passed) {
        Fail "Summon affinity policy check failed."
    }
}
catch {
    Fail ("Failed to validate summon affinity policy. Details: " + $_.Exception.Message)
}

# Spellcasting flow policy guard: intuitive multi-key real-time casting parity.
try {
    $spellcastingFlowPolicyScript = Join-Path $repoRoot "scripts\check-spellcasting-flow-policy.ps1"
    $spellcastingFlowPolicy = & $spellcastingFlowPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$spellcastingFlowPolicy.passed) {
        Fail "Spellcasting flow policy check failed."
    }
}
catch {
    Fail ("Failed to validate spellcasting flow policy. Details: " + $_.Exception.Message)
}

# Legendary force/presentation policy guard: gravity-size-density manipulation and visual quality rules.
try {
    $legendaryPolicyScript = Join-Path $repoRoot "scripts\check-legendary-forces-and-presentation-policy.ps1"
    $legendaryPolicy = & $legendaryPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$legendaryPolicy.passed) {
        Fail "Legendary forces and presentation policy check failed."
    }
}
catch {
    Fail ("Failed to validate legendary forces/presentation policy. Details: " + $_.Exception.Message)
}

# Boss enhancement policy guard: high health, higher-tier gear, enhancement/reward scaling.
try {
    $bossPolicyScript = Join-Path $repoRoot "scripts\check-boss-enhancement-policy.ps1"
    $bossPolicy = & $bossPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$bossPolicy.passed) {
        Fail "Boss enhancement policy check failed."
    }
}
catch {
    Fail ("Failed to validate boss enhancement policy. Details: " + $_.Exception.Message)
}

# Equipment condition policy guard: customization dimensions and qualified-craftsman mint restoration.
try {
    $equipmentPolicyScript = Join-Path $repoRoot "scripts\check-equipment-condition-policy.ps1"
    $equipmentPolicy = & $equipmentPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$equipmentPolicy.passed) {
        Fail "Equipment condition policy check failed."
    }
}
catch {
    Fail ("Failed to validate equipment condition policy. Details: " + $_.Exception.Message)
}

# Intra-species social bias policy guard: same-species prejudice drivers by social and political context.
try {
    $intraSpeciesBiasPolicyScript = Join-Path $repoRoot "scripts\check-intraspecies-social-bias-policy.ps1"
    $intraSpeciesBiasPolicy = & $intraSpeciesBiasPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$intraSpeciesBiasPolicy.passed) {
        Fail "Intra-species social bias policy check failed."
    }
}
catch {
    Fail ("Failed to validate intra-species social bias policy. Details: " + $_.Exception.Message)
}

# Feedback loop and acceptance policy guard: project-level, bot-system, and feedback-loop acceptance contracts.
try {
    $feedbackLoopPolicyScript = Join-Path $repoRoot "scripts\check-feedback-loop-policy.ps1"
    $feedbackLoopPolicy = & $feedbackLoopPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$feedbackLoopPolicy.passed) {
        Fail "Feedback loop and acceptance policy check failed."
    }
}
catch {
    Fail ("Failed to validate feedback loop/acceptance policy. Details: " + $_.Exception.Message)
}

# Feedback operations policy guard: collection channels, schema, triage, and critique-to-change workflow.
try {
    $feedbackOpsPolicyScript = Join-Path $repoRoot "scripts\check-feedback-operations-policy.ps1"
    $feedbackOpsPolicy = & $feedbackOpsPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$feedbackOpsPolicy.passed) {
        Fail "Feedback operations policy check failed."
    }
}
catch {
    Fail ("Failed to validate feedback operations policy. Details: " + $_.Exception.Message)
}

# Economy location/currency policy guard: market variation by location/kingdom and deterministic currency conversion.
try {
    $economyLocationCurrencyPolicyScript = Join-Path $repoRoot "scripts\check-economy-location-currency-policy.ps1"
    $economyLocationCurrencyPolicy = & $economyLocationCurrencyPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$economyLocationCurrencyPolicy.passed) {
        Fail "Economy location/currency policy check failed."
    }
}
catch {
    Fail ("Failed to validate economy location/currency policy. Details: " + $_.Exception.Message)
}

# Cohesion and governance policy guard: unified structure, coupling rules, and governance transparency.
try {
    $cohesionGovernancePolicyScript = Join-Path $repoRoot "scripts\check-cohesion-governance-policy.ps1"
    $cohesionGovernancePolicy = & $cohesionGovernancePolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$cohesionGovernancePolicy.passed) {
        Fail "Cohesion and governance policy check failed."
    }
}
catch {
    Fail ("Failed to validate cohesion/governance policy. Details: " + $_.Exception.Message)
}

# Live content, automation, and goal-alignment policy guard.
try {
    $liveContentAutomationGoalPolicyScript = Join-Path $repoRoot "scripts\check-live-content-automation-goal-policy.ps1"
    $liveContentAutomationGoalPolicy = & $liveContentAutomationGoalPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$liveContentAutomationGoalPolicy.passed) {
        Fail "Live content/automation/goal policy check failed."
    }
}
catch {
    Fail ("Failed to validate live content/automation/goal policy. Details: " + $_.Exception.Message)
}

# Apex/NPC/unified/integration policy guard.
try {
    $apexNpcUnifiedIntegrationPolicyScript = Join-Path $repoRoot "scripts\check-apex-npc-unified-integration-policy.ps1"
    $apexNpcUnifiedIntegrationPolicy = & $apexNpcUnifiedIntegrationPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$apexNpcUnifiedIntegrationPolicy.passed) {
        Fail "Apex/NPC/unified/integration policy check failed."
    }
}
catch {
    Fail ("Failed to validate apex/NPC/unified/integration policy. Details: " + $_.Exception.Message)
}

# Foundational world systems policy guard.
try {
    $foundationalWorldSystemsPolicyScript = Join-Path $repoRoot "scripts\check-foundational-world-systems-policy.ps1"
    $foundationalWorldSystemsPolicy = & $foundationalWorldSystemsPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$foundationalWorldSystemsPolicy.passed) {
        Fail "Foundational world systems policy check failed."
    }
}
catch {
    Fail ("Failed to validate foundational world systems policy. Details: " + $_.Exception.Message)
}

# Construction/items/economy/consequences policy guard.
try {
    $constructionItemsEconomyConsequencesPolicyScript = Join-Path $repoRoot "scripts\check-construction-items-economy-consequences-policy.ps1"
    $constructionItemsEconomyConsequencesPolicy = & $constructionItemsEconomyConsequencesPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$constructionItemsEconomyConsequencesPolicy.passed) {
        Fail "Construction/items/economy/consequences policy check failed."
    }
}
catch {
    Fail ("Failed to validate construction/items/economy/consequences policy. Details: " + $_.Exception.Message)
}

# Governance/AI/conflict/empire policy guard.
try {
    $governanceAiConflictEmpirePolicyScript = Join-Path $repoRoot "scripts\check-governance-ai-conflict-empire-policy.ps1"
    $governanceAiConflictEmpirePolicy = & $governanceAiConflictEmpirePolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$governanceAiConflictEmpirePolicy.passed) {
        Fail "Governance/AI/conflict/empire policy check failed."
    }
}
catch {
    Fail ("Failed to validate governance/AI/conflict/empire policy. Details: " + $_.Exception.Message)
}

# Engine/evolution/milestones/demonlord policy guard.
try {
    $engineEvolutionMilestonesDemonlordPolicyScript = Join-Path $repoRoot "scripts\check-engine-evolution-milestones-demonlord-policy.ps1"
    $engineEvolutionMilestonesDemonlordPolicy = & $engineEvolutionMilestonesDemonlordPolicyScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$engineEvolutionMilestonesDemonlordPolicy.passed) {
        Fail "Engine/evolution/milestones/demonlord policy check failed."
    }
}
catch {
    Fail ("Failed to validate engine/evolution/milestones/demonlord policy. Details: " + $_.Exception.Message)
}

# Phase 2 acceptance evidence pack guard.
try {
    $phase2EvidenceScript = Join-Path $repoRoot "scripts\check-phase2-acceptance-evidence-pack.ps1"
    $phase2Evidence = & $phase2EvidenceScript -RepoRoot $repoRoot -Strict | ConvertFrom-Json
    if (-not [bool]$phase2Evidence.passed) {
        Fail "Phase 2 acceptance evidence pack validation failed."
    }
}
catch {
    Fail ("Failed to validate phase2 acceptance evidence pack. Details: " + $_.Exception.Message)
}

# Test freshness policy: key bot reports must be recent after automated runs.
try {
    $configPath = Join-Path $repoRoot "automation\automation-config.json"
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $maxAgeHours = 24
    if ($null -ne $config.bots.testFreshnessPolicy -and $null -ne $config.bots.testFreshnessPolicy.maxAgeHours) {
        $maxAgeHours = [int]$config.bots.testFreshnessPolicy.maxAgeHours
    }

    $freshnessScript = Join-Path $repoRoot "scripts\check-test-freshness.ps1"
    $freshnessResult = & $freshnessScript -RepoRoot $repoRoot -MaxAgeHours $maxAgeHours -Strict:$Strict | ConvertFrom-Json
    $dataSufficient = $true
    if ($null -ne $freshnessResult.dataSufficient) {
        $dataSufficient = [bool]$freshnessResult.dataSufficient
    }

    if (-not $dataSufficient) {
        $reason = $(if (-not [string]::IsNullOrWhiteSpace([string]$freshnessResult.skipReason)) { [string]$freshnessResult.skipReason } else { "insufficient report history" })
        Write-Host ("[quality-gate] Freshness policy skipped: " + $reason)
    }
    elseif (-not $freshnessResult.passed) {
        $missingCount = @($freshnessResult.missing).Count
        $staleCount = @($freshnessResult.stale).Count
        if ($Strict) {
            Fail ("Test freshness policy failed. Missing: $missingCount, stale: $staleCount, maxAgeHours: $maxAgeHours")
        } else {
            Write-Host ("[quality-gate] WARNING test freshness policy not satisfied. Missing: $missingCount, stale: $staleCount")
        }
    }
}
catch {
    Fail ("Failed to validate test freshness policy. Details: " + $_.Exception.Message)
}

# Basic matrix checks
$matrix = Get-Content (Join-Path $repoRoot "INTERACTION_MATRIX.md") -Raw
if ($matrix -notmatch "INT-") {
    Fail "INTERACTION_MATRIX.md has no interaction IDs."
}
if ($matrix -notmatch "SCN-") {
    Fail "INTERACTION_MATRIX.md missing scenario mapping section."
}
if ($matrix -notmatch "INT-0013") {
    Fail "INTERACTION_MATRIX.md missing INT-0013 magitech interop mapping."
}
if ($matrix -notmatch "SCN-005") {
    Fail "INTERACTION_MATRIX.md missing SCN-005 magitech scenario mapping."
}

# Ensure requirements include key automation sections
$req = Get-Content (Join-Path $repoRoot "REQUIREMENTS.md") -Raw
$requiredMarkers = @(
    "## 24) Live Content Authoring and AI-Assisted Generation",
    "## 25) Autonomous Bot Framework",
    "## 27) System Interaction Matrix",
    "## 28) Human Feedback and Product Adaptation Loop"
)

foreach ($marker in $requiredMarkers) {
    if ($req -notmatch [regex]::Escape($marker)) {
        Fail "Missing required section in REQUIREMENTS.md: $marker"
    }
}
if ($req -notmatch [regex]::Escape("MAGITECH_INTEROP_SPEC.md")) {
    Fail "REQUIREMENTS.md must reference MAGITECH_INTEROP_SPEC.md."
}

if ($Strict) {
    Write-Host "[quality-gate] Strict mode enabled. Add project tests/lints here."
    # Placeholder for future commands:
    # npm test
    # dotnet test
    # python -m pytest
}

Write-Host "[quality-gate] PASS"
exit 0

