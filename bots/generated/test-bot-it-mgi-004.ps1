param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-mgi-004] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-mgi-004-$timestamp.json"

$resolver = Join-Path $RepoRoot "scripts\interop-effect-resolver.ps1"
$action = Join-Path $RepoRoot "tests\fixtures\it-mgi-004-action.json"
$envLow = Join-Path $RepoRoot "tests\fixtures\env-mgi-004-low-arcane.json"
$envHigh = Join-Path $RepoRoot "tests\fixtures\env-mgi-004-high-arcane.json"

$lowResult = (& $resolver -ActionJsonPath $action -EnvironmentJsonPath $envLow) | ConvertFrom-Json
$highResult = (& $resolver -ActionJsonPath $action -EnvironmentJsonPath $envHigh) | ConvertFrom-Json

$checks = @()
$checks += @{
    check = "environment_changes_outcome"
    passed = ([double]$lowResult.resolvedPower -ne [double]$highResult.resolvedPower)
    details = "low=$($lowResult.resolvedPower),high=$($highResult.resolvedPower)"
}
$checks += @{
    check = "both_resolutions_valid"
    passed = ($lowResult.passed -and $highResult.passed)
    details = "lowPassed=$($lowResult.passed),highPassed=$($highResult.passed)"
}
$checks += @{
    check = "high_arcane_outperforms_low_arcane"
    passed = ([double]$highResult.resolvedPower -gt [double]$lowResult.resolvedPower)
    details = "low=$($lowResult.resolvedPower),high=$($highResult.resolvedPower)"
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-mgi-004"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-MGI-004"
    resolver = "interop_effect_resolver_v1"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-mgi-004] Report: $output"
if (-not $passed) { exit 1 }
exit 0
