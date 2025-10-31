# Portable Sysinternals System Tester
# Created by Pacific Northwest Computers - 2025
# Complete Production Version - v2.2

param([switch]$AutoRun)

# Constants
$script:VERSION = "2.2"
$script:DXDIAG_TIMEOUT = 45
$script:ENERGY_DURATION = 15
$script:CPU_TEST_SECONDS = 10
$script:MAX_PATH_LENGTH = 240
$script:MIN_TOOL_SIZE_KB = 50

# Paths
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$DriveLetter = (Split-Path -Qualifier $ScriptRoot).TrimEnd('\')
$SysinternalsPath = Join-Path $ScriptRoot "Sysinternals"

# Global state
$script:TestResults = @()
$script:IsAdmin = $false
$script:LaunchedViaBatch = $false

Write-Host "========================================" -ForegroundColor Green
Write-Host "  SYSINTERNALS TESTER v$script:VERSION" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Running from: $DriveLetter" -ForegroundColor Cyan

# Detect if launched via batch file
function Test-LauncherAwareness {
    try {
        $parentPID = (Get-Process -Id $PID).Parent.Id
        if ($parentPID) {
            $parentProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$parentPID" -ErrorAction Stop
            if ($parentProcess.Name -eq "cmd.exe") {
                $script:LaunchedViaBatch = $true
                Write-Host "Launcher: Batch file detected" -ForegroundColor DarkGray
                return $true
            }
        }
    } catch {}
    Write-Host "Launcher: Direct PowerShell execution" -ForegroundColor DarkGray
    return $false
}

# Check admin privileges
function Test-AdminPrivileges {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $script:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($script:IsAdmin) {
            Write-Host "Administrator: YES" -ForegroundColor Green
        } else {
            Write-Host "Administrator: NO (limited functionality)" -ForegroundColor Yellow
        }
        return $script:IsAdmin
    } catch {
        return $false
    }
}

# Tool integrity verification
function Test-ToolIntegrity {
    param([string]$ToolName)
    
    $toolPath = Join-Path $SysinternalsPath "$ToolName.exe"
    
    # Check if file exists
    if (!(Test-Path $toolPath)) {
        return @{Status="MISSING"; Details="File not found"}
    }
    
    # Check file size
    $fileInfo = Get-Item $toolPath
    if ($fileInfo.Length -lt ($script:MIN_TOOL_SIZE_KB * 1KB)) {
        return @{Status="BAD_SIZE"; Details="File too small: $($fileInfo.Length) bytes"}
    }
    
    # Check digital signature
    try {
        $signature = Get-AuthenticodeSignature $toolPath -ErrorAction Stop
        
        if ($signature.Status -eq "Valid") {
            $subject = $signature.SignerCertificate.Subject
            if ($subject -match "Microsoft Corporation") {
                return @{Status="VALID_MS"; Details="Valid Microsoft signature"}
            } else {
                return @{Status="VALID_OTHER"; Details="Valid non-Microsoft signature: $subject"}
            }
        } elseif ($signature.Status -eq "NotSigned") {
            return @{Status="NOT_SIGNED"; Details="File is not digitally signed"}
        } else {
            return @{Status="BAD_SIGNATURE"; Details="Signature status: $($signature.Status)"}
        }
    } catch {
        return @{Status="CHECK_FAILED"; Details="Error: $($_.Exception.Message)"}
    }
}

