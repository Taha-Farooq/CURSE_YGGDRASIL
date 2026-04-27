param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-equipment-condition-valid.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing equipment condition input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$constructionTiers = @($input.constructionItemTiers)
$durabilityPct = [double]$input.durabilityPct
$craftsmanshipQuality = [double]$input.craftsmanshipQuality
$ageYears = [double]$input.ageYears
$maintenanceCondition = [double]$input.maintenanceCondition
$repairRequested = [bool]$input.repairRequested
$targetMint = [bool]$input.targetMint
$craftsman = $input.craftsman

$avgConstructionTier = 0.0
if ($constructionTiers.Count -gt 0) {
    $avgConstructionTier = [Math]::Round((($constructionTiers | Measure-Object -Average).Average), 2)
}
$qualifiedCrafter = ([bool]$craftsman.qualified -and [double]$craftsman.skillRating -ge 85.0 -and [int]$craftsman.certificationTier -ge 4)

$agePenalty = [Math]::Min(35.0, $ageYears * 1.8)
$conditionScore = [Math]::Round(
    (0.30 * $durabilityPct) +
    (0.25 * $craftsmanshipQuality) +
    (0.20 * $maintenanceCondition) +
    (0.15 * ($avgConstructionTier * 10.0)) +
    (0.10 * (100.0 - $agePenalty)),
    2
)
$valueMultiplier = [Math]::Round([Math]::Max(0.35, $conditionScore / 100.0), 3)
$effectivenessMultiplier = [Math]::Round([Math]::Max(0.40, (0.6 + ($conditionScore / 250.0))), 3)

$mintAchieved = $false
if ($repairRequested -and $targetMint -and $qualifiedCrafter) {
    $mintAchieved = $true
    $durabilityPct = 100.0
    $maintenanceCondition = 100.0
    $conditionScore = [Math]::Round(
        (0.30 * $durabilityPct) +
        (0.25 * $craftsmanshipQuality) +
        (0.20 * $maintenanceCondition) +
        (0.15 * ($avgConstructionTier * 10.0)) +
        (0.10 * (100.0 - [Math]::Min(35.0, $ageYears * 1.8))),
        2
    )
    $valueMultiplier = [Math]::Round([Math]::Max(0.35, $conditionScore / 100.0), 3)
    $effectivenessMultiplier = [Math]::Round([Math]::Max(0.40, (0.6 + ($conditionScore / 250.0))), 3)
}

$allowed = $true
$reasonCodes = @()
if ($repairRequested -and $targetMint -and -not $qualifiedCrafter) { $reasonCodes += "AUTH-EQUIP-MINT-REPAIR-QUALIFIED-CRAFTER-REQUIRED" }
if ($mintAchieved) { $reasonCodes += "AUTH-EQUIP-MINT-RESTORE-APPROVED" }
if (-not $mintAchieved) { $reasonCodes += "AUTH-EQUIP-CONDITION-UPDATED" }

$result = @{
    resolver = "equipment_condition_resolver_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    itemId = [string]$input.itemId
    customization = @{
        constructionItemTiers = $constructionTiers
        averageConstructionTier = $avgConstructionTier
        durabilityPct = $durabilityPct
        craftsmanshipQuality = $craftsmanshipQuality
        ageYears = $ageYears
        maintenanceCondition = $maintenanceCondition
    }
    condition = @{
        score = $conditionScore
        valueMultiplier = $valueMultiplier
        effectivenessMultiplier = $effectivenessMultiplier
    }
    repair = @{
        requested = $repairRequested
        targetMint = $targetMint
        qualifiedCraftsman = $qualifiedCrafter
        mintAchieved = $mintAchieved
    }
    allowed = $allowed
    reasonCodes = $reasonCodes
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if ($repairRequested -and $targetMint -and -not $qualifiedCrafter) { exit 1 }
exit 0
