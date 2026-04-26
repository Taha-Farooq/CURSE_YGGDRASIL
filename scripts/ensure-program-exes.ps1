param()

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

$gameProj = Join-Path $repoRoot "programs\game\launcher-src\GameLauncher.csproj"
$gameSrc = Join-Path $repoRoot "programs\game\launcher-src\Program.cs"
$gameExe = Join-Path $repoRoot "programs\game\GameLauncher.exe"

$assetProj = Join-Path $repoRoot "programs\asset-adder\launcher-src\AssetAdderLauncher.csproj"
$assetSrc = Join-Path $repoRoot "programs\asset-adder\launcher-src\Program.cs"
$assetExe = Join-Path $repoRoot "programs\asset-adder\AssetAdderLauncher.exe"

function NeedsRebuild([string]$exePath, [string[]]$inputs) {
    if (-not (Test-Path $exePath)) { return $true }
    $exeTime = (Get-Item $exePath).LastWriteTimeUtc
    foreach ($i in $inputs) {
        if (Test-Path $i) {
            if ((Get-Item $i).LastWriteTimeUtc -gt $exeTime) {
                return $true
            }
        }
    }
    return $false
}

$rebuildGame = NeedsRebuild $gameExe @($gameProj, $gameSrc)
$rebuildAsset = NeedsRebuild $assetExe @($assetProj, $assetSrc)

if ($rebuildGame -or $rebuildAsset) {
    Write-Output "Program EXEs are stale/missing. Rebuilding..."
    & (Join-Path $repoRoot "scripts\build-program-exes.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Failed rebuilding program EXEs." }
    Write-Output "Program EXEs rebuilt."
}
else {
    Write-Output "Program EXEs already up to date."
}

