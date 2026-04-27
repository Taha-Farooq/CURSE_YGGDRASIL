param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-live-008] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-live-008-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw
$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0010" } | Select-Object -First 1)
$checks = @()
$checks += @{ check = "contract_has_int_0010"; passed = ($null -ne $interaction); details = "INT-0010 exists" }
$checks += @{ check = "int_0010_maps_it_live_008"; passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-LIVE-008"); details = "IT-LIVE-008 mapping on INT-0010" }
$checks += @{ check = "matrix_declares_orchestrator_live_link"; passed = ($matrix -match [regex]::Escape("INT-0010") -and $matrix -match [regex]::Escape("IT-LIVE-008") -and $matrix -match [regex]::Escape("bot_policy_guard_v1")); details = "Matrix orchestrator/live link exists" }
$passed = $true
foreach ($c in $checks) { if (-not $c.passed) { $passed = $false } }
$result = @{
    bot = "test-bot-it-live-008"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-LIVE-008"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-live-008] Report: $output"
if (-not $passed) { exit 1 }
exit 0
