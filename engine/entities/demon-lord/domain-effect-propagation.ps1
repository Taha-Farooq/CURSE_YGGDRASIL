param(
    [string]$RepoRoot = "",
    [string]$ExpansionEventJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($ExpansionEventJsonPath)) {
    $ExpansionEventJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-domain-expansion-event.json"
}
if (-not (Test-Path $ExpansionEventJsonPath)) { throw "Missing expansion event json: $ExpansionEventJsonPath" }

$expansion = Get-Content $ExpansionEventJsonPath -Raw | ConvertFrom-Json
$intensity = [double]$expansion.deltaControl

$effects = @(
    @{
        effectId = "fear-aura"
        magnitude = [math]::Round(($intensity * 0.7), 3)
        subsystem = "ai"
    },
    @{
        effectId = "corruption-spread"
        magnitude = [math]::Round(($intensity * 0.5), 3)
        subsystem = "world"
    }
)

$result = @{
    service = "demon_lord_domain_effect_propagation_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    demonLordId = [string]$expansion.demonLordId
    regionId = [string]$expansion.regionId
    effectsApplied = $effects
    ledgerRecord = @{
        category = "demon_domain"
        actionType = "domain_expansion"
        actorId = [string]$expansion.demonLordId
        regionId = [string]$expansion.regionId
        replayRequired = $true
    }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
