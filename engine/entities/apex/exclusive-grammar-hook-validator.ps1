param(
    [string]$RepoRoot = "",
    [string]$ActionJsonPath = "",
    [string]$EnvironmentJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($ActionJsonPath)) {
    $ActionJsonPath = Join-Path $RepoRoot "tests\fixtures\phase1-apex-exclusive-action.json"
}
if ([string]::IsNullOrWhiteSpace($EnvironmentJsonPath)) {
    $EnvironmentJsonPath = Join-Path $RepoRoot "tests\fixtures\phase1-construction-env.json"
}

$authorityScript = Join-Path $RepoRoot "scripts\authority-validate-action.ps1"
$resolverScript = Join-Path $RepoRoot "scripts\interop-effect-resolver.ps1"
$authority = & $authorityScript -RepoRoot $RepoRoot -ActionJsonPath $ActionJsonPath | ConvertFrom-Json
$interop = & $resolverScript -ActionJsonPath $ActionJsonPath -EnvironmentJsonPath $EnvironmentJsonPath | ConvertFrom-Json

$passed = ([bool]$authority.allowed -and [bool]$interop.passed)
$result = @{
    validator = "apex_exclusive_grammar_hook_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    sharedInteropPath = @{
        authorityAllowed = [bool]$authority.allowed
        interopPassed = [bool]$interop.passed
    }
    passed = $passed
    reasonCodes = @(
        $(if (-not [bool]$authority.allowed) { "APEX-GRAMMAR-AUTH-REJECT" }),
        $(if (-not [bool]$interop.passed) { "APEX-GRAMMAR-INTEROP-REJECT" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
$result | ConvertTo-Json -Depth 8 | Write-Output
if (-not $passed) { exit 1 }
exit 0
