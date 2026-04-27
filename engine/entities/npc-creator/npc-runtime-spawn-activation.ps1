param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-npc-runtime-spec-valid.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing npc runtime spec: $InputJsonPath" }

$validatorScript = Join-Path $PSScriptRoot "npc-creator-validator.ps1"
$auditScript = Join-Path $PSScriptRoot "npc-creator-audit-tags.ps1"

$validator = & $validatorScript -RepoRoot $RepoRoot -InputJsonPath $InputJsonPath | ConvertFrom-Json
$audit = & $auditScript -InputJsonPath $InputJsonPath | ConvertFrom-Json
$spec = Get-Content $InputJsonPath -Raw | ConvertFrom-Json

$activationAllowed = [bool]$validator.passed
$spawned = $false
$spawnId = ""
if ($activationAllowed) {
    $spawned = $true
    $spawnId = ("spawn-" + [string]$spec.npcId + "-" + (Get-Date -Format "yyyyMMddHHmmss"))
}

$result = @{
    service = "npc_runtime_spawn_activation_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    npcId = [string]$spec.npcId
    activationAllowed = $activationAllowed
    spawned = $spawned
    spawnId = $spawnId
    lineage = @{
        creatorId = [string]$audit.creatorId
        packageId = [string]$audit.packageId
        version = [string]$audit.version
    }
    rejectionReasons = @($validator.rejectionReasons)
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $activationAllowed) { exit 1 }
exit 0
