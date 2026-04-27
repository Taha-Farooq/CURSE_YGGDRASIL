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
$mindDungeonClears = [int]$player.mindDungeonClears
$deathlessRuns = [int]$player.deathlessRuns
$stabilityScore = [double]$player.stabilityScore
$shadowEchoWins = [int]$player.shadowEchoWins

$profile = "stable"
$challenge = 1.0

if ($level -ge 2500 -or $shadowEchoWins -ge 5) {
    $profile = "echo_hunter"
    $challenge = 2.25
} elseif ($mindDungeonClears -ge 10 -and $deathlessRuns -ge 3) {
    $profile = "adaptive_predator"
    $challenge = 1.75
} elseif ($stabilityScore -lt 0.5) {
    $profile = "volatile"
    $challenge = 1.4
}

$encounterTags = @("mind_dungeon", "adaptive")
if ($profile -eq "echo_hunter") { $encounterTags += "shadow_echo" }
if ($profile -eq "volatile") { $encounterTags += "instability_pressure" }
if ($profile -eq "adaptive_predator") { $encounterTags += "counterplay_shift" }

$result = @{
    selector = "adaptive_encounter_profile_selector_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    playerId = [string]$player.playerId
    selectedProfile = $profile
    challengeMultiplier = $challenge
    encounterTags = $encounterTags
    driverSnapshot = @{
        level = $level
        mindDungeonClears = $mindDungeonClears
        deathlessRuns = $deathlessRuns
        stabilityScore = $stabilityScore
        shadowEchoWins = $shadowEchoWins
    }
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
