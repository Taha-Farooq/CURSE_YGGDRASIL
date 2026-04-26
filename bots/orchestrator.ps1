param(
    [string]$RepoRoot = "",
    [string]$ConfigPath = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $RepoRoot "automation\automation-config.json"
}

Write-Host "[bot-orchestrator] Starting..."
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportDir = Join-Path $RepoRoot $config.paths.botReportsDir
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$runReportPath = Join-Path $reportDir "orchestrator-run-$timestamp.json"

$run = @{
    orchestrator = "bot-orchestrator"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    steps = @()
}

function RunStep($name, $scriptPath, $splat) {
    Write-Host "[bot-orchestrator] Running $name ..."
    try {
        & $scriptPath @splat
        if ($LASTEXITCODE -ne 0) { throw "$name failed with code $LASTEXITCODE" }
        return @{ name = $name; status = "pass" }
    }
    catch {
        return @{ name = $name; status = "fail"; details = $_.Exception.Message }
    }
}

if ($config.bots.validationBot.enabled) {
    $step = RunStep "validation-bot" (Join-Path $RepoRoot "bots\validation-bot.ps1") @{ RepoRoot = $RepoRoot; Strict = $Strict }
    $run.steps += $step
}

if ($config.bots.worldExplorerBot.enabled) {
    $step = RunStep "world-explorer-bot" (Join-Path $RepoRoot "bots\world-explorer-bot.ps1") @{ RepoRoot = $RepoRoot }
    $run.steps += $step
}

if ($config.bots.routeClearabilityBot.enabled) {
    $step = RunStep "route-clearability-bot" (Join-Path $RepoRoot "bots\route-clearability-bot.ps1") @{ RepoRoot = $RepoRoot; MinScore = $config.bots.routeClearabilityBot.minClearabilityScore }
    $run.steps += $step
}

if ($config.bots.engineTestBot.enabled) {
    $step = RunStep "engine-test-bot" (Join-Path $RepoRoot "bots\engine-test-bot.ps1") @{
        RepoRoot = $RepoRoot
        TestCommand = $config.bots.engineTestBot.testCommand
        AllowPlaceholderPassWhenNoEngine = $config.bots.engineTestBot.allowPlaceholderPassWhenNoEngine
    }
    $run.steps += $step
}

if ($config.bots.architectureExtendabilityBot.enabled) {
    $step = RunStep "architecture-extendability-bot" (Join-Path $RepoRoot "bots\architecture-extendability-bot.ps1") @{
        RepoRoot = $RepoRoot
        RequiredKeywords = $config.bots.architectureExtendabilityBot.requiredKeywords
    }
    $run.steps += $step
}

if ($config.bots.errorCheckerBot.enabled) {
    $step = RunStep "error-checker-bot" (Join-Path $RepoRoot "bots\error-checker-bot.ps1") @{
        RepoRoot = $RepoRoot
        MaxAllowedCriticalFindings = $config.bots.errorCheckerBot.maxAllowedCriticalFindings
    }
    $run.steps += $step
}

if ($config.bots.bugFixerBot.enabled) {
    $step = RunStep "bug-fixer-bot" (Join-Path $RepoRoot "bots\bug-fixer-bot.ps1") @{
        RepoRoot = $RepoRoot
        Mode = $config.bots.bugFixerBot.mode
        MaxSuggestionsPerRun = $config.bots.bugFixerBot.maxSuggestionsPerRun
    }
    $run.steps += $step
}

if ($config.bots.featureSuggesterBot.enabled) {
    $step = RunStep "feature-suggester-bot" (Join-Path $RepoRoot "bots\feature-suggester-bot.ps1") @{
        RepoRoot = $RepoRoot
        MaxSuggestionsPerRun = $config.bots.featureSuggesterBot.maxSuggestionsPerRun
    }
    $run.steps += $step
}

if ($config.bots.taskPlannerBot.enabled) {
    $step = RunStep "task-planner-bot" (Join-Path $RepoRoot "bots\task-planner-bot.ps1") @{
        RepoRoot = $RepoRoot
        MaxTasksPerRun = $config.bots.taskPlannerBot.maxTasksPerRun
    }
    $run.steps += $step
}

if ($config.bots.systemBuilderBot.enabled) {
    $step = RunStep "system-builder-bot" (Join-Path $RepoRoot "bots\system-builder-bot.ps1") @{
        RepoRoot = $RepoRoot
        AutoScaffold = $config.bots.systemBuilderBot.autoScaffold
    }
    $run.steps += $step
}

if ($config.bots.implementationBot.enabled) {
    $step = RunStep "implementation-bot" (Join-Path $RepoRoot "bots\implementation-bot.ps1") @{
        RepoRoot = $RepoRoot
        Mode = $config.bots.implementationBot.mode
        MaxFileChangesPerRun = $config.bots.implementationBot.maxFileChangesPerRun
    }
    $run.steps += $step
}

if ($config.bots.teamGrowthBot.enabled) {
    $step = RunStep "team-growth-bot" (Join-Path $RepoRoot "bots\team-growth-bot.ps1") @{
        RepoRoot = $RepoRoot
        MaxNewRolesPerRun = $config.bots.teamGrowthBot.maxNewRolesPerRun
    }
    $run.steps += $step
}

if ($config.bots.testResearchBot.enabled) {
    $step = RunStep "test-research-bot" (Join-Path $RepoRoot "bots\test-research-bot.ps1") @{
        RepoRoot = $RepoRoot
        MaxRecommendationsPerRun = $config.bots.testResearchBot.maxRecommendationsPerRun
    }
    $run.steps += $step
}

if ($config.bots.goalAlignmentBot.enabled) {
    $step = RunStep "goal-alignment-bot" (Join-Path $RepoRoot "bots\goal-alignment-bot.ps1") @{
        RepoRoot = $RepoRoot
        GoalPath = (Join-Path $RepoRoot $config.bots.goalAlignmentBot.goalPath)
    }
    $run.steps += $step
}

if ($config.bots.botMakerBot.enabled) {
    $step = RunStep "bot-maker-bot" (Join-Path $RepoRoot "bots\bot-maker-bot.ps1") @{
        RepoRoot = $RepoRoot
        MaxBotsToCreatePerRun = $config.bots.botMakerBot.maxBotsToCreatePerRun
        OnlyCreateIfMissing = $config.bots.botMakerBot.onlyCreateIfMissing
    }
    $run.steps += $step
}

if ($config.bots.generatedTestBots.enabled) {
    $generatedDir = Join-Path $RepoRoot "bots\generated"
    if (Test-Path $generatedDir) {
        $generatedBots = Get-ChildItem -Path $generatedDir -Filter "*.ps1" | Sort-Object Name | Select-Object -First $config.bots.generatedTestBots.maxBotsPerRun
        foreach ($botFile in $generatedBots) {
            $step = RunStep ("generated-" + $botFile.BaseName) $botFile.FullName @{
                RepoRoot = $RepoRoot
            }
            $run.steps += $step
        }
    } else {
        $run.steps += @{ name = "generated-test-bots"; status = "pass"; details = "No generated bots directory yet" }
    }
}

foreach ($s in $run.steps) {
    if ($s.status -ne "pass") { $run.passed = $false }
}

$run | ConvertTo-Json -Depth 6 | Set-Content -Path $runReportPath -Encoding UTF8
Write-Host "[bot-orchestrator] Report: $runReportPath"
if (-not $run.passed) { exit 1 }
exit 0

