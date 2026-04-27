param(
    [string]$RepoRoot = "",
    [string]$PackageJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}
if ([string]::IsNullOrWhiteSpace($PackageJsonPath)) {
    $PackageJsonPath = Join-Path $RepoRoot "tests\fixtures\phase1-entity-package.json"
}
if (-not (Test-Path $PackageJsonPath)) { throw "Missing package json: $PackageJsonPath" }

$pkg = Get-Content $PackageJsonPath -Raw | ConvertFrom-Json
$checks = @(
    @{ check = "package_id_present"; passed = -not [string]::IsNullOrWhiteSpace([string]$pkg.packageId); details = "packageId exists" },
    @{ check = "type_supported"; passed = @("demon_lord","apex_entity","npc_creator") -contains [string]$pkg.entityType; details = "entityType=$($pkg.entityType)" },
    @{ check = "budget_within_limit"; passed = ([int]$pkg.estimatedBudget -le [int]$pkg.maxBudget); details = "estimated=$($pkg.estimatedBudget) max=$($pkg.maxBudget)" },
    @{ check = "legality_passed"; passed = ([bool]$pkg.legalityPassed); details = "legalityPassed=$($pkg.legalityPassed)" }
)
$passed = $true
foreach ($c in $checks) { if (-not [bool]$c.passed) { $passed = $false } }

$result = @{
    validator = "entity_package_validator_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    packageId = [string]$pkg.packageId
    passed = $passed
    checks = $checks
}
$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $passed) { exit 1 }
exit 0
