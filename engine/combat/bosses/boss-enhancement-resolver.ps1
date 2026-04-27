param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-boss-enhancement-valid.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing boss enhancement input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$bossType = [string]$input.bossType
$bossLevel = [int]$input.bossLevel
$baseMobHealth = [int]$input.baseMobHealth
$baseRewardTier = [int]$input.baseRewardTier
$baseRewardQuantity = [int]$input.baseRewardQuantity
$gearTier = [int]$input.gearTier
$enhancements = @($input.enhancements)

$isBossOrAreaBoss = ($bossType -in @("boss", "area_boss"))
$healthMultiplierBase = if ($bossType -eq "area_boss") { 3.2 } else { 4.0 }
$minHealthRequired = [int][Math]::Round($baseMobHealth * $healthMultiplierBase)
$healthValid = ([int]$input.bossHealth -ge $minHealthRequired)

$requiredGearTier = [Math]::Max(8, [int][Math]::Floor($bossLevel / 120) + 7)
$gearValid = ($gearTier -ge $requiredGearTier)

$enhancementWeights = @{
    electric = 1.10
    poisonous = 1.08
    thorns = 1.07
    trapper = 1.09
}
$enhancementCount = $enhancements.Count
$enhancementMultiplier = 1.0
$unknownEnhancements = @()
foreach ($e in $enhancements) {
    $name = [string]$e
    if ($enhancementWeights.ContainsKey($name)) {
        $enhancementMultiplier *= [double]$enhancementWeights[$name]
    } else {
        $unknownEnhancements += $name
    }
}
$enhancementMultiplier = [Math]::Round($enhancementMultiplier, 4)

$levelScale = [Math]::Round(1.0 + ($bossLevel / 4000.0), 4)
$powerScore = [Math]::Round($levelScale * $enhancementMultiplier * (1.0 + ($gearTier / 20.0)), 4)
$rewardTier = [int][Math]::Min(13, [Math]::Round($baseRewardTier + [Math]::Ceiling($enhancementCount / 2.0) + [Math]::Floor($powerScore - 1.0)))
$rewardQuantity = [int][Math]::Max($baseRewardQuantity, [Math]::Round($baseRewardQuantity * (1.0 + (0.35 * $enhancementCount))))

$enhancementScalingValid = ($enhancementCount -eq 0 -or $enhancementMultiplier -gt 1.0)
$rewardScalingValid = ($enhancementCount -eq 0 -or ($rewardTier -ge $baseRewardTier -and $rewardQuantity -ge $baseRewardQuantity))

$allowed = ($isBossOrAreaBoss -and $healthValid -and $gearValid -and $enhancementScalingValid -and $rewardScalingValid -and @($unknownEnhancements).Count -eq 0)
$reasonCodes = @()
if (-not $isBossOrAreaBoss) { $reasonCodes += "AUTH-BOSS-TYPE-INVALID" }
if (-not $healthValid) { $reasonCodes += "AUTH-BOSS-HEALTH-POOL-INSUFFICIENT" }
if (-not $gearValid) { $reasonCodes += "AUTH-BOSS-LEGENDARY-GEAR-TIER-INSUFFICIENT" }
if (-not $enhancementScalingValid) { $reasonCodes += "AUTH-BOSS-ENHANCEMENT-SCALING-INVALID" }
if (-not $rewardScalingValid) { $reasonCodes += "AUTH-BOSS-REWARD-SCALING-INVALID" }
if (@($unknownEnhancements).Count -gt 0) { $reasonCodes += "AUTH-BOSS-ENHANCEMENT-UNKNOWN" }
if ($allowed) { $reasonCodes += "AUTH-BOSS-ENHANCEMENT-ALLOWED" }

$result = @{
    validator = "boss_enhancement_resolver_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    bossType = $bossType
    bossLevel = $bossLevel
    health = @{
        baseMobHealth = $baseMobHealth
        bossHealth = [int]$input.bossHealth
        minRequired = $minHealthRequired
        valid = $healthValid
    }
    gear = @{
        gearTier = $gearTier
        minRequiredTier = $requiredGearTier
        valid = $gearValid
    }
    enhancements = @{
        count = $enhancementCount
        list = $enhancements
        multiplier = $enhancementMultiplier
        unknown = $unknownEnhancements
        valid = $enhancementScalingValid
    }
    power = @{
        levelScale = $levelScale
        score = $powerScore
    }
    rewards = @{
        baseTier = $baseRewardTier
        baseQuantity = $baseRewardQuantity
        scaledTier = $rewardTier
        scaledQuantity = $rewardQuantity
        valid = $rewardScalingValid
    }
    allowed = $allowed
    reasonCodes = $reasonCodes
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $allowed) { exit 1 }
exit 0
