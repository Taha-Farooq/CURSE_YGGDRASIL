param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-eco-009] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-eco-009-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw
$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0008" } | Select-Object -First 1)
$checks = @()
$checks += @{ check = "contract_has_int_0008"; passed = ($null -ne $interaction); details = "INT-0008 exists" }
$checks += @{ check = "int_0008_maps_it_eco_009"; passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-ECO-009"); details = "IT-ECO-009 mapping on INT-0008" }
$checks += @{ check = "matrix_declares_ai_economy_link"; passed = ($matrix -match [regex]::Escape("INT-0008") -and $matrix -match [regex]::Escape("IT-ECO-009") -and $matrix -match [regex]::Escape("ai_progression_guard_v1")); details = "Matrix AI/economy link exists" }
$passed = $true
foreach ($c in $checks) { if (-not $c.passed) { $passed = $false } }
$result = @{
    bot = "test-bot-it-eco-009"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-ECO-009"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-eco-009] Report: $output"
if (-not $passed) { exit 1 }
exit 0
