param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-logistics-shock-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing logistics shock input: $InputJsonPath" }

$payload = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$routes = @($payload.routes)

$events = @()
foreach ($r in $routes) {
    $baseSupply = [double]$r.baselineSupplyFlow
    $convoyLossPct = [double]$r.convoyLossPct
    $disruptionHours = [double]$r.disruptionHours
    $criticality = [double]$r.criticality

    $shockPct = [math]::Round(([math]::Min(100.0, ($convoyLossPct + ($disruptionHours * 2.5)) * $criticality)), 2)
    $supplyDelta = [math]::Round((-1.0 * $baseSupply * ($shockPct / 100.0)), 2)
    $severity = "low"
    if ($shockPct -ge 60) { $severity = "critical" }
    elseif ($shockPct -ge 35) { $severity = "high" }
    elseif ($shockPct -ge 15) { $severity = "medium" }

    $events += @{
        routeId = [string]$r.routeId
        regionId = [string]$r.regionId
        shockPct = $shockPct
        supplyDelta = $supplyDelta
        severity = $severity
        replayEvidence = @{
            required = $true
            tags = @("phase2", "logistics_shock", "economy")
            correlationId = ("shock-" + [string]$r.routeId)
        }
        audit = @{
            reasonCode = "ECO-LOG-SHOCK-001"
            source = "logistics_shock_propagation_v1"
        }
    }
}

$result = @{
    service = "logistics_shock_propagation_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    eventCount = @($events).Count
    events = $events
}

$result | ConvertTo-Json -Depth 12 | Write-Output
exit 0
