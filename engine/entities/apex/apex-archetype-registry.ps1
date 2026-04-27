param(
    [string]$RegistryJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RegistryJsonPath)) {
    $RegistryJsonPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")) "tests\fixtures\phase1-apex-archetypes.json"
}
if (-not (Test-Path $RegistryJsonPath)) { throw "Missing registry json: $RegistryJsonPath" }

$raw = Get-Content $RegistryJsonPath -Raw | ConvertFrom-Json
$archetypes = @()
if ($raw -is [System.Array]) {
    $archetypes = @($raw)
} elseif ($null -ne $raw -and $raw.PSObject.Properties.Name -contains "entityId" -and @($raw.entityId).Count -gt 1) {
    $count = @($raw.entityId).Count
    for ($i = 0; $i -lt $count; $i++) {
        $archetypes += @{
            entityId = @($raw.entityId)[$i]
            category = @($raw.category)[$i]
            dimensionId = @($raw.dimensionId)[$i]
        }
    }
} else {
    $archetypes = @($raw)
}

$categories = @($archetypes | ForEach-Object { [string]$_.category } | Sort-Object -Unique)

$result = @{
    registry = "apex_archetype_registry_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    count = @($archetypes).Count
    categories = $categories
    archetypes = $archetypes
}
$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
