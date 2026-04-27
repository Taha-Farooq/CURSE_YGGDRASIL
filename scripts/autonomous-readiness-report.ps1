param(
    [string]$RepoRoot = "",
    [switch]$WriteReport,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

function Invoke-JsonScript {
    param(
        [string]$ScriptPath,
        [string]$Root
    )
    try {
        $json = & $ScriptPath -RepoRoot $Root -Strict | ConvertFrom-Json
        return @{
            ok = $true
            result = $json
            error = ""
        }
    }
    catch {
        return @{
            ok = $false
            result = $null
            error = $_.Exception.Message
        }
    }
}

function Invoke-ExitOnlyScript {
    param(
        [string]$ScriptPath,
        [string]$Root
    )
    try {
        & $ScriptPath -Strict | Out-Null
        return @{
            ok = $true
            passed = ($LASTEXITCODE -eq 0)
            error = ""
        }
    }
    catch {
        return @{
            ok = $false
            passed = $false
            error = $_.Exception.Message
        }
    }
}

$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
if (-not (Test-Path $tasksPath)) { throw "Missing backlog/tasks.json" }
$tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json

$grouped = @{}
foreach ($t in $tasks) {
    $type = [string]$t.type
    if (-not $grouped.ContainsKey($type)) {
        $grouped[$type] = @()
    }
    $grouped[$type] += $t
}

$taskProgress = @{}
foreach ($type in $grouped.Keys) {
    $bucket = @($grouped[$type])
    $total = $bucket.Count
    $done = @($bucket | Where-Object { [string]$_.status -eq "done" }).Count
    $inProgress = @($bucket | Where-Object { [string]$_.status -eq "in_progress" }).Count
    $todo = @($bucket | Where-Object { [string]$_.status -eq "todo" }).Count
    $pct = 0.0
    if ($total -gt 0) { $pct = [Math]::Round((100.0 * $done) / $total, 2) }
    $taskProgress[$type] = @{
        total = $total
        done = $done
        inProgress = $inProgress
        todo = $todo
        completionPct = $pct
    }
}

$phase1Script = Join-Path $RepoRoot "scripts\phase1-acceptance-report.ps1"
$phase2Script = Join-Path $RepoRoot "scripts\phase2-acceptance-report.ps1"
$qualityScript = Join-Path $RepoRoot "scripts\quality-gate.ps1"
$phase1 = Invoke-JsonScript -ScriptPath $phase1Script -Root $RepoRoot
$phase2 = Invoke-JsonScript -ScriptPath $phase2Script -Root $RepoRoot
$quality = Invoke-ExitOnlyScript -ScriptPath $qualityScript -Root $RepoRoot

$configPath = Join-Path $RepoRoot "automation\automation-config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$implementationMode = [string]$config.bots.implementationBot.mode
$maxFileChangesPerRun = [int]$config.bots.implementationBot.maxFileChangesPerRun
$strictQualityGateEnabled = [bool]$config.strictQualityGate

$readinessSignals = @{
    qualityGatePassed = ($quality.ok -and [bool]$quality.passed)
    phase1AcceptancePassed = ($phase1.ok -and [bool]$phase1.result.passed)
    phase2AcceptancePassed = ($phase2.ok -and [bool]$phase2.result.passed)
    strictQualityGateEnabled = $strictQualityGateEnabled
    implementationMode = $implementationMode
    implementationCanWriteProductionCode = ($implementationMode -ne "scaffold_only")
}

$score = 0
if ($readinessSignals.qualityGatePassed) { $score += 30 }
if ($readinessSignals.phase1AcceptancePassed) { $score += 20 }
if ($readinessSignals.phase2AcceptancePassed) { $score += 20 }
if ($readinessSignals.strictQualityGateEnabled) { $score += 10 }
if ($readinessSignals.implementationCanWriteProductionCode) { $score += 20 }

$remaining = @()
if (-not $readinessSignals.qualityGatePassed) {
    $remaining += "Quality gate must pass in strict mode for autonomous edits."
}
if (-not $readinessSignals.phase1AcceptancePassed) {
    $remaining += "Phase 1 acceptance report must pass."
}
if (-not $readinessSignals.phase2AcceptancePassed) {
    $remaining += "Phase 2 acceptance report must pass."
}
if (-not $readinessSignals.implementationCanWriteProductionCode) {
    $remaining += "Implementation bot is scaffold_only; switch to a code-writing mode with guarded limits."
}

$systemTodo = @($tasks | Where-Object { [string]$_.type -eq "system" -and [string]$_.status -ne "done" }).Count
$userFeatureTodo = @($tasks | Where-Object { [string]$_.type -eq "user-feature" -and [string]$_.status -ne "done" }).Count
$legacyTodo = @($tasks | Where-Object { [string]$_.type -eq "legacy-triage" -and [string]$_.status -ne "done" }).Count

$result = @{
    report = "autonomous_readiness_report_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    readinessScorePct = $score
    autonomousEditReady = ($score -ge 85 -and @($remaining).Count -eq 0)
    readinessSignals = $readinessSignals
    implementationConstraints = @{
        implementationMode = $implementationMode
        maxFileChangesPerRun = $maxFileChangesPerRun
    }
    backlogStatus = @{
        systemTodo = $systemTodo
        userFeatureTodo = $userFeatureTodo
        legacyTodo = $legacyTodo
        byType = $taskProgress
    }
    remainingWork = $remaining
    checks = @{
        phase1 = $phase1
        phase2 = $phase2
        quality = $quality
    }
}

if ($WriteReport) {
    $outDir = Join-Path $RepoRoot "reports"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $path = Join-Path $outDir "autonomous-readiness-report-$stamp.json"
    $result | ConvertTo-Json -Depth 12 | Set-Content -Path $path -Encoding UTF8
    $result["reportPath"] = $path
}

$result | ConvertTo-Json -Depth 12 | Write-Output
if ($Strict -and -not [bool]$result.autonomousEditReady) { exit 1 }
exit 0
