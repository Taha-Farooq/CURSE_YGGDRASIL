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

# 23) Project-level acceptance section.
$hasProjectAcceptanceHeading = ($req -match [regex]::Escape("## 23) Acceptance Criteria (Project-Level)"))
$hasProjectRealtimeRule = ($req -match [regex]::Escape("Combat and attack resolution remains real-time at all progression tiers and does not enter turn-based mode."))
$hasProjectGameplayLoopRule = ($req -match [regex]::Escape("Core gameplay loop (combat + building + crafting + politics) is fun at low, mid, and high power."))

# 25.6) Acceptance for bot system.
$hasBotAcceptanceHeading = ($req -match [regex]::Escape("### 25.6) Acceptance for Bot System"))
$hasBotSweepRule = ($req -match [regex]::Escape("New features trigger automated bot sweeps before promotion."))
$hasBotComplianceRule = ($req -match [regex]::Escape("Validation bot reliably prevents non-compliant builds from release."))

# 28.6) Feedback-loop acceptance criteria.
$hasFeedbackAcceptanceHeading = ($req -match [regex]::Escape("### 28.6) Acceptance Criteria for Feedback Loop"))
$hasFeedbackArtifactRule = ($req -match [regex]::Escape("High-severity feedback receives reproducible investigation artifacts."))
$hasFeedbackIncorporationRule = ($req -match [regex]::Escape("Product changes demonstrably incorporate validated critique and improve targeted experience metrics."))

Add-Check "project_acceptance_heading_defined" $hasProjectAcceptanceHeading "requirements define project-level acceptance criteria heading"
Add-Check "project_acceptance_realtime_rule_defined" $hasProjectRealtimeRule "project-level acceptance retains real-time combat requirement"
Add-Check "project_acceptance_gameplay_loop_rule_defined" $hasProjectGameplayLoopRule "project-level acceptance includes gameplay loop quality target"

Add-Check "bot_system_acceptance_heading_defined" $hasBotAcceptanceHeading "requirements define acceptance criteria for bot system"
Add-Check "bot_system_acceptance_sweep_rule_defined" $hasBotSweepRule "bot acceptance requires pre-promotion automated sweeps"
Add-Check "bot_system_acceptance_compliance_rule_defined" $hasBotComplianceRule "bot acceptance requires validation bot to block non-compliant builds"

Add-Check "feedback_loop_acceptance_heading_defined" $hasFeedbackAcceptanceHeading "requirements define feedback-loop acceptance criteria heading"
Add-Check "feedback_loop_acceptance_artifact_rule_defined" $hasFeedbackArtifactRule "feedback-loop acceptance requires reproducible artifacts for high-severity feedback"
Add-Check "feedback_loop_acceptance_outcome_rule_defined" $hasFeedbackIncorporationRule "feedback-loop acceptance requires validated critique to improve experience metrics"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "feedback_loop_and_acceptance_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