# Verify all tools
function Test-ToolVerification {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  TOOL INTEGRITY VERIFICATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $allTools = @(
    "psinfo","coreinfo","pslist","handle","clockres",
    "autorunsc","du","streams","contig","sigcheck",
    "testlimit","diskext","listdlls"
    )
    
    $stats = @{
        VALID_MS=0; VALID_OTHER=0; NOT_SIGNED=0
        BAD_SIZE=0; BAD_SIGNATURE=0; MISSING=0; CHECK_FAILED=0
    }
    
    foreach ($tool in $allTools) {
        $result = Test-ToolIntegrity -ToolName $tool
        $stats[$result.Status]++
        
        $color = switch ($result.Status) {
            "VALID_MS" { "Green" }
            "VALID_OTHER" { "Cyan" }
            "NOT_SIGNED" { "Yellow" }
            "MISSING" { "Red" }
            "BAD_SIZE" { "Red" }
            "BAD_SIGNATURE" { "Red" }
            "CHECK_FAILED" { "Yellow" }
        }
        
        $statusText = switch ($result.Status) {
            "VALID_MS" { "[OK-MS]" }
            "VALID_OTHER" { "[OK-OTHER]" }
            "NOT_SIGNED" { "[NO-SIG]" }
            "MISSING" { "[MISSING]" }
            "BAD_SIZE" { "[BAD-SIZE]" }
            "BAD_SIGNATURE" { "[BAD-SIG]" }
            "CHECK_FAILED" { "[ERROR]" }
        }
        
        Write-Host "$statusText $tool" -ForegroundColor $color
        if ($result.Details -and $result.Status -ne "VALID_MS") {
            Write-Host "         $($result.Details)" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "SUMMARY:" -ForegroundColor White
    Write-Host "  Valid (Microsoft): $($stats.VALID_MS)" -ForegroundColor Green
    Write-Host "  Valid (Other): $($stats.VALID_OTHER)" -ForegroundColor Cyan
    Write-Host "  Not Signed: $($stats.NOT_SIGNED)" -ForegroundColor Yellow
    Write-Host "  Bad Size: $($stats.BAD_SIZE)" -ForegroundColor Red
    Write-Host "  Bad Signature: $($stats.BAD_SIGNATURE)" -ForegroundColor Red
    Write-Host "  Missing: $($stats.MISSING)" -ForegroundColor Red
    Write-Host "  Check Failed: $($stats.CHECK_FAILED)" -ForegroundColor Yellow
    Write-Host ""
    
    $totalIssues = $stats.BAD_SIZE + $stats.BAD_SIGNATURE + $stats.MISSING + $stats.CHECK_FAILED
    if ($totalIssues -eq 0 -and $stats.VALID_MS -gt 0) {
        Write-Host "STATUS: All present tools are verified and safe to use" -ForegroundColor Green
    } elseif ($totalIssues -gt 0) {
        Write-Host "STATUS: $totalIssues issue(s) detected - recommend re-download" -ForegroundColor Yellow
        if ($script:LaunchedViaBatch) {
            Write-Host "ACTION: Use Batch Menu Option 5 to re-download tools" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

# Initialize environment
function Initialize-Environment {
    Write-Host "Initializing..." -ForegroundColor Yellow
    
    Test-LauncherAwareness | Out-Null
    Test-AdminPrivileges | Out-Null

    # Path length check
    if ($ScriptRoot.Length -gt $script:MAX_PATH_LENGTH) {
        Write-Host "WARNING: Path length is $($ScriptRoot.Length) chars" -ForegroundColor Yellow
        Write-Host "         Consider moving to shorter path (Windows limit: 260)" -ForegroundColor Yellow
    }

    # Check tools folder
    if (!(Test-Path $SysinternalsPath)) {
        Write-Host "ERROR: Sysinternals folder not found!" -ForegroundColor Red
        Write-Host "Expected: $SysinternalsPath" -ForegroundColor Yellow
        if ($script:LaunchedViaBatch) {
            Write-Host "ACTION: Use Batch Menu Option 5 to download tools automatically" -ForegroundColor Yellow
        } else {
            Write-Host "ACTION: Download from https://download.sysinternals.com/files/SysinternalsSuite.zip" -ForegroundColor Yellow
            Write-Host "        Extract to: $SysinternalsPath" -ForegroundColor Yellow
        }
        return $false
    }

    # Check for key tools
    $tools = @("psinfo.exe","coreinfo.exe","pslist.exe","handle.exe","clockres.exe")
    $found = 0
    $missing = @()
    foreach ($tool in $tools) {
        if (Test-Path (Join-Path $SysinternalsPath $tool)) {
            $found++
        } else {
            $missing += $tool
        }
    }

    if ($found -eq 0) {
        Write-Host "ERROR: No tools found in $SysinternalsPath" -ForegroundColor Red
        if ($script:LaunchedViaBatch) {
            Write-Host "ACTION: Use Batch Menu Option 5 to download tools" -ForegroundColor Yellow
        }
        return $false
    }

    Write-Host "Found $found/$($tools.Count) key tools" -ForegroundColor Green
    if ($missing.Count -gt 0) {
        Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Yellow
        if ($script:LaunchedViaBatch) {
            Write-Host "TIP: Use Batch Menu Option 4 for integrity check" -ForegroundColor DarkYellow
            Write-Host "     Use Batch Menu Option 5 to update tools" -ForegroundColor DarkYellow
        }
    }
    return $true
}

# Clean tool output
function Convert-ToolOutput {
    param([string]$ToolName, [string]$RawOutput)
    if (!$RawOutput) { return "" }

    $lines = $RawOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $cleaned = @()

    foreach ($line in $lines) {
        # Skip boilerplate
        if ($line -match "Copyright|Sysinternals|www\.|EULA|Mark Russinovich|David Solomon|Bryce Cogswell") { continue }
        if ($line -match "^-+$|^=+$|^\*+$") { continue }

        # Tool-specific filtering
        switch ($ToolName) {
            "psinfo" {
                if ($line -match "^(System|Uptime|Kernel|Product|Service|Build|Processors|Physical|Computer|Domain|Install)") {
                    $cleaned += $line
                }
            }
            "coreinfo" {
                if ($line -match "^(Intel|AMD|Logical|Cores|Processor|CPU|Cache|Feature|\s+\*)") {
                    $cleaned += $line
                }
            }
            "pslist" {
                if ($line -match "^(Name|Process|Pid)\s+|^\w+\s+\d+") {
                    $cleaned += $line
                }
            }
            default {
                if ($line.Length -lt 200) { $cleaned += $line }
            }
        }
    }

    return ($cleaned | Select-Object -First 40) -join "`n"
}

# Run tool
function Run-Tool {
    param(
        [string]$ToolName,
        [Alias('Args')]
        [string]$ArgumentList = "",
        [string]$Description = "",
        [bool]$RequiresAdmin = $false
    )

    if ($RequiresAdmin -and -not $script:IsAdmin) {
        Write-Host "SKIP: $ToolName (requires admin)" -ForegroundColor Yellow
        $script:TestResults += @{
            Tool=$ToolName; Description=$Description
            Status="SKIPPED"; Output="Requires administrator privileges"; Duration=0
        }
        return
    }

    $toolPath = Join-Path $SysinternalsPath "$ToolName.exe"
    if (!(Test-Path $toolPath)) {
        Write-Host "SKIP: $ToolName (not found)" -ForegroundColor Yellow
        return
    }

    Write-Host "Running $ToolName..." -ForegroundColor Cyan
    try {
        $start = Get-Date
        if ($ToolName -in @("psinfo","pslist","handle","autorunsc","testlimit","contig")) {
            $Args = "-accepteula $Args"
        }

        $argArray = if ($Args.Trim()) { $Args.Split(' ') | Where-Object { $_ } } else { @() }
        $rawOutput = & $toolPath $argArray 2>&1 | Out-String
        $duration = ((Get-Date) - $start).TotalMilliseconds
        $cleanOutput = Clean-ToolOutput -ToolName $ToolName -RawOutput $rawOutput

        $script:TestResults += @{
            Tool=$ToolName; Description=$Description
            Status="SUCCESS"; Output=$cleanOutput; Duration=$duration
        }
        Write-Host "OK: $ToolName ($([math]::Round($duration))ms)" -ForegroundColor Green
    }
    catch {
        $script:TestResults += @{
            Tool=$ToolName; Description=$Description
            Status="FAILED"; Output="Error: $($_.Exception.Message)"; Duration=0
        }
        Write-Host "ERROR: $ToolName - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test: System Info
function Test-SystemInfo {
    Write-Host "`n=== System Information ===" -ForegroundColor Green
    Invoke-Tool -ToolName "psinfo" -ArgumentList "-h -s -d" -Description "System information"
    Invoke-Tool -ToolName "clockres" -Description "Clock resolution"

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $info = @"
OS: $($os.Caption) $($os.Version)
Architecture: $($os.OSArchitecture)
Computer: $($cs.Name)
Manufacturer: $($cs.Manufacturer)
Model: $($cs.Model)
RAM: $([math]::Round($cs.TotalPhysicalMemory/1GB,2)) GB
"@
        $script:TestResults += @{
            Tool="System-Overview"; Description="System overview"
            Status="SUCCESS"; Output=$info; Duration=100
        }
        Write-Host "System overview collected" -ForegroundColor Green
    } catch {
        Write-Host "Error getting system info" -ForegroundColor Red
    }
}

# Test: CPU
function Test-CPU {
    Write-Host "`n=== CPU Testing ===" -ForegroundColor Green
    Invoke-Tool -ToolName "coreinfo" -ArgumentList "-v -f -c" -Description "CPU architecture"

    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $info = @"
CPU: $($cpu.Name)
Cores: $($cpu.NumberOfCores)
Logical: $($cpu.NumberOfLogicalProcessors)
Speed: $($cpu.MaxClockSpeed) MHz
L2 Cache: $($cpu.L2CacheSize) KB
L3 Cache: $($cpu.L3CacheSize) KB
"@
        $script:TestResults += @{
            Tool="CPU-Details"; Description="CPU details"
            Status="SUCCESS"; Output=$info; Duration=100
        }
        Write-Host "CPU details collected" -ForegroundColor Green
    } catch {
        Write-Host "Error getting CPU details" -ForegroundColor Yellow
    }

    Write-Host "Running CPU test ($script:CPU_TEST_SECONDS sec - synthetic)..." -ForegroundColor Yellow
    try {
        $start = Get-Date
        $end = $start.AddSeconds($script:CPU_TEST_SECONDS)
        $counter = 0
        while ((Get-Date) -lt $end) {
            $counter++
            [math]::Sqrt($counter) | Out-Null
        }
        $duration = ((Get-Date) - $start).TotalSeconds
        $opsPerSec = [math]::Round($counter / $duration)
        $script:TestResults += @{
            Tool="CPU-Performance"; Description="CPU performance test (synthetic)"
            Status="SUCCESS"; Output="Operations: $counter`nOps/sec: $opsPerSec`nNote: Synthetic test only"; Duration=($duration*1000)
        }
        Write-Host "CPU test: $opsPerSec ops/sec" -ForegroundColor Green
    } catch {
        Write-Host "CPU test failed" -ForegroundColor Red
    }
}

# Test: Memory (FIXED)
function Test-Memory {
    Write-Host "`n=== RAM Testing ===" -ForegroundColor Green
    try {
        $mem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalGB = [math]::Round($mem.TotalPhysicalMemory/1GB,2)
        
        # FIX: FreePhysicalMemory is in KB, convert to GB correctly
        $availGB = [math]::Round($os.FreePhysicalMemory/1024/1024,2)
        
        $usedGB = $totalGB - $availGB
        $usage = [math]::Round(($usedGB/$totalGB)*100,1)

        $info = @"
Total RAM: $totalGB GB
Available: $availGB GB
Used: $usedGB GB
Usage: $usage%
"@
        $script:TestResults += @{
            Tool="RAM-Details"; Description="RAM information"
            Status="SUCCESS"; Output=$info; Duration=100
        }
        Write-Host "RAM: $totalGB GB total, $usage% used" -ForegroundColor Green
    } catch {
        Write-Host "Error getting memory info" -ForegroundColor Red
    }
}

# Test: Storage
function Test-Storage {
    Write-Host "`n=== Storage Testing ===" -ForegroundColor Green
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 }
        $info = "LOGICAL DRIVES:`n"
        foreach ($disk in $disks) {
            $totalGB = [math]::Round($disk.Size/1GB,2)
            $freeGB = [math]::Round($disk.FreeSpace/1GB,2)
            $freePercent = if ($totalGB -gt 0) { [math]::Round(($freeGB/$totalGB)*100,1) } else { 0 }
            $info += "$($disk.DeviceID) - $totalGB GB total, $freeGB GB free ($freePercent%)`n"
        }

        $script:TestResults += @{
            Tool="Storage-Overview"; Description="Storage information"
            Status="SUCCESS"; Output=$info; Duration=100
        }
        Write-Host "Storage overview collected" -ForegroundColor Green
    } catch {
        Write-Host "Error getting storage info" -ForegroundColor Red
    }

        Invoke-Tool -ToolName "du" -ArgumentList "-l 2 C:\" -Description "Disk usage C:"

    # Disk performance test
    Write-Host "Running disk test..." -ForegroundColor Yellow
    try {
        $testFile = Join-Path $env:TEMP "disktest_$([guid]::NewGuid().ToString('N')).tmp"
        $testData = "0" * 1024 * 1024

        $writeStart = Get-Date
        for ($i=0; $i -lt 10; $i++) {
            $testData | Out-File -FilePath $testFile -Append -Encoding ASCII -ErrorAction Stop
        }
        $writeTime = ((Get-Date) - $writeStart).TotalMilliseconds

        $readStart = Get-Date
        $null = Get-Content $testFile -Raw -ErrorAction Stop
        $readTime = ((Get-Date) - $readStart).TotalMilliseconds

        Remove-Item $testFile -ErrorAction Stop

        $writeMBps = if ($writeTime -gt 0) { [math]::Round(10/($writeTime/1000),2) } else { 0 }
        $readMBps = if ($readTime -gt 0) { [math]::Round(10/($readTime/1000),2) } else { 0 }

        $script:TestResults += @{
            Tool="Disk-Performance"; Description="Disk performance (10MB)"
            Status="SUCCESS"; Output="Write: $writeMBps MB/s`nRead: $readMBps MB/s"; Duration=($writeTime+$readTime)
        }
        Write-Host "Disk: Write $writeMBps MB/s, Read $readMBps MB/s" -ForegroundColor Green
    } catch {
        Write-Host "Disk test failed" -ForegroundColor Yellow
    }
}

# Test: Processes
function Test-Processes {
    Write-Host "`n=== Process Analysis ===" -ForegroundColor Green
    Invoke-Tool -ToolName "pslist" -ArgumentList "-t" -Description "Process tree"
    Invoke-Tool -ToolName "handle" -ArgumentList "-p explorer" -Description "Explorer handles"
}

# Test: Security
function Test-Security {
    Write-Host "`n=== Security Analysis ===" -ForegroundColor Green
    Invoke-Tool -ToolName "autorunsc" -ArgumentList "-a -c" -Description "Autorun entries" -RequiresAdmin $true
}

# Test: Network
function Test-Network {
    Write-Host "`n=== Network Analysis ===" -ForegroundColor Green
    try {
        $connections = (netstat -an 2>&1 | Measure-Object).Count
        $script:TestResults += @{
            Tool="Netstat"; Description="Network connections"
            Status="SUCCESS"; Output="Total connections: $connections"; Duration=50
        }
        Write-Host "Network: $connections connections" -ForegroundColor Green
    } catch {
        Write-Host "Error getting network info" -ForegroundColor Red
    }

    Test-NetworkSpeed
    Test-NetworkLatency
}

function Test-NetworkSpeed {
    Write-Host "`n=== Network Speed Test ===" -ForegroundColor Green

    $outputLines = @()
    $status = "SUCCESS"
    $durationMs = 0

    # Gather link speed information for active adapters
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" }
        if ($adapters) {
            $outputLines += "Active Link Speeds:"
            foreach ($adapter in $adapters) {
                $outputLines += "  $($adapter.Name): $($adapter.LinkSpeed)"
            }
        } else {
            $outputLines += "Active Link Speeds: No active adapters detected"
        }
    } catch {
        $status = "FAILED"
        $outputLines += "Active Link Speeds: Unable to query adapters ($($_.Exception.Message))"
    }

    # Perform an outbound download test to estimate internet throughput
    $tempFile = $null
    try {
        $testUrl = "https://speed.hetzner.de/10MB.bin"
        $tempFile = [System.IO.Path]::GetTempFileName()
        Write-Host "Running internet download test (~10MB)..." -ForegroundColor Yellow
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-WebRequest -Uri $testUrl -OutFile $tempFile -UseBasicParsing -TimeoutSec 120 | Out-Null
        $stopwatch.Stop()

        $fileInfo = Get-Item $tempFile
        $sizeBytes = [double]$fileInfo.Length
        $duration = [math]::Max($stopwatch.Elapsed.TotalSeconds, 0.001)
        $sizeMB = [math]::Round($sizeBytes / 1MB, 2)
        $mbps = [math]::Round((($sizeBytes * 8) / 1MB) / $duration, 2)
        $mbPerSec = [math]::Round(($sizeBytes / 1MB) / $duration, 2)

        $outputLines += "Internet Download Test:"
        $outputLines += "  URL: $testUrl"
        $outputLines += "  File Size: $sizeMB MB"
        $outputLines += "  Time: $([math]::Round($duration,2)) sec"
        $outputLines += "  Throughput: $mbps Mbps ($mbPerSec MB/s)"
        $durationMs = [math]::Round($stopwatch.Elapsed.TotalMilliseconds)
    } catch {
        if ($status -ne "FAILED") { $status = "FAILED" }
        $outputLines += "Internet Download Test: Failed - $($_.Exception.Message)"
    } finally {
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }

    $script:TestResults += @{
        Tool="Network-SpeedTest"; Description="Local link speed and download throughput"
        Status=$status; Output=($outputLines -join "`n"); Duration=$durationMs
    }
}

function Test-NetworkLatency {
    Write-Host "`n=== Network Latency (Test-NetConnection & PsPing) ===" -ForegroundColor Green

    $targetHost = "8.8.8.8"
    $targetPort = 443
    $lines = @("Target: $($targetHost):$targetPort")
    $status = "SUCCESS"

    # Built-in Test-NetConnection results
    try {
        $tnc = Test-NetConnection -ComputerName $targetHost -Port $targetPort -InformationLevel Detailed
        if ($tnc) {
            $lines += "Test-NetConnection:"
            $lines += "  Ping Succeeded: $($tnc.PingSucceeded)"
            if ($tnc.PingReplyDetails) {
                $lines += "  Ping RTT: $($tnc.PingReplyDetails.RoundtripTime) ms"
            }
            $lines += "  TCP Succeeded: $($tnc.TcpTestSucceeded)"
        }
    } catch {
        $status = "FAILED"
        $lines += "Test-NetConnection: Failed - $($_.Exception.Message)"
    }

    # Sysinternals PsPing results
    try {
        $pspingPath = Join-Path $SysinternalsPath "psping.exe"
        if (Test-Path $pspingPath) {
            $pspingArgs = @("-accepteula", "-n", "5", "{0}:{1}" -f $targetHost, $targetPort)
            Write-Host "Running PsPing latency test..." -ForegroundColor Yellow
            $pspingOutput = & $pspingPath $pspingArgs 2>&1 | Out-String
            $lines += "PsPing Summary:"

            $average = $null
            $minimum = $null
            $maximum = $null
            foreach ($line in $pspingOutput -split "`r?`n") {
                if ($line -match "Minimum = ([\d\.]+)ms, Maximum = ([\d\.]+)ms, Average = ([\d\.]+)ms") {
                    $minimum = [double]$matches[1]
                    $maximum = [double]$matches[2]
                    $average = [double]$matches[3]
                }
            }

            if ($null -ne $average) {
                $lines += "  Min: $minimum ms"
                $lines += "  Max: $maximum ms"
                $lines += "  Avg: $average ms"
            } else {
                $lines += "  Unable to parse latency results"
            }
        } else {
            $lines += "PsPing Summary: psping.exe not found in Sysinternals folder"
        }
    } catch {
        $status = "FAILED"
        $lines += "PsPing Summary: Failed - $($_.Exception.Message)"
    }

    $script:TestResults += @{
        Tool="Network-Latency"; Description="Connectivity latency tests"
        Status=$status; Output=($lines -join "`n"); Duration=0
    }
}

# Test: OS Health
function Test-OSHealth {
    Write-Host "`n=== OS Health (DISM/SFC) ===" -ForegroundColor Green
    if (-not $script:IsAdmin) {
        Write-Host "SKIP: Requires admin" -ForegroundColor Yellow
        $script:TestResults += @{
            Tool="OS-Health"; Description="DISM+SFC checks"
            Status="SKIPPED"; Output="Requires administrator privileges"; Duration=0
        }
        return
    }

    Write-Host "Running DISM and SFC (may take 5-15 min)..." -ForegroundColor Yellow
    try {
        $start = Get-Date
        $dism = (dism /Online /Cleanup-Image /ScanHealth) 2>&1 | Out-String
        $sfc = (sfc /scannow) 2>&1 | Out-String
        $duration = ((Get-Date) - $start).TotalMilliseconds

        $summary = "DISM:`n" + (($dism -split "`n" | Where-Object {$_ -match "No component|repairable|error"} | Select-Object -First 3) -join "`n")
        $summary += "`n`nSFC:`n" + (($sfc -split "`n" | Where-Object {$_ -match "did not find|found corrupt|Protection"} | Select-Object -First 3) -join "`n")

        $script:TestResults += @{
            Tool="OS-Health"; Description="DISM+SFC integrity"
            Status="SUCCESS"; Output=$summary; Duration=$duration
        }
        Write-Host "OS Health complete" -ForegroundColor Green
    } catch {
        Write-Host "OS Health check failed" -ForegroundColor Red
    }
}

# Test: SMART
function Test-StorageSMART {
    Write-Host "`n=== Storage SMART ===" -ForegroundColor Green
    try {
        $lines = @()
        try {
            $pd = Get-PhysicalDisk -ErrorAction Stop
            foreach ($p in $pd) {
                $lines += "$($p.FriendlyName) | Health: $($p.HealthStatus) | Media: $($p.MediaType)"
            }
        } catch {}

        if (-not $lines) { $lines = @("SMART data not available (driver limitation)") }

        $script:TestResults += @{
            Tool="Storage-SMART"; Description="SMART data"
            Status="SUCCESS"; Output=($lines -join "`n"); Duration=100
        }
        Write-Host "SMART data collected" -ForegroundColor Green
    } catch {
        Write-Host "SMART check failed" -ForegroundColor Yellow
    }
}

# Test: TRIM
function Test-Trim {
    Write-Host "`n=== SSD TRIM Status ===" -ForegroundColor Green
    try {
        $q = (fsutil behavior query DisableDeleteNotify) 2>&1
        $map = @{}
        ($q -split "`n") | ForEach-Object {
            if ($_ -match "NTFS DisableDeleteNotify\s*=\s*(\d)") { $map["NTFS"] = $matches[1] }
        }
        $txt = $map.GetEnumerator() | ForEach-Object {
            $status = if ($_.Value -eq "0") { "Enabled" } else { "Disabled" }
            "$($_.Key): TRIM $status"
        }
        if (-not $txt) { $txt = @("TRIM status unknown") }

        if ($map.Count -gt 0) {
            $enabledCount = ($map.GetEnumerator() | Where-Object { $_.Value -eq "0" }).Count
            if ($enabledCount -eq $map.Count) {
                $txt += "Overall: TRIM is ENABLED"
            } elseif ($enabledCount -eq 0) {
                $txt += "Overall: TRIM is DISABLED"
            } else {
                $txt += "Overall: TRIM mixed (check per-filesystem status)"
            }
        }

        $script:TestResults += @{
            Tool="SSD-TRIM"; Description="TRIM status"
            Status="SUCCESS"; Output=($txt -join "`n"); Duration=50
        }
        Write-Host "TRIM status collected" -ForegroundColor Green
    } catch {
        Write-Host "TRIM check failed" -ForegroundColor Yellow
    }
}

# Test: NIC
function Test-NIC {
    Write-Host "`n=== Network Adapters ===" -ForegroundColor Green
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object {$_.Status -eq "Up"}
        $lines = foreach ($a in $adapters) {
            "$($a.InterfaceAlias): $($a.LinkSpeed) | MAC: $($a.MacAddress)"
        }
        if (-not $lines) { $lines = @("No active adapters") }

        $script:TestResults += @{
            Tool="NIC-Info"; Description="Network adapters"
            Status="SUCCESS"; Output=($lines -join "`n"); Duration=100
        }
        Write-Host "Network adapters collected" -ForegroundColor Green
    } catch {
        Write-Host "Network adapter check failed" -ForegroundColor Yellow
    }
}

# Test: GPU (Enhanced)
function Test-GPU {
    Write-Host "`n=== GPU Testing (Enhanced) ===" -ForegroundColor Green
    
    # Part 1: Detailed WMI/CIM GPU Information
    Write-Host "Gathering GPU details..." -ForegroundColor Yellow
    try {
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction Stop
        $gpuCount = ($gpus | Measure-Object).Count
        
        $gpuInfo = @()
        $gpuInfo += "DETECTED GPUs: $gpuCount`n"
        
        $index = 1
        foreach ($gpu in $gpus) {
            $gpuInfo += "=" * 60
            $gpuInfo += "GPU #$index"
            $gpuInfo += "-" * 60
            $gpuInfo += "Name: $($gpu.Name)"
            $gpuInfo += "Status: $($gpu.Status)"
            $gpuInfo += "Adapter RAM: $([math]::Round($gpu.AdapterRAM/1GB,2)) GB"
            $gpuInfo += "Driver Version: $($gpu.DriverVersion)"
            $gpuInfo += "Driver Date: $($gpu.DriverDate)"
            $gpuInfo += "Video Processor: $($gpu.VideoProcessor)"
            $gpuInfo += "Video Architecture: $($gpu.VideoArchitecture)"
            $gpuInfo += "Video Mode: $($gpu.VideoModeDescription)"
            $gpuInfo += "Current Resolution: $($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)"
            $gpuInfo += "Refresh Rate: $($gpu.CurrentRefreshRate) Hz"
            $gpuInfo += "Bits Per Pixel: $($gpu.CurrentBitsPerPixel)"
            $gpuInfo += "PNP Device ID: $($gpu.PNPDeviceID)"
            
            if ($gpu.AdapterCompatibility) {
                $gpuInfo += "Manufacturer: $($gpu.AdapterCompatibility)"
            }
            
            $gpuInfo += ""
            $index++
        }
        
        $script:TestResults += @{
            Tool="GPU-Details"; Description="Detailed GPU information"
            Status="SUCCESS"; Output=($gpuInfo -join "`n"); Duration=200
        }
        Write-Host "GPU details collected ($gpuCount GPU(s))" -ForegroundColor Green
    } catch {
        Write-Host "Error getting GPU details: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Part 2: Display Configuration
    Write-Host "Analyzing display configuration..." -ForegroundColor Yellow
    try {
        $monitors = Get-CimInstance WmiMonitorID -Namespace root\wmi -ErrorAction Stop
        $monitorCount = ($monitors | Measure-Object).Count
        
        $displayInfo = @()
        $displayInfo += "DETECTED DISPLAYS: $monitorCount`n"
        
        $index = 1
        foreach ($monitor in $monitors) {
            $displayInfo += "Display #$index"
            $displayInfo += "-" * 40
            
            # Decode manufacturer name
            if ($monitor.ManufacturerName) {
                $mfg = [System.Text.Encoding]::ASCII.GetString($monitor.ManufacturerName -ne 0)
                $displayInfo += "Manufacturer: $mfg"
            }
            
            # Decode product name
            if ($monitor.UserFriendlyName) {
                $name = [System.Text.Encoding]::ASCII.GetString($monitor.UserFriendlyName -ne 0)
                $displayInfo += "Model: $name"
            }
            
            # Decode serial number
            if ($monitor.SerialNumberID) {
                $serial = [System.Text.Encoding]::ASCII.GetString($monitor.SerialNumberID -ne 0)
                $displayInfo += "Serial: $serial"
            }
            
            $displayInfo += "Year: $($monitor.YearOfManufacture)"
            $displayInfo += ""
            $index++
        }
        
        $script:TestResults += @{
            Tool="Display-Configuration"; Description="Display details"
            Status="SUCCESS"; Output=($displayInfo -join "`n"); Duration=150
        }
        Write-Host "Display configuration collected ($monitorCount display(s))" -ForegroundColor Green
    } catch {
        Write-Host "Display configuration unavailable" -ForegroundColor Yellow
    }
    
    # Part 3: GPU Driver Details (Enhanced)
    Write-Host "Checking GPU drivers..." -ForegroundColor Yellow
    try {
        $drivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | 
                   Where-Object { $_.DeviceClass -eq "DISPLAY" }
        
        $driverInfo = @()
        foreach ($driver in $drivers) {
            $driverInfo += "Device: $($driver.DeviceName)"
            $driverInfo += "Driver: $($driver.DriverVersion)"
            $driverInfo += "Provider: $($driver.DriverProviderName)"
            $driverInfo += "Date: $($driver.DriverDate)"
            $driverInfo += "Signer: $($driver.Signer)"
            $driverInfo += "INF: $($driver.InfName)"
            $driverInfo += ""
        }
        
        $script:TestResults += @{
            Tool="GPU-Drivers"; Description="GPU driver information"
            Status="SUCCESS"; Output=($driverInfo -join "`n"); Duration=100
        }
        Write-Host "GPU driver details collected" -ForegroundColor Green
    } catch {
        Write-Host "Driver details unavailable" -ForegroundColor Yellow
    }
    
    # Part 4: DirectX Diagnostics (Enhanced)
    Write-Host "Running DirectX diagnostics..." -ForegroundColor Yellow
    $dxProcess = $null
    try {
        $dx = Join-Path $env:TEMP "dxdiag_$([guid]::NewGuid().ToString('N')).txt"
        
        $dxProcess = Start-Process -FilePath "dxdiag" -ArgumentList "/t",$dx -WindowStyle Hidden -PassThru
        
        $elapsed = 0
        while (!(Test-Path $dx) -and $elapsed -lt $script:DXDIAG_TIMEOUT) {
            if ($dxProcess.HasExited) { break }
            Start-Sleep -Milliseconds 500
            $elapsed += 0.5
        }
        
        if (Test-Path $dx) {
            Start-Sleep -Seconds 1
            $raw = Get-Content $dx -Raw -ErrorAction Stop
            Remove-Item $dx -ErrorAction SilentlyContinue
            
            # Extract more detailed info
            $dxInfo = @()
            
            # DirectX version
            if ($raw -match "DirectX Version: (.+)") {
                $dxInfo += "DirectX Version: $($matches[1])"
            }
            
            # Display devices section
            $lines = $raw -split "`r?`n"
            $inDisplaySection = $false
            $displayLines = @()
            
            foreach ($line in $lines) {
                if ($line -match "Display Devices|Display \d+") {
                    $inDisplaySection = $true
                }
                if ($inDisplaySection) {
                    if ($line -match "Card name:|Manufacturer:|Chip type:|DAC type:|Device Type:|Display Memory:|Dedicated Memory:|Shared Memory:|Current Mode:|Monitor Name:|Monitor Model:|Driver Name:|Driver File Version:|Driver Version:|Driver Date/Size:") {
                        $displayLines += $line.Trim()
                    }
                    if ($line -match "^-{20,}") {
                        $inDisplaySection = $false
                    }
                }
            }
            
            $dxInfo += $displayLines
            
            $script:TestResults += @{
                Tool="GPU-DirectX"; Description="DirectX diagnostics"
                Status="SUCCESS"; Output=($dxInfo -join "`n"); Duration=($elapsed*1000)
            }
            Write-Host "DirectX diagnostics complete" -ForegroundColor Green
        } else {
            throw "DxDiag timeout or failed"
        }
    } catch {
        Write-Host "DxDiag failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $script:TestResults += @{
            Tool="GPU-DirectX"; Description="DirectX diagnostics"
            Status="FAILED"; Output="DxDiag unavailable: $($_.Exception.Message)"; Duration=0
        }
    } finally {
        if ($dxProcess -and !$dxProcess.HasExited) {
            try { $dxProcess.Kill(); $dxProcess.WaitForExit(5000) } catch {}
        }
    }
    
    # Part 5: OpenGL Information
    Write-Host "Checking OpenGL support..." -ForegroundColor Yellow
    try {
        $openglInfo = @()
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\OpenGLDrivers"
        
        if (Test-Path $regPath) {
            $oglKeys = Get-ItemProperty $regPath -ErrorAction SilentlyContinue
            if ($oglKeys) {
                $openglInfo += "OpenGL Registry Keys Found:"
                $oglKeys.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                    $openglInfo += "$($_.Name): $($_.Value)"
                }
            }
        } else {
            $openglInfo += "OpenGL: Registry information not available"
        }
        
        $script:TestResults += @{
            Tool="GPU-OpenGL"; Description="OpenGL information"
            Status="SUCCESS"; Output=($openglInfo -join "`n"); Duration=50
        }
        Write-Host "OpenGL check complete" -ForegroundColor Green
    } catch {
        Write-Host "OpenGL check skipped" -ForegroundColor DarkGray
    }
    
    # Part 6: GPU Performance Capabilities
    Write-Host "Checking GPU capabilities..." -ForegroundColor Yellow
    try {
        $capabilities = @()
        
        # Check for hardware acceleration
        $dwm = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -ErrorAction SilentlyContinue
        if ($dwm) {
            $capabilities += "DWM Composition: Enabled"
        }
        
        # Check for GPU scheduling
        $gpuScheduling = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue
        if ($gpuScheduling.HwSchMode) {
            $schedStatus = if ($gpuScheduling.HwSchMode -eq 2) { "Enabled" } else { "Disabled" }
            $capabilities += "Hardware-Accelerated GPU Scheduling: $schedStatus"
        }
        
        # Check DirectX feature levels
        $gpus = Get-CimInstance Win32_VideoController
        foreach ($gpu in $gpus) {
            if ($gpu.Name) {
                $driverYear = $null
                if ($gpu.DriverDate) {
                    try {
                        $driverYear = ([DateTime]$gpu.DriverDate).Year
                    } catch {
                        $driverYear = $null
                    }
                }

                if (-not $driverYear) {
                    # Fall back to a conservative default if parsing fails
                    $driverYear = 2014
                }

                $featureLevel = if ($driverYear -ge 2020) { "12_x" }
                               elseif ($driverYear -ge 2016) { "12_0" }
                               elseif ($driverYear -ge 2012) { "11_0" }
                               else { "10_x" }

                $capabilities += "$($gpu.Name): Likely supports DirectX $featureLevel"
            }
        }
        
        $script:TestResults += @{
            Tool="GPU-Capabilities"; Description="GPU feature capabilities"
            Status="SUCCESS"; Output=($capabilities -join "`n"); Duration=100
        }
        Write-Host "GPU capabilities assessed" -ForegroundColor Green
    } catch {
        Write-Host "Capabilities check failed" -ForegroundColor Yellow
    }
}

