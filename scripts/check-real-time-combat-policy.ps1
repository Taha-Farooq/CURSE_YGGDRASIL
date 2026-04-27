param(
    [string]$RepoRoot = "",
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}

$reqPath = Join-Path $RepoRoot "REQUIREMENTS.md"
if (-not (Test-Path $reqPath)) {
    throw "Missing REQUIREMENTS.md"
}

$req = Get-Content $reqPath -Raw
$checks = @()
function Add-Check([string]$name, [bool]$passed, [string]$details) {
    $script:checks += @{
        check = $name
        passed = $passed
        details = $details
    }
}

$hasRealtimeVision = ($req -match [regex]::Escape("All battles and attacks are real-time action simulation; turn-based combat is disallowed."))
$hasRealtimeAcceptance = ($req -match [regex]::Escape("Combat and attack resolution remains real-time at all progression tiers and does not enter turn-based mode."))
$mentionsTurnBased = ($req -match "(?i)turn[\-\s]?based")

Add-Check "realtime_rule_in_vision" $hasRealtimeVision "product vision explicitly bans turn-based combat"
Add-Check "realtime_rule_in_acceptance" $hasRealtimeAcceptance "project acceptance requires real-time combat resolution"
Add-Check "turnbased_reference_present" $mentionsTurnBased "requirements contain explicit turn-based reference for policy enforcement"

$passed = (@($checks | Where-Object { -not [bool]$_.passed }).Count -eq 0)
$result = @{
    check = "real_time_combat_policy_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    passed = $passed
    checks = $checks
}

$result | ConvertTo-Json -Depth 8 | Write-Output
if ($Strict -and -not $passed) { exit 1 }
exit 0
