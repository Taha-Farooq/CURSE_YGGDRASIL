param(
    [string]$CommandJsonPath = "",
    [string]$TemperamentJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($CommandJsonPath)) {
    $CommandJsonPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")) "tests\fixtures\phase1-demon-lord-command.json"
}
if (-not (Test-Path $CommandJsonPath)) { throw "Missing command json: $CommandJsonPath" }

if ([string]::IsNullOrWhiteSpace($TemperamentJsonPath)) {
    $TemperamentJsonPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")) "tests\fixtures\phase1-demon-lord-temperament.json"
}

$cmd = Get-Content $CommandJsonPath -Raw | ConvertFrom-Json
$required = @("demonLordId","minionGroupId","commandType","domainEffect")
$missing = @($required | Where-Object { [string]::IsNullOrWhiteSpace([string]$cmd.$_) })

$temperament = $null
$prejudiceScore = 0
$obedienceDelta = 0
if (Test-Path $TemperamentJsonPath) {
    $temperament = & (Join-Path $PSScriptRoot "temperament-profile-evaluator.ps1") -TemperamentJsonPath $TemperamentJsonPath | ConvertFrom-Json
    $prejudiceScore = [int]$temperament.socialBias.prejudiceScore
    $obedienceDelta = [int]$temperament.socialBias.obedienceDelta
}

$maxPrejudiceScore = 35
$minObedienceDelta = -25
if ($null -ne $cmd.obediencePolicy) {
    if ($null -ne $cmd.obediencePolicy.maxPrejudiceScore) { $maxPrejudiceScore = [int]$cmd.obediencePolicy.maxPrejudiceScore }
    if ($null -ne $cmd.obediencePolicy.minObedienceDelta) { $minObedienceDelta = [int]$cmd.obediencePolicy.minObedienceDelta }
}

$obedienceGatePassed = ($prejudiceScore -lt $maxPrejudiceScore -and $obedienceDelta -gt $minObedienceDelta)
$passed = (@($missing).Count -eq 0 -and $obedienceGatePassed)
$reasonCodes = @()
if (-not $obedienceGatePassed) { $reasonCodes += "AUTH-CMD-OBEDIENCE-BLOCKED-INTRASPECIES-BIAS" }
if ($passed) { $reasonCodes += "AUTH-CMD-ACCEPTED" }

$result = @{
    interface = "demon_lord_minion_command_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    command = $cmd
    missingFields = $missing
    applied = $passed
    socialBias = @{
        prejudiceScore = $prejudiceScore
        obedienceDelta = $obedienceDelta
        policy = @{
            maxPrejudiceScore = $maxPrejudiceScore
            minObedienceDelta = $minObedienceDelta
        }
        obedienceGatePassed = $obedienceGatePassed
    }
    reasonCodes = $reasonCodes
}
$result | ConvertTo-Json -Depth 8 | Write-Output
if (-not $passed) { exit 1 }
exit 0