# Test: Vendor-Specific GPU Testing (NVIDIA/AMD)
function Test-GPUVendorSpecific {
    Write-Host "`n=== Vendor-Specific GPU Testing ===" -ForegroundColor Green
    
    # Check for NVIDIA
    try {
        $nvidiaSmi = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
        if (Test-Path $nvidiaSmi) {
            Write-Host "NVIDIA GPU detected - running nvidia-smi..." -ForegroundColor Yellow
            
            $nvidiaOutput = & $nvidiaSmi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,memory.total,memory.used,power.draw,clocks.current.graphics,clocks.current.memory --format=csv 2>&1 | Out-String
            
            $script:TestResults += @{
                Tool="NVIDIA-SMI"; Description="NVIDIA GPU metrics"
                Status="SUCCESS"; Output=$nvidiaOutput; Duration=500
            }
            
            Write-Host "NVIDIA metrics collected" -ForegroundColor Green
            
            # Get more detailed info
            $detailedOutput = & $nvidiaSmi -q 2>&1 | Out-String
            
            $script:TestResults += @{
                Tool="NVIDIA-SMI-Detailed"; Description="NVIDIA detailed info"
                Status="SUCCESS"; Output=$detailedOutput; Duration=500
            }
            
        } else {
            Write-Host "NVIDIA GPU not detected or nvidia-smi not installed" -ForegroundColor DarkGray
            $script:TestResults += @{
                Tool="NVIDIA-SMI"; Description="NVIDIA GPU metrics"
                Status="SKIPPED"; Output="nvidia-smi not found - install NVIDIA drivers for this feature"; Duration=0
            }
        }
    } catch {
        Write-Host "NVIDIA test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Check for AMD
    try {
        $amdClassRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"

        if (Test-Path $amdClassRoot) {
            $amdOutputs = @()
            $detected = $false

            $subKeys = Get-ChildItem $amdClassRoot -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match "^\d{4}$" }
            foreach ($subKey in $subKeys) {
                try {
                    $amdInfo = Get-ItemProperty $subKey.PSPath -ErrorAction Stop
                } catch {
                    continue
                }

                if ($amdInfo.DriverDesc -and $amdInfo.DriverDesc -match "AMD|Radeon") {
                    $detected = $true
                    $amdOutputs += "AMD GPU Slot $($subKey.PSChildName)"
                    $amdOutputs += "Driver Description: $($amdInfo.DriverDesc)"
                    if ($amdInfo.DeviceDesc) { $amdOutputs += "Device: $($amdInfo.DeviceDesc)" }
                    if ($amdInfo.DriverVersion) { $amdOutputs += "Driver Version: $($amdInfo.DriverVersion)" }
                    if ($amdInfo.DriverDate) { $amdOutputs += "Driver Date: $($amdInfo.DriverDate)" }
                    $amdOutputs += ""
                }
            }

            if ($detected) {
                $script:TestResults += @{
                    Tool="AMD-GPU"; Description="AMD GPU information"
                    Status="SUCCESS"; Output=($amdOutputs -join "`n"); Duration=150
                }
                Write-Host "AMD GPU information collected" -ForegroundColor Green
            } else {
                Write-Host "AMD GPU not detected" -ForegroundColor DarkGray
                $script:TestResults += @{
                    Tool="AMD-GPU"; Description="AMD GPU information"
                    Status="SKIPPED"; Output="No AMD GPU detected"; Duration=0
                }
            }
        } else {
            Write-Host "AMD GPU not detected" -ForegroundColor DarkGray
            $script:TestResults += @{
                Tool="AMD-GPU"; Description="AMD GPU information"
                Status="SKIPPED"; Output="No AMD GPU detected"; Duration=0
            }
        }
    } catch {
        Write-Host "AMD GPU check unavailable" -ForegroundColor DarkGray
    }
}

