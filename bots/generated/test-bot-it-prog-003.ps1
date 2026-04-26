param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-prog-003] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-prog-003-$timestamp.json"

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"

if (-not (Test-Path $contractPath)) { throw "Missing contract file: $contractPath" }
if (-not (Test-Path $matrixPath)) { throw "Missing matrix file: $matrixPath" }

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json
$matrix = Get-Content $matrixPath -Raw

$interaction = @($contract.interactions | Where-Object { $_.interactionId -eq "INT-0001" } | Select-Object -First 1)

$checks = @()
$checks += @{
    check = "contract_has_int_0001"
    passed = ($null -ne $interaction)
    details = $(if ($null -ne $interaction) { "INT-0001 found in contract" } else { "INT-0001 missing from contract" })
}
$checks += @{
    check = "int_0001_maps_it_prog_003"
    passed = ($null -ne $interaction -and @($interaction.integrationTestIds) -contains "IT-PROG-003")
    details = $(if ($null -ne $interaction) { "integrationTestIds=" + (@($interaction.integrationTestIds) -join ", ") } else { "interaction missing" })
}
$checks += @{
    check = "matrix_declares_prog_link"
    passed = ($matrix -match [regex]::Escape("INT-0001") -and $matrix -match [regex]::Escape("IT-PROG-003") -and $matrix -match [regex]::Escape("progression_and_evolution"))
    details = "INTERACTION_MATRIX.md contains INT-0001 / IT-PROG-003 progression linkage"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-prog-003"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-PROG-003"
    checks = $checks
    validator = "interaction_contract_consistency_v1"
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-prog-003] Report: $output"
if (-not $passed) { exit 1 }
exit 0
