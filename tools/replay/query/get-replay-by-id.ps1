param(
    [string]$RepoRoot = "",
    [string]$EventId = "",
    [string]$PlayerId = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}

$replayDir = Join-Path $RepoRoot "reports\replay"
if (-not (Test-Path $replayDir)) {
    $empty = @{
        tool = "replay_query_v1"
        found = $false
        reason = "replay directory missing"
        replay = $null
    }
    $empty | ConvertTo-Json -Depth 8 | Write-Output
    exit 0
}

$files = Get-ChildItem -Path $replayDir -Filter "replay-event-*.json" | Sort-Object LastWriteTimeUtc -Descending
$match = $null
foreach ($file in $files) {
    try {
        $r = Get-Content $file.FullName -Raw | ConvertFrom-Json
    } catch { continue }
    if (-not [string]::IsNullOrWhiteSpace($EventId) -and [string]$r.eventId -ne $EventId) { continue }
    if (-not [string]::IsNullOrWhiteSpace($PlayerId) -and [string]$r.actorId -ne $PlayerId) { continue }
    $match = @{
        file = $file.Name
        payload = $r
    }
    break
}

if ($null -eq $match) {
    @{
        tool = "replay_query_v1"
        found = $false
        reason = "no matching replay record"
        query = @{
            eventId = $EventId
            playerId = $PlayerId
        }
    } | ConvertTo-Json -Depth 8 | Write-Output
    exit 0
}

@{
    tool = "replay_query_v1"
    found = $true
    replay = $match
} | ConvertTo-Json -Depth 8 | Write-Output
exit 0
