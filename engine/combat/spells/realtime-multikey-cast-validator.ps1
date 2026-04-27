param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-realtime-multikey-cast-valid.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing multikey cast input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$sequence = @($input.sequence)
$profile = $input.profile
$timings = $input.timings
$delivery = $input.delivery

$sequenceLength = $sequence.Count
$maxSequenceLength = 4
$minSequenceLength = 2
$sequenceLengthValid = ($sequenceLength -ge $minSequenceLength -and $sequenceLength -le $maxSequenceLength)

$requiredKeys = @($input.requiredKeys)
$keysMatch = ($requiredKeys.Count -eq $sequence.Count -and (@($requiredKeys | Where-Object { $sequence -notcontains $_ }).Count -eq 0))

$castWindowMs = [int]$timings.castWindowMs
$totalInputMs = [int]$timings.totalInputMs
$recoveryMs = [int]$timings.recoveryMs
$nonMagicCadenceMs = [int]$profile.nonMagicCadenceMs

$withinWindow = ($totalInputMs -le $castWindowMs)
$parityCadence = (($totalInputMs + $recoveryMs) -le [int]($nonMagicCadenceMs * 1.15))

$spellTier = [int]$input.spellTier
$requiresPrecompiledAid = ($spellTier -ge 9)
$requiresFullTome = ($spellTier -ge 11)
$requiresMaxLevelCasterAndWorldItems = ($spellTier -ge 12)
$hasPrecompiledAid = ([bool]$delivery.scrollPrepared -or [bool]$delivery.itemComboPrepared -or [bool]$delivery.autoSpellcastingEnabled -or [bool]$delivery.macroApproved)
$rawAssemblyRequested = [bool]$delivery.rawAssemblyRequested
$highTierDeliveryValid = ((-not $requiresPrecompiledAid) -or ($hasPrecompiledAid -and -not $rawAssemblyRequested))

$fullTomeEquipped = [bool]$delivery.fullTomeEquipped
$tomeRequirementValid = ((-not $requiresFullTome) -or $fullTomeEquipped)

$casterLevel = [int]$input.casterLevel
$maxCasterLevel = 9999
$requiredWorldItemIds = @($input.requiredWorldItemIds)
$worldItemSpellConstructorIds = @($delivery.worldItemSpellConstructorIds)
$hasRequiredWorldItems = (@($requiredWorldItemIds | Where-Object { $worldItemSpellConstructorIds -notcontains $_ }).Count -eq 0 -and $requiredWorldItemIds.Count -gt 0)
$highestTierCasterAndItemValid = ((-not $requiresMaxLevelCasterAndWorldItems) -or ($casterLevel -ge $maxCasterLevel -and $hasRequiredWorldItems))

$components = @($input.components)
$isComplexSpell = [bool]$input.isComplexSpell
$complexStageCount = $components.Count
$complexSpellValid = ((-not $isComplexSpell) -or ($complexStageCount -ge 2 -and [bool]$input.deterministicStageOrder))

$isMultidimensional = [bool]$input.isMultidimensional
$dimensionLegalityPassed = [bool]$input.dimensionLegalityPassed
$multidimensionalValid = ((-not $isMultidimensional) -or $dimensionLegalityPassed)

$parallelCastsRequested = [int]$input.parallelCastsRequested
$parallelBudgetCap = [int]$input.parallelBudgetCap
$parallelLegalityPassed = [bool]$input.parallelLegalityPassed
$parallelCastsValid = (($parallelCastsRequested -le 1) -or ($parallelCastsRequested -le $parallelBudgetCap -and $parallelLegalityPassed))

$concurrentSpells = @($input.concurrentSpells)
$enhancementPairs = @($input.enhancementPairs)
$casterMagicExperience = [int]$input.casterMagicExperience
$casterMagicClass = [string]$input.casterMagicClass
$casterMagicSubclass = [string]$input.casterMagicSubclass
$currentMp = [int]$input.currentMp
$maxMp = [int]$input.maxMp
$currentHp = [int]$input.currentHp
$maxHp = [int]$input.maxHp
$currentBuild = [string]$input.currentBuild
$currentSetBonus = [int]$input.currentSetBonus
$currentItemBonus = [int]$input.currentItemBonus
$lowResourceMulticastAffinity = [bool]$input.lowResourceMulticastAffinity
$actorType = [string]$input.actorType
if ([string]::IsNullOrWhiteSpace($actorType)) { $actorType = "player" }
$itemlessMulticastRequested = [bool]$input.itemlessMulticastRequested
$elementMastery = @($input.elementMastery)

