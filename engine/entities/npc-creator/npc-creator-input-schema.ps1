param(
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")) "tests\fixtures\phase1-npc-creator-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing npc creator input: $InputJsonPath" }

$spec = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$required = @("npcId","creatorId","temperament","classStack","powerBudget","packageId")
$missing = @($required | Where-Object { $null -eq $spec.$_ -or [string]::IsNullOrWhiteSpace([string]$spec.$_) })

$result = @{
    schema = "advanced_npc_creator_input_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = (@($missing).Count -eq 0)
    missingFields = $missing
    input = $spec
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $result.passed) { exit 1 }
exit 0
