param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-control-precomputed.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing summon control input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$target = $input.target
$controllers = @($input.controllers)
$context = $input.context

if ($controllers.Count -lt 1) { throw "At least one controller is required." }

$targetLevel = [int]$target.level
$targetPowerTier = [int]$target.powerTier
$avgControllerLevel = [double](($controllers | Measure-Object -Property level -Average).Average)
$highestControllerLevel = [int](($controllers | Measure-Object -Property level -Maximum).Maximum)

# Equitable level gate: controller collective must be near target level.
$equitableLevelDeltaMax = 5
$equitableLevel = ([math]::Abs($avgControllerLevel - $targetLevel) -le $equitableLevelDeltaMax)

# Control threshold: stronger entities require more same-level controllers.
$requiredControllers = [math]::Max(2, [int][math]::Ceiling($targetLevel / 80.0))
$meetsControllerCount = ($controllers.Count -ge $requiredControllers)

# Strength-linked complexity cost.
$baseComplexity = [int]([math]::Ceiling(($targetLevel * 0.9) + ($targetPowerTier * 15)))
$coordinationComplexity = [int]([math]::Ceiling($requiredControllers * 6))
$requiredComplexity = $baseComplexity + $coordinationComplexity

$quicksummonEnabled = [bool]$context.quicksummonEnabled
$quicksummonPrecomputedComplexity = [int]$context.quicksummonPrecomputedComplexity
$assistItemComplexity = [int]$context.assistItemComplexity
$preparedComplexity = $quicksummonPrecomputedComplexity + $assistItemComplexity
$precomputeSatisfied = ($preparedComplexity -ge $requiredComplexity)

$runtimeMode = if ($quicksummonEnabled -and $precomputeSatisfied) { "automatic" } else { "manual_complex" }
$allowed = ($equitableLevel -and $meetsControllerCount -and (($runtimeMode -eq "automatic") -or $precomputeSatisfied))

$reasonCodes = @()
if (-not $equitableLevel) { $reasonCodes += "AUTH-SUMMON-LEVEL-NOT-EQUITABLE" }
if (-not $meetsControllerCount) { $reasonCodes += "AUTH-SUMMON-CONTROL-THRESHOLD-NOT-MET" }
if (-not $precomputeSatisfied) { $reasonCodes += "AUTH-SUMMON-COMPLEXITY-PRECOMPUTE-INSUFFICIENT" }
if ($allowed) { $reasonCodes += "AUTH-SUMMON-CONTROL-ALLOWED" }

$result = @{
    validator = "summon_control_complexity_validator_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    target = @{
        entityId = [string]$target.entityId
        level = $targetLevel
        powerTier = $targetPowerTier
    }
    controllerSummary = @{
        count = $controllers.Count
        requiredCount = $requiredControllers
        highestLevel = $highestControllerLevel
        averageLevel = [math]::Round($avgControllerLevel, 2)
    }
    complexity = @{
        required = $requiredComplexity
        precomputed = $preparedComplexity
        quicksummonEnabled = $quicksummonEnabled
    }
    eligibility = @{
        equitableLevel = $equitableLevel
        meetsControlThreshold = $meetsControllerCount
        precomputeSatisfied = $precomputeSatisfied
        runtimeMode = $runtimeMode
        allowed = $allowed
    }
    reasonCodes = $reasonCodes
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $allowed) { exit 1 }
exit 0
