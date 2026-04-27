param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-log-005] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-log-005-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"

if (-not (Test-Path $contractPath)) { throw "Missing contract file: $contractPath" }
if (-not (Test-Path $matrixPath)) { throw "Missing matrix file: $matrixPath" }

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw

$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0007" } | Select-Object -First 1)
$scenario = @($contract.scenarios | Where-Object { $_.scenarioId -eq "SCN-001" } | Select-Object -First 1)

$checks = @()
$checks += @{
    check = "contract_has_int_0007"
    passed = ($null -ne $interaction)
    details = $(if ($null -ne $interaction) { "INT-0007 found in contract" } else { "INT-0007 missing from contract" })
}
$checks += @{
    check = "int_0007_maps_it_log_005"
    passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-LOG-005")
    details = $(if ($null -ne $interaction) { "integrationTestIds=" + (@($interaction.integrationTestIds) -join ", ") } else { "interaction missing" })
}
$checks += @{
    check = "scenario_001_references_logistics_test"
    passed = ($null -ne $scenario -and @($scenario.testIds) -contains "IT-LOG-005")
    details = $(if ($null -ne $scenario) { "SCN-001 tests=" + (@($scenario.testIds) -join ", ") } else { "SCN-001 missing" })
}
$checks += @{
    check = "matrix_declares_logistics_link"
    passed = ($matrix -match [regex]::Escape("INT-0007") -and $matrix -match [regex]::Escape("IT-LOG-005") -and $matrix -match [regex]::Escape("SCN-001"))
    details = "INTERACTION_MATRIX.md contains INT-0007 / IT-LOG-005 / SCN-001 linkage"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-log-005"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-LOG-005"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-log-005] Report: $output"
if (-not $passed) { exit 1 }
exit 0
