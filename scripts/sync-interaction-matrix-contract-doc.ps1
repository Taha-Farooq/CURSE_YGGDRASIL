param(
    [string]$RepoRoot = "",
    [switch]$Check
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$jsonPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT.json"
$mdPath = Join-Path $RepoRoot "systems\integration\INTERACTION_MATRIX_CONTRACT_SUMMARY.md"

if (-not (Test-Path $jsonPath)) {
    throw "Missing interaction matrix contract JSON: $jsonPath"
}

$contract = Get-Content $jsonPath -Raw | ConvertFrom-Json

$interactionLines = @()
foreach ($i in @($contract.interactions)) {
    $tests = (@($i.integrationTestIds) -join ", ")
    $interactionLines += "| ``$($i.interactionId)`` | $($i.sourceSubsystem) | $($i.targetSubsystem) | $tests | $($i.owner) |"
}

$scenarioLines = @()
foreach ($s in @($contract.scenarios)) {
    $ints = (@($s.interactionIds) -join ", ")
    $tests = (@($s.testIds) -join ", ")
    $scenarioLines += "| ``$($s.scenarioId)`` | $ints | $tests | $($s.status) |"
}

$content = @(
    "# Interaction Matrix Contract Summary v$($contract.version)",
    "",
    "<!-- AUTO-GENERATED: Run scripts/sync-interaction-matrix-contract-doc.ps1 -->",
    "",
    "Machine-readable source of truth: ``systems/integration/INTERACTION_MATRIX_CONTRACT.json``.",
    "",
    "## Contract Overview",
    "",
    "- Interactions: $(@($contract.interactions).Count)",
    "- Scenarios: $(@($contract.scenarios).Count)",
    "- Required interaction IDs: $(@($contract.requiredInteractionIds) -join ", " )",
    "- Required scenario IDs: $(@($contract.requiredScenarioIds) -join ", " )",
    "",
    "## Interactions",
    "",
    "| interaction_id | source_subsystem | target_subsystem | integration_test_ids | owner |",
    "|---|---|---|---|---|"
) + $interactionLines + @(
    "",
    "## Scenarios",
    "",
    "| scenario_id | interaction_ids | test_ids | status |",
    "|---|---|---|---|"
) + $scenarioLines + @(
    "",
    "Last generated from JSON contract version ``$($contract.version)`` at ``$($contract.updatedUtc)``."
)

$generated = ($content -join [Environment]::NewLine) + [Environment]::NewLine
$existing = ""
if (Test-Path $mdPath) {
    $existing = Get-Content $mdPath -Raw
}

function Normalize-ForCompare {
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $normalized = $Text -replace "^\uFEFF", ""
    $normalized = $normalized -replace "`r`n", "`n"
    return $normalized.TrimEnd("`n")
}

if ($Check) {
    if ((Normalize-ForCompare $existing) -ne (Normalize-ForCompare $generated)) {
        Write-Error "INTERACTION_MATRIX_CONTRACT_SUMMARY.md is out of sync with INTERACTION_MATRIX_CONTRACT.json"
        exit 1
    }
    Write-Host "[sync-interaction-matrix-contract-doc] In sync."
    exit 0
}

Set-Content -Path $mdPath -Value $generated -Encoding UTF8
Write-Host "[sync-interaction-matrix-contract-doc] Wrote $mdPath"
exit 0