# Test: GPU Memory
function Test-GPUMemory {
    Write-Host "`n=== GPU Memory Test ===" -ForegroundColor Green
    
    try {
        $gpus = Get-CimInstance Win32_VideoController
        
        foreach ($gpu in $gpus) {
            $totalRAM = [math]::Round($gpu.AdapterRAM / 1GB, 2)
            
            Write-Host "Testing $($gpu.Name) - $totalRAM GB VRAM" -ForegroundColor Yellow
            
            # Get current usage via performance counters (if available)
            try {
                $perfCounters = Get-Counter -Counter "\GPU Engine(*)\Running Time" -ErrorAction Stop
                
                $usage = @()
                $usage += "GPU: $($gpu.Name)"
                $usage += "Total VRAM: $totalRAM GB"
                $usage += "`nActive GPU processes detected: $($perfCounters.CounterSamples.Count)"
                
                $script:TestResults += @{
                    Tool="GPU-Memory-Test"; Description="GPU memory analysis"
                    Status="SUCCESS"; Output=($usage -join "`n"); Duration=200
                }
                
                Write-Host "GPU memory test complete" -ForegroundColor Green
            } catch {
                # Fallback to basic info
                $usage = @()
                $usage += "GPU: $($gpu.Name)"
                $usage += "Total VRAM: $totalRAM GB"
                $usage += "Note: Performance counters not available for detailed usage"
                
                $script:TestResults += @{
                    Tool="GPU-Memory-Test"; Description="GPU memory analysis"
                    Status="SUCCESS"; Output=($usage -join "`n"); Duration=100
                }
                
                Write-Host "GPU memory info collected (limited data)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "GPU memory test failed: $($_.Exception.Message)" -ForegroundColor Yellow
        $script:TestResults += @{
            Tool="GPU-Memory-Test"; Description="GPU memory analysis"
            Status="FAILED"; Output="Error: $($_.Exception.Message)"; Duration=0
        }
    }
}

# Test: Power
function Test-Power {
    Write-Host "`n=== Power/Battery ===" -ForegroundColor Green
    try {
        $lines = @()
        try {
            $bat = Get-CimInstance Win32_Battery -ErrorAction Stop
            foreach ($b in $bat) {
                $lines += "Battery: $($b.BatteryStatus) | Design: $($b.DesignCapacity)"
            }
            if (-not $bat) { $lines += "No battery (desktop)" }
        } catch { $lines += "No battery (desktop)" }

        if ($script:IsAdmin) {
            $report = Join-Path $ScriptRoot "energy-report.html"
            Write-Host "Generating energy report ($script:ENERGY_DURATION sec)..." -ForegroundColor Yellow
            powercfg /energy /output $report /duration $script:ENERGY_DURATION 2>&1 | Out-Null
            if (Test-Path $report) {
                $lines += "Energy report: $report"
            }
        }

        $script:TestResults += @{
            Tool="Power-Energy"; Description="Power info"
            Status="SUCCESS"; Output=($lines -join "`n"); Duration=($script:ENERGY_DURATION*1000)
        }
        Write-Host "Power check complete" -ForegroundColor Green
    } catch {
        Write-Host "Power check failed" -ForegroundColor Yellow
    }
}

# Test: WHEA
function Test-HardwareEvents {
    Write-Host "`n=== Hardware Events (WHEA) ===" -ForegroundColor Green
    try {
        $ev = Get-WinEvent -FilterHashtable @{
            LogName='System'
            ProviderName='Microsoft-Windows-WHEA-Logger'
            StartTime=(Get-Date).AddDays(-7)
        } -ErrorAction SilentlyContinue | Select-Object -First 10

        if ($ev) {
            $text = ($ev | ForEach-Object {
                "[{0:yyyy-MM-dd}] ID {1}: {2}" -f $_.TimeCreated,$_.Id,$_.LevelDisplayName
            }) -join "`n"
        } else {
            $text = "No WHEA errors in last 7 days (good)"
        }

        $script:TestResults += @{
            Tool="WHEA"; Description="Hardware events (7d)"
            Status="SUCCESS"; Output=$text; Duration=100
        }
        Write-Host "WHEA scan complete" -ForegroundColor Green
    } catch {
        Write-Host "WHEA check failed" -ForegroundColor Yellow
    }
}

# Test: Windows Update
function Test-WindowsUpdate {
    Write-Host "`n=== Windows Update ===" -ForegroundColor Green
    $updateSession = $null
    $searcher = $null
    $result = $null
    try {
        $lines = @()
        try {
            $svc = Get-Service -Name wuauserv -ErrorAction Stop
            $lines += "Service: $($svc.Status)"
        } catch {
            $lines += "Service: Unable to query"
        }

        Write-Host "Checking for updates (may take 30-90 sec)..." -ForegroundColor Yellow
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $searcher = $updateSession.CreateUpdateSearcher()

        try {
            $result = $searcher.Search("IsInstalled=0")
            $pendingCount = $result.Updates.Count
            $lines += "Pending: $pendingCount"

            if ($pendingCount -gt 0) {
                $lines += "Pending Updates:"
                $maxList = 10
                for ($i = 0; $i -lt [math]::Min($pendingCount, $maxList); $i++) {
                    $update = $result.Updates.Item($i)
                    $classification = ($update.Categories | Select-Object -First 1).Name
                    if (-not $classification) { $classification = "Unspecified" }
                    $lines += "  - $($update.Title) [$classification]"
                }
                if ($pendingCount -gt $maxList) {
                    $lines += "  ... ($($pendingCount - $maxList) additional updates not listed)"
                }
            } else {
                $lines += "Pending Updates: None"
            }
        } catch {
            $lines += "Search failed: $($_.Exception.Message)"
        }

        $script:TestResults += @{
            Tool="Windows-Update"; Description="Update status"
            Status="SUCCESS"; Output=($lines -join "`n"); Duration=1000
        }
        Write-Host "Windows Update check complete" -ForegroundColor Green
    } catch {
        Write-Host "Windows Update check failed" -ForegroundColor Yellow
    } finally {
        if ($result) {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($result) | Out-Null } catch {}
        }
        if ($searcher) {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($searcher) | Out-Null } catch {}
        }
        if ($updateSession) {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($updateSession) | Out-Null } catch {}
        }
        [System.GC]::Collect()
    }
}

