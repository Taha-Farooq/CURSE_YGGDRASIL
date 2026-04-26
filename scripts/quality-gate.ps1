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

if (-not (Test-Path (Join-Path $repoRoot "FEEDBACK_SCHEMA.json"))) {
    Fail "Missing FEEDBACK_SCHEMA.json"
}

if (-not (Test-Path (Join-Path $repoRoot "INTERACTION_MATRIX.md"))) {
    Fail "Missing INTERACTION_MATRIX.md"
}

if (-not (Test-Path (Join-Path $repoRoot "REQUIREMENTS.md"))) {
    Fail "Missing REQUIREMENTS.md"
}

# Basic JSON parse check
try {
    Get-Content (Join-Path $repoRoot "FEEDBACK_SCHEMA.json") -Raw | ConvertFrom-Json | Out-Null
    Write-Host "[quality-gate] FEEDBACK_SCHEMA.json is valid JSON."
}
catch {
    Fail "Invalid FEEDBACK_SCHEMA.json JSON."
}

# Basic matrix checks
$matrix = Get-Content (Join-Path $repoRoot "INTERACTION_MATRIX.md") -Raw
if ($matrix -notmatch "INT-") {
    Fail "INTERACTION_MATRIX.md has no interaction IDs."
}
if ($matrix -notmatch "SCN-") {
    Fail "INTERACTION_MATRIX.md missing scenario mapping section."
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

if ($Strict) {
    Write-Host "[quality-gate] Strict mode enabled. Add project tests/lints here."
    # Placeholder for future commands:
    # npm test
    # dotnet test
    # python -m pytest
}

Write-Host "[quality-gate] PASS"
exit 0

