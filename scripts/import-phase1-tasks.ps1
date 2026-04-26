param()

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$phasePath = Join-Path $repoRoot "PHASE1_IMPLEMENTATION_PACK.md"
$tasksPath = Join-Path $repoRoot "backlog\tasks.json"
$backlogDir = Split-Path $tasksPath -Parent

if (-not (Test-Path $phasePath)) {
    throw "Missing PHASE1_IMPLEMENTATION_PACK.md"
}
if (-not (Test-Path $backlogDir)) { New-Item -ItemType Directory -Path $backlogDir -Force | Out-Null }
if (-not (Test-Path $tasksPath)) { Set-Content -Path $tasksPath -Value "[]" -Encoding UTF8 }

$phase = Get-Content $phasePath -Raw
$matches = [regex]::Matches($phase, "##\s+Task\s+(\d+)\s+-\s+([^\r\n]+)")

$existing = @()
try {
    $existing = Get-Content $tasksPath -Raw | ConvertFrom-Json
} catch {
    $existing = @()
}

$taskMap = @{}
foreach ($t in $existing) { $taskMap[$t.id] = $t }

$added = 0
foreach ($m in $matches) {
    $num = $m.Groups[1].Value
    $title = $m.Groups[2].Value.Trim()
    $id = "TASK-PHASE1-" + $num.PadLeft(2,'0') + "-" + (($title.ToUpper() -replace "[^A-Z0-9]+","-").Trim("-"))
    if (-not $taskMap.ContainsKey($id)) {
        $taskMap[$id] = @{
            id = $id
            title = $title
            source = "PHASE1_IMPLEMENTATION_PACK.md"
            status = "todo"
            priority = "high"
            type = "phase1"
        }
        $added++
    }
}

$final = $taskMap.Values | Sort-Object id
$final | ConvertTo-Json -Depth 8 | Set-Content -Path $tasksPath -Encoding UTF8
Write-Output "Imported Phase 1 tasks. Added: $added"

