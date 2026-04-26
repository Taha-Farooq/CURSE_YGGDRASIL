param(
    [string]$RepoRoot = "",
    [int]$MaxTasksPerRun = 25
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[task-planner-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
$backlogDir = Join-Path $RepoRoot "backlog"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
if (-not (Test-Path $backlogDir)) { New-Item -ItemType Directory -Path $backlogDir -Force | Out-Null }
$output = Join-Path $botDir "task-planner-bot-$timestamp.json"
$tasksPath = Join-Path $backlogDir "tasks.json"

$requirementsPath = Join-Path $RepoRoot "REQUIREMENTS.md"
if (-not (Test-Path $requirementsPath)) {
    throw "Missing REQUIREMENTS.md"
}

$requirements = Get-Content $requirementsPath -Raw
$matches = [regex]::Matches($requirements, "##\s+\d+(\.\d+)?\)\s+([^\r\n]+)")

$newTasks = @()
$count = 0
foreach ($m in $matches) {
    if ($count -ge $MaxTasksPerRun) { break }
    $title = $m.Groups[2].Value.Trim()
    $id = "TASK-" + ($title.ToUpper() -replace "[^A-Z0-9]+","-" ).Trim("-")
    $newTasks += @{
        id = $id
        title = $title
        source = "REQUIREMENTS.md"
        status = "todo"
        priority = "high"
        type = "system"
    }
    $count++
}

# Add goal-specific seed tasks for current direction if relevant text exists.
$goalSeeds = @(
    @{ title = "Demon Lord Authority System"; id = "TASK-DEMON-LORD-AUTHORITY-SYSTEM" },
    @{ title = "Legendary and God-Killer Entity Framework"; id = "TASK-LEGENDARY-AND-GOD-KILLER-ENTITY-FRAMEWORK" },
    @{ title = "Interdimensional Demon Domain Runtime"; id = "TASK-INTERDIMENSIONAL-DEMON-DOMAIN-RUNTIME" },
    @{ title = "Advanced NPC Creator and Cross-Class Forge"; id = "TASK-ADVANCED-NPC-CREATOR-AND-CROSS-CLASS-FORGE" }
)
foreach ($g in $goalSeeds) {
    if ($newTasks.Count -ge $MaxTasksPerRun) { break }
    $newTasks += @{
        id = $g.id
        title = $g.title
        source = "goal-seed"
        status = "todo"
        priority = "high"
        type = "system"
    }
}

$existing = @()
if (Test-Path $tasksPath) {
    try {
        $existing = Get-Content $tasksPath -Raw | ConvertFrom-Json
    } catch {
        $existing = @()
    }
}

$merged = @{}
foreach ($t in $existing) { $merged[$t.id] = $t }
foreach ($t in $newTasks) {
    if (-not $merged.ContainsKey($t.id)) {
        $merged[$t.id] = $t
    }
}

$finalTasks = $merged.Values | Sort-Object id
$finalTasks | ConvertTo-Json -Depth 8 | Set-Content -Path $tasksPath -Encoding UTF8

$result = @{
    bot = "task-planner-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    tasksGenerated = $newTasks.Count
    totalTasks = $finalTasks.Count
    tasksPath = $tasksPath
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[task-planner-bot] Report: $output"
exit 0