# Generate Dual Reports (Clean + Detailed) - ENHANCED VERSION
# Replace the entire Generate-Report function in SystemTester.ps1 (around line 1260)
function New-Report {
    Write-Host "`nGenerating reports..." -ForegroundColor Cyan

    # Test write access
    $testFile = Join-Path $ScriptRoot "writetest_$([guid]::NewGuid().ToString('N')).tmp"
    try {
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -ErrorAction Stop
    } catch {
        Write-Host "ERROR: Cannot write to $ScriptRoot" -ForegroundColor Red
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $cleanPath = Join-Path $ScriptRoot "SystemTest_Clean_$timestamp.txt"
    $detailedPath = Join-Path $ScriptRoot "SystemTest_Detailed_$timestamp.txt"

    # Calculate stats
    $success = ($TestResults | Where-Object {$_.Status -eq "SUCCESS"}).Count
    $failed = ($TestResults | Where-Object {$_.Status -eq "FAILED"}).Count
    $skipped = ($TestResults | Where-Object {$_.Status -eq "SKIPPED"}).Count
    $total = $TestResults.Count
    $successRate = if ($total -gt 0) { [math]::Round(($success/$total)*100,1) } else { 0 }

    # === CLEAN REPORT ===
    $cleanReport = @()
    $cleanReport += "========================================="
    $cleanReport += "  SYSTEM TEST REPORT v$script:VERSION"
    $cleanReport += "  CLEAN SUMMARY"
    $cleanReport += "========================================="
    $cleanReport += "Date: $(Get-Date)"
    $cleanReport += "Computer: $env:COMPUTERNAME"
    $cleanReport += "Admin: $(if ($script:IsAdmin) {'YES'} else {'NO'})"
    $cleanReport += ""

    $cleanReport += "SUMMARY:"
    $cleanReport += "  Total Tests: $total"
    $cleanReport += "  Success: $success"
    $cleanReport += "  Failed: $failed"
    $cleanReport += "  Skipped: $skipped"
    $cleanReport += "  Success Rate: $successRate%"
    $cleanReport += ""

    $cleanReport += "KEY FINDINGS:"
    $cleanReport += "-------------"
    
    # Extract key info from results
    $sysInfo = $TestResults | Where-Object {$_.Tool -eq "System-Overview"}
    if ($sysInfo) {
        $cleanReport += ""
        $cleanReport += "SYSTEM:"
        $sysInfo.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }

    $ramInfo = $TestResults | Where-Object {$_.Tool -eq "RAM-Details"}
    if ($ramInfo -and $ramInfo.Output -match "Usage: ([\d\.]+)%") {
        $cleanReport += ""
        $cleanReport += "MEMORY:"
        $ramInfo.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }

    $diskPerf = $TestResults | Where-Object {$_.Tool -eq "Disk-Performance"}
    if ($diskPerf) {
        $cleanReport += ""
        $cleanReport += "DISK PERFORMANCE:"
        $diskPerf.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }

    $gpuDetails = $TestResults | Where-Object {$_.Tool -eq "GPU-Details"}
    if ($gpuDetails -and $gpuDetails.Output -match "GPU #1") {
        $cleanReport += ""
        $cleanReport += "GPU:"
        # Extract just the first GPU's name
        $gpuLines = $gpuDetails.Output -split "`n"
        foreach ($line in $gpuLines) {
            if ($line -match "Name:|Adapter RAM:|Driver Version:") {
                $cleanReport += "  $line"
            }
            if ($line -match "GPU #2") { break }  # Stop at second GPU
        }
    }

    $netSpeed = $TestResults | Where-Object {$_.Tool -eq "Network-SpeedTest"} | Select-Object -Last 1
    if ($netSpeed) {
        $cleanReport += ""
        $cleanReport += "NETWORK SPEED:"
        $netSpeed.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }

    $netLatency = $TestResults | Where-Object {$_.Tool -eq "Network-Latency"} | Select-Object -Last 1
    if ($netLatency) {
        $cleanReport += ""
        $cleanReport += "NETWORK LATENCY:"
        $netLatency.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }

    $updateInfo = $TestResults | Where-Object {$_.Tool -eq "Windows-Update"} | Select-Object -Last 1
    if ($updateInfo) {
        $cleanReport += ""
        $cleanReport += "WINDOWS UPDATE:"
        $updateInfo.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }

    # ========================================
    # ENHANCED RECOMMENDATIONS ENGINE
    # ========================================
    $cleanReport += ""
    $cleanReport += "RECOMMENDATIONS:"
    $cleanReport += "----------------"

    $recommendations = @()

    # === MEMORY ANALYSIS ===
    if ($ramInfo -and $ramInfo.Output -match "Usage: ([\d\.]+)%") {
        $usage = [float]$matches[1]
        if ($usage -gt 85) {
            $recommendations += "• CRITICAL: High memory usage ($usage%)"
            $recommendations += "  → Close unnecessary programs"
            $recommendations += "  → Check for memory leaks in Task Manager"
            $recommendations += "  → Consider adding more RAM (current usage indicates shortage)"
        } elseif ($usage -gt 70) {
            $recommendations += "• WARNING: Elevated memory usage ($usage%)"
            $recommendations += "  → Monitor for memory-intensive applications"
            $recommendations += "  → RAM upgrade recommended if usage stays consistently high"
        } elseif ($usage -lt 30) {
            $recommendations += "• GOOD: Low memory usage ($usage%) - plenty of RAM available"
        }
    }

    # === STORAGE HEALTH ===
    $smartInfo = $TestResults | Where-Object {$_.Tool -eq "Storage-SMART"}
    if ($smartInfo -and $smartInfo.Output -notmatch "not available") {
        if ($smartInfo.Output -match "Warning|Caution|Failed|Degraded") {
            $recommendations += "• CRITICAL: Drive health issue detected"
            $recommendations += "  → BACKUP DATA IMMEDIATELY"
            $recommendations += "  → Run manufacturer's diagnostic tool"
            $recommendations += "  → Consider drive replacement"
        }
    }

    # === STORAGE PERFORMANCE ===
    if ($diskPerf -and $diskPerf.Output -match "Write: ([\d\.]+) MB/s.*Read: ([\d\.]+) MB/s") {
        $writeSpeed = [float]$matches[1]
        $readSpeed = [float]$matches[2]
        
        # HDD typical: 80-160 MB/s, SSD typical: 200-550 MB/s (SATA), NVMe: 1500+ MB/s
        if ($writeSpeed -lt 50 -or $readSpeed -lt 50) {
            $recommendations += "• WARNING: Very slow disk performance detected"
            $recommendations += "  → Write: $writeSpeed MB/s, Read: $readSpeed MB/s"
            $recommendations += "  → Check for background processes (antivirus, Windows Update)"
            $recommendations += "  → Run disk defragmentation (HDD only, not SSD)"
            $recommendations += "  → Check disk health with manufacturer tools"
            $recommendations += "  → Consider SSD upgrade for significant speed improvement"
        } elseif ($writeSpeed -lt 100 -or $readSpeed -lt 100) {
            $recommendations += "• INFO: Moderate disk performance (likely HDD)"
            $recommendations += "  → Write: $writeSpeed MB/s, Read: $readSpeed MB/s"
            $recommendations += "  → Consider SSD upgrade for 3-5x speed improvement"
        }
    }

    # === NETWORK PERFORMANCE ===
    if ($netSpeed -and $netSpeed.Output -match "Throughput: ([\d\.]+) Mbps") {
        $throughputMbps = [float]$matches[1]
        if ($throughputMbps -lt 25) {
            $recommendations += "• WARNING: Internet throughput appears slow ($throughputMbps Mbps)"
            $recommendations += "  → Verify ISP plan and router performance"
            $recommendations += "  → Re-test when fewer applications are consuming bandwidth"
        }
    }

    if ($netLatency -and $netLatency.Output -match "Avg: ([\d\.]+) ms") {
        $avgLatency = [float]$matches[1]
        if ($avgLatency -gt 100) {
            $recommendations += "• NOTICE: High network latency detected (Avg $avgLatency ms)"
            $recommendations += "  → Check local network congestion"
            $recommendations += "  → Contact ISP if latency persists"
        }
    }

    if ($updateInfo -and $updateInfo.Output -match "Pending: (\d+)") {
        $pendingUpdates = [int]$matches[1]
        if ($pendingUpdates -gt 0) {
            $recommendations += "• ACTION: $pendingUpdates Windows update(s) pending installation"
            $recommendations += "  → Install updates via Settings > Windows Update"
            $recommendations += "  → Reboot system after installation completes"
        }
    }

    # === STORAGE CAPACITY ===
    $storageInfo = $TestResults | Where-Object {$_.Tool -eq "Storage-Overview"}
    if ($storageInfo) {
        $drives = $storageInfo.Output -split "`n" | Where-Object {$_ -match "([A-Z]:).*\((\d+)%\)"}
        foreach ($drive in $drives) {
            if ($drive -match "([A-Z]:).*\((\d+)%\)") {
                $driveLetter = $matches[1]
                $freePercent = [int]$matches[2]
                
                if ($freePercent -lt 10) {
                    $recommendations += "• CRITICAL: Drive $driveLetter has less than 10% free space"
                    $recommendations += "  → Delete unnecessary files immediately"
                    $recommendations += "  → Use Disk Cleanup (cleanmgr.exe)"
                    $recommendations += "  → Move files to external storage"
                    $recommendations += "  → System performance will degrade below 10% free"
                } elseif ($freePercent -lt 20) {
                    $recommendations += "• WARNING: Drive $driveLetter has less than 20% free space"
                    $recommendations += "  → Clean up unnecessary files soon"
                    $recommendations += "  → Use Storage Sense or Disk Cleanup"
                }
            }
        }
    }

    # === SSD TRIM STATUS ===
    $trimInfo = $TestResults | Where-Object {$_.Tool -eq "SSD-TRIM"}
    if ($trimInfo -and $trimInfo.Output -match "Disabled") {
        $recommendations += "• WARNING: TRIM is disabled for SSD"
        $recommendations += "  → Enable TRIM: fsutil behavior set DisableDeleteNotify 0"
        $recommendations += "  → TRIM maintains SSD performance and longevity"
    }

    # === NETWORK PERFORMANCE ===
    $nicInfo = $TestResults | Where-Object {$_.Tool -eq "NIC-Info"}
    if ($nicInfo) {
        if ($nicInfo.Output -match "10 Mbps|100 Mbps") {
            $recommendations += "• INFO: Slow network adapter detected (10/100 Mbps)"
            $recommendations += "  → Upgrade to Gigabit Ethernet (1000 Mbps)"
            $recommendations += "  → Check cable quality (use Cat5e or Cat6)"
        }
        
        if ($nicInfo.Output -match "No active adapters") {
            $recommendations += "• CRITICAL: No active network adapters"
            $recommendations += "  → Check network cable connections"
            $recommendations += "  → Verify adapter is enabled in Device Manager"
            $recommendations += "  → Update network drivers"
        }
    }

    # === WINDOWS UPDATE ===
    $updateInfo = $TestResults | Where-Object {$_.Tool -eq "Windows-Update"}
    if ($updateInfo) {
        if ($updateInfo.Output -match "Pending: (\d+)") {
            $pendingCount = [int]$matches[1]
            if ($pendingCount -gt 20) {
                $recommendations += "• WARNING: $pendingCount pending Windows Updates"
                $recommendations += "  → Install updates soon for security and stability"
                $recommendations += "  → Schedule during non-working hours"
                $recommendations += "  → Ensure backup before major updates"
            } elseif ($pendingCount -gt 5) {
                $recommendations += "• INFO: $pendingCount pending Windows Updates available"
                $recommendations += "  → Install updates when convenient"
            } elseif ($pendingCount -eq 0) {
                $recommendations += "• GOOD: Windows is up to date"
            }
        }
        
        if ($updateInfo.Output -match "Service: Stopped") {
            $recommendations += "• WARNING: Windows Update service is stopped"
            $recommendations += "  → Start service: net start wuauserv"
            $recommendations += "  → Set to Automatic in services.msc"
        }
    }

    # === OS HEALTH (DISM/SFC) ===
    $osHealth = $TestResults | Where-Object {$_.Tool -eq "OS-Health"}
    if ($osHealth -and $osHealth.Status -eq "SUCCESS") {
        if ($osHealth.Output -match "corrupt|error|repairable") {
            $recommendations += "• WARNING: System file corruption detected"
            $recommendations += "  → Run: DISM /Online /Cleanup-Image /RestoreHealth"
            $recommendations += "  → Then run: sfc /scannow"
            $recommendations += "  → Reboot and re-test"
        }
    }

    # === HARDWARE ERRORS (WHEA) ===
    $wheaInfo = $TestResults | Where-Object {$_.Tool -eq "WHEA"}
    if ($wheaInfo -and $wheaInfo.Output -notmatch "No WHEA errors") {
        $recommendations += "• WARNING: Hardware errors detected in event log"
        $recommendations += "  → Review Event Viewer for details"
        $recommendations += "  → Test RAM with Windows Memory Diagnostic"
        $recommendations += "  → Update BIOS/UEFI firmware"
        $recommendations += "  → Check for overheating issues"
    }

    # === CPU PERFORMANCE ===
    $cpuPerf = $TestResults | Where-Object {$_.Tool -eq "CPU-Performance"}
    if ($cpuPerf -and $cpuPerf.Output -match "Ops/sec: (\d+)") {
        $opsPerSec = [int]$matches[1]
        if ($opsPerSec -lt 5000000) {
            $recommendations += "• INFO: CPU performance lower than expected"
            $recommendations += "  → Check for background processes consuming CPU"
            $recommendations += "  → Set power plan to High Performance"
            $recommendations += "  → Check CPU temperatures (thermal throttling)"
            $recommendations += "  → Update chipset drivers"
        }
    }

    # === GPU HEALTH ===
    if ($gpuDetails) {
        if ($gpuDetails.Output -match "Driver Date:.*?(\d{4})") {
            $driverYear = 0
            if ([int]::TryParse($matches[1], [ref]$driverYear)) {
                $currentYear = (Get-Date).Year
                if ($currentYear - $driverYear -gt 1) {
                    $recommendations += "• INFO: GPU drivers are over 1 year old"
                    $recommendations += "  → Update to latest drivers for best performance"
                    $recommendations += "  → NVIDIA: GeForce Experience or nvidia.com"
                    $recommendations += "  → AMD: amd.com/en/support"
                }
            }
        }
    }

    # === BATTERY HEALTH (Laptops) ===
    $powerInfo = $TestResults | Where-Object {$_.Tool -eq "Power-Energy"}
    if ($powerInfo -and $powerInfo.Output -match "Battery") {
        if ($powerInfo.Output -match "energy-report.html") {
            $recommendations += "• INFO: Energy report generated"
            $recommendations += "  → Review energy-report.html for battery health"
        }
    }

    # === OVERALL SYSTEM HEALTH ===
    if ($failed -gt 5) {
        $recommendations += "• CRITICAL: Multiple test failures ($failed failures)"
        $recommendations += "  → Review detailed report for specific issues"
        $recommendations += "  → Consider professional diagnostics"
    }

    if ($failed -eq 0 -and $skipped -eq 0) {
        $recommendations += "• EXCELLENT: All tests passed successfully"
        $recommendations += "  → System is operating normally"
    } elseif ($skipped -gt 5) {
        $recommendations += "• INFO: $skipped tests skipped (admin required)"
        $recommendations += "  → Run as administrator for complete diagnostics"
    }

    # === GENERAL MAINTENANCE ===
    if ($recommendations.Count -lt 3) {
        $recommendations += ""
        $recommendations += "GENERAL MAINTENANCE TIPS:"
        $recommendations += "• Keep Windows and drivers updated"
        $recommendations += "• Run disk cleanup monthly (cleanmgr.exe)"
        $recommendations += "• Monitor temperatures during heavy use"
        $recommendations += "• Maintain at least 20% free disk space"
        $recommendations += "• Back up important data regularly"
    }

    # Add all recommendations to report
    foreach ($rec in $recommendations) {
        $cleanReport += $rec
    }

    $cleanReport += ""
    $cleanReport += "For detailed output, see: $detailedPath"
    $cleanReport += ""

    # === DETAILED REPORT ===
    $detailedReport = @()
    $detailedReport += "========================================="
    $detailedReport += "  SYSTEM TEST REPORT v$script:VERSION"
    $detailedReport += "  DETAILED RESULTS"
    $detailedReport += "========================================="
    $detailedReport += "Date: $(Get-Date)"
    $detailedReport += "Computer: $env:COMPUTERNAME"
    $detailedReport += "Admin: $(if ($script:IsAdmin) {'YES'} else {'NO'})"
    $detailedReport += "Launched via: $(if ($script:LaunchedViaBatch) {'Batch file'} else {'Direct PowerShell'})"
    $detailedReport += ""

    $detailedReport += "SUMMARY:"
    $detailedReport += "  Total: $total | Success: $success | Failed: $failed | Skipped: $skipped"
    $detailedReport += ""

    $detailedReport += "DETAILED RESULTS:"
    $detailedReport += "=" * 80
    foreach ($result in $TestResults) {
        $detailedReport += ""
        $detailedReport += "TOOL: $($result.Tool)"
        $detailedReport += "DESCRIPTION: $($result.Description)"
        $detailedReport += "STATUS: $($result.Status)"
        $detailedReport += "DURATION: $([math]::Round($result.Duration)) ms"
        $detailedReport += "OUTPUT:"
        if ($result.Output) {
            $result.Output -split "`n" | ForEach-Object { $detailedReport += "  $_" }
        }
        $detailedReport += "-" * 80
    }

    # Save reports
    try {
        $cleanReport | Out-File -FilePath $cleanPath -Encoding UTF8
        $detailedReport | Out-File -FilePath $detailedPath -Encoding UTF8

        $cleanSize = [math]::Round((Get-Item $cleanPath).Length/1KB,1)
        $detailSize = [math]::Round((Get-Item $detailedPath).Length/1KB,1)

        Write-Host ""
        Write-Host "Reports saved:" -ForegroundColor Green
        Write-Host "  Clean:    $cleanPath ($cleanSize KB)" -ForegroundColor White
        Write-Host "  Detailed: $detailedPath ($detailSize KB)" -ForegroundColor White
        Write-Host ""

        Write-Host "Which report would you like to open?" -ForegroundColor Yellow
        Write-Host "1. Clean Summary (Recommended)"
        Write-Host "2. Detailed Report"
        Write-Host "3. Both"
        Write-Host "4. None"
        
        $choice = Read-Host "Choice (1-4)"
        switch ($choice) {
            "1" { try { Start-Process notepad.exe $cleanPath } catch {} }
            "2" { try { Start-Process notepad.exe $detailedPath } catch {} }
            "3" { try { Start-Process notepad.exe $cleanPath; Start-Process notepad.exe $detailedPath } catch {} }
        }
    } catch {
        Write-Host "Error saving reports: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Menu
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  SYSINTERNALS TESTER v$script:VERSION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Drive: $DriveLetter | Admin: $(if ($script:IsAdmin) {'YES'} else {'NO'})" -ForegroundColor Gray
    Write-Host ""
    Write-Host "1.  System Information"
    Write-Host "2.  CPU Testing"
    Write-Host "3.  RAM Testing"
    Write-Host "4.  Storage Testing"
    Write-Host "5.  Process Analysis"
    Write-Host "6.  Security Analysis $(if (-not $script:IsAdmin) {'[Admin]'})"
    Write-Host "7.  Network Analysis"
    Write-Host "8.  OS Health (DISM/SFC) $(if (-not $script:IsAdmin) {'[Admin]'})"
    Write-Host "9.  Storage SMART"
    Write-Host "10. SSD TRIM Status"
    Write-Host "11. Network Adapters"
    Write-Host "12. GPU (Enhanced)" -ForegroundColor Cyan
    <#
    Write-Host "    └─ 12a. Basic GPU Info"
    Write-Host "    └─ 12b. Vendor-Specific (NVIDIA/AMD)"
    Write-Host "    └─ 12c. GPU Memory Test"
    #>
    Write-Host "    - 12a. Basic GPU Info"
    Write-Host "    - 12b. Vendor-Specific (NVIDIA/AMD)"
    Write-Host "    - 12c. GPU Memory Test"
    Write-Host "13. Power/Battery"
    Write-Host "14. Hardware Events (WHEA)"
    Write-Host "15. Windows Update"
    Write-Host "16. Run ALL Tests" -ForegroundColor Yellow
    Write-Host "17. Generate Report (Clean + Detailed)" -ForegroundColor Green
    Write-Host "18. Clear Results" -ForegroundColor Red
    Write-Host "Q.  Quit"
    Write-Host ""
    Write-Host "Tests completed: $($TestResults.Count)" -ForegroundColor Gray
}

function Start-Menu {
    do {
        Show-Menu
        $choice = Read-Host "`nSelect (1-18, 12a-c, Q)"
        switch ($choice) {
            "1"  { Test-SystemInfo; Read-Host "`nPress Enter" }
            "2"  { Test-CPU; Read-Host "`nPress Enter" }
            "3"  { Test-Memory; Read-Host "`nPress Enter" }
            "4"  { Test-Storage; Read-Host "`nPress Enter" }
            "5"  { Test-Processes; Read-Host "`nPress Enter" }
            "6"  { Test-Security; Read-Host "`nPress Enter" }
            "7"  { Test-Network; Read-Host "`nPress Enter" }
            "8"  { Test-OSHealth; Read-Host "`nPress Enter" }
            "9"  { Test-StorageSMART; Read-Host "`nPress Enter" }
            "10" { Test-Trim; Read-Host "`nPress Enter" }
            "11" { Test-NIC; Read-Host "`nPress Enter" }
            "12" { 
                # Run all GPU tests when "12" is selected
                Test-GPU
                Test-GPUVendorSpecific
                Test-GPUMemory
                Read-Host "`nPress Enter" 
            }
            "12a" { 
                # Basic GPU info only
                Test-GPU
                Read-Host "`nPress Enter" 
            }
            "12b" { 
                # Vendor-specific only
                Test-GPUVendorSpecific
                Read-Host "`nPress Enter" 
            }
            "12c" { 
                # GPU memory test only
                Test-GPUMemory
                Read-Host "`nPress Enter" 
            }
            "13" { Test-Power; Read-Host "`nPress Enter" }
            "14" { Test-HardwareEvents; Read-Host "`nPress Enter" }
            "15" { Test-WindowsUpdate; Read-Host "`nPress Enter" }
            "16" {
                Write-Host "`nRunning all tests..." -ForegroundColor Yellow
                Test-SystemInfo; Test-CPU; Test-Memory; Test-Storage
                Test-Processes; Test-Security; Test-Network; Test-OSHealth
                Test-StorageSMART; Test-Trim; Test-NIC
                Test-GPU; Test-GPUVendorSpecific; Test-GPUMemory  # All GPU tests
                Test-Power; Test-HardwareEvents; Test-WindowsUpdate
                Write-Host "`nAll tests complete!" -ForegroundColor Green
                Read-Host "Press Enter"
            }
            "17" { New-Report; Read-Host "`nPress Enter" }
            "18" { $script:TestResults = @(); Write-Host "Cleared" -ForegroundColor Green; Start-Sleep 1 }
            "Q"  { return }
            "q"  { return }
            default { Write-Host "Invalid" -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($choice -ne "Q" -and $choice -ne "q")
}

# Main - only execute if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Write-Host "Starting Sysinternals Tester v$script:VERSION..." -ForegroundColor Green

        if (!(Initialize-Environment)) {
            Write-Host "`nSetup required." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }

        if ($AutoRun) {
            Write-Host "`nAuto-running all tests..." -ForegroundColor Yellow
            if (-not $script:IsAdmin) {
                Write-Host "WARNING: Running without admin - some tests will be skipped" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
            Test-SystemInfo; Test-CPU; Test-Memory; Test-Storage
            Test-Processes; Test-Security; Test-Network; Test-OSHealth
            Test-StorageSMART; Test-Trim; Test-NIC
            Test-GPU; Test-GPUVendorSpecific; Test-GPUMemory
            Test-Power; Test-HardwareEvents; Test-WindowsUpdate
            New-Report
            Write-Host "`nAuto-run complete!" -ForegroundColor Green
            Read-Host "Press Enter to exit"
        } else {
            Start-Menu
        }

        Write-Host "`nSession complete!" -ForegroundColor Green
    }
    catch {
        Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    finally {
        Write-Host "Thank you for using Sysinternals Tester v$script:VERSION!" -ForegroundColor Cyan
    }
}
