param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-summon-party-plan-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing summon party planner input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$target = $input.target
$availableControllers = @($input.availableControllers)
$availableTools = @($input.availableTools)
$preferences = $input.preferences

if ($availableControllers.Count -lt 1) { throw "No controllers supplied for planning." }

$targetLevel = [int]$target.level
$targetPowerTier = [int]$target.powerTier
$equitableLevelDeltaMax = 5
$requiredControllers = [math]::Max(2, [int][math]::Ceiling($targetLevel / 80.0))
$requiredComplexity = [int]([math]::Ceiling(($targetLevel * 0.9) + ($targetPowerTier * 15) + ($requiredControllers * 6)))

$eligibleControllers = @(
    $availableControllers |
    Where-Object { [math]::Abs([int]$_.level - $targetLevel) -le $equitableLevelDeltaMax } |
    Sort-Object -Property @{Expression = { [math]::Abs([int]$_.level - $targetLevel) }; Ascending = $true }, @{Expression = { [int]$_.controlSkill }; Descending = $true }
)

$selectedControllers = @($eligibleControllers | Select-Object -First $requiredControllers)
$selectedCount = $selectedControllers.Count
$controllerCoverageMet = ($selectedCount -ge $requiredControllers)

$selectedControllerComplexity = [int](($selectedControllers | Measure-Object -Property precomputeCapacity -Sum).Sum)

$selectedTools = @(
    $availableTools |
    Sort-Object -Property @{Expression = { [int]$_.complexityContribution }; Descending = $true }, @{Expression = { [bool]$_.automatic }; Descending = $true }
)

$toolComplexity = 0
$selectedToolIds = @()
foreach ($tool in $selectedTools) {
    if (($selectedControllerComplexity + $toolComplexity) -ge $requiredComplexity) { break }
    $toolComplexity += [int]$tool.complexityContribution
    $selectedToolIds += [string]$tool.toolId
}

$totalPrecompute = $selectedControllerComplexity + $toolComplexity
$complexitySatisfied = ($totalPrecompute -ge $requiredComplexity)

$preferAutomatic = $true
if ($null -ne $preferences -and $null -ne $preferences.preferAutomatic) {
    $preferAutomatic = [bool]$preferences.preferAutomatic
}

$allSelectedTools = @($availableTools | Where-Object { $selectedToolIds -contains [string]$_.toolId })
$hasAutomaticTool = (@($allSelectedTools | Where-Object { [bool]$_.automatic }).Count -ge 1)
$runtimeMode = if ($preferAutomatic -and $complexitySatisfied -and $hasAutomaticTool) { "automatic" } elseif ($complexitySatisfied) { "simple" } else { "manual_complex" }

$planViable = ($controllerCoverageMet -and $complexitySatisfied)
$reasonCodes = @()
if (-not $controllerCoverageMet) { $reasonCodes += "PLAN-SUMMON-CONTROLLERS-INSUFFICIENT" }
if (-not $complexitySatisfied) { $reasonCodes += "PLAN-SUMMON-PRECOMPUTE-INSUFFICIENT" }
if ($planViable) { $reasonCodes += "PLAN-SUMMON-READY" }

$result = @{
    planner = "summon_party_planner_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    target = @{
        entityId = [string]$target.entityId
        level = $targetLevel
        powerTier = $targetPowerTier
    }
    requirements = @{
        equitableLevelDeltaMax = $equitableLevelDeltaMax
        requiredControllers = $requiredControllers
        requiredPrecomputeComplexity = $requiredComplexity
    }
    plan = @{
        selectedControllers = @($selectedControllers | ForEach-Object {
            @{
                entityId = [string]$_.entityId
                level = [int]$_.level
                controlSkill = [int]$_.controlSkill
                precomputeCapacity = [int]$_.precomputeCapacity
            }
        })
        selectedTools = $selectedToolIds
        precomputeComplexity = $totalPrecompute
        runtimeMode = $runtimeMode
        viable = $planViable
    }
    reasonCodes = $reasonCodes
}

$result | ConvertTo-Json -Depth 12 | Write-Output
if (-not $planViable) { exit 1 }
exit 0
