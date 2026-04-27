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

$hasTriangleRule = ($req -match [regex]::Escape("Most summonable mobs/NPCs must use a race-and-class-driven rock-paper-scissors affinity triangle during combat resolution."))
$hasDeterministicRule = ($req -match [regex]::Escape("Affinity triangle effects are deterministic and authority-validated."))
$hasSecondaryAffinityRule = ($req -match [regex]::Escape("Affinity advantage/disadvantage modifies effectiveness as a secondary multiplier only."))
$hasLevelDominanceRule = (
    $req -match [regex]::Escape("Overall level differential remains the dominant factor in summon-vs-creature outcomes.") -and
    $req -match [regex]::Escape("Large level gaps must outweigh affinity mismatch in final resolution.")
)
$hasEquitableLevelRule = ($req -match [regex]::Escape("Any creature is summon/control-eligible when attempted by controllers at equitable level."))
$hasMultiControllerRule = ($req -match [regex]::Escape("Taking control of a single creature requires multiple controllers of similar level (one-to-many control threshold), not a single equivalent-level controller."))
$hasComplexityScalingRule = ($req -match [regex]::Escape("Summon/control complexity must scale directly with summon strength (level/power tier)."))
$hasQuicksummonPrecomputeRules = (
    $req -match "(?i)Complexity can be precomputed before combat" -and
    $req -match "(?i)quicksummon" -and
    $req -match "(?i)summon-assist items" -and
    $req -match "(?i)simple or automatic execution at runtime" -and
    $req -match "(?i)precomputed complexity prerequisites are satisfied"
)

Add-Check "summon_triangle_rule_defined" $hasTriangleRule "requirements define race/class summon triangle rule"
Add-Check "summon_triangle_deterministic_authority_validated" $hasDeterministicRule "requirements enforce deterministic authority validation"
Add-Check "affinity_is_secondary_multiplier" $hasSecondaryAffinityRule "requirements define affinity as secondary"
Add-Check "level_gap_dominates_outcomes" $hasLevelDominanceRule "requirements define level differential as dominant"
Add-Check "equitable_level_summon_gate_defined" $hasEquitableLevelRule "requirements define equitable-level summon/control eligibility"
Add-Check "multi_controller_control_threshold_defined" $hasMultiControllerRule "requirements require multiple same-level controllers for single-target control"
Add-Check "summon_complexity_scales_with_strength_defined" $hasComplexityScalingRule "requirements define direct complexity scaling with summon strength"
Add-Check "quicksummon_precompute_rules_defined" $hasQuicksummonPrecomputeRules "requirements define precompute and runtime auto-execution constraints"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "summon_affinity_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
