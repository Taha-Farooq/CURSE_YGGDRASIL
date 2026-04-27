param(
    [string]$OwnershipJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($OwnershipJsonPath)) {
    $OwnershipJsonPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")) "tests\fixtures\phase1-apex-dimension-ownership.json"
}
if (-not (Test-Path $OwnershipJsonPath)) { throw "Missing ownership json: $OwnershipJsonPath" }

$data = Get-Content $OwnershipJsonPath -Raw | ConvertFrom-Json
$passed = (-not [string]::IsNullOrWhiteSpace([string]$data.dimensionId) -and -not [string]::IsNullOrWhiteSpace([string]$data.ownerEntityId))

$result = @{
    contract = "apex_dimension_ownership_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    ownership = $data
}
$result | ConvertTo-Json -Depth 8 | Write-Output
if (-not $passed) { exit 1 }
exit 0
