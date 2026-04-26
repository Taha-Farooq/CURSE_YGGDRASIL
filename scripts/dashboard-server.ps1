param(
    [int]$Port = 8765,
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$dashboardPath = Join-Path $repoRoot "dashboard\index.html"
$featureDir = Join-Path $repoRoot "automation\user-input"
$featureFile = Join-Path $featureDir "feature-requests.md"
$backlogDir = Join-Path $repoRoot "backlog"
$tasksFile = Join-Path $backlogDir "tasks.json"

if (-not (Test-Path $dashboardPath)) { throw "Missing dashboard/index.html" }
if (-not (Test-Path $featureDir)) { New-Item -ItemType Directory -Path $featureDir -Force | Out-Null }
if (-not (Test-Path $featureFile)) {
    Set-Content -Path $featureFile -Value "# Feature Requests`n" -Encoding UTF8
}
if (-not (Test-Path $backlogDir)) { New-Item -ItemType Directory -Path $backlogDir -Force | Out-Null }
if (-not (Test-Path $tasksFile)) {
    Set-Content -Path $tasksFile -Value "[]" -Encoding UTF8
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "[dashboard-server] Running at $prefix"
if (-not $NoOpen) {
    Start-Process $prefix | Out-Null
}

function Write-TextResponse($ctx, [string]$text, [int]$status = 200, [string]$contentType = "text/plain; charset=utf-8") {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $ctx.Response.StatusCode = $status
    $ctx.Response.ContentType = $contentType
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}

while ($listener.IsListening) {
    try {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $path = $req.Url.AbsolutePath
        $method = $req.HttpMethod

        if ($method -eq "GET" -and $path -eq "/") {
            $html = Get-Content $dashboardPath -Raw
            Write-TextResponse $ctx $html 200 "text/html; charset=utf-8"
            continue
        }

        if ($method -eq "GET" -and $path -eq "/api/status") {
            $progressScript = Join-Path $repoRoot "scripts\progress-check.ps1"
            $statusText = & $progressScript 2>&1 | Out-String
            Write-TextResponse $ctx $statusText 200 "text/plain; charset=utf-8"
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/run-daily") {
            $runScript = Join-Path $repoRoot "scripts\run-autonomous.ps1"
            $out = & $runScript -Once -Strict 2>&1 | Out-String
            Write-TextResponse $ctx "Daily cycle done.`n$out"
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/test-game") {
            & (Join-Path $repoRoot "scripts\ensure-program-exes.ps1") 2>&1 | Out-Null
            $exe = Join-Path $repoRoot "programs\game\GameLauncher.exe"
            $ps1 = Join-Path $repoRoot "programs\game\launch-game.ps1"
            if (Test-Path $exe) {
                $out = & $exe 2>&1 | Out-String
                Write-TextResponse $ctx ("Game launcher test complete.`n" + $out)
                continue
            }
            if (Test-Path $ps1) {
                $out = & $ps1 2>&1 | Out-String
                Write-TextResponse $ctx ("Game script test complete (EXE missing).`n" + $out)
                continue
            }
            Write-TextResponse $ctx "Game launcher not found. Build EXE with ./scripts/build-program-exes.ps1" 404
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/test-asset-adder") {
            & (Join-Path $repoRoot "scripts\ensure-program-exes.ps1") 2>&1 | Out-Null
            $exe = Join-Path $repoRoot "programs\asset-adder\AssetAdderLauncher.exe"
            $ps1 = Join-Path $repoRoot "programs\asset-adder\launch-asset-adder.ps1"
            if (Test-Path $exe) {
                $out = & $exe 2>&1 | Out-String
                Write-TextResponse $ctx ("Asset adder launcher test complete.`n" + $out)
                continue
            }
            if (Test-Path $ps1) {
                $out = & $ps1 2>&1 | Out-String
                Write-TextResponse $ctx ("Asset adder script test complete (EXE missing).`n" + $out)
                continue
            }
            Write-TextResponse $ctx "Asset adder launcher not found. Build EXE with ./scripts/build-program-exes.ps1" 404
            continue
        }

        if ($method -eq "GET" -and $path -eq "/api/features") {
            $text = Get-Content $featureFile -Raw
            Write-TextResponse $ctx $text 200 "text/plain; charset=utf-8"
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/features") {
            $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
            $body = $reader.ReadToEnd()
            $reader.Close()

            $json = $body | ConvertFrom-Json
            $text = [string]$json.text
            if ([string]::IsNullOrWhiteSpace($text)) {
                Write-TextResponse $ctx "Feature text is empty." 400
                continue
            }

            $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Add-Content -Path $featureFile -Value "`n## $stamp`n- $text`n"
            Write-TextResponse $ctx "Saved feature request."
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/promote-features") {
            $featureText = Get-Content $featureFile -Raw
            $lines = $featureText -split "`r?`n"
            $featureBullets = @($lines | Where-Object { $_ -match "^\s*-\s+" } | ForEach-Object { ($_ -replace "^\s*-\s+","").Trim() })

            $existingTasks = @()
            try {
                $existingTasks = Get-Content $tasksFile -Raw | ConvertFrom-Json
            }
            catch {
                $existingTasks = @()
            }

            $taskMap = @{}
            foreach ($t in $existingTasks) { $taskMap[$t.id] = $t }

            $added = 0
            foreach ($f in $featureBullets) {
                if ([string]::IsNullOrWhiteSpace($f)) { continue }
                $idCore = ($f.ToUpper() -replace "[^A-Z0-9]+","-").Trim("-")
                if ($idCore.Length -gt 56) { $idCore = $idCore.Substring(0,56).Trim("-") }
                $id = "TASK-USER-" + $idCore
                if (-not $taskMap.ContainsKey($id)) {
                    $taskMap[$id] = @{
                        id = $id
                        title = $f
                        source = "automation/user-input/feature-requests.md"
                        status = "todo"
                        priority = "high"
                        type = "user-feature"
                    }
                    $added++
                }
            }

            $final = $taskMap.Values | Sort-Object id
            $final | ConvertTo-Json -Depth 8 | Set-Content -Path $tasksFile -Encoding UTF8
            Write-TextResponse $ctx "Promoted features to backlog. Added: $added task(s)."
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/import-phase1") {
            $importScript = Join-Path $repoRoot "scripts\import-phase1-tasks.ps1"
            $result = & $importScript 2>&1 | Out-String
            Write-TextResponse $ctx $result
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/commit") {
            $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
            $body = $reader.ReadToEnd()
            $reader.Close()
            $json = $body | ConvertFrom-Json
            $msg = [string]$json.message
            if ([string]::IsNullOrWhiteSpace($msg)) {
                Write-TextResponse $ctx "Commit message is empty." 400
                continue
            }

            $gitStatus = & git -C $repoRoot status --porcelain 2>&1
            if ([string]::IsNullOrWhiteSpace(($gitStatus | Out-String).Trim())) {
                Write-TextResponse $ctx "No local changes to commit."
                continue
            }

            & git -C $repoRoot add . 2>&1 | Out-Null
            $commitOut = & git -C $repoRoot commit -m $msg 2>&1 | Out-String
            Write-TextResponse $ctx $commitOut
            continue
        }

        if ($method -eq "POST" -and $path -eq "/api/commit-push") {
            $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
            $body = $reader.ReadToEnd()
            $reader.Close()
            $json = $body | ConvertFrom-Json
            $msg = [string]$json.message
            if ([string]::IsNullOrWhiteSpace($msg)) {
                Write-TextResponse $ctx "Commit message is empty." 400
                continue
            }

            $remote = & git -C $repoRoot remote get-url origin 2>$null
            if ([string]::IsNullOrWhiteSpace(($remote | Out-String).Trim())) {
                Write-TextResponse $ctx "No git remote 'origin' configured. Aborting push." 400
                continue
            }

            $gitStatus = & git -C $repoRoot status --porcelain 2>&1
            $hadChanges = -not [string]::IsNullOrWhiteSpace(($gitStatus | Out-String).Trim())

            $commitOut = ""
            if ($hadChanges) {
                & git -C $repoRoot add . 2>&1 | Out-Null
                $commitOut = & git -C $repoRoot commit -m $msg 2>&1 | Out-String
            } else {
                $commitOut = "No local changes to commit.`n"
            }

            $pushOut = & git -C $repoRoot push 2>&1 | Out-String
            Write-TextResponse $ctx ($commitOut + "`n" + $pushOut)
            continue
        }

        Write-TextResponse $ctx "Not found" 404
    }
    catch {
        try {
            if ($ctx -and $ctx.Response -and $ctx.Response.OutputStream) {
                Write-TextResponse $ctx ("Server error: " + $_.Exception.Message) 500
            }
        }
        catch {}
    }
}

