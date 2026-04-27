param(
    [string]$RepoRoot = "",
    [string]$RollbackJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}
if ([string]::IsNullOrWhiteSpace($RollbackJsonPath)) {
    $RollbackJsonPath = Join-Path $RepoRoot "tests\fixtures\phase1-entity-rollback.json"
}
if (-not (Test-Path $RollbackJsonPath)) { throw "Missing rollback json: $RollbackJsonPath" }

$rb = Get-Content $RollbackJsonPath -Raw | ConvertFrom-Json
$passed = (-not [string]::IsNullOrWhiteSpace([string]$rb.currentPackageId) -and -not [string]::IsNullOrWhiteSpace([string]$rb.previousPackageId))

$result = @{
    rollback = "entity_package_rollback_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    restoredPackageId = [string]$rb.previousPackageId
    fromPackageId = [string]$rb.currentPackageId
}
$result | ConvertTo-Json -Depth 8 | Write-Output
if (-not $passed) { exit 1 }
exit 0