$effectiveConcurrentSpellCount = [Math]::Max($parallelCastsRequested, $concurrentSpells.Count)
$totalConcurrentComplexity = 0
$totalConcurrentTier = 0
$elements = @()
foreach ($s in $concurrentSpells) {
    $totalConcurrentComplexity += [int]$s.complexity
    $totalConcurrentTier += [int]$s.spellTier
    $elements += [string]$s.element
}
$avgConcurrentTier = 0.0
if ($concurrentSpells.Count -gt 0) {
    $avgConcurrentTier = [double]$totalConcurrentTier / [double]$concurrentSpells.Count
}
$uniqueElementCount = @($elements | Sort-Object -Unique).Count

$hasWaterFireConflict = ($elements -contains "water" -and $elements -contains "fire")
$conflictBridgePresent = @($enhancementPairs | Where-Object {
    ([string]$_.a -eq "water" -and [string]$_.b -eq "fire") -or
    ([string]$_.a -eq "fire" -and [string]$_.b -eq "water")
}).Count -gt 0
$elementConflictPenalty = 0
if ($hasWaterFireConflict -and -not $conflictBridgePresent) {
    $elementConflictPenalty = 18
}

$combinedSpells = @()
foreach ($pair in $enhancementPairs) {
    $a = [string]$pair.a
    $b = [string]$pair.b
    $resultElement = [string]$pair.result
    if (($elements -contains $a) -and ($elements -contains $b) -and -not [string]::IsNullOrWhiteSpace($resultElement)) {
        $combinedSpells += @{
            from = @($a, $b)
            resultElement = $resultElement
            synthesisAllowed = $true
        }
    }
}
$synthesisBonus = @($combinedSpells).Count * 6

$classAffinityBonus = 0
if ($casterMagicClass -eq "archmage") { $classAffinityBonus += 8 }
if ($casterMagicClass -eq "healer") { $classAffinityBonus += 4 }
if ($casterMagicSubclass -eq "multicaster") { $classAffinityBonus += 10 }
if ($casterMagicSubclass -eq "spellweaver") { $classAffinityBonus += 6 }

$mpRatio = 1.0
if ($maxMp -gt 0) { $mpRatio = [double]$currentMp / [double]$maxMp }
$hpRatio = 1.0
if ($maxHp -gt 0) { $hpRatio = [double]$currentHp / [double]$maxHp }
$isLowResourceState = ($mpRatio -le 0.25 -or $hpRatio -le 0.25)
$lowResourceBuildBonus = 0
if ($lowResourceMulticastAffinity -and $isLowResourceState) {
    $lowResourceBuildBonus = 15
}
$enemyMulticastProficiencyBonus = 0
if ($actorType -eq "enemy" -and $parallelCastsRequested -gt 1) {
    $enemyMulticastProficiencyBonus = 20
}

$multicastHighLevelThreshold = 1000
$requiredAffinityThreshold = 70
$requiredElementExperienceThreshold = 1000
$uniqueElements = @($elements | Sort-Object -Unique)
$masteryByElement = @{}
foreach ($m in $elementMastery) {
    $masteryByElement[[string]$m.element] = @{
        affinity = [int]$m.affinity
        experience = [int]$m.experience
    }
}
$elementMasteryChecks = @()
foreach ($el in $uniqueElements) {
    $has = $masteryByElement.ContainsKey($el)
    $aff = if ($has) { [int]$masteryByElement[$el].affinity } else { 0 }
    $exp = if ($has) { [int]$masteryByElement[$el].experience } else { 0 }
    $ok = ($aff -ge $requiredAffinityThreshold -and $exp -ge $requiredElementExperienceThreshold)
    $elementMasteryChecks += @{
        element = $el
        affinity = $aff
        experience = $exp
        valid = $ok
    }
}
$requiresPlayerItemlessAffinityGate = (
    $actorType -eq "player" -and
    $parallelCastsRequested -gt 1 -and
    $itemlessMulticastRequested -and
    $casterLevel -lt $multicastHighLevelThreshold
)
$playerItemlessAffinityGateValid = ((-not $requiresPlayerItemlessAffinityGate) -or (@($elementMasteryChecks | Where-Object { -not [bool]$_.valid }).Count -eq 0))

