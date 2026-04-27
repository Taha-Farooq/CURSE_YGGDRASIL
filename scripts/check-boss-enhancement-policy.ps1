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

$hasBossArchetypeRule = ($req -match [regex]::Escape("Boss and area-boss archetypes are mandatory:"))
$hasHighHpRule = ($req -match [regex]::Escape("Boss and area-boss mobs must have substantially higher health pools than standard same-level mobs."))
$hasLegendaryGearRule = ($req -match [regex]::Escape("Boss and area-boss loadouts must include specialized legendary/higher-tier gear appropriate to their level band."))
$hasEnhancementRule = ($req -match [regex]::Escape("Optional boss enhancements (for example electric, poisonous, thorns, trapper) must be composable."))
$hasStackScalingRule = ($req -match [regex]::Escape("More stacked enhancements must deterministically increase boss/area-boss combat strength."))
$hasRewardScalingRule = ($req -match [regex]::Escape("Reward quality/quantity must scale with enhancement count and boss difficulty tier."))
$hasAuthorityAuditRule = ($req -match [regex]::Escape("Boss scaling and reward outputs must remain authority-validated and replay-auditable with explicit reason codes."))

Add-Check "boss_archetype_rule_defined" $hasBossArchetypeRule "requirements define mandatory boss and area-boss archetypes"
Add-Check "boss_high_health_rule_defined" $hasHighHpRule "requirements define high-health rule for boss/area-boss mobs"
Add-Check "boss_legendary_gear_rule_defined" $hasLegendaryGearRule "requirements define specialized legendary/higher-tier boss gear"
Add-Check "boss_enhancement_composition_rule_defined" $hasEnhancementRule "requirements define composable boss enhancements"
Add-Check "boss_enhancement_strength_scaling_rule_defined" $hasStackScalingRule "requirements define deterministic stacked enhancement strength scaling"
Add-Check "boss_reward_scaling_rule_defined" $hasRewardScalingRule "requirements define reward scaling by enhancement and difficulty"
Add-Check "boss_authority_audit_rule_defined" $hasAuthorityAuditRule "requirements define authority/replay auditability for boss scaling and rewards"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "boss_enhancement_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
