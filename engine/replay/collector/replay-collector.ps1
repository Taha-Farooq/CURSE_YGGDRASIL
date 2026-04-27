param(
    [string]$RepoRoot = "",
    [string]$EventJsonPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($EventJsonPath)) {
    $EventJsonPath = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json"
}
if (-not (Test-Path $EventJsonPath)) {
    throw "Missing event json: $EventJsonPath"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $outDir = Join-Path $RepoRoot "reports\replay"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $OutputPath = Join-Path $outDir "replay-event-$stamp.json"
}

$event = Get-Content $EventJsonPath -Raw | ConvertFrom-Json
$record = @{
    collector = "replay_collector_v1"
    capturedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    eventId = [string]$event.actionId
    actorId = [string]$event.actorId
    actionType = [string]$event.actionType
    contactFrame = @{
        regionId = [string]$event.scope.regionId
        actionTags = @($event.executionTags)
    }
    replayRequired = ($null -ne $event.replay -and $event.replay.required -eq $true)
}

$record | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8
$result = @{
    service = "replay_collector_v1"
    outputPath = $OutputPath
    capturedEventId = [string]$event.actionId
}
$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
