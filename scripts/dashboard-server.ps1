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
$botReportsDir = Join-Path $repoRoot "reports\bots"

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

function Write-JsonResponse($ctx, $obj, [int]$status = 200) {
    $json = $obj | ConvertTo-Json -Depth 8
    Write-TextResponse $ctx $json $status "application/json; charset=utf-8"
}

function Get-AuthCodeSeverity([string]$code) {
    if ([string]::IsNullOrWhiteSpace($code)) { return "info" }
    if ($code -like "AUTH-SEC-*") { return "critical" }
    if ($code -like "AUTH-BUDGET-*") { return "warning" }
    if ($code -like "AUTH-INTEROP-*") { return "warning" }
    return "info"
}

function Get-SeverityRank([string]$severity) {
    switch ($severity) {
        "critical" { return 3 }
        "warning" { return 2 }
        "info" { return 1 }
        default { return 0 }
    }
}

function Get-TopAuthorityRejections([int]$MaxFiles = 80) {
    $result = [ordered]@{
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        filesScanned = 0
        eventsWithCodes = 0
        trendWindow = @{
            currentFiles = 0
            previousFiles = 0
        }
        topReasonCodes = @()
    }

    if (-not (Test-Path $botReportsDir)) {
        return $result
    }

    $counts = @{}
    $previousCounts = @{}
    $files = Get-ChildItem -Path $botReportsDir -Filter "*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First $MaxFiles
    $result.filesScanned = @($files).Count
    $split = [math]::Floor(@($files).Count / 2)
    $result.trendWindow.currentFiles = $split
    $result.trendWindow.previousFiles = (@($files).Count - $split)

    for ($idx = 0; $idx -lt @($files).Count; $idx++) {
        $file = $files[$idx]
        try {
            $report = Get-Content $file.FullName -Raw | ConvertFrom-Json
        } catch {
            continue
        }

        if ($null -eq $report.checks) { continue }
        foreach ($check in @($report.checks)) {
            if ($null -eq $check.details) { continue }
            $details = [string]$check.details
            if ($details -notmatch "reasonCodes=") { continue }

            $raw = ($details -split "reasonCodes=", 2)[1]
            $codes = @($raw -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -like "AUTH-*" })
            if (@($codes).Count -eq 0) { continue }

            $result.eventsWithCodes++
            foreach ($code in $codes) {
                if (-not $counts.ContainsKey($code)) { $counts[$code] = 0 }
                $counts[$code]++
                if ($idx -ge $split) {
                    if (-not $previousCounts.ContainsKey($code)) { $previousCounts[$code] = 0 }
                    $previousCounts[$code]++
                }
            }
        }
    }

    $top = @(
        $counts.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            $severity = Get-AuthCodeSeverity $_.Key
            $currentCount = $_.Value
            $previousCount = $(if ($previousCounts.ContainsKey($_.Key)) { $previousCounts[$_.Key] } else { 0 })
            $delta = ($currentCount - $previousCount)
            [ordered]@{
                code = $_.Key
                count = $currentCount
                previousCount = $previousCount
                delta = $delta
                severity = $severity
                severityRank = (Get-SeverityRank $severity)
            }
        }
    )
    $result.topReasonCodes = $top
    return $result
}