$compoundMulticastRequested = [bool]$input.compoundMulticastRequested
$compoundSequences = @($input.compoundSequences)
$compoundSimultaneousWindowMs = [int]$input.compoundSimultaneousWindowMs
$compoundMinSequenceLength = 2
$compoundMaxSequenceLength = 4
$compoundSequenceChecks = @()
$compoundSequenceValidity = @()
$compoundStartOffsets = @()
foreach ($compound in $compoundSequences) {
    $compoundProvided = @($compound.sequence)
    $compoundRequired = @($compound.requiredKeys)
    $compoundLengthValid = ($compoundProvided.Count -ge $compoundMinSequenceLength -and $compoundProvided.Count -le $compoundMaxSequenceLength)
    $compoundKeysMatch = ($compoundRequired.Count -eq $compoundProvided.Count -and (@($compoundRequired | Where-Object { $compoundProvided -notcontains $_ }).Count -eq 0))
    $compoundWindowValid = ([int]$compound.totalInputMs -le [int]$compound.castWindowMs)
    $compoundSequenceIsValid = ($compoundLengthValid -and $compoundKeysMatch -and $compoundWindowValid)
    $compoundSequenceValidity += $compoundSequenceIsValid
    $compoundStartOffsets += [int]$compound.startOffsetMs
    $compoundSequenceChecks += @{
        id = [string]$compound.id
        validLength = $compoundLengthValid
        keysMatch = $compoundKeysMatch
        withinWindow = $compoundWindowValid
        valid = $compoundSequenceIsValid
    }
}
$hasMinimumCompoundSequences = ($compoundSequences.Count -ge 2)
$allCompoundSequencesValid = (@($compoundSequenceValidity | Where-Object { -not $_ }).Count -eq 0)
$compoundSimultaneousValid = $false
if ($compoundStartOffsets.Count -ge 2) {
    $compoundSimultaneousValid = ((($compoundStartOffsets | Measure-Object -Maximum).Maximum - ($compoundStartOffsets | Measure-Object -Minimum).Minimum) -le $compoundSimultaneousWindowMs)
}
$compoundMulticastValid = ((-not $compoundMulticastRequested) -or ($hasMinimumCompoundSequences -and $allCompoundSequencesValid -and $compoundSimultaneousValid))

$difficultyScore = [int][Math]::Round(
    (12 * [Math]::Max(0, $effectiveConcurrentSpellCount - 1)) +
    (1.2 * $totalConcurrentComplexity) +
    (3.5 * $avgConcurrentTier) +
    (2.0 * $uniqueElementCount) +
    $elementConflictPenalty -
    $synthesisBonus
)
$capacityScore = [int][Math]::Round(
    (0.006 * $casterLevel) +
    (0.02 * $casterMagicExperience) +
    $classAffinityBonus +
    (0.12 * $currentSetBonus) +
    (0.10 * $currentItemBonus) +
    (0.05 * $currentMp) +
    (0.02 * $currentHp) +
    $lowResourceBuildBonus +
    $enemyMulticastProficiencyBonus
)
$concurrentDifficultyValid = (($parallelCastsRequested -le 1) -or ($difficultyScore -le $capacityScore))

