param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-eco-007] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-eco-007-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw
$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0006" } | Select-Object -First 1)
$checks = @()
$checks += @{ check = "contract_has_int_0006"; passed = ($null -ne $interaction); details = "INT-0006 exists" }
$checks += @{ check = "int_0006_maps_it_eco_007"; passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-ECO-007"); details = "IT-ECO-007 mapping on INT-0006" }
$checks += @{ check = "matrix_declares_industry_economy_link"; passed = ($matrix -match [regex]::Escape("INT-0006") -and $matrix -match [regex]::Escape("IT-ECO-007") -and $matrix -match [regex]::Escape("factory_budget_guard_v1")); details = "Matrix industry/economy link exists" }
$passed = $true
foreach ($c in $checks) { if (-not $c.passed) { $passed = $false } }
$result = @{
    bot = "test-bot-it-eco-007"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-ECO-007"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-eco-007] Report: $output"
if (-not $passed) { exit 1 }
exit 0
