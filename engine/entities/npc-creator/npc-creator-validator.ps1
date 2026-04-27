param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase1-npc-creator-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing npc creator input: $InputJsonPath" }

$schemaScript = Join-Path $PSScriptRoot "npc-creator-input-schema.ps1"
$schemaCheck = & $schemaScript -InputJsonPath $InputJsonPath | ConvertFrom-Json
$spec = Get-Content $InputJsonPath -Raw | ConvertFrom-Json

$classCount = @($spec.classStack).Count
$maxClassStack = 6
$budget = [int]$spec.powerBudget
$maxBudget = 100
$temperamentValid = @("hostile","friendly","pragmatic","chaotic","lawful") -contains [string]$spec.temperament

$checks = @(
    @{ check = "schema_valid"; passed = [bool]$schemaCheck.passed; details = "input schema validation" },
    @{ check = "class_stack_limit"; passed = ($classCount -le $maxClassStack); details = "classStack count=$classCount max=$maxClassStack" },
    @{ check = "power_budget_limit"; passed = ($budget -le $maxBudget); details = "powerBudget=$budget max=$maxBudget" },
    @{ check = "temperament_valid"; passed = $temperamentValid; details = "temperament=$($spec.temperament)" }
)

$passed = $true
foreach ($c in $checks) { if (-not [bool]$c.passed) { $passed = $false } }

$result = @{
    validator = "advanced_npc_creator_validator_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    npcId = [string]$spec.npcId
    passed = $passed
    checks = $checks
    rejectionReasons = @(
        $(if ($classCount -gt $maxClassStack) { "NPC-CLASS-STACK-EXCEEDED" }),
        $(if ($budget -gt $maxBudget) { "NPC-POWER-BUDGET-EXCEEDED" }),
        $(if (-not $temperamentValid) { "NPC-TEMPERAMENT-INVALID" }),
        $(if (-not [bool]$schemaCheck.passed) { "NPC-SCHEMA-INVALID" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $passed) { exit 1 }
exit 0