$allowed = ($sequenceLengthValid -and $keysMatch -and $withinWindow -and $parityCadence -and $highTierDeliveryValid -and $tomeRequirementValid -and $highestTierCasterAndItemValid -and $complexSpellValid -and $multidimensionalValid -and $parallelCastsValid -and $concurrentDifficultyValid -and $compoundMulticastValid -and $playerItemlessAffinityGateValid)
$reasonCodes = @()
if (-not $sequenceLengthValid) { $reasonCodes += "AUTH-CAST-MULTIKEY-SEQUENCE-LENGTH-INVALID" }
if (-not $keysMatch) { $reasonCodes += "AUTH-CAST-MULTIKEY-SEQUENCE-MISMATCH" }
if (-not $withinWindow) { $reasonCodes += "AUTH-CAST-MULTIKEY-WINDOW-EXCEEDED" }
if (-not $parityCadence) { $reasonCodes += "AUTH-CAST-TEMPO-PARITY-FAILED" }
if ($requiresPrecompiledAid -and -not $hasPrecompiledAid) { $reasonCodes += "AUTH-CAST-HIGH-TIER-PRECOMPILED-AID-REQUIRED" }
if ($requiresPrecompiledAid -and $rawAssemblyRequested) { $reasonCodes += "AUTH-CAST-HIGH-TIER-RAW-ASSEMBLY-DISALLOWED" }
if ($requiresFullTome -and -not $fullTomeEquipped) { $reasonCodes += "AUTH-CAST-VERY-HIGH-TIER-TOME-REQUIRED" }
if ($requiresMaxLevelCasterAndWorldItems -and $casterLevel -lt $maxCasterLevel) { $reasonCodes += "AUTH-CAST-HIGHEST-TIER-MAX-LEVEL-REQUIRED" }
if ($requiresMaxLevelCasterAndWorldItems -and -not $hasRequiredWorldItems) { $reasonCodes += "AUTH-CAST-HIGHEST-TIER-WORLD-ITEM-REQUIRED" }
if ($isComplexSpell -and -not $complexSpellValid) { $reasonCodes += "AUTH-CAST-COMPLEX-STAGE-ORDER-INVALID" }
if ($isMultidimensional -and -not $dimensionLegalityPassed) { $reasonCodes += "AUTH-CAST-MULTIDIMENSIONAL-LEGALITY-FAILED" }
if ($parallelCastsRequested -gt 1 -and -not $parallelCastsValid) { $reasonCodes += "AUTH-CAST-PARALLEL-BUDGET-OR-LEGALITY-FAILED" }
if ($parallelCastsRequested -gt 1 -and -not $concurrentDifficultyValid) { $reasonCodes += "AUTH-CAST-CONCURRENT-DIFFICULTY-EXCEEDS-CAPACITY" }
if ($hasWaterFireConflict -and -not $conflictBridgePresent) { $reasonCodes += "AUTH-CAST-ELEMENT-CONFLICT-WATER-FIRE-WEAKENED" }
if (@($combinedSpells).Count -gt 0) { $reasonCodes += "AUTH-CAST-ELEMENT-SYNTHESIS-APPLIED" }
if ($compoundMulticastRequested -and (-not $hasMinimumCompoundSequences -or -not $allCompoundSequencesValid)) { $reasonCodes += "AUTH-CAST-COMPOUND-SEQUENCE-INVALID" }
if ($compoundMulticastRequested -and -not $compoundSimultaneousValid) { $reasonCodes += "AUTH-CAST-COMPOUND-NOT-SIMULTANEOUS" }
if ($requiresPlayerItemlessAffinityGate -and -not $playerItemlessAffinityGateValid) { $reasonCodes += "AUTH-CAST-PLAYER-AFFINITY-EXPERIENCE-INSUFFICIENT-FOR-ITEMLESS-MULTICAST" }
if ($actorType -eq "enemy" -and $parallelCastsRequested -gt 1) { $reasonCodes += "AUTH-CAST-ENEMY-MULTICAST-PROFICIENCY-APPLIED" }
if ($allowed) { $reasonCodes += "AUTH-CAST-MULTIKEY-ALLOWED" }

