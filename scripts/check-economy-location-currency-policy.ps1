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

$hasLocationKingdomVariationRule = ($req -match [regex]::Escape("Market pricing must vary by location and kingdom context (for example regional demand, logistics friction, trade risk, and kingdom tax/subsidy policy)."))
$hasCurrencyConversionRule = ($req -match [regex]::Escape("Economy calculations must support kingdom/local currency differences with deterministic conversion into quoted currencies for audits and cross-store comparison."))
$hasAuthorityAuditRule = ($req -match [regex]::Escape("Pricing outputs must stay authority-validated and replay-auditable with explicit reason codes for condition, location/kingdom, and currency conversion factors."))

Add-Check "economy_location_kingdom_variation_rule_defined" $hasLocationKingdomVariationRule "requirements define location/kingdom pricing variation"
Add-Check "economy_currency_conversion_rule_defined" $hasCurrencyConversionRule "requirements define deterministic cross-currency conversion support"
Add-Check "economy_pricing_authority_audit_rule_defined" $hasAuthorityAuditRule "requirements define authority/replay reason-code auditability for pricing"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "economy_location_currency_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
