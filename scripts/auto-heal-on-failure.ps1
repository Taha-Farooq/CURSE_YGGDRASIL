param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$actions = @()
function Add-Action([string]$name, [bool]$passed, [string]$details) {
    $script:actions += @{
        name = $name
        passed = $passed
        details = $details
    }
}

function Invoke-Step([string]$name, [scriptblock]$Block) {
    try {
        & $Block
        Add-Action $name $true "ok"
    } catch {
        Add-Action $name $false $_.Exception.Message
    }
}

# Safe auto-patches for known drift/failure patterns.
Invoke-Step "sync-authority-reason-codes-doc" { & (Join-Path $RepoRoot "scripts\sync-authority-reason-codes-doc.ps1") -RepoRoot $RepoRoot -Write }
Invoke-Step "sync-interaction-matrix-contract-doc" { & (Join-Path $RepoRoot "scripts\sync-interaction-matrix-contract-doc.ps1") -RepoRoot $RepoRoot -Write }
Invoke-Step "import-phase2-tasks" { & (Join-Path $RepoRoot "scripts\import-phase2-tasks.ps1") }
Invoke-Step "refresh-phase2-acceptance-artifact" { & (Join-Path $RepoRoot "scripts\phase2-acceptance-report.ps1") -RepoRoot $RepoRoot -WriteReport }

$qualityPassed = $false
$qualityMessage = ""
try {
    & (Join-Path $RepoRoot "scripts\quality-gate.ps1") -Strict:$Strict
    $qualityPassed = $true
    $qualityMessage = "quality gate passed after auto-heal"
} catch {
    $qualityPassed = $false
    $qualityMessage = $_.Exception.Message
}
Add-Action "quality-gate-recheck" $qualityPassed $qualityMessage

$reportDir = Join-Path $RepoRoot "reports\bots"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$path = Join-Path $reportDir "auto-heal-on-failure-$stamp.json"

$result = @{
    bot = "auto-heal-on-failure"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $qualityPassed
    actions = $actions
}

$result | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $qualityPassed) { exit 1 }
exit 0
