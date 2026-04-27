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

# 24.1 Content pipeline stages.
$hasPipelineHeading = ($req -match [regex]::Escape("### 24.1) Content Pipeline Stages"))
$hasPipelineStatic = ($req -match [regex]::Escape("2. Static validation:"))
$hasPipelineSimulation = ($req -match [regex]::Escape("3. Simulation validation:"))
$hasPipelineRollout = ($req -match [regex]::Escape("6. Controlled rollout:"))
$hasPipelinePromotionGate = ($req -match [regex]::Escape("7. Promotion to base game content only after passing all required gates."))

# 25 Autonomous bot framework.
$hasBotFrameworkHeading = ($req -match [regex]::Escape("## 25) Autonomous Bot Framework (Testing, Validation, and Assisted Implementation)"))
$hasBotContinuousRule = ($req -match [regex]::Escape("- Bots must run continuously in CI and on scheduled world sweeps for staging shards."))
$hasValidationComplianceHeading = ($req -match [regex]::Escape("### 25.3) Validation/Compliance Bot"))
$hasOrchestrationSafetyHeading = ($req -match [regex]::Escape("### 25.5) Orchestration and Safety"))

# 28 Human feedback and adaptation loop.
$hasFeedbackLoopHeading = ($req -match [regex]::Escape("## 28) Human Feedback and Product Adaptation Loop"))
$hasFeedbackSchemaHeading = ($req -match [regex]::Escape("### 28.2) Required Feedback Schema"))
$hasCritiqueWorkflowHeading = ($req -match [regex]::Escape("### 28.4) Critique-to-Change Workflow"))
$hasFeedbackAcceptanceHeading = ($req -match [regex]::Escape("### 28.6) Acceptance Criteria for Feedback Loop"))

# 31 Goal-aligned automation progress.
$hasGoalAlignedHeading = ($req -match [regex]::Escape("## 31) Goal-Aligned Automation Progress"))
$hasGoalProfilesRule = ($req -match [regex]::Escape("- Introduce goal profiles (keywords + required systems + acceptance tests)."))
$hasGoalAlignmentBotRule = ($req -match [regex]::Escape("- Add a goal-alignment bot that:"))
$hasGoalDriftRule = ($req -match [regex]::Escape("- Goal drift findings must be surfaced in daily reports with suggested corrective tasks."))

Add-Check "content_pipeline_stages_heading_defined" $hasPipelineHeading "requirements define content pipeline stages section"
Add-Check "content_pipeline_stages_core_rules_defined" ($hasPipelineStatic -and $hasPipelineSimulation -and $hasPipelineRollout -and $hasPipelinePromotionGate) "requirements define static/simulation/rollout/promotion gates for live content"

Add-Check "autonomous_bot_framework_heading_defined" $hasBotFrameworkHeading "requirements define autonomous bot framework section"
Add-Check "autonomous_bot_framework_core_rules_defined" ($hasBotContinuousRule -and $hasValidationComplianceHeading -and $hasOrchestrationSafetyHeading) "requirements define continuous bot operation, validation/compliance, and orchestration safety"

Add-Check "human_feedback_adaptation_loop_heading_defined" $hasFeedbackLoopHeading "requirements define human feedback and adaptation loop section"
Add-Check "human_feedback_adaptation_loop_core_rules_defined" ($hasFeedbackSchemaHeading -and $hasCritiqueWorkflowHeading -and $hasFeedbackAcceptanceHeading) "requirements define schema, critique-to-change workflow, and acceptance criteria"

Add-Check "goal_aligned_automation_heading_defined" $hasGoalAlignedHeading "requirements define goal-aligned automation progress section"
Add-Check "goal_aligned_automation_core_rules_defined" ($hasGoalProfilesRule -and $hasGoalAlignmentBotRule -and $hasGoalDriftRule) "requirements define goal profiles, goal-alignment bot, and drift reporting"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "live_content_automation_goal_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
