param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-affinity-level-dominates.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing summon affinity input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json

$triangle = @{
    vanguard = "skirmisher"
    skirmisher = "arcanist"
    arcanist = "vanguard"
}

$raceNodeMap = @{
    human = "vanguard"
    dwarf = "vanguard"
    beast = "skirmisher"
    beastkin = "skirmisher"
    spirit = "arcanist"
    demon = "arcanist"
}

$classNodeMap = @{
    knight = "vanguard"
    guardian = "vanguard"
    rogue = "skirmisher"
    ranger = "skirmisher"
    mage = "arcanist"
    warlock = "arcanist"
}

function Resolve-TriangleNode([string]$race, [string]$className) {
    $normalizedRace = if ([string]::IsNullOrWhiteSpace($race)) { "human" } else { $race.ToLowerInvariant() }
    $normalizedClass = if ([string]::IsNullOrWhiteSpace($className)) { "knight" } else { $className.ToLowerInvariant() }

    $raceNode = if ($raceNodeMap.ContainsKey($normalizedRace)) { [string]$raceNodeMap[$normalizedRace] } else { "vanguard" }
    $classNode = if ($classNodeMap.ContainsKey($normalizedClass)) { [string]$classNodeMap[$normalizedClass] } else { "vanguard" }

    if ($raceNode -eq $classNode) { return $raceNode }
    return $raceNode
}

function Get-AffinityRelation([string]$attackerNode, [string]$defenderNode) {
    if ($attackerNode -eq $defenderNode) { return "neutral" }
    if ([string]$triangle[$attackerNode] -eq $defenderNode) { return "advantage" }
    return "disadvantage"
}

function Get-AffinityMultiplier([string]$relation) {
    switch ($relation) {
        "advantage" { return 1.12 }
        "disadvantage" { return 0.88 }
        default { return 1.0 }
    }
}

function Get-LevelMultiplier([int]$attackerLevel, [int]$defenderLevel) {
    $levelDelta = $attackerLevel - $defenderLevel
    $scaled = 1.0 + ($levelDelta * 0.04)
    if ($scaled -lt 0.4) { return 0.4 }
    if ($scaled -gt 2.6) { return 2.6 }
    return [math]::Round($scaled, 4)
}

$attacker = $input.attacker
$defender = $input.defender
$attackerLevel = [int]$attacker.level
$defenderLevel = [int]$defender.level

$attackerNode = Resolve-TriangleNode -race ([string]$attacker.race) -className ([string]$attacker.class)
$defenderNode = Resolve-TriangleNode -race ([string]$defender.race) -className ([string]$defender.class)
$relation = Get-AffinityRelation -attackerNode $attackerNode -defenderNode $defenderNode
$affinityMultiplier = Get-AffinityMultiplier -relation $relation
$levelMultiplier = Get-LevelMultiplier -attackerLevel $attackerLevel -defenderLevel $defenderLevel

$combinedMultiplier = [math]::Round(($levelMultiplier * $affinityMultiplier), 4)
$dominantDriver = if ([math]::Abs($levelMultiplier - 1.0) -ge [math]::Abs($affinityMultiplier - 1.0)) { "level" } else { "affinity" }

$result = @{
    resolver = "summon_affinity_triangle_resolver_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    attacker = @{
        entityId = [string]$attacker.entityId
        race = [string]$attacker.race
        class = [string]$attacker.class
        level = $attackerLevel
        triangleNode = $attackerNode
    }
    defender = @{
        entityId = [string]$defender.entityId
        race = [string]$defender.race
        class = [string]$defender.class
        level = $defenderLevel
        triangleNode = $defenderNode
    }
    relation = $relation
    multipliers = @{
        level = $levelMultiplier
        affinity = $affinityMultiplier
        combined = $combinedMultiplier
    }
    dominantDriver = $dominantDriver
    reasonCodes = @("AUTH-SUMMON-AFFINITY-TRIANGLE-EVALUATED")
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
