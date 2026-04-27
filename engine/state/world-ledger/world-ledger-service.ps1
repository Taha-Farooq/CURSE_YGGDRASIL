param(
    [string]$RepoRoot = "",
    [string]$ActionJsonPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($ActionJsonPath)) {
    $ActionJsonPath = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json"
}
if (-not (Test-Path $ActionJsonPath)) {
    throw "Missing action json: $ActionJsonPath"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $outDir = Join-Path $RepoRoot "reports\ledger"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
    $OutputPath = Join-Path $outDir "world-ledger-$stamp.json"
}

$action = Get-Content $ActionJsonPath -Raw | ConvertFrom-Json
$ledgerRecord = @{
    ledger = "world_state_ledger_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    entityIds = @{
        actorId = [string]$action.actorId
        actionId = [string]$action.actionId
        regionId = [string]$action.scope.regionId
    }
    event = @{
        category = "action"
        actionType = [string]$action.actionType
        source = "server_authority_path"
        stateWrite = @("action_event")
    }
}

$payload = @{
    records = @($ledgerRecord)
    count = 1
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $OutputPath -Encoding UTF8

$result = @{
    service = "world_state_ledger_v1"
    outputPath = $OutputPath
    recordsWritten = 1
}
$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
