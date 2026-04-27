param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-item-magic-modifier-valid.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing item magic modifier input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$allowed = $true
$reasonCodes = @()

$nowEpoch = [int64]$input.nowEpochSeconds
$baseValueMultiplier = [double]$input.baseCondition.valueMultiplier
$baseEffectivenessMultiplier = [double]$input.baseCondition.effectivenessMultiplier

$activeTemporary = @()
foreach ($e in @($input.temporaryEnchantments)) {
    $start = [int64]$e.startEpochSeconds
    $end = [int64]$e.expiryEpochSeconds
    $active = ($start -le $nowEpoch -and $nowEpoch -le $end)
    $row = @{
        id = [string]$e.id
        school = [string]$e.school
        active = $active
        valueBonusPct = [double]$e.valueBonusPct
        effectivenessBonusPct = [double]$e.effectivenessBonusPct
    }
    if ($end -lt $start) {
        $allowed = $false
        $reasonCodes += "AUTH-ITEM-TEMP-ENCHANT-DURATION-INVALID"
    }
    if ($active) { $activeTemporary += $row }
}

$permanent = @($input.permanentEnchantments)
$runes = @($input.runes)
$scripts = @($input.integratedMagicScripts)
$context = $input.context

$supportedTargets = @("value", "effectiveness")
$contextualMods = @()
foreach ($m in @($input.contextualModifiers)) {
    $target = [string]$m.target
    if ($supportedTargets -notcontains $target) {
        $allowed = $false
        $reasonCodes += "AUTH-ITEM-CONTEXT-MODIFIER-TARGET-INVALID"
        continue
    }

    $envOk = (([string]$m.environment -eq "any") -or ([string]$m.environment -eq [string]$context.environment))
    $classOk = (([string]$m.class -eq "any") -or ([string]$m.class -eq [string]$context.class))
    $raceOk = (([string]$m.race -eq "any") -or ([string]$m.race -eq [string]$context.race))
    $subclassOk = (([string]$m.subclass -eq "any") -or ([string]$m.subclass -eq [string]$context.subclass))
    $setOk = (([string]$m.setTag -eq "any") -or (@($context.activeSetTags) -contains [string]$m.setTag))
    $magicStateOk = (([string]$m.magicState -eq "any") -or ([string]$m.magicState -eq [string]$context.magicState))
    $conditionMin = [double]$m.conditionMinScore
    $conditionOk = ([double]$input.conditionScore -ge $conditionMin)
    $applies = ($envOk -and $classOk -and $raceOk -and $subclassOk -and $setOk -and $magicStateOk -and $conditionOk)

    $contextualMods += @{
        id = [string]$m.id
        target = $target
        pct = [double]$m.pct
        applies = $applies
    }
}

$valuePct = 0.0
$effectivenessPct = 0.0
foreach ($e in $activeTemporary) {
    $valuePct += [double]$e.valueBonusPct
    $effectivenessPct += [double]$e.effectivenessBonusPct
}
foreach ($e in $permanent) {
    $valuePct += [double]$e.valueBonusPct
    $effectivenessPct += [double]$e.effectivenessBonusPct
}
foreach ($r in $runes) {
    $valuePct += [double]$r.valueBonusPct
    $effectivenessPct += [double]$r.effectivenessBonusPct
}
foreach ($m in @($contextualMods | Where-Object { [bool]$_.applies })) {
    if ([string]$m.target -eq "value") { $valuePct += [double]$m.pct }
    if ([string]$m.target -eq "effectiveness") { $effectivenessPct += [double]$m.pct }
}

$scriptAutomationScore = 0
foreach ($s in $scripts) {
    if (-not [bool]$s.authorityApproved) {
        $allowed = $false
        $reasonCodes += "AUTH-ITEM-INTEGRATED-SCRIPT-NOT-APPROVED"
    }
    $scriptAutomationScore += [int]$s.automationScore
}

$valueMultiplier = [Math]::Round($baseValueMultiplier * (1.0 + ($valuePct / 100.0)), 4)
$effectivenessMultiplier = [Math]::Round($baseEffectivenessMultiplier * (1.0 + ($effectivenessPct / 100.0)), 4)

if (@($activeTemporary).Count -gt 0) { $reasonCodes += "AUTH-ITEM-TEMP-ENCHANT-ACTIVE" }
if (@($permanent).Count -gt 0) { $reasonCodes += "AUTH-ITEM-PERM-ENCHANT-APPLIED" }
if (@($runes).Count -gt 0) { $reasonCodes += "AUTH-ITEM-RUNES-APPLIED" }
if (@($scripts).Count -gt 0 -and $allowed) { $reasonCodes += "AUTH-ITEM-INTEGRATED-SCRIPT-ACTIVE" }
if (@($contextualMods | Where-Object { [bool]$_.applies }).Count -gt 0) { $reasonCodes += "AUTH-ITEM-CONTEXT-MODIFIERS-APPLIED" }
if ($allowed) { $reasonCodes += "AUTH-ITEM-MODIFIER-RESOLUTION-ALLOWED" }

$result = @{
    resolver = "item_magic_modifier_resolver_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    itemId = [string]$input.itemId
    allowed = $allowed
    enchantments = @{
        temporary = @{
            total = @($input.temporaryEnchantments).Count
            active = @($activeTemporary).Count
            activeItems = $activeTemporary
        }
        permanent = @{
            total = @($permanent).Count
            items = $permanent
        }
    }
    runes = @{
        total = @($runes).Count
        items = $runes
    }
    integratedScripts = @{
        total = @($scripts).Count
        automationScore = $scriptAutomationScore
        items = $scripts
    }
    contextualModifiers = $contextualMods
    multipliers = @{
        baseValueMultiplier = $baseValueMultiplier
        baseEffectivenessMultiplier = $baseEffectivenessMultiplier
        finalValueMultiplier = $valueMultiplier
        finalEffectivenessMultiplier = $effectivenessMultiplier
    }
    reasonCodes = @($reasonCodes | Select-Object -Unique)
}

$result | ConvertTo-Json -Depth 12 | Write-Output
if (-not $allowed) { exit 1 }
exit 0
