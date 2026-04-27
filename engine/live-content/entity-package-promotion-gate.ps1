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

$validator = Join-Path $PSScriptRoot "entity-package-validator.ps1"
$val = & $validator -RepoRoot $RepoRoot -PackageJsonPath $PackageJsonPath | ConvertFrom-Json

$result = @{
    gate = "entity_package_promotion_gate_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    packageId = [string]$val.packageId
    canaryEligible = [bool]$val.passed
    promotionAllowed = [bool]$val.passed
    validator = $val
}
$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not [bool]$val.passed) { exit 1 }
exit 0
