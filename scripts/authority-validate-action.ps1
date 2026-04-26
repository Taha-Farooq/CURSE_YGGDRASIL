param(
    [string]$RepoRoot = "",
    [string]$ActionJsonPath = "",
    [switch]$FailOnReject
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}
if ([string]::IsNullOrWhiteSpace($ActionJsonPath)) {
    $ActionJsonPath = Join-Path $RepoRoot "tests\fixtures\it-mgi-001-action-valid.json"
}

$service = Join-Path $RepoRoot "engine\net\authority-validation\authority-validation-service.ps1"
if (-not (Test-Path $service)) {
    throw "Missing authority service entrypoint: $service"
}

& $service -RepoRoot $RepoRoot -ActionJsonPath $ActionJsonPath -FailOnReject:$FailOnReject
if (-not $?) { exit 1 }
exit 0
