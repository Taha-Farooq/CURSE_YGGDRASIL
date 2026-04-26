param()

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Get-BestTargetFramework {
    $sdks = & dotnet --list-sdks 2>$null
    if (-not $sdks) { throw "dotnet SDK not found." }

    $has8 = $false
    $has7 = $false
    foreach ($line in $sdks) {
        if ($line -match "^\s*8\.") { $has8 = $true }
        if ($line -match "^\s*7\.") { $has7 = $true }
    }

    if ($has8) { return "net8.0-windows" }
    if ($has7) { return "net7.0-windows" }
    throw "No supported SDK found (need .NET 7 or 8)."
}

$targetFramework = Get-BestTargetFramework
Write-Host "[build-program-exes] Using target framework: $targetFramework"

Write-Host "[build-program-exes] Building GameLauncher.exe ..."
dotnet publish (Join-Path $repoRoot "programs\game\launcher-src\GameLauncher.csproj") -c Release -f $targetFramework -r win-x64 --self-contained false -o (Join-Path $repoRoot "programs\game")
if ($LASTEXITCODE -ne 0) { throw "Failed to build GameLauncher.exe" }

Write-Host "[build-program-exes] Building AssetAdderLauncher.exe ..."
dotnet publish (Join-Path $repoRoot "programs\asset-adder\launcher-src\AssetAdderLauncher.csproj") -c Release -f $targetFramework -r win-x64 --self-contained false -o (Join-Path $repoRoot "programs\asset-adder")
if ($LASTEXITCODE -ne 0) { throw "Failed to build AssetAdderLauncher.exe" }

Write-Host "[build-program-exes] Done."
Write-Host "Generated:"
Write-Host "- programs/game/GameLauncher.exe"
Write-Host "- programs/asset-adder/AssetAdderLauncher.exe"

