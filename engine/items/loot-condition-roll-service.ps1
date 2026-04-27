param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-loot-condition-roll-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing loot condition input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$resolverScript = Join-Path $RepoRoot "engine\items\equipment-condition-resolver.ps1"
if (-not (Test-Path $resolverScript)) { throw "Missing equipment condition resolver: $resolverScript" }

$rarity = [string]$input.lootRarity
$baseTiers = @($input.baseConstructionTiers)
$dropTierBonus = switch ($rarity) {
    "common" { 0 }
    "uncommon" { 1 }
    "rare" { 2 }
    "epic" { 3 }
    "legendary" { 4 }
    default { 1 }
}

$rolledTiers = @()
foreach ($tier in $baseTiers) {
    $rolledTiers += [int]$tier + $dropTierBonus
}

$qualityBonus = [double]$input.zoneDifficulty * 2.2
$durability = [Math]::Min(100.0, [Math]::Max(25.0, 55.0 + (6.0 * $dropTierBonus) + $qualityBonus))
$craftsmanship = [Math]::Min(100.0, [Math]::Max(35.0, 50.0 + (7.0 * $dropTierBonus) + ($qualityBonus * 0.7)))
$maintenance = [Math]::Min(95.0, [Math]::Max(20.0, 45.0 + (5.0 * $dropTierBonus) + ($qualityBonus * 0.5)))
$ageYears = [Math]::Max(0.0, [double]$input.lootAgeYears)

$resolverInput = @{
    itemId = [string]$input.itemId
    constructionItemTiers = $rolledTiers
    durabilityPct = [Math]::Round($durability, 2)
    craftsmanshipQuality = [Math]::Round($craftsmanship, 2)
    ageYears = [Math]::Round($ageYears, 2)
    maintenanceCondition = [Math]::Round($maintenance, 2)
    repairRequested = $false
    targetMint = $false
    craftsman = @{
        id = "none"
        qualified = $false
        skillRating = 0
        certificationTier = 0
    }
}

$tempDir = Join-Path $RepoRoot "reports\temp"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
$tempPath = Join-Path $tempDir ("loot-condition-resolver-input-" + [guid]::NewGuid().ToString() + ".json")
$resolverInput | ConvertTo-Json -Depth 8 | Set-Content -Path $tempPath -Encoding UTF8

try {
    $resolved = & $resolverScript -RepoRoot $RepoRoot -InputJsonPath $tempPath | ConvertFrom-Json
}
finally {
    if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
}

$result = @{
    service = "loot_condition_roll_service_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    loot = @{
        itemId = [string]$input.itemId
        rarity = $rarity
        source = [string]$input.source
        constructionItemTiers = $rolledTiers
    }
    condition = $resolved.condition
    customization = $resolved.customization
    reasonCodes = @("AUTH-LOOT-CONDITION-ROLLED")
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
