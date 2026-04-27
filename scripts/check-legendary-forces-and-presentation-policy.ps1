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

$hasLegendaryForceRule = ($req -match [regex]::Escape("Legendary creatures and legendary magics must be able to manipulate fundamental forces including gravity fields, scale/size transformation, and magical density compression/expansion."))
$hasLegendaryDeterminismRule = ($req -match [regex]::Escape("Fundamental-force manipulation outcomes must remain deterministic, authority-validated, and replay-auditable with explicit legality/failure reason codes."))
$hasLegendaryAnimationRule = ($req -match [regex]::Escape("Legendary force-manipulation attacks must combine creative, high-signal animation choreography with readable telegraphs and counterplay windows."))
$hasTextureDepthRule = ($req -match [regex]::Escape("Environments must ship with rich, high-variance texture sets and material depth that preserve readability in motion and combat."))
$hasAnimationDiversityRule = ($req -match [regex]::Escape("Combat entities and spells must have diverse animation sets (startup, loop, release, recovery, failure, interruption, combo-branch) to avoid repetitive playback."))
$hasTierIdentityVfxRule = ($req -match [regex]::Escape("Spell and attack VFX must express power tier and elemental identity clearly while remaining performance-budget compliant."))

Add-Check "legendary_force_manipulation_rule_defined" $hasLegendaryForceRule "requirements define legendary manipulation of gravity/size/magical density"
Add-Check "legendary_force_deterministic_authority_rule_defined" $hasLegendaryDeterminismRule "requirements enforce deterministic authority/replay legality for force manipulation"
Add-Check "legendary_force_animation_telegraph_rule_defined" $hasLegendaryAnimationRule "requirements define creative but readable legendary force attack animation telegraphs"
Add-Check "environment_texture_depth_rule_defined" $hasTextureDepthRule "requirements define rich environment texture/material depth expectations"
Add-Check "animation_diversity_rule_defined" $hasAnimationDiversityRule "requirements define diverse combat/spell animation set requirements"
Add-Check "vfx_tier_identity_rule_defined" $hasTierIdentityVfxRule "requirements define tier/element readable VFX requirements under performance budgets"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "legendary_forces_and_presentation_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
