param(
    [string]$RepoRoot = "",
    [int]$MaxAgeHours = 24,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reportsDir = Join-Path $RepoRoot "reports\bots"
$criticalBots = @(
    "test-bot-it-auth-base-001",
    "test-bot-it-mgi-001",
    "test-bot-it-mgi-002",
    "test-bot-it-mgi-003",
    "test-bot-it-mgi-004",
    "test-bot-scn-005"
)

$missing = @()
$stale = @()
$nowUtc = (Get-Date).ToUniversalTime()

if (-not (Test-Path $reportsDir)) {
    $result = @{
        check = "test_freshness_policy"
        timestampUtc = $nowUtc.ToString("o")
        maxAgeHours = $MaxAgeHours
        passed = $true
        dataSufficient = $false
        skipped = $true
        skipReason = "No reports directory yet."
        missing = $criticalBots
        stale = @()
    }
    $result | ConvertTo-Json -Depth 8 | Write-Output
    exit 0
}

foreach ($bot in $criticalBots) {
    $latest = Get-ChildItem -Path $reportsDir -Filter "$bot-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $latest) {
        $missing += $bot
        continue
    }

    $ageHours = ($nowUtc - $latest.LastWriteTimeUtc).TotalHours
    if ($ageHours -gt $MaxAgeHours) {
        $stale += @{
            bot = $bot
            reportFile = $latest.Name
            ageHours = [math]::Round($ageHours, 2)
            maxAgeHours = $MaxAgeHours
        }
    }
}

$result = @{
    check = "test_freshness_policy"
    timestampUtc = $nowUtc.ToString("o")
    maxAgeHours = $MaxAgeHours
    passed = ((@($missing).Count -eq 0) -and (@($stale).Count -eq 0))
    dataSufficient = (@($missing).Count -eq 0)
    skipped = $false
    skipReason = ""
    missing = $missing
    stale = $stale
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and (-not $result.passed)) {
    exit 1
}
exit 0
