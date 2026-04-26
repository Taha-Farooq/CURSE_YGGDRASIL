param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-mgi-003] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-mgi-003-$timestamp.json"

$validator = Join-Path $RepoRoot "scripts\interop-legality-validator.ps1"
$invalidFixture = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-invalid.json"

$invalidResult = (& $validator -RepoRoot $RepoRoot -ActionJsonPath $invalidFixture) | ConvertFrom-Json

$checks = @()
$checks += @{
    check = "budget_overflow_rejected"
    passed = ($invalidResult.passed -eq $false)
    details = "validatorPassed=$($invalidResult.passed)"
}
$checks += @{
    check = "budget_reason_code_present"
    passed = (@($invalidResult.reasonCodes) -contains "INT-LEG-010-SIM_BUDGET_EXCEEDED")
    details = "reasonCodes=" + (@($invalidResult.reasonCodes) -join ",")
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-mgi-003"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-MGI-003"
    validator = "interop_legality_validator_v1"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-mgi-003] Report: $output"
if (-not $passed) { exit 1 }
exit 0
