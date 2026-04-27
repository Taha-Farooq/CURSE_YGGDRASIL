param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-ind-003] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-ind-003-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"

if (-not (Test-Path $contractPath)) { throw "Missing contract file: $contractPath" }
if (-not (Test-Path $matrixPath)) { throw "Missing matrix file: $matrixPath" }

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw

$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0006" } | Select-Object -First 1)

$checks = @()
$checks += @{
    check = "contract_has_int_0006"
    passed = ($null -ne $interaction)
    details = $(if ($null -ne $interaction) { "INT-0006 found in contract" } else { "INT-0006 missing from contract" })
}
$checks += @{
    check = "int_0006_maps_it_ind_003"
    passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-IND-003")
    details = $(if ($null -ne $interaction) { "integrationTestIds=" + (@($interaction.integrationTestIds) -join ", ") } else { "interaction missing" })
}
$checks += @{
    check = "matrix_declares_industrial_link"
    passed = ($matrix -match [regex]::Escape("INT-0006") -and $matrix -match [regex]::Escape("IT-IND-003") -and $matrix -match [regex]::Escape("factory_budget_guard_v1"))
    details = "INTERACTION_MATRIX.md contains INT-0006 / IT-IND-003 / factory_budget_guard_v1 linkage"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-ind-003"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-IND-003"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-ind-003] Report: $output"
if (-not $passed) { exit 1 }
exit 0
