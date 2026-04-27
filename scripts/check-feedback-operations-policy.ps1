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

$hasFeedbackChannelsHeading = ($req -match [regex]::Escape("### 28.1) Feedback Collection Channels"))
$hasFeedbackFormRule = ($req -match [regex]::Escape("- In-game structured feedback forms (context-aware)."))
$hasFeedbackSurveyRule = ($req -match [regex]::Escape("- Session-end surveys for fun, clarity, fairness, and thematic fit."))

$hasFeedbackSchemaHeading = ($req -match [regex]::Escape("### 28.2) Required Feedback Schema"))
$hasFeedbackSchemaCategoryRule = ($req -match [regex]::Escape("- Category:"))
$hasFeedbackSchemaIntentRule = ($req -match [regex]::Escape("- Player intent (what they tried to do)."))
$hasFeedbackSchemaEvidenceRule = ($req -match [regex]::Escape("- Optional linked evidence:"))

$hasTriageHeading = ($req -match [regex]::Escape("### 28.3) Triage and Prioritization"))
$hasTriageServiceRule = ($req -match [regex]::Escape("- Create a Feedback Triage Service that combines:"))
$hasTriageWeightedRule = ($req -match [regex]::Escape("- Prioritize with weighted scoring:"))
$hasTriageQueueRule = ($req -match [regex]::Escape("- Generate an actionable change queue with clear owner, scope, and ETA."))

$hasWorkflowHeading = ($req -match [regex]::Escape("### 28.4) Critique-to-Change Workflow"))
$hasWorkflowIntakeStep = ($req -match [regex]::Escape("1. Intake and de-duplication."))
$hasWorkflowValidationStep = ($req -match [regex]::Escape("5. Validate in bot sweeps + targeted human playtest."))
$hasWorkflowVerificationStep = ($req -match [regex]::Escape("7. Post-change verification:"))

Add-Check "feedback_collection_channels_defined" $hasFeedbackChannelsHeading "requirements define feedback collection channels section"
Add-Check "feedback_collection_channels_core_rules_defined" ($hasFeedbackFormRule -and $hasFeedbackSurveyRule) "requirements define structured forms and session-end surveys"

Add-Check "required_feedback_schema_defined" $hasFeedbackSchemaHeading "requirements define required feedback schema section"
Add-Check "required_feedback_schema_fields_defined" ($hasFeedbackSchemaCategoryRule -and $hasFeedbackSchemaIntentRule -and $hasFeedbackSchemaEvidenceRule) "requirements define category, intent, and evidence fields"

Add-Check "feedback_triage_prioritization_defined" $hasTriageHeading "requirements define triage and prioritization section"
Add-Check "feedback_triage_prioritization_rules_defined" ($hasTriageServiceRule -and $hasTriageWeightedRule -and $hasTriageQueueRule) "requirements define triage service, weighted scoring, and actionable queue output"

Add-Check "critique_to_change_workflow_defined" $hasWorkflowHeading "requirements define critique-to-change workflow section"
Add-Check "critique_to_change_workflow_steps_defined" ($hasWorkflowIntakeStep -and $hasWorkflowValidationStep -and $hasWorkflowVerificationStep) "requirements define workflow intake, validation, and post-change verification steps"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "feedback_operations_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
