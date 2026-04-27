param(
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")) "tests\fixtures\phase1-npc-creator-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing npc creator input: $InputJsonPath" }

$spec = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$tags = @{
    audit = "npc_creator_audit_tags_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    creatorId = [string]$spec.creatorId
    packageId = [string]$spec.packageId
    version = [string]$spec.version
    npcId = [string]$spec.npcId
}

$tags | ConvertTo-Json -Depth 8 | Write-Output
exit 0
