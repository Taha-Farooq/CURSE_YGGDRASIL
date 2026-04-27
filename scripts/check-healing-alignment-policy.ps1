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

$hasHealingClass = ($req -match [regex]::Escape("Healing is a dedicated magic class with two aligned branches:"))
$hasHolyBranch = ($req -match [regex]::Escape("Holy Healing"))
$hasProfaneBranch = ($req -match [regex]::Escape("Profane Healing"))
$hasAlignmentHarmRules = (
    $req -match [regex]::Escape("Evil-aligned entities are harmed by Holy Healing.") -and
    $req -match [regex]::Escape("Good-aligned entities are harmed by Profane Healing.") -and
    $req -match [regex]::Escape("Neutral-aligned entities can be healed by both branches.")
)
$hasNeutralCasterPenalty = ($req -match [regex]::Escape("Neutral casters can learn either healing branch but have increased cast difficulty/cost and reduced reliability compared to aligned casters."))
$hasResistanceStacking = (
    $req -match [regex]::Escape("Mitigation from natural resistances.") -and
    $req -match [regex]::Escape("Mitigation from temporary resistances/buffs.") -and
    $req -match [regex]::Escape("Mitigation from item/equipment resistances.")
)
$hasDeterministicValidation = ($req -match [regex]::Escape("Final outcome must be deterministic and authority-validated."))

Add-Check "healing_class_defined" $hasHealingClass "requirements define dedicated healing class"
Add-Check "holy_and_profane_branches" ($hasHolyBranch -and $hasProfaneBranch) "requirements define holy and profane healing branches"
Add-Check "alignment_harm_rules_defined" $hasAlignmentHarmRules "requirements define opposite-alignment healing damage rules"
Add-Check "neutral_casting_penalty_defined" $hasNeutralCasterPenalty "requirements define neutral-caster difficulty/cost penalty"
Add-Check "resistance_stacking_defined" $hasResistanceStacking "requirements define natural/temp/item resistance mitigation stack"
Add-Check "deterministic_authority_validation_defined" $hasDeterministicValidation "requirements enforce deterministic authority-validated final outcome"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "healing_alignment_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
