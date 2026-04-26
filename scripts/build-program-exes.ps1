param()

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Write-Host "[build-program-exes] Building GameLauncher.exe ..."
dotnet publish (Join-Path $repoRoot "programs\game\launcher-src\GameLauncher.csproj") -c Release -r win-x64 --self-contained false -o (Join-Path $repoRoot "programs\game")
if ($LASTEXITCODE -ne 0) { throw "Failed to build GameLauncher.exe" }

Write-Host "[build-program-exes] Building AssetAdderLauncher.exe ..."
dotnet publish (Join-Path $repoRoot "programs\asset-adder\launcher-src\AssetAdderLauncher.csproj") -c Release -r win-x64 --self-contained false -o (Join-Path $repoRoot "programs\asset-adder")
if ($LASTEXITCODE -ne 0) { throw "Failed to build AssetAdderLauncher.exe" }

Write-Host "[build-program-exes] Done."
Write-Host "Generated:"
Write-Host "- programs/game/GameLauncher.exe"
Write-Host "- programs/asset-adder/AssetAdderLauncher.exe"