function Get-LatestFailingChecks([int]$MaxFiles = 80, [int]$MaxItems = 20) {
    $result = [ordered]@{
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        filesScanned = 0
        failingChecks = @()
    }

    if (-not (Test-Path $botReportsDir)) {
        return $result
    }

    $items = @()
    $files = Get-ChildItem -Path $botReportsDir -Filter "*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First $MaxFiles
    $result.filesScanned = @($files).Count

    foreach ($file in $files) {
        $report = $null
        try {
            $report = Get-Content $file.FullName -Raw | ConvertFrom-Json
        } catch {
            continue
        }
        if ($null -eq $report -or $null -eq $report.checks) { continue }

        foreach ($check in @($report.checks)) {
            $isFail = $false
            if ($null -ne $check.passed -and ($check.passed -eq $false)) { $isFail = $true }
            if ($null -ne $check.status -and ([string]$check.status).ToLowerInvariant() -eq "fail") { $isFail = $true }
            if (-not $isFail) { continue }

            $items += [ordered]@{
                timestampUtc = $report.timestampUtc
                reportFile = $file.Name
                bot = $(if ($null -ne $report.bot) { [string]$report.bot } else { "" })
                testId = $(if ($null -ne $report.testId) { [string]$report.testId } else { "" })
                check = $(if ($null -ne $check.check) { [string]$check.check } else { "" })
                details = $(if ($null -ne $check.details) { [string]$check.details } else { "" })
                severity = "info"
                severityRank = 1
            }
        }
    }

    foreach ($item in $items) {
        $details = [string]$item.details
        $codes = @()
        if ($details -match "reasonCodes=") {
            $raw = ($details -split "reasonCodes=", 2)[1]
            $codes = @($raw -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -like "AUTH-*" })
        }
        if (@($codes).Count -gt 0) {
            $maxRank = 1
            $maxSeverity = "info"
            foreach ($code in $codes) {
                $sev = Get-AuthCodeSeverity $code
                $rank = Get-SeverityRank $sev
                if ($rank -gt $maxRank) {
                    $maxRank = $rank
                    $maxSeverity = $sev
                }
            }
            $item.severity = $maxSeverity
            $item.severityRank = $maxRank
        }
    }

    $result.failingChecks = @($items | Select-Object -First $MaxItems)
    return $result
}

function Get-TestAutomationHealth {
    $result = [ordered]@{
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        contractCoverage = $null
        criticalRegressionGuard = $null
    }

    $coverageScript = Join-Path $repoRoot "scripts\check-test-contract-coverage.ps1"
    $criticalGuardScript = Join-Path $repoRoot "scripts\check-critical-regressions.ps1"

    try {
        $coverage = & $coverageScript -RepoRoot $repoRoot | ConvertFrom-Json
        $result.contractCoverage = $coverage
    } catch {
        $result.contractCoverage = @{
            passed = $false
            error = $_.Exception.Message
        }
    }

    try {
        $critical = & $criticalGuardScript -RepoRoot $repoRoot | ConvertFrom-Json
        $result.criticalRegressionGuard = $critical
    } catch {
        $result.criticalRegressionGuard = @{
            passed = $false
            error = $_.Exception.Message
        }
    }

    return $result
}

function Get-LatestReleaseReadinessSnapshot {
    $result = [ordered]@{
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        hasSnapshot = $false
        snapshotFile = $null
        snapshot = $null
    }

    $reportsDir = Join-Path $repoRoot "reports"
    if (-not (Test-Path $reportsDir)) {
        return $result
    }

    $file = Get-ChildItem -Path $reportsDir -Filter "release-readiness-snapshot-*.json" | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $file) {
        return $result
    }

    try {
        $snapshot = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $result.hasSnapshot = $true
        $result.snapshotFile = $file.Name
        $result.snapshot = $snapshot
    }
    catch {
        $result.hasSnapshot = $false
        $result.snapshotFile = $file.Name
        $result.snapshot = @{
            error = $_.Exception.Message
        }
    }

    return $result
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

        if ($method -eq "GET" -and $path -eq "/api/auth-rejections") {
            $payload = Get-TopAuthorityRejections
            Write-JsonResponse $ctx $payload 200
            continue
        }

        if ($method -eq "GET" -and $path -eq "/api/failing-checks") {
            $payload = Get-LatestFailingChecks
            Write-JsonResponse $ctx $payload 200
            continue
        }

        if ($method -eq "GET" -and $path -eq "/api/test-health") {
            $payload = Get-TestAutomationHealth
            Write-JsonResponse $ctx $payload 200
            continue
        }

        if ($method -eq "GET" -and $path -eq "/api/release-readiness") {
            $payload = Get-LatestReleaseReadinessSnapshot
            Write-JsonResponse $ctx $payload 200
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

        if ($method -eq "POST" -and $path -eq "/api/import-legacy-triage") {
            $importScript = Join-Path $repoRoot "scripts\import-legacy-triage-tasks.ps1"
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

