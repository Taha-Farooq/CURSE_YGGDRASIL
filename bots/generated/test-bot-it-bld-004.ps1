param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-bld-004] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-bld-004-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
if (-not (Test-Path $contractPath)) { throw "Missing contract file: $contractPath" }
if (-not (Test-Path $matrixPath)) { throw "Missing matrix file: $matrixPath" }
$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw
$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0005" } | Select-Object -First 1)
$checks = @()
$checks += @{ check = "contract_has_int_0005"; passed = ($null -ne $interaction); details = "INT-0005 presence" }
$checks += @{ check = "int_0005_maps_it_bld_004"; passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-BLD-004"); details = "IT-BLD-004 mapped on INT-0005" }
$checks += @{ check = "matrix_declares_build_link"; passed = ($matrix -match [regex]::Escape("INT-0005") -and $matrix -match [regex]::Escape("IT-BLD-004") -and $matrix -match [regex]::Escape("build_legality_v1")); details = "Matrix link for build legality exists" }
$passed = $true
foreach ($c in $checks) { if (-not $c.passed) { $passed = $false } }
$result = @{
    bot = "test-bot-it-bld-004"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-BLD-004"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-bld-004] Report: $output"
if (-not $passed) { exit 1 }
exit 0
