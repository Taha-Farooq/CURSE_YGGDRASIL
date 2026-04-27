param(
    [string]$RepoRoot = "",
    [string]$DomainStateJsonPath = "",
    [string]$TemperamentJsonPath = "",
    [string]$CommandJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($DomainStateJsonPath)) {
    $DomainStateJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-domain-state.json"
}
if ([string]::IsNullOrWhiteSpace($TemperamentJsonPath)) {
    $TemperamentJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-lord-temperament.json"
}
if ([string]::IsNullOrWhiteSpace($CommandJsonPath)) {
    $CommandJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-demon-lord-command.json"
}
if (-not (Test-Path $DomainStateJsonPath)) { throw "Missing domain state json: $DomainStateJsonPath" }
if (-not (Test-Path $TemperamentJsonPath)) { throw "Missing temperament json: $TemperamentJsonPath" }
if (-not (Test-Path $CommandJsonPath)) { throw "Missing command json: $CommandJsonPath" }

$domain = Get-Content $DomainStateJsonPath -Raw | ConvertFrom-Json
$temperament = & (Join-Path $PSScriptRoot "temperament-profile-evaluator.ps1") -TemperamentJsonPath $TemperamentJsonPath | ConvertFrom-Json
$command = & (Join-Path $PSScriptRoot "minion-command-interface.ps1") -CommandJsonPath $CommandJsonPath | ConvertFrom-Json

$baseExpansion = [double]$domain.baseExpansionRate
$minionPressure = [double]$domain.minionPressure
$commandBoost = 1.0
if ([string]$command.command.commandType -eq "expand_domain") { $commandBoost = 1.35 }

$styleBoost = 1.0
switch ([string]$temperament.modifiers.commandStyle) {
    "aggressive" { $styleBoost = 1.2 }
    "strategic" { $styleBoost = 1.15 }
    "structured" { $styleBoost = 1.1 }
    "unpredictable" { $styleBoost = 1.05 }
    default { $styleBoost = 1.0 }
}

$domainDelta = [math]::Round(($baseExpansion * $minionPressure * $commandBoost * $styleBoost), 3)
$newControl = [math]::Round(([double]$domain.currentControl + $domainDelta), 3)
if ($newControl -gt 100.0) { $newControl = 100.0 }

$result = @{
    service = "demon_lord_domain_expansion_scheduler_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    demonLordId = [string]$domain.demonLordId
    regionId = [string]$domain.regionId
    commandApplied = [bool]$command.applied
    commandStyle = [string]$temperament.modifiers.commandStyle
    previousControl = [double]$domain.currentControl
    deltaControl = $domainDelta
    newControl = $newControl
    replayEvidence = @{
        required = $true
        tags = @("phase2", "demon_domain_expansion")
    }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not [bool]$command.applied) { exit 1 }
exit 0
