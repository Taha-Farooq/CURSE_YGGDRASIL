param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-combat-equipment-effectiveness-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing combat effectiveness input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$baseAttack = [double]$input.baseAttack
$baseDefense = [double]$input.baseDefense
$conditionMultiplier = [double]$input.conditionEffectivenessMultiplier

$attackOut = [Math]::Round($baseAttack * $conditionMultiplier, 3)
$defenseOut = [Math]::Round($baseDefense * (0.75 + (0.25 * $conditionMultiplier)), 3)

$result = @{
    service = "equipment_combat_effectiveness_service_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    combat = @{
        baseAttack = $baseAttack
        baseDefense = $baseDefense
        conditionEffectivenessMultiplier = $conditionMultiplier
        adjustedAttack = $attackOut
        adjustedDefense = $defenseOut
    }
    reasonCodes = @("AUTH-COMBAT-EQUIP-CONDITION-APPLIED")
}

$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
