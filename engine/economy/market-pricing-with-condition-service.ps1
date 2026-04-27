param(
    [string]$RepoRoot = "",
    [string]$InputJsonPath = ""
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
}
if ([string]::IsNullOrWhiteSpace($InputJsonPath)) {
    $InputJsonPath = Join-Path $RepoRoot "tests\fixtures\phase2-market-pricing-with-condition-input.json"
}
if (-not (Test-Path $InputJsonPath)) { throw "Missing market pricing input: $InputJsonPath" }

$input = Get-Content $InputJsonPath -Raw | ConvertFrom-Json
$basePrice = [double]$input.basePrice
$marketPressure = [double]$input.marketPressure
$conditionMultiplier = [double]$input.conditionValueMultiplier
$demandScalar = [double]$input.demandScalar

$pressureMultiplier = [Math]::Max(0.7, 1.0 + ($marketPressure * 0.08))
$demandMultiplier = [Math]::Max(0.8, 1.0 + ($demandScalar * 0.05))
$baseResolvedPrice = $basePrice * $conditionMultiplier * $pressureMultiplier * $demandMultiplier

$location = $null
$kingdom = $null
$currency = $null
if ($null -ne $input.locationProfile) { $location = $input.locationProfile }
if ($null -ne $input.kingdomProfile) { $kingdom = $input.kingdomProfile }
if ($null -ne $input.currencyProfile) { $currency = $input.currencyProfile }

$locationDemandDelta = 0.0
$logisticsFriction = 0.0
$tradeRisk = 0.0
$locationTaxRate = 0.0
if ($null -ne $location) {
    if ($null -ne $location.demandDelta) { $locationDemandDelta = [double]$location.demandDelta }
    if ($null -ne $location.logisticsFriction) { $logisticsFriction = [double]$location.logisticsFriction }
    if ($null -ne $location.tradeRisk) { $tradeRisk = [double]$location.tradeRisk }
    if ($null -ne $location.taxRate) { $locationTaxRate = [double]$location.taxRate }
}

$kingdomTaxModifier = 0.0
$subsidyRate = 0.0
$stabilityDelta = 0.0
if ($null -ne $kingdom) {
    if ($null -ne $kingdom.taxModifier) { $kingdomTaxModifier = [double]$kingdom.taxModifier }
    if ($null -ne $kingdom.subsidyRate) { $subsidyRate = [double]$kingdom.subsidyRate }
    if ($null -ne $kingdom.stabilityDelta) { $stabilityDelta = [double]$kingdom.stabilityDelta }
}

$locationDemandMultiplier = [Math]::Max(0.75, 1.0 + ($locationDemandDelta * 0.04))
$logisticsMultiplier = [Math]::Max(0.85, 1.0 + ($logisticsFriction * 0.03))
$tradeRiskMultiplier = [Math]::Max(0.85, 1.0 + ($tradeRisk * 0.02))
$stabilityMultiplier = [Math]::Max(0.85, 1.0 + ($stabilityDelta * 0.02))
$taxMultiplier = [Math]::Max(0.5, 1.0 + $locationTaxRate + $kingdomTaxModifier)
$subsidyMultiplier = [Math]::Max(0.6, 1.0 - $subsidyRate)

$regionalPrice = $baseResolvedPrice * $locationDemandMultiplier * $logisticsMultiplier * $tradeRiskMultiplier * $stabilityMultiplier * $taxMultiplier * $subsidyMultiplier

$baseCurrencyCode = "BASE"
$storeCurrencyCode = "BASE"
$quoteCurrencyCode = "BASE"
$storeToBaseRate = 1.0
$quoteToBaseRate = 1.0
if ($null -ne $currency) {
    if (-not [string]::IsNullOrWhiteSpace([string]$currency.baseCurrencyCode)) { $baseCurrencyCode = [string]$currency.baseCurrencyCode }
    if (-not [string]::IsNullOrWhiteSpace([string]$currency.storeCurrencyCode)) { $storeCurrencyCode = [string]$currency.storeCurrencyCode }
    if (-not [string]::IsNullOrWhiteSpace([string]$currency.quoteCurrencyCode)) { $quoteCurrencyCode = [string]$currency.quoteCurrencyCode }
    if ($null -ne $currency.storeToBaseRate) { $storeToBaseRate = [double]$currency.storeToBaseRate }
    if ($null -ne $currency.quoteToBaseRate) { $quoteToBaseRate = [double]$currency.quoteToBaseRate }
}
if ($storeToBaseRate -le 0) { $storeToBaseRate = 1.0 }
if ($quoteToBaseRate -le 0) { $quoteToBaseRate = 1.0 }

$priceInStoreCurrency = [Math]::Round($regionalPrice, 2)
$priceInBaseCurrency = [Math]::Round(($priceInStoreCurrency * $storeToBaseRate), 2)
$finalPrice = [Math]::Round(($priceInBaseCurrency / $quoteToBaseRate), 2)

$result = @{
    service = "market_pricing_with_condition_service_v1"
    timestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    deterministic = $true
    authorityValidated = $true
    pricing = @{
        basePrice = $basePrice
        conditionValueMultiplier = $conditionMultiplier
        marketPressure = $marketPressure
        pressureMultiplier = [Math]::Round($pressureMultiplier, 4)
        demandScalar = $demandScalar
        demandMultiplier = [Math]::Round($demandMultiplier, 4)
        locationDemandDelta = $locationDemandDelta
        locationDemandMultiplier = [Math]::Round($locationDemandMultiplier, 4)
        logisticsFriction = $logisticsFriction
        logisticsMultiplier = [Math]::Round($logisticsMultiplier, 4)
        tradeRisk = $tradeRisk
        tradeRiskMultiplier = [Math]::Round($tradeRiskMultiplier, 4)
        stabilityDelta = $stabilityDelta
        stabilityMultiplier = [Math]::Round($stabilityMultiplier, 4)
        locationTaxRate = $locationTaxRate
        kingdomTaxModifier = $kingdomTaxModifier
        taxMultiplier = [Math]::Round($taxMultiplier, 4)
        subsidyRate = $subsidyRate
        subsidyMultiplier = [Math]::Round($subsidyMultiplier, 4)
        regionalPriceInStoreCurrency = $priceInStoreCurrency
        baseCurrencyCode = $baseCurrencyCode
        storeCurrencyCode = $storeCurrencyCode
        quoteCurrencyCode = $quoteCurrencyCode
        storeToBaseRate = [Math]::Round($storeToBaseRate, 6)
        quoteToBaseRate = [Math]::Round($quoteToBaseRate, 6)
        finalPriceInQuoteCurrency = $finalPrice
        finalPrice = $finalPrice
    }
    reasonCodes = @(
        "AUTH-ECON-PRICE-CONDITION-APPLIED",
        "AUTH-ECON-PRICE-LOCATION-KINGDOM-APPLIED",
        "AUTH-ECON-PRICE-CURRENCY-CONVERSION-APPLIED"
    )
}

$result | ConvertTo-Json -Depth 8 | Write-Output
exit 0
