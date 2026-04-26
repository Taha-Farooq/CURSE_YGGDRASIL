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

$goalReport = $latest | Where-Object { $_.Name -like "goal-alignment-bot-*.json" } | Select-Object -First 1
$orchestratorReport = $latest | Where-Object { $_.Name -like "orchestrator-run-*.json" } | Select-Object -First 1

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

Write-Output "Top recent bot reports:"
$top = $latest | Select-Object -First 10
foreach ($f in $top) {
    Write-Output (" - " + $f.Name)
}

exit 0

