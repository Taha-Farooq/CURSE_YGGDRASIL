param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-pol-006] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-pol-006-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw
$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0003" } | Select-Object -First 1)
$scenario = @($contract.scenarios | Where-Object { $_.scenarioId -eq "SCN-003" } | Select-Object -First 1)
$checks = @()
$checks += @{ check = "contract_has_int_0003"; passed = ($null -ne $interaction); details = "INT-0003 exists" }
$checks += @{ check = "int_0003_maps_it_pol_006"; passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-POL-006"); details = "IT-POL-006 mapping on INT-0003" }
$checks += @{ check = "scenario_003_references_test"; passed = ($null -ne $scenario -and @($scenario.testIds) -contains "IT-POL-006"); details = "SCN-003 references IT-POL-006" }
$checks += @{ check = "matrix_declares_policy_gate_link"; passed = ($matrix -match [regex]::Escape("INT-0003") -and $matrix -match [regex]::Escape("IT-POL-006") -and $matrix -match [regex]::Escape("magic_gate_validator_v1")); details = "Matrix policy/magic gate link exists" }
$passed = $true
foreach ($c in $checks) { if (-not $c.passed) { $passed = $false } }
$result = @{
    bot = "test-bot-it-pol-006"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-POL-006"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-pol-006] Report: $output"
if (-not $passed) { exit 1 }
exit 0
