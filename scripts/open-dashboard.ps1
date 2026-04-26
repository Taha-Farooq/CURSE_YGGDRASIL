param(
    [int]$Port = 8765
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$serverScript = Join-Path $repoRoot "scripts\dashboard-server.ps1"

Write-Host "[open-dashboard] Starting dashboard server..."
Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$serverScript`" -Port $Port"
Start-Sleep -Seconds 1
Start-Process "http://localhost:$Port/"
Write-Host "[open-dashboard] Dashboard opened at http://localhost:$Port/"

