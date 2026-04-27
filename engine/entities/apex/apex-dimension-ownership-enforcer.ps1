param(
    [string]$RepoRoot = "",
    [string]$OwnershipJsonPath = "",
    [string]$InjectionEventJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($OwnershipJsonPath)) {
    $OwnershipJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-dimension-ownership.json"
}
if ([string]::IsNullOrWhiteSpace($InjectionEventJsonPath)) {
    $InjectionEventJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-injection-event.json"
}
if (-not (Test-Path $OwnershipJsonPath)) { throw "Missing ownership json: $OwnershipJsonPath" }
if (-not (Test-Path $InjectionEventJsonPath)) { throw "Missing injection event json: $InjectionEventJsonPath" }

$ownership = Get-Content $OwnershipJsonPath -Raw | ConvertFrom-Json
$event = Get-Content $InjectionEventJsonPath -Raw | ConvertFrom-Json

$allowed = ([string]$ownership.dimensionId -eq [string]$event.dimensionId -and -not [string]::IsNullOrWhiteSpace([string]$ownership.ownerEntityId))

$result = @{
    service = "apex_dimension_ownership_enforcer_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    allowed = $allowed
    dimensionId = [string]$event.dimensionId
    ownerEntityId = [string]$ownership.ownerEntityId
    reasonCodes = @(
        $(if (-not $allowed) { "APEX-OWNERSHIP-MISMATCH" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $allowed) { exit 1 }
exit 0
