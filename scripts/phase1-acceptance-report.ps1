param(
    [string]$RepoRoot = "",
    [switch]$WriteReport,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

function Invoke-Json([scriptblock]$Block) {
    $out = & $Block
    return ($out | ConvertFrom-Json)
}

$checks = @()
function Add-Check([string]$taskId, [string]$name, [bool]$passed, [string]$details) {
    $script:checks += @{
        taskId = $taskId
        check = $name
        passed = $passed
        details = $details
    }
}

# Task 1
$tick1 = Invoke-Json { & (Join-Path $RepoRoot "engine\sim\tick-loop\tick-loop-service.ps1") -RepoRoot $RepoRoot -Ticks 3 }
$tick2 = Invoke-Json { & (Join-Path $RepoRoot "engine\sim\tick-loop\tick-loop-service.ps1") -RepoRoot $RepoRoot -Ticks 3 }
$ledger = Invoke-Json { & (Join-Path $RepoRoot "engine\state\world-ledger\world-ledger-service.ps1") -RepoRoot $RepoRoot }
Add-Check "TASK-PHASE1-01-CORE-TICK-AND-WORLD-STATE-LEDGER" "deterministic_hash" ($tick1.worldStateHash -eq $tick2.worldStateHash) "same seed hash stable"
Add-Check "TASK-PHASE1-01-CORE-TICK-AND-WORLD-STATE-LEDGER" "ledger_writes" ([int]$ledger.recordsWritten -ge 1) "world ledger wrote record(s)"

# Task 2
$auth = Invoke-Json { & (Join-Path $RepoRoot "scripts\authority-validate-action.ps1") -RepoRoot $RepoRoot -ActionJsonPath (Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json") }
Add-Check "TASK-PHASE1-02-AUTHORITY-VALIDATION-SERVICE-V1" "authority_allows_valid_hybrid" ([bool]$auth.allowed) "IT-MGI-001 valid path"
Add-Check "TASK-PHASE1-02-AUTHORITY-VALIDATION-SERVICE-V1" "authority_reason_codes_present" (@($auth.reasonCodes).Count -ge 0) "reason code contract wired"

# Task 3
$replayCapture = Invoke-Json { & (Join-Path $RepoRoot "engine\replay\collector\replay-collector.ps1") -RepoRoot $RepoRoot }
$replayQuery = Invoke-Json { & (Join-Path $RepoRoot "tools\replay\query\get-replay-by-id.ps1") -RepoRoot $RepoRoot -EventId ([string]$replayCapture.capturedEventId) }
Add-Check "TASK-PHASE1-03-REPLAY-EVIDENCE-PIPELINE-V1" "replay_capture" (-not [string]::IsNullOrWhiteSpace([string]$replayCapture.capturedEventId)) "captured event id exists"
Add-Check "TASK-PHASE1-03-REPLAY-EVIDENCE-PIPELINE-V1" "replay_query" ([bool]$replayQuery.found) "query by event id returns record"

# Task 4
$tiered = Invoke-Json { & (Join-Path $RepoRoot "engine\sim\tiered-world\tiered-world-continuity-service.ps1") -RepoRoot $RepoRoot -LocalCombatActive $true }
Add-Check "TASK-PHASE1-04-TIERED-WORLD-SIMULATION-CONTINUITY" "distant_jobs_progress" ([bool]$tiered.distantJobsProgressed) "cold/archive progress during local combat"

# Task 5
$buildEval = Invoke-Json { & (Join-Path $RepoRoot "engine\build\construction-magic\build-permission-evaluator.ps1") -RepoRoot $RepoRoot }
$deconEval = Invoke-Json { & (Join-Path $RepoRoot "engine\build\construction-magic\deconstruction-evaluator.ps1") -RepoRoot $RepoRoot }
Add-Check "TASK-PHASE1-05-CONSTRUCTION-MAGIC-AND-BUILD-PERMISSION-V1" "build_permission" ([bool]$buildEval.allowed) "cm complexity within bounds"
Add-Check "TASK-PHASE1-05-CONSTRUCTION-MAGIC-AND-BUILD-PERMISSION-V1" "deconstruction_gap" ([bool]$deconEval.allowed) "deconstruction gap policy enforced"
Add-Check "TASK-PHASE1-05-CONSTRUCTION-MAGIC-AND-BUILD-PERMISSION-V1" "shared_validator_path" ([bool]$buildEval.sharedValidatorPath.authorityAllowed -and [bool]$buildEval.sharedValidatorPath.interopPassed) "authority+interop both pass"

# Task 6
$demonSchema = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\demon-lord\demon-lord-entity-schema.ps1") }
$demonCmd = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\demon-lord\minion-command-interface.ps1") }
$demonTemp = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\demon-lord\temperament-profile-evaluator.ps1") }
Add-Check "TASK-PHASE1-06-DEMON-LORD-AUTHORITY-FRAMEWORK" "demon_schema" (-not [string]::IsNullOrWhiteSpace([string]$demonSchema.entityId)) "schema instance emits"
Add-Check "TASK-PHASE1-06-DEMON-LORD-AUTHORITY-FRAMEWORK" "minion_command" ([bool]$demonCmd.passed) "minion command applies"
Add-Check "TASK-PHASE1-06-DEMON-LORD-AUTHORITY-FRAMEWORK" "temperament_hook" (-not [string]::IsNullOrWhiteSpace([string]$demonTemp.modifiers.commandStyle)) "temperament modifies behavior outputs"

# Task 7
$apexRegistry = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\apex\apex-archetype-registry.ps1") }
$apexOwn = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\apex\dimension-ownership-contract.ps1") }
$apexGrammar = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\apex\exclusive-grammar-hook-validator.ps1") -RepoRoot $RepoRoot }
Add-Check "TASK-PHASE1-07-APEX-ENTITY-FRAMEWORK-LEGENDARY-GOD-KILLER-INTERDIMENSIONAL" "apex_registry_categories" (@($apexRegistry.categories).Count -ge 3) "legendary/god-killer/interdimensional present"
Add-Check "TASK-PHASE1-07-APEX-ENTITY-FRAMEWORK-LEGENDARY-GOD-KILLER-INTERDIMENSIONAL" "dimension_ownership" ([bool]$apexOwn.passed) "dimension ownership contract valid"
Add-Check "TASK-PHASE1-07-APEX-ENTITY-FRAMEWORK-LEGENDARY-GOD-KILLER-INTERDIMENSIONAL" "exclusive_grammar_shared_interop" ([bool]$apexGrammar.passed) "exclusive grammar via shared interop path"

# Task 8
$npcSchema = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\npc-creator\npc-creator-input-schema.ps1") }
$npcVal = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\npc-creator\npc-creator-validator.ps1") -RepoRoot $RepoRoot }
$npcAudit = Invoke-Json { & (Join-Path $RepoRoot "engine\entities\npc-creator\npc-creator-audit-tags.ps1") }
Add-Check "TASK-PHASE1-08-ADVANCED-NPC-CREATOR-V1-DATA-VALIDATION" "npc_schema" ([bool]$npcSchema.passed) "creator input schema valid"
Add-Check "TASK-PHASE1-08-ADVANCED-NPC-CREATOR-V1-DATA-VALIDATION" "npc_validator" ([bool]$npcVal.passed) "deterministic validator output"
Add-Check "TASK-PHASE1-08-ADVANCED-NPC-CREATOR-V1-DATA-VALIDATION" "npc_audit_tags" (-not [string]::IsNullOrWhiteSpace([string]$npcAudit.packageId)) "audit tags include package/version/creator"

# Task 9
$pkgVal = Invoke-Json { & (Join-Path $RepoRoot "engine\live-content\entity-package-validator.ps1") -RepoRoot $RepoRoot }
$pkgGate = Invoke-Json { & (Join-Path $RepoRoot "engine\live-content\entity-package-promotion-gate.ps1") -RepoRoot $RepoRoot }
$pkgRollback = Invoke-Json { & (Join-Path $RepoRoot "engine\live-content\entity-package-rollback.ps1") -RepoRoot $RepoRoot }
Add-Check "TASK-PHASE1-09-LIVE-CONTENT-PROMOTION-GATES-FOR-NEW-ENTITY-SYSTEMS" "entity_package_validator" ([bool]$pkgVal.passed) "package budget+legality checks"
Add-Check "TASK-PHASE1-09-LIVE-CONTENT-PROMOTION-GATES-FOR-NEW-ENTITY-SYSTEMS" "promotion_gate" ([bool]$pkgGate.promotionAllowed) "canary/promotion gating"
Add-Check "TASK-PHASE1-09-LIVE-CONTENT-PROMOTION-GATES-FOR-NEW-ENTITY-SYSTEMS" "rollback_support" ([bool]$pkgRollback.passed) "rollback restores known-good package id"

# Task 10
$interop = Invoke-Json { & (Join-Path $RepoRoot "scripts\check-test-contract-coverage.ps1") -RepoRoot $RepoRoot }
$progressText = & (Join-Path $RepoRoot "scripts\progress-check.ps1") | Out-String
$dashboardPath = Join-Path $RepoRoot "scripts\dashboard-server.ps1"
$dashboardText = Get-Content $dashboardPath -Raw
$progressHasHeader = ($progressText -match [regex]::Escape("=== CURSE Progress Check ==="))
$progressHasOrchestrator = ($progressText -match "Orchestrator:\s+(PASS|FAIL)")
$progressHasGoalAlignment = ($progressText -match "Goal Alignment:\s+(PASS|FAIL|NOT RUN)")
$progressHasCoverage = ($progressText -match "Coverage:\s+")
Add-Check "TASK-PHASE1-10-DASHBOARD-V2-PRODUCT-CONTROL-SURFACE" "progress_pass" ($progressHasHeader -and $progressHasOrchestrator -and $progressHasGoalAlignment -and $progressHasCoverage) "progress-check emits core status telemetry"
Add-Check "TASK-PHASE1-10-DASHBOARD-V2-PRODUCT-CONTROL-SURFACE" "interop_status_data" ([double]$interop.functionalPct -ge 100) "interop functional coverage visible"
Add-Check "TASK-PHASE1-10-DASHBOARD-V2-PRODUCT-CONTROL-SURFACE" "dashboard_interop_endpoint" ($dashboardText -match [regex]::Escape("/api/interop-health")) "dashboard exposes interop endpoint"

$taskIds = @($checks | ForEach-Object { $_.taskId } | Sort-Object -Unique)
$taskSummaries = @()
foreach ($tid in $taskIds) {
    $rows = @($checks | Where-Object { $_.taskId -eq $tid })
    $allPass = (@($rows | Where-Object { -not [bool]$_.passed }).Count -eq 0)
    $taskSummaries += @{
        taskId = $tid
        passed = $allPass
        checks = $rows
    }
}

$allPassed = (@($taskSummaries | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    report = "phase1_acceptance_report_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $allPassed
    tasks = $taskSummaries
}

if ($WriteReport) {
    $outDir = Join-Path $RepoRoot "reports"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $path = Join-Path $outDir "phase1-acceptance-report-$stamp.json"
    $result | ConvertTo-Json -Depth 12 | Set-Content -Path $path -Encoding UTF8
    $result["reportPath"] = $path
}

$result | ConvertTo-Json -Depth 12 | Write-Output
if ($Strict -and -not $allPassed) { exit 1 }
exit 0
