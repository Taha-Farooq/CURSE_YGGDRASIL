param()

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$triagePath = Join-Path $repoRoot "LEGACY_DOC_TRIAGE_2022_2025.md"
$tasksPath = Join-Path $repoRoot "backlog\tasks.json"
$backlogDir = Split-Path $tasksPath -Parent

if (-not (Test-Path $triagePath)) {
    throw "Missing LEGACY_DOC_TRIAGE_2022_2025.md"
}
if (-not (Test-Path $backlogDir)) { New-Item -ItemType Directory -Path $backlogDir -Force | Out-Null }
if (-not (Test-Path $tasksPath)) { Set-Content -Path $tasksPath -Value "[]" -Encoding UTF8 }

$content = Get-Content $triagePath -Raw

# Parse lines under "## 5) Immediate Backlog Inserts"
$sectionPattern = "(?s)## 5\)\s+Immediate Backlog Inserts.*?\n(.*?)\n## 6\)"
$sectionMatch = [regex]::Match($content, $sectionPattern)
if (-not $sectionMatch.Success) {
    throw "Could not locate immediate backlog insert section."
}

$section = $sectionMatch.Groups[1].Value
$lineMatches = [regex]::Matches($section, "^\s*\d+\.\s+(.+)$", [System.Text.RegularExpressions.RegexOptions]::Multiline)

$existing = @()
try {
    $existing = Get-Content $tasksPath -Raw | ConvertFrom-Json
} catch {
    $existing = @()
}

$taskMap = @{}
foreach ($t in $existing) { $taskMap[$t.id] = $t }

$added = 0
foreach ($m in $lineMatches) {
    $title = $m.Groups[1].Value.Trim().TrimEnd(".")
    if ([string]::IsNullOrWhiteSpace($title)) { continue }
    $idCore = ($title.ToUpper() -replace "[^A-Z0-9]+","-").Trim("-")
    if ($idCore.Length -gt 64) { $idCore = $idCore.Substring(0,64).Trim("-") }
    $id = "TASK-LEGACY-" + $idCore
    if (-not $taskMap.ContainsKey($id)) {
        $taskMap[$id] = @{
            id = $id
            title = $title
            source = "LEGACY_DOC_TRIAGE_2022_2025.md"
            status = "todo"
            priority = "high"
            type = "legacy-triage"
        }
        $added++
    }
}

$final = $taskMap.Values | Sort-Object id
$final | ConvertTo-Json -Depth 8 | Set-Content -Path $tasksPath -Encoding UTF8

Write-Output "Imported legacy triage tasks. Added: $added"

