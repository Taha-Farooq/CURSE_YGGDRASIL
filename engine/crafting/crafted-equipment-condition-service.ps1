param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-crafted-equipment-condition-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing crafted equipment condition input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$resolverScript = Join-Path $RepoRoot "engine\items\equipment-condition-resolver.ps1"
if (-not (Test-Path $resolverScript)) { throw "Missing equipment condition resolver: $resolverScript" }

$materialTiers = @($input.materialTiers)
$artisanSkill = [double]$input.artisanSkill
$workshopTier = [double]$input.workshopTier
$recipeComplexity = [double]$input.recipeComplexity

$craftsmanship = [Math]::Min(100.0, [Math]::Max(30.0, (0.55 * $artisanSkill) + (3.5 * $workshopTier) - (2.0 * $recipeComplexity)))
$durability = [Math]::Min(100.0, [Math]::Max(35.0, (48.0 + (4.5 * $workshopTier) + (0.15 * $artisanSkill) - (1.2 * $recipeComplexity))))
$maintenance = [Math]::Min(100.0, [Math]::Max(40.0, 60.0 + (0.2 * $artisanSkill) - (1.0 * $recipeComplexity)))

$resolverInput = @{
    itemId = [string]$input.itemId
    constructionItemTiers = $materialTiers
    durabilityPct = [Math]::Round($durability, 2)
    craftsmanshipQuality = [Math]::Round($craftsmanship, 2)
    ageYears = 0.0
    maintenanceCondition = [Math]::Round($maintenance, 2)
    repairRequested = $false
    targetMint = $false
    craftsman = @{
        id = [string]$input.crafterId
        qualified = [bool]$input.crafterQualified
        skillRating = [Math]::Round($artisanSkill, 2)
        certificationTier = [int]$input.crafterCertificationTier
    }
}

$tempDir = Join-Path $RepoRoot "reports\temp"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
$tempPath = Join-Path $tempDir ("crafted-condition-resolver-input-" + [guid]::NewGuid().ToString() + ".json")
$resolverInput | ConvertTo-Json -Depth 8 | Set-Content -Path $tempPath -Encoding UTF8

try {
    $resolved = & $resolverScript -RepoRoot $RepoRoot -InputJsonPath $tempPath | ConvertFrom-Json
}
finally {
    if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
}

$result = @{
    service = "crafted_equipment_condition_service_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    crafting = @{
        itemId = [string]$input.itemId
        crafterId = [string]$input.crafterId
        recipeComplexity = $recipeComplexity
        materialTiers = $materialTiers
    }
    customization = $resolved.customization
    condition = $resolved.condition
    reasonCodes = @("AUTH-CRAFT-CONDITION-APPLIED")
}

$result | ConvertTo-Json -Depth 10 | Write-Output
exit 0
