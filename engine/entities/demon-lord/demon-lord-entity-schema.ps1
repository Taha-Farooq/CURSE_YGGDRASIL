param(
    [string]$EntityId = "demon-lord-001",
    [string]$DomainId = "domain-ashen-vale",
    [string]$Temperament = "pragmatic"
)

$ErrorActionPreference = "Stop"

$valid = @("hostile","friendly","pragmatic","chaotic","lawful")
if ($valid -notcontains $Temperament) { throw "Invalid temperament: $Temperament" }

$schema = @{
    schema = "demon_lord_entity_v1"
    entityId = $EntityId
    class = "demon_lord"
    domainId = $DomainId
    temperament = $Temperament
    commandChannels = @("warband", "logistics", "ritual")
    domainEffects = @("fear_aura", "corruption_pulse")
}

$schema | ConvertTo-Json -Depth 8 | Write-Output
exit 0
