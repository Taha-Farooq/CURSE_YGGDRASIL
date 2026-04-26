param(
    [string]$RepoRoot = "",
    [string]$TestCommand = "",
    [switch]$AllowPlaceholderPassWhenNoEngine
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[engine-test-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "engine-test-bot-$timestamp.json"

$checks = @()
$passed = $true

if (-not [string]::IsNullOrWhiteSpace($TestCommand)) {
    try {
        Write-Host "[engine-test-bot] Running test command: $TestCommand"
        Invoke-Expression $TestCommand
        if ($LASTEXITCODE -ne 0) { throw "Engine test command failed with code $LASTEXITCODE" }
        $checks += @{ check = "engine_tests"; status = "pass"; details = "Command succeeded" }
    }
    catch {
        $passed = $false
        $checks += @{ check = "engine_tests"; status = "fail"; details = $_.Exception.Message }
    }
}
else {
    $engineIndicators = @("engine", "src/engine", "Engine", "CMakeLists.txt")
    $foundAny = $false
    foreach ($i in $engineIndicators) {
        if (Test-Path (Join-Path $RepoRoot $i)) { $foundAny = $true }
    }

    if ($foundAny) {
        if ($AllowPlaceholderPassWhenNoEngine) {
            $checks += @{ check = "engine_tests"; status = "pass"; details = "Engine-like files found but no explicit testCommand yet; placeholder pass allowed by config" }
        }
        else {
            $passed = $false
            $checks += @{ check = "engine_tests"; status = "fail"; details = "Engine-like files found but no testCommand configured in automation-config.json" }
        }
    }
    else {
        if ($AllowPlaceholderPassWhenNoEngine) {
            $checks += @{ check = "engine_tests"; status = "pass"; details = "No engine files yet; placeholder pass allowed" }
        }
        else {
            $passed = $false
            $checks += @{ check = "engine_tests"; status = "fail"; details = "No engine command configured and placeholder pass disabled" }
        }
    }
}

$result = @{
    bot = "engine-test-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[engine-test-bot] Report: $output"
if (-not $passed) { exit 1 }
exit 0

