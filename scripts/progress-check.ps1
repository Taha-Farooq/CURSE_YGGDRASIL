param()

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$reportsDir = Join-Path $repoRoot "reports\bots"

if (-not (Test-Path $reportsDir)) {
    Write-Output "No bot reports yet. Run: ./scripts/run-autonomous.ps1 -Once -Strict"
    exit 1
}

$latest = Get-ChildItem -Path $reportsDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
if ($latest.Count -eq 0) {
    Write-Output "No bot reports yet. Run: ./scripts/run-autonomous.ps1 -Once -Strict"
    exit 1
}

$goalReport = Get-ChildItem -Path $reportsDir -Filter "goal-alignment-bot-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$orchestratorReport = Get-ChildItem -Path $reportsDir -Filter "orchestrator-run-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$coverageReport = Get-ChildItem -Path $reportsDir -Filter "contract-coverage-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1

Write-Output "=== CURSE Progress Check ==="
if ($orchestratorReport) {
    $or = Get-Content $orchestratorReport.FullName -Raw | ConvertFrom-Json
    Write-Output ("Orchestrator: " + $(if ($or.passed) { "PASS" } else { "FAIL" }) + " | " + $or.timestampUtc)
}

if ($goalReport) {
    $gr = Get-Content $goalReport.FullName -Raw | ConvertFrom-Json
    Write-Output ("Goal Alignment: " + $(if ($gr.passed) { "PASS" } else { "FAIL" }) + " | Goal=" + $gr.goal)
    $fails = @($gr.checks | Where-Object { $_.status -eq "fail" })
    if ($fails.Count -gt 0) {
        Write-Output "Missing signals:"
        foreach ($f in $fails) {
            Write-Output (" - [" + $f.area + "] " + $f.key)
        }
    }
}
else {
    Write-Output "Goal Alignment: NOT RUN"
}

$tasksPath = Join-Path $repoRoot "backlog\tasks.json"
if (Test-Path $tasksPath) {
    try {
        $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
        $phase1 = @($tasks | Where-Object { $_.type -eq "phase1" })
        if (@($phase1).Count -gt 0) {
            $done = @($phase1 | Where-Object { $_.status -eq "done" }).Count
            $inProgress = @($phase1 | Where-Object { $_.status -eq "in_progress" }).Count
            $todo = @($phase1 | Where-Object { $_.status -eq "todo" }).Count
            $pct = [math]::Round(($done / @($phase1).Count) * 100, 2)
            Write-Output ("Phase 1 Tasks: done=$done, in_progress=$inProgress, todo=$todo, completion=" + $pct + "%")
        } else {
            Write-Output "Phase 1 Tasks: none found in backlog."
        }
    }
    catch {
        Write-Output "Phase 1 Tasks: unable to parse backlog/tasks.json"
    }
}

if ($coverageReport) {
    try {
        $cr = Get-Content $coverageReport.FullName -Raw | ConvertFrom-Json
        Write-Output ("Coverage: " + $cr.coveragePct + "% mapped, functional=" + $cr.functionalPct + "%")
        if ($null -ne $cr.topWeakDomains -and @($cr.topWeakDomains).Count -gt 0) {
            $parts = @($cr.topWeakDomains | ForEach-Object { $_.domain + " (" + $_.functionalPct + "%)" })
            Write-Output ("Top weak domains: " + ($parts -join ", "))
        }
    }
    catch {
        Write-Output "Coverage: unable to parse latest contract coverage report."
    }
}

Write-Output "Top recent bot reports:"
$top = $latest | Select-Object -First 10
foreach ($f in $top) {
    Write-Output (" - " + $f.Name)
}

exit 0

