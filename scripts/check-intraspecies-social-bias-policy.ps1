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

$hasIntraSpeciesBiasRule = ($req -match [regex]::Escape("Intra-species social bias/prejudice modeling is mandatory:"))
$hasDriverRule = ($req -match [regex]::Escape("Individuals of the same species may hold prejudice/bias against each other based on socioeconomic status (for example income tier), hometown/region identity, national alliance alignments, historical or recent political events/war exposure, and personal/family vendettas."))
$hasDeterministicRuntimeRule = ($req -match [regex]::Escape("These intra-species social modifiers must be represented as deterministic runtime drivers (not hardcoded species-wide assumptions) and may influence diplomacy, cooperation, trust, command obedience, or conflict likelihood."))
$hasAuthorityAuditRule = ($req -match [regex]::Escape("Intra-species prejudice/bias resolution must be authority-validated, replay-auditable, and emitted with explicit reason codes."))

Add-Check "intraspecies_bias_rule_defined" $hasIntraSpeciesBiasRule "requirements define mandatory intra-species social bias modeling"
Add-Check "intraspecies_bias_driver_rule_defined" $hasDriverRule "requirements define income/hometown/alliance/event/vendetta driver set"
Add-Check "intraspecies_bias_deterministic_runtime_rule_defined" $hasDeterministicRuntimeRule "requirements define deterministic runtime social modifier behavior"
Add-Check "intraspecies_bias_authority_audit_rule_defined" $hasAuthorityAuditRule "requirements define authority/replay reason-code emission for bias resolution"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "intraspecies_social_bias_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
