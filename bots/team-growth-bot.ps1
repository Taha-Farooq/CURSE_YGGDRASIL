param(
    [string]$RepoRoot = "",
    [int]$MaxNewRolesPerRun = 3
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[team-growth-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$botDir = Join-Path $RepoRoot "reports\bots"
$teamDir = Join-Path $RepoRoot "team"
$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
$rolesPath = Join-Path $teamDir "roles.json"
if (-not (Test-Path $botDir)) { New-Item -ItemType Directory -Path $botDir -Force | Out-Null }
if (-not (Test-Path $teamDir)) { New-Item -ItemType Directory -Path $teamDir -Force | Out-Null }
$output = Join-Path $botDir "team-growth-bot-$timestamp.json"

$roles = @()
if (Test-Path $rolesPath) {
    $roles = Get-Content $rolesPath -Raw | ConvertFrom-Json
}

$tasks = @()
if (Test-Path $tasksPath) {
    $tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
}

$todoCount = @($tasks | Where-Object { $_.status -eq "todo" }).Count
$baseRoles = @(
    @{ id = "role-systems-architect"; focus = "core simulation and contracts"; status = "active" },
    @{ id = "role-runtime-engineer"; focus = "runtime and validators"; status = "active" },
    @{ id = "role-qa-automation"; focus = "bot coverage and test quality"; status = "active" },
    @{ id = "role-world-sim-engineer"; focus = "economy, AI society, logistics"; status = "active" },
    @{ id = "role-tools-engineer"; focus = "live pipeline and content tooling"; status = "active" }
)

$existingMap = @{}
foreach ($r in $roles) { $existingMap[$r.id] = $r }

$newRoles = @()
if ($todoCount -gt 10) {
    foreach ($candidate in $baseRoles) {
        if ($newRoles.Count -ge $MaxNewRolesPerRun) { break }
        if (-not $existingMap.ContainsKey($candidate.id)) {
            $newRoles += $candidate
            $existingMap[$candidate.id] = $candidate
        }
    }
}

$finalRoles = $existingMap.Values | Sort-Object id
$finalRoles | ConvertTo-Json -Depth 6 | Set-Content -Path $rolesPath -Encoding UTF8

$result = @{
    bot = "team-growth-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    todoCount = $todoCount
    newRolesAdded = $newRoles.Count
    rolesPath = $rolesPath
}

$result | ConvertTo-Json -Depth 6 | Set-Content -Path $output -Encoding UTF8
Write-Host "[team-growth-bot] Report: $output"
exit 0

