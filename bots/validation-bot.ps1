param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[validation-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "validation-bot-$timestamp.json"

$passed = $true
$checks = @()

try {
    & (Join-Path $RepoRoot "scripts\quality-gate.ps1") -Strict:$Strict
    $checks += @{ check = "quality_gate"; status = "pass"; details = "quality-gate passed" }
}

try {
    $authValidation = & (Join-Path $RepoRoot "scripts\authority-validate-action.ps1") -RepoRoot $RepoRoot -ActionJsonPath (Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json") | ConvertFrom-Json
    if ($authValidation.allowed -eq $true) {
        $checks += @{ check = "authority_validation_smoke"; status = "pass"; details = "canonical authority validation entrypoint passed" }
    } else {
        $passed = $false
        $checks += @{ check = "authority_validation_smoke"; status = "fail"; details = "unexpected rejection: " + ($authValidation.reasonCodes -join ",") }
    }
}
catch {
    $passed = $false
    $checks += @{ check = "authority_validation_smoke"; status = "fail"; details = $_.Exception.Message }
}
catch {
    $passed = $false
    $checks += @{ check = "quality_gate"; status = "fail"; details = $_.Exception.Message }
}

$requiredFiles = @(
    "REQUIREMENTS.md",
    "FEEDBACK_SCHEMA.json",
    "INTERACTION_MATRIX.md",
    "ONE_PERSON_TEAM_LOOP.md"
)
foreach ($file in $requiredFiles) {
    $exists = Test-Path (Join-Path $RepoRoot $file)
    if ($exists) {
        $checks += @{ check = "required_file"; status = "pass"; details = $file }
    } else {
        $passed = $false
        $checks += @{ check = "required_file"; status = "fail"; details = "Missing $file" }
    }
}

$result = @{
    bot = "validation-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[validation-bot] Report: $output"
if (-not $passed) { exit 1 }
exit 0

