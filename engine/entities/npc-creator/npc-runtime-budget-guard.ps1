param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = "",
    [int]$RuntimeBudgetCap = 120
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-npc-runtime-spec-valid.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing npc runtime spec: $InputJsonPath" }

$spec = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$runtimeCost = 0
$runtimeCost += [int]$spec.powerBudget
$runtimeCost += (@($spec.classStack).Count * 4)
$runtimeCost += [int]([math]::Ceiling([double]$spec.behaviorComplexity * 10))

$passed = ($runtimeCost -le $RuntimeBudgetCap)
$result = @{
    service = "npc_runtime_budget_guard_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    npcId = [string]$spec.npcId
    runtimeCost = $runtimeCost
    runtimeBudgetCap = $RuntimeBudgetCap
    passed = $passed
    reasonCodes = @(
        $(if (-not $passed) { "NPC-RUNTIME-BUDGET-BLOCKED" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $passed) { exit 1 }
exit 0