$result = @{
    validator = "realtime_multikey_cast_validator_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    spellId = [string]$input.spellId
    spellTier = $spellTier
    casterLevel = $casterLevel
    composition = @{
        isComplexSpell = $isComplexSpell
        componentCount = $complexStageCount
        deterministicStageOrder = [bool]$input.deterministicStageOrder
        valid = $complexSpellValid
    }
    dimensions = @{
        isMultidimensional = $isMultidimensional
        legalityPassed = $dimensionLegalityPassed
        valid = $multidimensionalValid
    }
    parallel = @{
        requested = $parallelCastsRequested
        budgetCap = $parallelBudgetCap
        legalityPassed = $parallelLegalityPassed
        valid = $parallelCastsValid
    }
    concurrentCasting = @{
        spellCount = $effectiveConcurrentSpellCount
        totalComplexity = $totalConcurrentComplexity
        averageTier = $avgConcurrentTier
        uniqueElementCount = $uniqueElementCount
        conflict = @{
            waterFirePresent = $hasWaterFireConflict
            bridgePresent = $conflictBridgePresent
            penalty = $elementConflictPenalty
        }
        synthesis = @{
            applied = (@($combinedSpells).Count -gt 0)
            combinedSpells = $combinedSpells
            bonus = $synthesisBonus
        }
        caster = @{
            actorType = $actorType
            magicClass = $casterMagicClass
            magicSubclass = $casterMagicSubclass
            magicExperience = $casterMagicExperience
            build = $currentBuild
            setBonus = $currentSetBonus
            itemBonus = $currentItemBonus
            currentMp = $currentMp
            maxMp = $maxMp
            currentHp = $currentHp
            maxHp = $maxHp
            lowResourceState = $isLowResourceState
            lowResourceMulticastAffinity = $lowResourceMulticastAffinity
            lowResourceBuildBonus = $lowResourceBuildBonus
            enemyMulticastProficiencyBonus = $enemyMulticastProficiencyBonus
        }
        progressionGate = @{
            itemlessMulticastRequested = $itemlessMulticastRequested
            highLevelThreshold = $multicastHighLevelThreshold
            requiredAffinityThreshold = $requiredAffinityThreshold
            requiredElementExperienceThreshold = $requiredElementExperienceThreshold
            requiresPlayerItemlessAffinityGate = $requiresPlayerItemlessAffinityGate
            elementChecks = $elementMasteryChecks
            valid = $playerItemlessAffinityGateValid
        }
        score = @{
            difficulty = $difficultyScore
            capacity = $capacityScore
            valid = $concurrentDifficultyValid
        }
    }
    compoundMulticast = @{
        requested = $compoundMulticastRequested
        sequenceCount = $compoundSequences.Count
        simultaneityWindowMs = $compoundSimultaneousWindowMs
        hasMinimumSequences = $hasMinimumCompoundSequences
        allSequencesValid = $allCompoundSequencesValid
        simultaneous = $compoundSimultaneousValid
        sequences = $compoundSequenceChecks
        valid = $compoundMulticastValid
    }
    sequence = @{
        provided = $sequence
        required = $requiredKeys
        length = $sequenceLength
        validLength = $sequenceLengthValid
        keysMatch = $keysMatch
    }
    timing = @{
        castWindowMs = $castWindowMs
        totalInputMs = $totalInputMs
        recoveryMs = $recoveryMs
        nonMagicCadenceMs = $nonMagicCadenceMs
        withinWindow = $withinWindow
        parityCadence = $parityCadence
    }
    delivery = @{
        requiresPrecompiledAid = $requiresPrecompiledAid
        requiresFullTome = $requiresFullTome
        requiresMaxLevelCasterAndWorldItems = $requiresMaxLevelCasterAndWorldItems
        scrollPrepared = [bool]$delivery.scrollPrepared
        itemComboPrepared = [bool]$delivery.itemComboPrepared
        autoSpellcastingEnabled = [bool]$delivery.autoSpellcastingEnabled
        macroApproved = [bool]$delivery.macroApproved
        fullTomeEquipped = $fullTomeEquipped
        rawAssemblyRequested = $rawAssemblyRequested
        requiredWorldItemIds = $requiredWorldItemIds
        worldItemSpellConstructorIds = $worldItemSpellConstructorIds
        hasPrecompiledAid = $hasPrecompiledAid
        hasRequiredWorldItems = $hasRequiredWorldItems
        valid = $highTierDeliveryValid
    }
    allowed = $allowed
    reasonCodes = $reasonCodes
}

$result | ConvertTo-Json -Depth 10 | Write-Output
if (-not $allowed) { exit 1 }
exit 0
