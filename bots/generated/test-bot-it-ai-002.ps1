param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-ai-002] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-ai-002-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$requirementsPath = Join-Path $RepoRoot "REQUIREMENTS.md"

if (-not (Test-Path $contractPath)) { throw "Missing contract file: $contractPath" }
if (-not (Test-Path $matrixPath)) { throw "Missing matrix file: $matrixPath" }
if (-not (Test-Path $requirementsPath)) { throw "Missing requirements file: $requirementsPath" }

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw
$requirements = Get-Content $requirementsPath -Raw

$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0008" } | Select-Object -First 1)
$scenario = @($contract.scenarios | Where-Object { $_.scenarioId -eq "SCN-003" } | Select-Object -First 1)

$checks = @()
$checks += @{
    check = "contract_has_int_0008"
    passed = ($null -ne $interaction)
    details = $(if ($null -ne $interaction) { "INT-0008 found in contract" } else { "INT-0008 missing from contract" })
}
$checks += @{
    check = "int_0008_maps_it_ai_002"
    passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-AI-002")
    details = $(if ($null -ne $interaction) { "integrationTestIds=" + (@($interaction.integrationTestIds) -join ", ") } else { "interaction missing" })
}
$checks += @{
    check = "scenario_003_references_ai_test"
    passed = ($null -ne $scenario -and @($scenario.testIds) -contains "IT-AI-002")
    details = $(if ($null -ne $scenario) { "SCN-003 tests=" + (@($scenario.testIds) -join ", ") } else { "SCN-003 missing" })
}
$checks += @{
    check = "matrix_declares_ai_economy_link"
    passed = ($matrix -match [regex]::Escape("INT-0008") -and $matrix -match [regex]::Escape("IT-AI-002") -and $matrix -match [regex]::Escape("ai_progression_guard_v1"))
    details = "INTERACTION_MATRIX.md contains INT-0008 / IT-AI-002 / ai_progression_guard_v1 linkage"
}
$checks += @{
    check = "requirements_cover_npc_learning"
    passed = ($requirements -match [regex]::Escape("## 16) NPC/Mob Intelligence and Memory"))
    details = "REQUIREMENTS.md includes NPC/Mob Intelligence and Memory section"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-ai-002"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-AI-002"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-ai-002] Report: $output"
if (-not $passed) { exit 1 }
exit 0
