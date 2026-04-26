param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-scn-005] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-scn-005-$timestamp.json"

$validator = Join-Path $RepoRoot "scripts\authority-validate-action.ps1"
$resolver = Join-Path $RepoRoot "scripts\interop-effect-resolver.ps1"
$action = Join-Path $RepoRoot "tests\fixtures\scn-005-action.json"
$envA = Join-Path $RepoRoot "tests\fixtures\env-mgi-004-low-arcane.json"
$envB = Join-Path $RepoRoot "tests\fixtures\env-mgi-004-high-arcane.json"

$legality = (& $validator -RepoRoot $RepoRoot -ActionJsonPath $action) | ConvertFrom-Json
$resolutionA = (& $resolver -ActionJsonPath $action -EnvironmentJsonPath $envA) | ConvertFrom-Json
$resolutionB = (& $resolver -ActionJsonPath $action -EnvironmentJsonPath $envB) | ConvertFrom-Json

$checks = @()
$checks += @{
    check = "hybrid_action_legality_pass"
    passed = ($legality.allowed -eq $true)
    details = "reasonCodes=" + (@($legality.reasonCodes) -join ",")
}
$checks += @{
    check = "environment_driven_variation"
    passed = ([double]$resolutionA.resolvedPower -ne [double]$resolutionB.resolvedPower)
    details = "envA=$($resolutionA.resolvedPower),envB=$($resolutionB.resolvedPower)"
}
$checks += @{
    check = "replay_evidence_present"
    passed = (
        $resolutionA.replayEvidence.replayRequired -eq $true -and
        $resolutionB.replayEvidence.replayRequired -eq $true -and
        $resolutionA.replayEvidence.replayEventCount -gt 0 -and
        $resolutionB.replayEvidence.replayEventCount -gt 0
    )
    details = "envAEvents=$($resolutionA.replayEvidence.replayEventCount),envBEvents=$($resolutionB.replayEvidence.replayEventCount)"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-scn-005"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "SCN-005"
    validator = "authority_validation_service_v1"
    resolver = "interop_effect_resolver_v1"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-scn-005] Report: $output"
if (-not $passed) { exit 1 }
exit 0
