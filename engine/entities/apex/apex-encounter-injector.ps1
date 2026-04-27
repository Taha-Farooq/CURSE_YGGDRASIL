param(
    [string]$RepoRoot = "",
    [string]$RegistryJsonPath = "",
    [string]$RegionStateJsonPath = "",
    [string]$OwnershipJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($RegistryJsonPath)) {
    $RegistryJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-archetypes.json"
}
if ([string]::IsNullOrWhiteSpace($RegionStateJsonPath)) {
    $RegionStateJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-region-state.json"
}
if ([string]::IsNullOrWhiteSpace($OwnershipJsonPath)) {
    $OwnershipJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-apex-dimension-ownership.json"
}
if (-not (Test-Path $RegistryJsonPath)) { throw "Missing registry json: $RegistryJsonPath" }
if (-not (Test-Path $RegionStateJsonPath)) { throw "Missing region state json: $RegionStateJsonPath" }
if (-not (Test-Path $OwnershipJsonPath)) { throw "Missing ownership json: $OwnershipJsonPath" }

$registryScript = Join-Path $PSScriptRoot "apex-archetype-registry.ps1"
$ownershipScript = Join-Path $PSScriptRoot "dimension-ownership-contract.ps1"

$registry = & $registryScript -RegistryJsonPath $RegistryJsonPath | ConvertFrom-Json
$ownership = & $ownershipScript -OwnershipJsonPath $OwnershipJsonPath | ConvertFrom-Json
$region = Get-Content $RegionStateJsonPath -Raw | ConvertFrom-Json

$eligible = @($registry.archetypes | Where-Object {
    [string]$_.dimensionId -eq [string]$region.dimensionId -and [double]$_.threatBudget -le [double]$region.maxThreatBudget
})

$selected = $null
if (@($eligible).Count -gt 0) {
    $selected = $eligible | Sort-Object -Property @{ Expression = { [double]$_.threatBudget }; Descending = $true } | Select-Object -First 1
}

$injected = ($null -ne $selected -and [bool]$ownership.passed)

$result = @{
    service = "apex_encounter_injector_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    dimensionId = [string]$region.dimensionId
    regionId = [string]$region.regionId
    ownershipPassed = [bool]$ownership.passed
    injected = $injected
    selectedEntity = $selected
    eligibleCount = @($eligible).Count
    replayEvidence = @{
        required = $true
        tags = @("phase2", "apex_encounter_injection")
    }
    reasonCodes = @(
        $(if (-not [bool]$ownership.passed) { "APEX-OWNERSHIP-CONTRACT-BLOCKED" }),
        $(if ($null -eq $selected) { "APEX-NO-ELIGIBLE-ENTITY" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$result | ConvertTo-Json -Depth 12 | Write-Output
if (-not $injected) { exit 1 }
exit 0
