param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reqPath = Join-Path $RepoRoot "REQUIREMENTS.md"
if (-not (Test-Path $reqPath)) { throw "Missing REQUIREMENTS.md" }
$req = Get-Content $reqPath -Raw

$checks = @()
function Add-Check([string]$name, [bool]$passed, [string]$details) {
    $script:checks += @{ check = $name; passed = $passed; details = $details }
}

# Cohesion unified structure.
$hasCohesionHeading = ($req -match [regex]::Escape("## 26) Cohesion Requirement: One Unified Structure"))
$hasUnifiedInteropRule = ($req -match [regex]::Escape("- All major systems must interoperate through shared core models, not isolated minigames."))
$hasUnifiedContractRule = ($req -match [regex]::Escape("- Combat, crafting, building, logistics, diplomacy, AI society, and progression must exchange state through a unified simulation contract."))
$hasCanonicalLedgerRule = ($req -match [regex]::Escape("- A single canonical world state ledger is required for:"))
$hasNoBypassRule = ($req -match [regex]::Escape("- No feature may ship as standalone if it bypasses authority, progression, economy, or consequence models."))

# Cross-system coupling.
$hasCouplingHeading = ($req -match [regex]::Escape("### 26.1) Cross-System Coupling Rules"))
$hasCombatCouplingRule = ($req -match [regex]::Escape("- Combat outcomes must influence economy and politics where relevant."))
$hasLogisticsCouplingRule = ($req -match [regex]::Escape("- Logistics disruptions must affect military readiness and city output."))
$hasGovernanceMagicCouplingRule = ($req -match [regex]::Escape("- Social policy and governance choices must influence magic stability and progression gates where defined."))

# Cohesion acceptance criteria.
$hasCohesionAcceptanceHeading = ($req -match [regex]::Escape("### 26.3) Cohesion Acceptance Criteria"))
$hasPropagationRule = ($req -match [regex]::Escape("- End-to-end scenario tests must demonstrate that a change in one pillar propagates correctly to others."))
$hasIntegrationBlockRule = ($req -match [regex]::Escape("- Feature additions failing integration contracts are blocked until unified behavior is restored."))

# Governance and transparency in feedback loop.
$hasGovernanceHeading = ($req -match [regex]::Escape("### 28.5) Governance and Transparency"))
$hasChangelogRule = ($req -match [regex]::Escape("- Maintain a public/internal changelog linking major fixes to feedback themes."))
$hasKnownIssuesRule = ($req -match [regex]::Escape('- Keep a "Known Issues / Intentional Friction" board to separate bugs from deliberate design.'))
$hasReviewRitualsRule = ($req -match [regex]::Escape("- Add periodic review rituals (e.g., weekly triage, milestone retrospectives) with explicit accept/reject rationale for major feedback clusters."))

Add-Check "cohesion_requirement_heading_defined" $hasCohesionHeading "requirements define cohesion unified structure section"
Add-Check "cohesion_requirement_core_rules_defined" ($hasUnifiedInteropRule -and $hasUnifiedContractRule -and $hasCanonicalLedgerRule -and $hasNoBypassRule) "requirements define unified interop, contract, ledger, and no-bypass rules"

Add-Check "cross_system_coupling_heading_defined" $hasCouplingHeading "requirements define cross-system coupling rules section"
Add-Check "cross_system_coupling_core_rules_defined" ($hasCombatCouplingRule -and $hasLogisticsCouplingRule -and $hasGovernanceMagicCouplingRule) "requirements define economy/politics/logistics/magic coupling behavior"

Add-Check "cohesion_acceptance_heading_defined" $hasCohesionAcceptanceHeading "requirements define cohesion acceptance criteria section"
Add-Check "cohesion_acceptance_rules_defined" ($hasPropagationRule -and $hasIntegrationBlockRule) "requirements define propagation and integration-block acceptance rules"

Add-Check "governance_transparency_heading_defined" $hasGovernanceHeading "requirements define governance and transparency section"
Add-Check "governance_transparency_rules_defined" ($hasChangelogRule -and $hasKnownIssuesRule -and $hasReviewRitualsRule) "requirements define changelog, known-issues board, and review rituals"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "cohesion_governance_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
