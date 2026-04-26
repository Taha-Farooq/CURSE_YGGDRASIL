param(
    [string]$RepoRoot = "",
    [switch]$Check
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$jsonPath = Join-Path $RepoRoot "systems\networking\AUTHORITY_REASON_CODES.json"
$mdPath = Join-Path $RepoRoot "systems\networking\AUTHORITY_REASON_CODES.md"

if (-not (Test-Path $jsonPath)) {
    throw "Missing reason code contract JSON: $jsonPath"
}

$contract = Get-Content $jsonPath -Raw | ConvertFrom-Json
$codeRows = @()
foreach ($entry in $contract.codes) {
    $codeRows += "| ``$($entry.code)`` | $($entry.domain) | $($entry.meaning) |"
}

$mappingRows = @()
$mappingNames = @($contract.interopCodeMapping.PSObject.Properties | Select-Object -ExpandProperty Name | Sort-Object)
foreach ($fromCode in $mappingNames) {
    $toCode = $contract.interopCodeMapping.$fromCode
    $mappingRows += "- ``$fromCode`` -> ``$toCode``"
}

$content = @(
    "# Authority Reason Codes v$($contract.version)",
    "",
    "<!-- AUTO-GENERATED: Run scripts/sync-authority-reason-codes-doc.ps1 -->",
    "",
    "This document defines canonical reason codes returned by ``engine/net/authority-validation``.",
    "Machine-readable source of truth: ``systems/networking/AUTHORITY_REASON_CODES.json``.",
    "",
    "## Purpose",
    "",
    "- Ensure every rejected action has a deterministic machine-readable reason.",
    "- Keep replay, telemetry, and moderation tooling aligned to one reason-code taxonomy.",
    "",
    "## Format",
    "",
    "- Prefix: ``AUTH-``",
    "- Structure: ``AUTH-<domain>-<number>``",
    "- Example: ``AUTH-SCOPE-001``",
    "",
    "## Codes",
    "",
    "| code | domain | meaning |",
    "|---|---|---|"
) + $codeRows + @(
    "",
    "## Mapping to Interop Validator",
    "",
    "The authority service maps ``INT-LEG-*`` legality failures to canonical ``AUTH-*`` codes via the JSON contract:",
    ""
) + $mappingRows + @(
    "",
    "Fallback code for unmapped reasons: ``$($contract.fallbackCode)``",
    "",
    "## Contract Rules",
    "",
    "- Every rejection MUST include at least one reason code.",
    "- Reason codes MUST be stable across versions unless explicitly deprecated.",
    "- Replay capture MUST persist reason codes even when user replay UI is disabled.",
    "- Telemetry event ``authority.validation.rejected`` MUST include:",
    "  - action ID",
    "  - actor ID",
    "  - reason codes[]",
    "  - validator version",
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
        Write-Error "AUTHORITY_REASON_CODES.md is out of sync with AUTHORITY_REASON_CODES.json"
        exit 1
    }
    Write-Host "[sync-authority-reason-codes-doc] In sync."
    exit 0
}

Set-Content -Path $mdPath -Value $generated -Encoding UTF8
Write-Host "[sync-authority-reason-codes-doc] Wrote $mdPath"
exit 0
