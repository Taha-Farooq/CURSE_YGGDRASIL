param(
    [string]$RepoRoot = "",
    [int]$MaxBotsToCreatePerRun = 5,
    [bool]$OnlyCreateIfMissing = $true
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[bot-maker-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
$handoffPath = Join-Path $RepoRoot "automation\handoff\bot-maker-requests.json"
$generatedBotsDir = Join-Path $RepoRoot "bots\generated"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
if (-not (Test-Path $generatedBotsDir)) { New-Item -ItemType Directory -Path $generatedBotsDir -Force | Out-Null }
$output = Join-Path $botDir "bot-maker-bot-$timestamp.json"

$created = @()
$skipped = @()

if (-not (Test-Path $handoffPath)) {
    $result = @{
        bot = "bot-maker-bot"
        timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
        passed = $true
        created = @()
        skipped = @("No handoff file present")
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
    Write-Host "[bot-maker-bot] Report: $output"
    exit 0
}

$requests = Get-Content $handoffPath -Raw | ConvertFrom-Json
$count = 0
foreach ($req in $requests) {
    if ($count -ge $MaxBotsToCreatePerRun) { break }
    if ($req.kind -ne "create_test_bot_stub") { continue }

    $safeName = ($req.name -replace "[^a-zA-Z0-9\-_]","").Trim()
    if ([string]::IsNullOrWhiteSpace($safeName)) { continue }
    $botPath = Join-Path $generatedBotsDir ($safeName + ".ps1")

    if ($OnlyCreateIfMissing -and (Test-Path $botPath)) {
        $skipped += "$safeName (already exists)"
        continue
    }

    $content = @"
param(
    [string]`$RepoRoot = ""
)

`$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace(`$RepoRoot)) {
    `$RepoRoot = Resolve-Path (Join-Path `$PSScriptRoot "..\..")
}

Write-Host "[$safeName] Starting..."
`$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
`$reportDir = Join-Path `$RepoRoot "reports\bots"
if (-not (Test-Path `$reportDir)) { New-Item -ItemType Directory -Path `$reportDir -Force | Out-Null }
`$output = Join-Path `$reportDir "$safeName-`$timestamp.json"

`$result = @{
    bot = "$safeName"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = `$true
    testId = "$($req.targetTestId)"
    note = "Generated stub by bot-maker-bot. Replace with real test logic."
}
`$result | ConvertTo-Json -Depth 6 | Set-Content -Path `$output -Encoding UTF8
Write-Host "[$safeName] Report: `$output"
exit 0
"@

    Set-Content -Path $botPath -Value $content -Encoding UTF8
    $created += $botPath
    $count++
}

$result = @{
    bot = "bot-maker-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    created = $created
    skipped = $skipped
    handoffPath = $handoffPath
}
$result | ConvertTo-Json -Depth 8 | Set-Content -Path $output -Encoding UTF8
Write-Host "[bot-maker-bot] Report: $output"
exit 0

