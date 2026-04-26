param(
    [string]$RepoRoot = "",
    [switch]$Strict,
    [switch]$WriteReport
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$generatedDir = Join-Path $RepoRoot "bots\generated"
$reportsDir = Join-Path $RepoRoot "reports\bots"

if (-not (Test-Path $contractPath)) {
    throw "Missing interaction contract: $contractPath"
}
if (-not (Test-Path $generatedDir)) {
    throw "Missing generated bot directory: $generatedDir"
}
if ($WriteReport -and -not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
}

$contract = Get-Content $contractPath -Raw | ConvertFrom-Json

function Get-BotNameForId([string]$id) {
    $slug = $id.ToLowerInvariant()
    return "test-bot-$slug.ps1"
}

function Is-StubBot([string]$path) {
    $content = Get-Content $path -Raw
    return ($content -match "Generated stub by bot-maker-bot\. Replace with real test logic\.")
}

$requiredIds = @()
foreach ($i in @($contract.interactions)) {
    foreach ($tid in @($i.integrationTestIds)) { $requiredIds += [string]$tid }
}
foreach ($s in @($contract.scenarios)) {
    $requiredIds += [string]$s.scenarioId
}
$requiredIds = @($requiredIds | Sort-Object -Unique)

$missing = @()
$stub = @()
$functional = @()

foreach ($id in $requiredIds) {
    $fileName = Get-BotNameForId $id
    $path = Join-Path $generatedDir $fileName
    if (-not (Test-Path $path)) {
        $missing += @{
            id = $id
            expectedBot = $fileName
        }
        continue
    }

    if (Is-StubBot $path) {
        $stub += @{
            id = $id
            bot = $fileName
        }
    } else {
        $functional += @{
            id = $id
            bot = $fileName
        }
    }
}

$coveredCount = @($functional).Count + @($stub).Count
$requiredCount = @($requiredIds).Count
$functionalPct = if ($requiredCount -gt 0) { [math]::Round((@($functional).Count / $requiredCount) * 100, 2) } else { 0 }
$coveragePct = if ($requiredCount -gt 0) { [math]::Round(($coveredCount / $requiredCount) * 100, 2) } else { 0 }

$result = @{
    check = "test_contract_coverage"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    requiredCount = $requiredCount
    coveredCount = $coveredCount
    coveragePct = $coveragePct
    functionalCount = @($functional).Count
    functionalPct = $functionalPct
    stubCount = @($stub).Count
    missingCount = @($missing).Count
    missing = $missing
    stub = $stub
    functional = $functional
    passed = (@($missing).Count -eq 0)
}

if ($WriteReport) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportPath = Join-Path $reportsDir "contract-coverage-$stamp.json"
    $result | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8
    $result["reportPath"] = $reportPath
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and @($missing).Count -gt 0) {
    exit 1
}
exit 0
