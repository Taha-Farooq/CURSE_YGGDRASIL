param(
    [string]$RepoRoot = "",
    [string]$ShockEventsJsonPath = "",
    [string]$MarketStateJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($ShockEventsJsonPath)) {
    $ShockEventsJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-logistics-shock-events.json"
}
if ([string]::IsNullOrWhiteSpace($MarketStateJsonPath)) {
    $MarketStateJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-market-state.json"
}
if (-not (Test-Path $ShockEventsJsonPath)) { throw "Missing shock events json: $ShockEventsJsonPath" }
if (-not (Test-Path $MarketStateJsonPath)) { throw "Missing market state json: $MarketStateJsonPath" }

$shockPayload = Get-Content $ShockEventsJsonPath -Raw | ConvertFrom-Json
$market = Get-Content $MarketStateJsonPath -Raw | ConvertFrom-Json
$events = @($shockPayload.events)
$regions = @($market.regions)

$updatedRegions = @()
foreach ($region in $regions) {
    $regionId = [string]$region.regionId
    $matching = @($events | Where-Object { [string]$_.regionId -eq $regionId })
    $shockSum = 0.0
    foreach ($e in $matching) { $shockSum += [double]$e.shockPct }
    $avgShock = 0.0
    if (@($matching).Count -gt 0) { $avgShock = $shockSum / @($matching).Count }

    $basePressure = [double]$region.basePressure
    $newPressure = [math]::Round(($basePressure + ($avgShock / 25.0)), 3)
    if ($newPressure -gt 5.0) { $newPressure = 5.0 }

    $updatedRegions += @{
        regionId = $regionId
        basePressure = $basePressure
        appliedShockAvgPct = [math]::Round($avgShock, 3)
        pressure = $newPressure
        supplyModifier = [math]::Round((1.0 - ($avgShock / 120.0)), 3)
        replayEvidence = @{
            required = $true
            tags = @("phase2", "economy_pressure")
        }
        audit = @{
            reasonCode = "ECO-PRESSURE-UPDATE-001"
            source = "economy_pressure_update_v1"
        }
    }
}

$result = @{
    service = "economy_pressure_update_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    regionsUpdated = @($updatedRegions).Count
    regions = $updatedRegions
}

$result | ConvertTo-Json -Depth 12 | Write-Output
exit 0
