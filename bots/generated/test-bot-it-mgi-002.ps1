param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-mgi-002] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-mgi-002-$timestamp.json"

$resolver = Join-Path $RepoRoot "scripts\interop-effect-resolver.ps1"
$action = Join-Path $RepoRoot "tests\fixtures\it-mgi-002-action.json"
$envNoSupp = Join-Path $RepoRoot "tests\fixtures\env-mgi-002-no-suppression.json"
$envSupp = Join-Path $RepoRoot "tests\fixtures\env-mgi-002-with-suppression.json"

$noSuppResult = (& $resolver -ActionJsonPath $action -EnvironmentJsonPath $envNoSupp) | ConvertFrom-Json
$suppResult = (& $resolver -ActionJsonPath $action -EnvironmentJsonPath $envSupp) | ConvertFrom-Json
$suppResultRepeat = (& $resolver -ActionJsonPath $action -EnvironmentJsonPath $envSupp) | ConvertFrom-Json

$checks = @()
$checks += @{
    check = "suppression_reduces_power"
    passed = ([double]$suppResult.resolvedPower -lt [double]$noSuppResult.resolvedPower)
    details = "suppressed=$($suppResult.resolvedPower),unsuppressed=$($noSuppResult.resolvedPower)"
}
$checks += @{
    check = "suppression_path_deterministic"
    passed = ([double]$suppResult.resolvedPower -eq [double]$suppResultRepeat.resolvedPower)
    details = "run1=$($suppResult.resolvedPower),run2=$($suppResultRepeat.resolvedPower)"
}
$checks += @{
    check = "suppression_modifier_present"
    passed = (@($suppResult.modifiers) -contains "tech_suppression")
    details = "modifiers=" + (@($suppResult.modifiers) -join ",")
}

$passed = $true
foreach ($c in $checks) {
    if (-not $c.passed) { $passed = $false }
}

$result = @{
    bot = "test-bot-it-mgi-002"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    testId = "IT-MGI-002"
    resolver = "interop_effect_resolver_v1"
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-mgi-002] Report: $output"
if (-not $passed) { exit 1 }
exit 0
