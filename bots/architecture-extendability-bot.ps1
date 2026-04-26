param(
    [string]$RepoRoot = "",
    [string[]]$RequiredKeywords = @("non-Euclidean", "tiered simulation", "authority", "replay")
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[architecture-extendability-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
$output = Join-Path $botDir "architecture-extendability-bot-$timestamp.json"

$reqPath = Join-Path $RepoRoot "REQUIREMENTS.md"
$matrixPath = Join-Path $RepoRoot "INTERACTION_MATRIX.md"
$combined = ""
if (Test-Path $reqPath) { $combined += (Get-Content $reqPath -Raw) + "`n" }
if (Test-Path $matrixPath) { $combined += (Get-Content $matrixPath -Raw) + "`n" }

$checks = @()
$passed = $true
foreach ($kw in $RequiredKeywords) {
    if ($combined -match [regex]::Escape($kw)) {
        $checks += @{ check = "keyword"; keyword = $kw; status = "pass" }
    } else {
        $passed = $false
        $checks += @{ check = "keyword"; keyword = $kw; status = "fail"; details = "Missing architecture keyword in core docs" }
    }
}

$extensionSignals = @("shared", "schema", "contract", "validator", "runtime")
$signalCount = 0
foreach ($s in $extensionSignals) {
    if ($combined -match $s) { $signalCount++ }
}
$checks += @{ check = "extension_signals"; status = "info"; count = $signalCount; requiredMin = 3 }
if ($signalCount -lt 3) {
    $passed = $false
}

$result = @{
    bot = "architecture-extendability-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
    recommendation = "Keep runtime/validation/data contracts strict to support future dimensional operations."
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[architecture-extendability-bot] Report: $output"
if (-not $passed) { exit 1 }
exit 0

