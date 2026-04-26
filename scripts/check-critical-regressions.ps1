param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reportsDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportsDir)) {
    $result = @{
        check = "critical_regression_guard"
        timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
        passed = $true
        message = "No reports directory yet."
        criticalFindings = @()
    }
    $result | ConvertTo-Json -Depth 8 | Write-Output
    exit 0
}

$criticalBots = @(
    "test-bot-it-auth-base-001",
    "test-bot-it-mgi-001",
    "test-bot-it-mgi-002",
    "test-bot-it-mgi-003",
    "test-bot-it-mgi-004",
    "test-bot-scn-005"
)

$findings = @()
foreach ($bot in $criticalBots) {
    $files = @(Get-ChildItem -Path $reportsDir -Filter "$bot-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 2)
    if (@($files).Count -lt 2) { continue }

    $twoFails = $true
    $windows = @()
    foreach ($f in $files) {
        try {
            $report = Get-Content $f.FullName -Raw | ConvertFrom-Json
            $passed = [bool]$report.passed
            $windows += @{
                file = $f.Name
                passed = $passed
            }
            if ($passed) { $twoFails = $false }
        } catch {
            $twoFails = $false
        }
    }

    if ($twoFails) {
        $findings += @{
            bot = $bot
            consecutiveFailures = 2
            windows = $windows
        }
    }
}

$result = @{
    check = "critical_regression_guard"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = (@($findings).Count -eq 0)
    criticalFindings = $findings
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and @($findings).Count -gt 0) {
    exit 1
}
exit 0
