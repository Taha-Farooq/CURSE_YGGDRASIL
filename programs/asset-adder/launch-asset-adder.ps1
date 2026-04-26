param(
    [string]$SourcePath = "",
    [string]$Profile = "default"
)

$ErrorActionPreference = "Stop"
Write-Host "[asset-adder] Launch requested. Profile=$Profile"
if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
    Write-Host "[asset-adder] SourcePath=$SourcePath"
}
Write-Host "[asset-adder] Placeholder launcher: wire this to content import/register pipeline."
exit 0

