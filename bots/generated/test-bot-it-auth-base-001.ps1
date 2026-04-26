param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-auth-base-001] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-auth-base-001-$timestamp.json"

$authorityService = Join-Path $RepoRoot "scripts\authority-validate-action.ps1"
$validFixture = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json"
$invalidFixture = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-invalid.json"

if (-not (Test-Path $authorityService)) { throw "Missing authority service script: $authorityService" }

$validDecision = (& $authorityService -RepoRoot $RepoRoot -ActionJsonPath $validFixture) | ConvertFrom-Json
$invalidDecision = (& $authorityService -RepoRoot $RepoRoot -ActionJsonPath $invalidFixture) | ConvertFrom-Json

$checks = @()
$checks += @{
    check = "valid_action_allowed"
    passed = ($validDecision.allowed -eq $true)
    details = "allowed=$($validDecision.allowed)"
}
$checks += @{
    check = "invalid_action_rejected"
    passed = ($invalidDecision.allowed -eq $false)
    details = "allowed=$($invalidDecision.allowed)"
}
$checks += @{
    check = "interop_to_authority_mapping_present"
    passed = ((@($invalidDecision.reasonCodes) -contains "AUTH-INTEROP-001") -and (@($invalidDecision.reasonCodes) -contains "AUTH-BUDGET-001"))
    details = "reasonCodes=" + (@($invalidDecision.reasonCodes) -join ",")
}
$checks += @{
    check = "replay_metadata_emitted"
    passed = ($null -ne $validDecision.replayMetadata -and -not [string]::IsNullOrWhiteSpace($validDecision.replayMetadata.authorityDecisionId))
    details = "authorityDecisionId=$($validDecision.replayMetadata.authorityDecisionId)"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-auth-base-001"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-AUTH-BASE-001"
    service = "authority_validation_service_v1"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-auth-base-001] Report: $output"
if (-not $passed) { exit 1 }
exit 0
