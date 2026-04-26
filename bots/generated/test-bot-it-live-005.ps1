param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-live-005] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-live-005-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"

if (-not (Test-Path $contractPath)) { throw "Missing contract file: $contractPath" }
if (-not (Test-Path $matrixPath)) { throw "Missing matrix file: $matrixPath" }

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw

$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0009" } | Select-Object -First 1)
$scenario = @($contract.scenarios | Where-Object { $_.scenarioId -eq "SCN-004" } | Select-Object -First 1)

$checks = @()
$checks += @{
    check = "contract_has_int_0009"
    passed = ($null -ne $interaction)
    details = $(if ($null -ne $interaction) { "INT-0009 found in contract" } else { "INT-0009 missing from contract" })
}
$checks += @{
    check = "int_0009_maps_it_live_005"
    passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-LIVE-005")
    details = $(if ($null -ne $interaction) { "integrationTestIds=" + (@($interaction.integrationTestIds) -join ", ") } else { "interaction missing" })
}
$checks += @{
    check = "scenario_004_references_live_test"
    passed = ($null -ne $scenario -and @($scenario.testIds) -contains "IT-LIVE-005")
    details = $(if ($null -ne $scenario) { "SCN-004 tests=" + (@($scenario.testIds) -join ", ") } else { "SCN-004 missing" })
}
$checks += @{
    check = "matrix_declares_live_link"
    passed = ($matrix -match [regex]::Escape("INT-0009") -and $matrix -match [regex]::Escape("IT-LIVE-005") -and $matrix -match [regex]::Escape("SCN-004"))
    details = "INTERACTION_MATRIX.md contains INT-0009 / IT-LIVE-005 / SCN-004 linkage"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-live-005"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-LIVE-005"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-live-005] Report: $output"
if (-not $passed) { exit 1 }
exit 0
