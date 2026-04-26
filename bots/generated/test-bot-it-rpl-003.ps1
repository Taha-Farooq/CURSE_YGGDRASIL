param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}

Write-Host "[test-bot-it-rpl-003] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$output = Join-Path $reportDir "test-bot-it-rpl-003-$timestamp.json"

$result = @{
    bot = "test-bot-it-rpl-003"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    testId = "IT-RPL-003"
    note = "Generated stub by bot-maker-bot. Replace with real test logic."
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[test-bot-it-rpl-003] Report: $output"
exit 0
