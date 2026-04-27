param(
    [string]$RepoRoot = "",
    [int]$MaxFindings = 40
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reportsDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

$requirementsPath = Join-Path $RepoRoot "REQUIREMENTS.md"
$contractPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportPath = Join-Path $reportsDir "autonomous-drift-report-bot-$timestamp.json"
$coverageScriptPath = Join-Path $RepoRoot "scripts\check-test-contract-coverage.ps1"

$findings = @()
$coverageBackedIds = @()

try {
    $req = Get-Content $requirementsPath -Raw
    $sectionCount = @([regex]::Matches($req, "(?m)^##\s+\d+\)")).Count
    if ($sectionCount -lt 20) {
        $findings += @{
            type = "requirements_structure"
            severity = "warning"
            details = "REQUIREMENTS.md has fewer than 20 numbered sections."
        }
    }
}
catch {
    $findings += @{
        type = "requirements_missing"
        severity = "critical"
        details = "Unable to read REQUIREMENTS.md."
    }
}

$contractIds = @()
try {
    $contract = Get-Content $contractPath -Raw | ConvertFrom-Json
    foreach ($interaction in @($contract.interactions)) {
        foreach ($testId in @($interaction.integrationTestIds)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$testId)) {
                $contractIds += [string]$testId
            }
        }
    }
    foreach ($scenario in @($contract.scenarios)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$scenario.scenarioId)) {
            $contractIds += [string]$scenario.scenarioId
        }
    }
    $contractIds = @($contractIds | Sort-Object -Unique)
}
catch {
    $findings += @{
        type = "contract_missing_or_invalid"
        severity = "critical"
        details = "Unable to parse INTERACTION_MATRIX_CONTRACT.json."
    }
}

try {
    if (Test-Path $coverageScriptPath) {
        $coverage = & $coverageScriptPath -RepoRoot $RepoRoot | ConvertFrom-Json
        foreach ($entry in @($coverage.functional)) {
            if ($null -ne $entry -and -not [string]::IsNullOrWhiteSpace([string]$entry.id)) {
                $coverageBackedIds += [string]$entry.id
            }
        }
        foreach ($entry in @($coverage.stub)) {
            if ($null -ne $entry -and -not [string]::IsNullOrWhiteSpace([string]$entry.id)) {
                $coverageBackedIds += [string]$entry.id
            }
        }
        $coverageBackedIds = @($coverageBackedIds | Sort-Object -Unique)
    }
}
catch {
    $findings += @{
        type = "contract_coverage_probe_failed"
        severity = "warning"
        details = "Unable to load check-test-contract-coverage output."
    }
}

$taskIds = @()
try {
    $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
    $taskIds = @($tasks | ForEach-Object { [string]$_.id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}
catch {
    $findings += @{
        type = "tasks_missing_or_invalid"
        severity = "critical"
        details = "Unable to parse backlog/tasks.json."
    }
}

if (@($contractIds).Count -gt 0 -and @($taskIds).Count -gt 0) {
    foreach ($id in $contractIds) {
        if (@($coverageBackedIds | Where-Object { $_ -eq $id }).Count -gt 0) {
            continue
        }
        $idPrefix = ("TASK-" + $id.ToUpperInvariant())
        $matching = @($taskIds | Where-Object { $_ -eq $idPrefix -or $_ -like ("*" + $id.ToUpperInvariant() + "*") })
        if (@($matching).Count -eq 0) {
            $findings += @{
                type = "missing_backlog_link"
                severity = "warning"
                contractId = $id
                expectedTaskHint = $idPrefix
                details = "No backlog task appears linked to this contract id."
            }
        }
    }
}

$findings = @($findings | Select-Object -First $MaxFindings)

$report = @{
    bot = "autonomous-drift-report-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = (@($findings).Count -eq 0)
    checks = @(
        @{
            check = "contract_backlog_drift"
            passed = (@($findings | Where-Object { $_.severity -eq "critical" }).Count -eq 0)
            findingCount = @($findings).Count
            details = "Findings indicate requirement/contract/backlog drift risk."
        }
    )
    findings = $findings
    contractIdCount = @($contractIds).Count
    taskIdCount = @($taskIds).Count
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8
Write-Host "[autonomous-drift-report-bot] Report: $reportPath"
exit 0
