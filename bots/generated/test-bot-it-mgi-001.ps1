param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-mgi-001] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-mgi-001-$timestamp.json"

$validator = Join-Path $RepoRoot "scripts\authority-validate-action.ps1"
$validFixture = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json"
$invalidFixture = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-invalid.json"

if (-not (Test-Path $validator)) { throw "Missing validator script: $validator" }
if (-not (Test-Path $validFixture)) { throw "Missing fixture: $validFixture" }
if (-not (Test-Path $invalidFixture)) { throw "Missing fixture: $invalidFixture" }

$validResult = (& $validator -RepoRoot $RepoRoot -ActionJsonPath $validFixture) | ConvertFrom-Json
$invalidResult = (& $validator -RepoRoot $RepoRoot -ActionJsonPath $invalidFixture) | ConvertFrom-Json

$checks = @()
$checks += @{
    check = "valid_fixture_passes"
    passed = ($validResult.allowed -eq $true)
    details = $(if ($validResult.allowed) { "valid fixture accepted" } else { "valid fixture rejected: " + (($validResult.reasonCodes -join ", ")) })
}
$checks += @{
    check = "invalid_fixture_rejected"
    passed = ($invalidResult.allowed -eq $false)
    details = $(if (-not $invalidResult.allowed) { "invalid fixture rejected as expected" } else { "invalid fixture unexpectedly accepted" })
}
$checks += @{
    check = "invalid_fixture_reason_codes"
    passed = (($invalidResult.reasonCodes | Measure-Object).Count -gt 0)
    details = "reasonCodes=" + ($invalidResult.reasonCodes -join ",")
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) {
        $passed = $false
    }
}

$result = @{
    bot = "test-bot-it-mgi-001"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-MGI-001"
    validator = "authority_validation_service_v1"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-mgi-001] Report: $output"
if (-not $passed) { exit 1 }
exit 0
