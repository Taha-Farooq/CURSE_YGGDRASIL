param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-scn-001] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-scn-001-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw
$scenario = @($contract.scenarios | Where-Object { $_.scenarioId -eq "SCN-001" } | Select-Object -First 1)
$checks = @()
$checks += @{ check = "scenario_exists"; passed = ($null -ne $scenario); details = "SCN-001 exists" }
$checks += @{ check = "scenario_interactions_match"; passed = ($null -ne $scenario -and @($scenario.interactionIds) -contains "INT-0007" -and @($scenario.interactionIds) -contains "INT-0005"); details = "SCN-001 interaction IDs validated" }
$checks += @{ check = "scenario_tests_match"; passed = ($null -ne $scenario -and @($scenario.testIds) -contains "IT-LOG-005" -and @($scenario.testIds) -contains "IT-POL-010"); details = "SCN-001 test IDs validated" }
$checks += @{ check = "matrix_row_present"; passed = ($matrix -match [regex]::Escape("SCN-001") -and $matrix -match [regex]::Escape("INT-0007, INT-0005")); details = "SCN-001 row present in matrix doc" }
$passed = $true
foreach ($c in $checks) { if (-not $c.passed) { $passed = $false } }
$result = @{
    bot = "test-bot-scn-001"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "SCN-001"
    checks = $checks
    validator = "scenario_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-scn-001] Report: $output"
if (-not $passed) { exit 1 }
exit 0
