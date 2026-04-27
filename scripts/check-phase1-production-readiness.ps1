param(
    [string]$RepoRoot = "",
    [double]$MinFunctionalCoveragePct = 30.0,
    [double]$MinInteropPassRatePct = 100.0,
    [int]$MinPhase1InProgress = 2,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reportsDir = Join-Path $RepoRoot "reports"
$botReportsDir = Join-Path $RepoRoot "reports\bots"
$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"

$result = @{
    check = "phase1_production_readiness"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $false
    thresholds = @{
        minFunctionalCoveragePct = $MinFunctionalCoveragePct
        minInteropPassRatePct = $MinInteropPassRatePct
        minPhase1InProgress = $MinPhase1InProgress
    }
    checks = @()
}

function Add-Check([string]$name, [bool]$passed, [string]$details) {
    return @{
        check = $name
        passed = $passed
        details = $details
    }
}

$snapshotFile = $null
if (Test-Path $reportsDir) {
    $snapshotFile = Get-ChildItem -Path $reportsDir -Filter "release-readiness-snapshot-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
}

if ($null -eq $snapshotFile) {
    $result.checks += Add-Check "snapshot_exists" $false "No release-readiness snapshot found."
    $result | ConvertTo-Json -Depth 10 | Write-Output
    if ($Strict) { exit 1 } else { exit 0 }
}

$snapshot = Get-Content $snapshotFile.FullName -Raw | ConvertFrom-Json
$result.checks += Add-Check "snapshot_exists" $true ("Using " + $snapshotFile.Name)

$qgPassed = [bool]$snapshot.qualityGateStatus.passed
$result.checks += Add-Check "quality_gate_passed" $qgPassed ("qualityGateStatus.passed=" + $qgPassed)

$orchestratorPassed = $false
$orchestratorDetails = "latestOrchestratorRun missing"
if ($null -ne $snapshot.latestOrchestratorRun) {
    $steps = @($snapshot.latestOrchestratorRun.steps)
    if ($steps.Count -gt 0) {
        $nonSelf = @($steps | Where-Object { $_.name -ne "phase1-production-readiness-bot" })
        if ($nonSelf.Count -gt 0) {
            $failed = @($nonSelf | Where-Object { $_.status -ne "pass" })
            $orchestratorPassed = (@($failed).Count -eq 0)
            $orchestratorDetails = "non-self failed steps=" + @($failed).Count
        } else {
            $orchestratorPassed = [bool]$snapshot.latestOrchestratorRun.passed
            $orchestratorDetails = "fallback latestOrchestratorRun.passed=" + $orchestratorPassed
        }
    } elseif ($null -ne $snapshot.latestOrchestratorRun.passed) {
        $orchestratorPassed = [bool]$snapshot.latestOrchestratorRun.passed
        $orchestratorDetails = "latestOrchestratorRun.passed=" + $orchestratorPassed
    }
}
$result.checks += Add-Check "orchestrator_passed" $orchestratorPassed $orchestratorDetails

$functionalCoverage = 0.0
if ($null -ne $snapshot.contractCoverage -and $null -ne $snapshot.contractCoverage.functionalPct) {
    $functionalCoverage = [double]$snapshot.contractCoverage.functionalPct
}
$coveragePassed = ($functionalCoverage -ge $MinFunctionalCoveragePct)
$result.checks += Add-Check "functional_coverage_threshold" $coveragePassed ("functionalPct=" + $functionalCoverage)

$interopPassRate = 0.0
if (Test-Path $botReportsDir) {
    $tracked = @("IT-MGI-001","IT-MGI-002","IT-MGI-003","IT-MGI-004","SCN-005")
    $passCount = 0
    foreach ($tid in $tracked) {
        $slug = "test-bot-" + $tid.ToLowerInvariant()
        $file = Get-ChildItem -Path $botReportsDir -Filter "$slug-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($null -eq $file) { continue }
        try {
            $report = Get-Content $file.FullName -Raw | ConvertFrom-Json
            if ([bool]$report.passed) { $passCount++ }
        } catch {}
    }
    $interopPassRate = [math]::Round(($passCount / 5.0) * 100, 2)
}
$interopPassed = ($interopPassRate -ge $MinInteropPassRatePct)
$result.checks += Add-Check "interop_pass_rate_threshold" $interopPassed ("interopPassRatePct=" + $interopPassRate)

$phase1InProgress = 0
$phase1Done = 0
$phase1Total = 0
if (Test-Path $tasksPath) {
    try {
        $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
        $phase1Tasks = @($tasks | Where-Object { $_.type -eq "phase1" })
        $phase1Total = $phase1Tasks.Count
        $phase1InProgress = @($phase1Tasks | Where-Object { $_.status -eq "in_progress" }).Count
        $phase1Done = @($phase1Tasks | Where-Object { $_.status -eq "done" }).Count
    } catch {}
}
$phase1FullyCompleted = ($phase1Total -gt 0 -and $phase1Done -eq $phase1Total)
$phase1InProgressPassed = (($phase1InProgress -ge $MinPhase1InProgress) -or $phase1FullyCompleted)
$result.checks += Add-Check "phase1_in_progress_threshold" $phase1InProgressPassed ("phase1InProgress=" + $phase1InProgress + "; phase1Done=" + $phase1Done + "/" + $phase1Total)

$allPassed = $true
foreach ($c in $result.checks) {
    if (-not [bool]$c.passed) { $allPassed = $false }
}
$result.passed = $allPassed

$result | ConvertTo-Json -Depth 10 | Write-Output
if ($Strict -and -not $allPassed) { exit 1 }
exit 0
