param(
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
Write-Host "[quality-gate] Starting..."
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Fail($msg) {
    Write-Error $msg
    exit 1
}

function Invoke-ResilientCheck {
    param(
        [scriptblock]$PrimaryCheck,
        [scriptblock]$Remediation,
        [scriptblock]$SecondaryCheck,
        [string]$FailureMessage,
        [string]$RecoveryMessage
    )

    try {
        & $PrimaryCheck
        return
    }
    catch {
        try {
            & $Remediation
            & $SecondaryCheck
            if (-not [string]::IsNullOrWhiteSpace($RecoveryMessage)) {
                Write-Host $RecoveryMessage
            }
        }
        catch {
            Fail ($FailureMessage + " Details: " + $_.Exception.Message)
        }
    }
}

if (-not (Test-Path (Join-Path $repoRoot "FEEDBACK_SCHEMA.json"))) {
    Fail "Missing FEEDBACK_SCHEMA.json"
}

if (-not (Test-Path (Join-Path $repoRoot "INTERACTION_MATRIX.md"))) {
    Fail "Missing INTERACTION_MATRIX.md"
}

if (-not (Test-Path (Join-Path $repoRoot "REQUIREMENTS.md"))) {
    Fail "Missing REQUIREMENTS.md"
}

if (-not (Test-Path (Join-Path $repoRoot "MAGITECH_INTEROP_SPEC.md"))) {
    Fail "Missing MAGITECH_INTEROP_SPEC.md"
}

if (-not (Test-Path (Join-Path $repoRoot "systems\networking\AUTHORITY_REASON_CODES.json"))) {
    Fail "Missing systems/networking/AUTHORITY_REASON_CODES.json"
}

# Basic JSON parse check
try {
    Get-Content (Join-Path $repoRoot "FEEDBACK_SCHEMA.json") -Raw | ConvertFrom-Json | Out-Null
    Write-Host "[quality-gate] FEEDBACK_SCHEMA.json is valid JSON."
}
catch {
    Fail "Invalid FEEDBACK_SCHEMA.json JSON."
}

# Authority reason-code contract parse and minimum validation
try {
    $reasonContract = Get-Content (Join-Path $repoRoot "systems\networking\AUTHORITY_REASON_CODES.json") -Raw | ConvertFrom-Json
    $requiredAuthCodes = @(
        "AUTH-INPUT-001",
        "AUTH-INPUT-002",
        "AUTH-SCOPE-001",
        "AUTH-BUDGET-001",
        "AUTH-INTEROP-001",
        "AUTH-INTEROP-002",
        "AUTH-INTEROP-003",
        "AUTH-INTEROP-004"
    )
    $presentCodes = @($reasonContract.codes | ForEach-Object { $_.code })
    foreach ($requiredCode in $requiredAuthCodes) {
        if ($presentCodes -notcontains $requiredCode) {
            Fail "Missing required authority reason code in AUTHORITY_REASON_CODES.json: $requiredCode"
        }
    }
    $requiredInteropMappings = @(
        "INT-LEG-004-FACT_ACCESS_EMPTY",
        "INT-LEG-005-REPLAY_REQUIRED",
        "INT-LEG-006-MISSING_INTEROP_TAGS",
        "INT-LEG-007-HYBRID_COST_CHANNELS_MISSING",
        "INT-LEG-010-SIM_BUDGET_EXCEEDED"
    )
    foreach ($interopCode in $requiredInteropMappings) {
        if ($null -eq $reasonContract.interopCodeMapping.$interopCode) {
            Fail "Missing INT->AUTH mapping in AUTHORITY_REASON_CODES.json: $interopCode"
        }
    }
}
catch {
    Fail "Invalid systems/networking/AUTHORITY_REASON_CODES.json contract."
}

$syncScript = Join-Path $repoRoot "scripts\sync-authority-reason-codes-doc.ps1"
Invoke-ResilientCheck `
    -PrimaryCheck {
        & $syncScript -RepoRoot $repoRoot -Check
        if ($LASTEXITCODE -ne 0) { throw "sync check exit code: $LASTEXITCODE" }
    } `
    -Remediation {
        & $syncScript -RepoRoot $repoRoot
    } `
    -SecondaryCheck {
        & $syncScript -RepoRoot $repoRoot -Check
        if ($LASTEXITCODE -ne 0) { throw "sync re-check exit code: $LASTEXITCODE" }
    } `
    -FailureMessage "Failed to validate authority reason code doc sync." `
    -RecoveryMessage "[quality-gate] AUTHORITY_REASON_CODES.md required regeneration during validation."

# Basic matrix checks
$matrix = Get-Content (Join-Path $repoRoot "INTERACTION_MATRIX.md") -Raw
if ($matrix -notmatch "INT-") {
    Fail "INTERACTION_MATRIX.md has no interaction IDs."
}
if ($matrix -notmatch "SCN-") {
    Fail "INTERACTION_MATRIX.md missing scenario mapping section."
}
if ($matrix -notmatch "INT-0013") {
    Fail "INTERACTION_MATRIX.md missing INT-0013 magitech interop mapping."
}
if ($matrix -notmatch "SCN-005") {
    Fail "INTERACTION_MATRIX.md missing SCN-005 magitech scenario mapping."
}

# Ensure requirements include key automation sections
$req = Get-Content (Join-Path $repoRoot "REQUIREMENTS.md") -Raw
$requiredMarkers = @(
    "## 24) Live Content Authoring and AI-Assisted Generation",
    "## 25) Autonomous Bot Framework",
    "## 27) System Interaction Matrix",
    "## 28) Human Feedback and Product Adaptation Loop"
)

foreach ($marker in $requiredMarkers) {
    if ($req -notmatch [regex]::Escape($marker)) {
        Fail "Missing required section in REQUIREMENTS.md: $marker"
    }
}
if ($req -notmatch [regex]::Escape("MAGITECH_INTEROP_SPEC.md")) {
    Fail "REQUIREMENTS.md must reference MAGITECH_INTEROP_SPEC.md."
}

if ($Strict) {
    Write-Host "[quality-gate] Strict mode enabled. Add project tests/lints here."
    # Placeholder for future commands:
    # npm test
    # dotnet test
    # python -m pytest
}

Write-Host "[quality-gate] PASS"
exit 0

