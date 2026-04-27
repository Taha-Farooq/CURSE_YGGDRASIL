param(
    [string]$RepoRoot = "",
    [int]$MaxCandidates = 10
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

Write-Host "[nice-to-have-investigator-bot] Starting..."
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportsDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
$reportPath = Join-Path $reportsDir "nice-to-have-investigator-bot-$timestamp.json"

$tasksPath = Join-Path $RepoRoot "backlog\tasks.json"
$requirementsPath = Join-Path $RepoRoot "REQUIREMENTS.md"
$tasks = @()
$requirements = ""

if (Test-Path $tasksPath) {
    try { $tasks = @(Get-Content $tasksPath -Raw | ConvertFrom-Json) } catch { $tasks = @() }
}
if (Test-Path $requirementsPath) {
    try { $requirements = Get-Content $requirementsPath -Raw } catch { $requirements = "" }
}

$existingTitles = @($tasks | ForEach-Object { ([string]$_.title).ToLowerInvariant() })

function New-Candidate(
    [string]$id,
    [string]$title,
    [string]$description,
    [string]$category,
    [int]$impact,
    [int]$effort,
    [int]$risk
) {
    $alignmentBonus = 0
    $d = $description.ToLowerInvariant()
    if ($d -match "deterministic|authority|replay") { $alignmentBonus += 2 }
    if ($d -match "real-time|economy|social|validation") { $alignmentBonus += 1 }
    $score = (($impact * 2) - $effort - $risk + $alignmentBonus)
    return @{
        id = $id
        title = $title
        description = $description
        category = $category
        impact = $impact
        effort = $effort
        risk = $risk
        alignmentBonus = $alignmentBonus
        desirabilityScore = $score
    }
}

$candidatePool = @(
    (New-Candidate "NTH-001" "Regional Economy Stress Replay Pack" "Add deterministic replay scenarios for tax/logistics/shock combinations to validate economy and authority outputs." "economy" 5 2 1)
    (New-Candidate "NTH-002" "Spell Input Ergonomics Heatmap" "Record failed and partial real-time spell sequences, then emit heatmaps for sequence ergonomics tuning." "combat-ux" 4 2 2)
    (New-Candidate "NTH-003" "Summon Control Auto-Advisor" "Recommend precompute toolchains and controller composition for high-complexity summon control plans." "summoning" 4 2 1)
    (New-Candidate "NTH-004" "Boss Enhancement Telemetry Dashboard Card" "Expose enhancement mix versus reward scaling curves for boss and area-boss balancing." "dashboard" 4 1 1)
    (New-Candidate "NTH-005" "Legendary FX Budget Guard" "Add a strict validator for high-tier VFX readability and performance budget envelopes." "presentation" 5 3 2)
    (New-Candidate "NTH-006" "Social Bias Scenario Fuzzer" "Generate deterministic social bias edge-case scenarios across alliances, vendettas, and political shifts." "ai-social" 5 2 1)
    (New-Candidate "NTH-007" "Equipment Lifecycle Audit Trail" "Track craft, wear, repair, and enchantment timeline per item for economy/combat investigations." "equipment" 4 2 1)
    (New-Candidate "NTH-008" "High-Tier Cast Readiness Overlay" "Add runtime precompiled-aid readiness checks and reason-code explanations for T9+ casting." "magic" 4 1 1)
    (New-Candidate "NTH-009" "Autonomous Regression Spotlight" "Rank recurring warnings from bot reports and suggest targeted validation slices before regressions grow." "automation" 5 1 1)
    (New-Candidate "NTH-010" "Faction Conflict Forecast Snapshot" "Project short-horizon diplomacy/conflict likelihood from social bias and logistics stress signals." "simulation" 4 3 2)
    (New-Candidate "NTH-011" "Condition-Driven Crafting Recommendations" "Suggest repair versus recraft decisions from item condition, market pressure, and combat utility." "economy" 3 2 1)
    (New-Candidate "NTH-012" "Authority Reason-Code Explorer" "Search and group reason-code frequencies by subsystem to accelerate balancing and QA loops." "tooling" 4 1 1)
)

$filtered = @()
foreach ($candidate in $candidatePool) {
    $titleLower = ([string]$candidate.title).ToLowerInvariant()
    $isDuplicate = $false
    foreach ($existingTitle in $existingTitles) {
        if ($existingTitle -like ("*" + ($titleLower.Split(" ")[0]) + "*") -and $existingTitle -like ("*" + ($titleLower.Split(" ")[1]) + "*")) {
            $isDuplicate = $true
            break
        }
    }
    if (-not $isDuplicate) { $filtered += $candidate }
}

$selected = @(
    $filtered |
    Sort-Object -Property @{ Expression = { [int]$_.desirabilityScore }; Descending = $true }, @{ Expression = { [int]$_.impact }; Descending = $true } |
    Select-Object -First $MaxCandidates
)

$result = @{
    bot = "nice-to-have-investigator-bot"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $true
    candidateCount = @($selected).Count
    candidates = $selected
    note = "Investigative output only. Requires review before backlog admission."
}

$result | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding UTF8
Write-Host "[nice-to-have-investigator-bot] Report: $reportPath"
exit 0
