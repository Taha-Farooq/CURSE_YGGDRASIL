param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$phase2Script = Join-Path $RepoRoot "scripts\phase2-acceptance-report.ps1"
if (-not (Test-Path $phase2Script)) {
    throw "Missing scripts/phase2-acceptance-report.ps1"
}

$checks = @()
function Add-Check([string]$name, [bool]$passed, [string]$details) {
    $script:checks += @{
        check = $name
        passed = $passed
        details = $details
    }
}

$normalRaw = & $phase2Script -RepoRoot $RepoRoot -WriteReport
$normal = $normalRaw | ConvertFrom-Json
$hasReportName = ([string]$normal.report -eq "phase2_acceptance_report_v1")
$hasTasks = (@($normal.tasks).Count -gt 0)
$reportPath = [string]$normal.reportPath
if ([string]::IsNullOrWhiteSpace($reportPath)) {
    $latest = Get-ChildItem -Path (Join-Path $RepoRoot "reports") -Filter "phase2-acceptance-report-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -ne $latest) { $reportPath = $latest.FullName }
}
$hasReportPath = (-not [string]::IsNullOrWhiteSpace($reportPath) -and (Test-Path $reportPath))

Add-Check "report_name" $hasReportName "phase2 acceptance report id is correct"
Add-Check "tasks_present" $hasTasks "phase2 report includes task summaries"
Add-Check "artifact_written" $hasReportPath "phase2 report writes artifact when -WriteReport is used"

$strictRaw = & $phase2Script -RepoRoot $RepoRoot -Strict 2>&1
$strictExit = $LASTEXITCODE
$strictJson = $strictRaw | ConvertFrom-Json
$expectedExit = $(if ([bool]$strictJson.passed) { 0 } else { 1 })
$strictExitMatches = ($strictExit -eq $expectedExit)
Add-Check "strict_exit_behavior" $strictExitMatches "strict mode exit code matches report pass/fail state"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "phase2_acceptance_evidence_pack_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
