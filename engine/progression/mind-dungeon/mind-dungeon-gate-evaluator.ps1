param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-mind-dungeon-player-eligible.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing player progression input: $InputJsonPath" }

$player = Get-Content $InputJsonPath -Raw | ConvertFrom-Json

$level = [int]$player.level
$milestones = @($player.milestonesCompleted | ForEach-Object { [string]$_ })
$requiredLevel = 1000
$requiredMilestones = @("mind_dungeon_attunement", "shadow_echo_unlock")

$missingMilestones = @($requiredMilestones | Where-Object { $milestones -notcontains $_ })
$hasRequiredLevel = ($level -ge $requiredLevel)
$hasMilestones = (@($missingMilestones).Count -eq 0)
$allowed = ($hasRequiredLevel -and $hasMilestones)

$result = @{
    evaluator = "mind_dungeon_gate_runtime_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    playerId = [string]$player.playerId
    allowed = $allowed
    gate = @{
        requiredLevel = $requiredLevel
        requiredMilestones = $requiredMilestones
    }
    playerState = @{
        level = $level
        milestonesCompleted = $milestones
    }
    rejectionReasons = @(
        $(if (-not $hasRequiredLevel) { "MIND-DUNGEON-LEVEL-REQUIRED" }),
        $(if (-not $hasMilestones) { "MIND-DUNGEON-MILESTONE-REQUIRED" })
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $allowed) { exit 1 }
exit 0
