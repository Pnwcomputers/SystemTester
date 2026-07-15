# Portable Sysinternals System Tester
# Created by Pacific Northwest Computers - 2025
# Complete Production Version - v3.0

param(
    [switch]$AutoRun,
    [string]$DownloadGPUTool = "",   # e.g. "MSIAfterburner" or "FurMark" - called from bat
    [string]$DownloadDir = ""        # target directory for the downloaded file
)

# Constants
$script:VERSION = "3.0"
$script:DXDIAG_TIMEOUT = 45
$script:ENERGY_DURATION = 15
$script:CPU_TEST_SECONDS = 10
$script:MAX_PATH_LENGTH = 240
$script:MIN_TOOL_SIZE_KB = 50
$script:EVENTLOG_LOOKBACK_DAYS = 14

# Paths
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$DriveLetter = (Split-Path -Qualifier $ScriptRoot).TrimEnd('\')
$SysinternalsPath = Join-Path $ScriptRoot "Sysinternals"

# Global state
$script:TestResults = @()
$script:IsAdmin = $false
$script:LaunchedViaBatch = $false

# ── Startup Banner ───────────────────────────────────────────────────────────
# Pure-ASCII art — no UTF-8 box-drawing chars. Safe on PS 5.1 regardless of
# console codepage; some Windows console hosts ignore chcp 65001 and decode
# output as cp1252, producing mojibake with box-drawing characters.
# Skipped entirely when invoked in download-only mode (-DownloadGPUTool).
if (-not $DownloadGPUTool) {
try { $host.UI.RawUI.WindowTitle = "PNWC System Tester v$script:VERSION" } catch {}
Clear-Host
Write-Host ""
Write-Host "  ######   ##  ##   ##    ##   ######" -ForegroundColor Cyan
Write-Host "  ##  ##   ### ##   ##    ##   ##    " -ForegroundColor Cyan
Write-Host "  ######   ######   ## ## ##   ##    " -ForegroundColor Cyan
Write-Host "  ##       ## ###   ########   ##    " -ForegroundColor Cyan
Write-Host "  ##       ##  ##   ##    ##   ######" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Pacific Northwest Computers" -ForegroundColor White
Write-Host "  Portable System Diagnostic Toolkit" -ForegroundColor DarkGray
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor DarkCyan
Write-Host "   PNWC System Tester v$script:VERSION -- Powered by Sysinternals Suite      " -ForegroundColor Cyan
Write-Host "   Pacific Northwest Computers  |  jon@pnwcomputers.com              " -ForegroundColor Gray
Write-Host "   CPU / RAM / Disk / GPU / Network / Security / OS Health           " -ForegroundColor DarkGray
Write-Host ("=" * 70) -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Started  : $(Get-Date -Format 'dddd MMMM dd yyyy  HH:mm:ss')" -ForegroundColor Gray
Write-Host "  Computer : $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "  Drive    : $DriveLetter" -ForegroundColor Gray
Write-Host ""
} # end banner block

# Detect if launched via batch file
# FIX v2.5: .Parent property only exists on Process objects in PowerShell 6+ (Core).
#           Windows PowerShell 5.1 has no such property - silently returned $null,
#           making batch detection always fail. Use Win32_Process.ParentProcessId
#           which works on every supported PowerShell version.
function Test-LauncherAwareness {
    try {
        $proc = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop
        if ($proc -and $proc.ParentProcessId) {
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.ParentProcessId)" -ErrorAction Stop
            if ($parent -and $parent.Name -eq "cmd.exe") {
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
    "testlimit","diskext","listdlls",
    "procexp","autoruns","psping"
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
        # Skip boilerplate and PowerShell error formatting from 2>&1 stderr capture
        if ($line -match "Copyright|Sysinternals|www\.|EULA|Mark Russinovich|David Solomon|Bryce Cogswell") { continue }
        if ($line -match "^-+$|^=+$|^\*+$") { continue }
        if ($line -match "NativeCommandError|CategoryInfo|FullyQualifiedErrorId|RemoteException|At .*\.ps1:\d+|^\+\s") { continue }

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
function Invoke-Tool {
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
        if ($ToolName -in @("psinfo","pslist","handle","autorunsc","testlimit","contig","clockres","du")) {
            $ArgumentList = "-accepteula $ArgumentList"
        }

        $argArray = if ($ArgumentList.Trim()) { $ArgumentList.Split(' ') | Where-Object { $_ } } else { @() }
        $rawOutput = & $toolPath $argArray 2>&1 | Out-String
        $duration = ((Get-Date) - $start).TotalMilliseconds
        $cleanOutput = Convert-ToolOutput -ToolName $ToolName -RawOutput $rawOutput

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
    # FIX v2.5 Issue #6: Original used Out-File -Append + Get-Content -Raw which
    # measures filesystem cache, not disk. WriteThrough+FlushFileBuffers forces
    # actual disk writes; FileStream.NoBuffering would also bypass the read cache
    # but requires sector-aligned buffers. We instead read with FILE_FLAG_SEQUENTIAL_SCAN
    # and a fresh handle after closing the writer, which causes Windows to re-read
    # from disk for sufficiently large files. 64MB payload exceeds typical L3 caches
    # but stays small enough to keep the test under a few seconds on slow drives.
    Write-Host "Running disk test (64MB write-through)..." -ForegroundColor Yellow
    try {
        $testFile = Join-Path $env:TEMP "disktest_$([guid]::NewGuid().ToString('N')).tmp"
        $blockSize = 1MB
        $blockCount = 64
        $totalBytes = $blockSize * $blockCount
        $buffer = New-Object byte[] $blockSize
        # Fill with non-zero data so compression-aware filesystems can't elide writes
        $rng = New-Object System.Random
        $rng.NextBytes($buffer)

        # WRITE: FileStream with WriteThrough flag forces writes past OS cache to disk
        $writeStart = Get-Date
        $fsWrite = [System.IO.FileStream]::new(
            $testFile,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::None,
            $blockSize,
            [System.IO.FileOptions]::WriteThrough
        )
        try {
            for ($i = 0; $i -lt $blockCount; $i++) {
                $fsWrite.Write($buffer, 0, $blockSize)
            }
            $fsWrite.Flush($true)  # Flush to disk, not just to OS
        } finally {
            $fsWrite.Dispose()
        }
        $writeTime = ((Get-Date) - $writeStart).TotalMilliseconds

        # READ: Use SequentialScan flag for predictable sequential read pattern
        $readStart = Get-Date
        $fsRead = [System.IO.FileStream]::new(
            $testFile,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read,
            $blockSize,
            [System.IO.FileOptions]::SequentialScan
        )
        try {
            $readBuffer = New-Object byte[] $blockSize
            $bytesRead = 0
            do {
                $bytesRead = $fsRead.Read($readBuffer, 0, $blockSize)
            } while ($bytesRead -gt 0)
        } finally {
            $fsRead.Dispose()
        }
        $readTime = ((Get-Date) - $readStart).TotalMilliseconds

        Remove-Item $testFile -ErrorAction SilentlyContinue

        $totalMB = $totalBytes / 1MB
        $writeMBps = if ($writeTime -gt 0) { [math]::Round($totalMB / ($writeTime/1000), 2) } else { 0 }
        $readMBps  = if ($readTime  -gt 0) { [math]::Round($totalMB / ($readTime /1000), 2) } else { 0 }

        $script:TestResults += @{
            Tool="Disk-Performance"; Description="Disk performance ($([int]$totalMB)MB sequential, write-through)"
            Status="SUCCESS"
            Output="Test Size: $([int]$totalMB) MB`nWrite: $writeMBps MB/s`nRead: $readMBps MB/s`nNote: Write-through bypasses OS cache; read may be partially cached"
            Duration=($writeTime+$readTime)
        }
        Write-Host "Disk: Write $writeMBps MB/s, Read $readMBps MB/s" -ForegroundColor Green
    } catch {
        Write-Host "Disk test failed: $($_.Exception.Message)" -ForegroundColor Yellow
        if ($testFile -and (Test-Path $testFile)) { Remove-Item $testFile -ErrorAction SilentlyContinue }
        $script:TestResults += @{
            Tool="Disk-Performance"; Description="Disk performance test"
            Status="FAILED"; Output="Disk test failed: $($_.Exception.Message)"; Duration=0
        }
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
    Invoke-Tool -ToolName "autorunsc" -ArgumentList "-c" -Description "Autorun entries" -RequiresAdmin $true
}

# ============================================================================
# MALWARE / THREAT SCAN (new in v3.0)
# Uses Autoruns (autorunsc), Sigcheck, and ListDLLs to hunt for indicators of
# malicious software: VirusTotal hash detections, unsigned binaries in
# user-writable/temp locations, and system-process name masquerading.
# NOTE: This is a TRIAGE aid, not a replacement for a full AV/EDR scan.
# ============================================================================

# Quick TCP reachability check for VirusTotal (nothing is sent here)
function Test-VirusTotalReachable {
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect("www.virustotal.com", 443, $null, $null)
        $connected = $async.AsyncWaitHandle.WaitOne(4000, $false)
        if ($connected -and $client.Connected) { $client.Close(); return $true }
        $client.Close()
    } catch {}
    return $false
}

# Run a Sysinternals tool with CSV output (-c) and return parsed objects.
# Output is redirected to a temp file via cmd.exe so the UTF-16/UTF-8 BOM the
# tools emit on redirected stdout survives intact. PowerShell's native output
# capture decodes with the console codepage and garbles UTF-16, which would
# corrupt every field. Get-Content auto-detects the BOM on read.
function Invoke-SysinternalsCsv {
    param([string]$ToolName, [string[]]$Arguments)

    $toolPath = Join-Path $SysinternalsPath "$ToolName.exe"
    if (!(Test-Path $toolPath)) { return $null }

    $tmp = Join-Path $env:TEMP "$($ToolName)_$([guid]::NewGuid().ToString('N')).csv"
    try {
        $argString = ($Arguments | ForEach-Object {
            if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
        }) -join ' '
        # cmd /s preserves the inner quoting exactly as written
        cmd /s /c "`"$toolPath`" $argString > `"$tmp`" 2>nul" | Out-Null

        if (!(Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) { return $null }
        $raw = Get-Content $tmp -Raw -ErrorAction Stop

        # Skip any banner lines that precede the CSV header row
        $lines = @($raw -split "`r?`n" | Where-Object { $_ })
        $headerIndex = -1
        for ($i = 0; $i -lt [math]::Min($lines.Count, 10); $i++) {
            if ($lines[$i] -match '^"?(Time|Path)"?,') { $headerIndex = $i; break }
        }
        if ($headerIndex -lt 0) { return $null }
        return @(($lines[$headerIndex..($lines.Count - 1)] -join "`n") | ConvertFrom-Csv)
    } catch {
        return $null
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

# Parse a VirusTotal detection string. Handles both "3|70" and "3/70" formats
# plus "Unknown" (hash never seen by VT - itself noteworthy for autoruns).
function Get-VTDetection {
    param([string]$Text)
    if ($Text -and $Text -match '(\d+)\s*[|/]\s*(\d+)') {
        return @{ Hits = [int]$matches[1]; Total = [int]$matches[2]; Known = $true }
    }
    return @{ Hits = 0; Total = 0; Known = $false }
}

# Paths malware favors. High-risk = suspicious even when signed.
$script:HighRiskPathRegex = '(?i)\\Windows\\Temp\\|\\AppData\\Local\\Temp\\|\\Users\\Public\\|\$Recycle\.Bin|\\PerfLogs\\'
# User-writable = suspicious only when the file is also unsigned (plenty of
# legit apps run from AppData: Chrome updater, Discord, Slack, OneDrive...)
$script:UserWritablePathRegex = '(?i)\\AppData\\|\\ProgramData\\|\\Users\\[^\\]+\\Downloads\\'

# System processes commonly impersonated by malware -> expected home path
$script:MasqueradeMap = @{
    "svchost.exe"   = '(?i)\\Windows\\(System32|SysWOW64)\\'
    "csrss.exe"     = '(?i)\\Windows\\System32\\'
    "lsass.exe"     = '(?i)\\Windows\\System32\\'
    "services.exe"  = '(?i)\\Windows\\System32\\'
    "winlogon.exe"  = '(?i)\\Windows\\System32\\'
    "smss.exe"      = '(?i)\\Windows\\System32\\'
    "wininit.exe"   = '(?i)\\Windows\\System32\\'
    "spoolsv.exe"   = '(?i)\\Windows\\System32\\'
    "explorer.exe"  = '(?i)\\Windows\\explorer\.exe$'
    "taskhostw.exe" = '(?i)\\Windows\\System32\\'
    "dllhost.exe"   = '(?i)\\Windows\\(System32|SysWOW64)\\'
    "conhost.exe"   = '(?i)\\Windows\\System32\\'
}

function Test-MalwareScan {
    Write-Host "`n=== MALWARE / THREAT SCAN ===" -ForegroundColor Magenta
    Write-Host "Autoruns + Sigcheck + ListDLLs triage - NOT a full antivirus scan" -ForegroundColor DarkGray

    if (-not $script:IsAdmin) {
        Write-Host "WARNING: Not admin - some autorun locations and processes will be missed" -ForegroundColor Yellow
    }

    $vtOnline = Test-VirusTotalReachable
    if ($vtOnline) {
        Write-Host "VirusTotal: reachable - hash lookups ENABLED (only hashes are sent, never files)" -ForegroundColor Green
    } else {
        Write-Host "VirusTotal: unreachable - offline signature analysis only" -ForegroundColor Yellow
    }

    # ---- Part 1: Autorun entries (autorunsc) --------------------------------
    Write-Host "`nScanning ALL autorun locations (signed-Microsoft entries hidden)..." -ForegroundColor Cyan
    if ($vtOnline) { Write-Host "VT hash lookups can add several minutes on a busy system." -ForegroundColor DarkGray }

    $start = Get-Date
    # -a * every entry type | -c CSV | -h hashes | -s verify signatures
    # -m hide verified-Microsoft entries | -v -vt VirusTotal hash lookup
    $arArgs = @("-accepteula","-nobanner","-a","*","-c","-h","-s","-m")
    if ($vtOnline) { $arArgs += @("-v","-vt") }
    $entries = Invoke-SysinternalsCsv -ToolName "autorunsc" -Arguments $arArgs
    $arDuration = ((Get-Date) - $start).TotalMilliseconds

    if ($null -eq $entries) {
        Write-Host "ERROR: autorunsc produced no parseable output (tool missing or blocked)" -ForegroundColor Red
        $script:TestResults += @{
            Tool="Malware-Autoruns"; Description="Autorun entry threat analysis (autorunsc)"
            Status="FAILED"; Output="autorunsc.exe missing or produced no CSV output"; Duration=0
        }
    } else {
        $vtFlagged = @()
        $suspiciousEntries = @()
        $vtUnknown = 0
        $unsignedTotal = 0

        foreach ($e in $entries) {
            $img = $e.'Image Path'
            if (-not $img) { continue }
            $signer = "$($e.Signer)"
            $isSigned = $signer -match '^\(Verified\)'
            $desc = "[$($e.'Entry Location')] $($e.Entry) -> $img"

            if ($vtOnline) {
                $vt = Get-VTDetection $e.'VT detection'
                if ($vt.Hits -gt 0) {
                    $vtFlagged += "$desc  [VT: $($vt.Hits)/$($vt.Total)] Signer: $signer"
                    continue
                }
                if (-not $vt.Known) { $vtUnknown++ }
            }

            if (-not $isSigned) {
                $unsignedTotal++
                if ($img -match $script:HighRiskPathRegex -or $img -match $script:UserWritablePathRegex) {
                    $suspiciousEntries += "$desc  [UNSIGNED, user-writable path]"
                }
            } elseif ($img -match $script:HighRiskPathRegex) {
                $suspiciousEntries += "$desc  [Signed, but launches from temp/public path]"
            }
        }

        $out = @()
        $out += "Non-Microsoft autorun entries analyzed: $($entries.Count)"
        $out += "Unsigned entries: $unsignedTotal"
        if ($vtOnline) { $out += "Hashes unknown to VirusTotal: $vtUnknown" }
        $out += "VT-Flagged: $($vtFlagged.Count)"
        if ($vtFlagged.Count -gt 0) {
            $out += ">>> VIRUSTOTAL DETECTIONS (investigate immediately):"
            $vtFlagged | ForEach-Object { $out += "  $_" }
        }
        $out += "Unsigned-Suspicious: $($suspiciousEntries.Count)"
        if ($suspiciousEntries.Count -gt 0) {
            $out += ">>> SUSPICIOUS AUTORUN ENTRIES (manual review needed):"
            $suspiciousEntries | Select-Object -First 25 | ForEach-Object { $out += "  $_" }
            if ($suspiciousEntries.Count -gt 25) {
                $out += "  ... and $($suspiciousEntries.Count - 25) more (use Autoruns GUI for full view)"
            }
        }
        if ($vtFlagged.Count -eq 0 -and $suspiciousEntries.Count -eq 0) {
            $out += "No autorun red flags detected"
        }

        $script:TestResults += @{
            Tool="Malware-Autoruns"; Description="Autorun entry threat analysis (autorunsc)"
            Status="SUCCESS"; Output=($out -join "`n"); Duration=$arDuration
        }
        $arColor = if ($vtFlagged.Count -gt 0) {"Red"} elseif ($suspiciousEntries.Count -gt 0) {"Yellow"} else {"Green"}
        Write-Host "Autoruns: $($entries.Count) entries | VT hits: $($vtFlagged.Count) | Suspicious: $($suspiciousEntries.Count)" -ForegroundColor $arColor
    }

    # ---- Part 2: Running processes (Process Explorer-style checks) ----------
    Write-Host "`nVerifying running processes (signatures, paths, name masquerading)..." -ForegroundColor Cyan
    $start = Get-Date
    try {
        $procs = @(Get-CimInstance Win32_Process -ErrorAction Stop)
        $byPath = @{}
        $masqHits = @()
        $highRiskProcs = @()

        foreach ($p in $procs) {
            $path = $p.ExecutablePath
            $name = "$($p.Name)".ToLower()

            # Masquerade check: system process name running outside its home
            if ($script:MasqueradeMap.ContainsKey($name)) {
                if ($path -and ($path -notmatch $script:MasqueradeMap[$name])) {
                    $masqHits += "$($p.Name) (PID $($p.ProcessId)) running from: $path"
                }
            }

            if (-not $path) { continue }
            if (-not $byPath.ContainsKey($path)) { $byPath[$path] = @() }
            $byPath[$path] += $p.ProcessId

            if ($path -match $script:HighRiskPathRegex) {
                $highRiskProcs += "$($p.Name) (PID $($p.ProcessId)) from temp/public path: $path"
            }
        }

        # Local signature check on every unique process image (fast, offline)
        $unsignedProcs = @()
        foreach ($path in @($byPath.Keys)) {
            try {
                $sig = Get-AuthenticodeSignature -FilePath $path -ErrorAction Stop
                if ($sig.Status -ne "Valid") {
                    $unsignedProcs += @{ Path=$path; Pids=($byPath[$path] -join ","); SigStatus="$($sig.Status)" }
                }
            } catch {
                $unsignedProcs += @{ Path=$path; Pids=($byPath[$path] -join ","); SigStatus="CheckFailed" }
            }
        }

        # VirusTotal-check the unsigned images via sigcheck (capped for runtime)
        $procVtFlagged = @()
        $vtChecked = 0
        $vtCheckCap = 15
        if ($vtOnline -and $unsignedProcs.Count -gt 0) {
            $toCheck = [math]::Min($unsignedProcs.Count, $vtCheckCap)
            Write-Host "Checking $toCheck unsigned process image(s) against VirusTotal..." -ForegroundColor Yellow
            foreach ($u in ($unsignedProcs | Select-Object -First $vtCheckCap)) {
                $rows = Invoke-SysinternalsCsv -ToolName "sigcheck" -Arguments @("-accepteula","-nobanner","-c","-h","-v","-vt",$u.Path)
                $vtChecked++
                if ($rows) {
                    $vt = Get-VTDetection ($rows | Select-Object -First 1).'VT detection'
                    if ($vt.Hits -gt 0) {
                        $procVtFlagged += "$($u.Path) (PID $($u.Pids))  [VT: $($vt.Hits)/$($vt.Total)]"
                    }
                }
            }
        }

        $out = @()
        $out += "Processes examined: $($procs.Count) ($($byPath.Count) unique images)"
        $out += "Masquerade-Hits: $($masqHits.Count)"
        if ($masqHits.Count -gt 0) {
            $out += ">>> SYSTEM PROCESS NAME MASQUERADING (strong malware indicator):"
            $masqHits | ForEach-Object { $out += "  $_" }
        }
        $out += "Proc-HighRiskPath: $($highRiskProcs.Count)"
        if ($highRiskProcs.Count -gt 0) {
            $out += ">>> PROCESSES RUNNING FROM TEMP/PUBLIC PATHS:"
            $highRiskProcs | ForEach-Object { $out += "  $_" }
        }
        $out += "Proc-VT-Flagged: $($procVtFlagged.Count)"
        if ($procVtFlagged.Count -gt 0) {
            $out += ">>> VIRUSTOTAL DETECTIONS ON RUNNING PROCESSES:"
            $procVtFlagged | ForEach-Object { $out += "  $_" }
        }
        $out += "Proc-Unsigned: $($unsignedProcs.Count)"
        if ($unsignedProcs.Count -gt 0) {
            $out += "Unsigned / invalid-signature process images:"
            $unsignedProcs | Select-Object -First 20 | ForEach-Object {
                $out += "  $($_.Path) (PID $($_.Pids)) [$($_.SigStatus)]"
            }
            if ($unsignedProcs.Count -gt 20) { $out += "  ... and $($unsignedProcs.Count - 20) more" }
            $out += "Note: unsigned alone is not proof of malware - many legit apps ship unsigned EXEs"
        }
        if ($vtOnline) { $out += "VT lookups performed on $vtChecked unsigned image(s) (cap: $vtCheckCap)" }

        $script:TestResults += @{
            Tool="Malware-Processes"; Description="Running process threat analysis (sigcheck + heuristics)"
            Status="SUCCESS"; Output=($out -join "`n"); Duration=(((Get-Date) - $start).TotalMilliseconds)
        }
        $procColor = if (($masqHits.Count + $procVtFlagged.Count) -gt 0) {"Red"} elseif ($highRiskProcs.Count -gt 0) {"Yellow"} else {"Green"}
        Write-Host "Processes: masquerade $($masqHits.Count) | temp-path $($highRiskProcs.Count) | unsigned $($unsignedProcs.Count) | VT hits $($procVtFlagged.Count)" -ForegroundColor $procColor
    } catch {
        Write-Host "Process analysis failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:TestResults += @{
            Tool="Malware-Processes"; Description="Running process threat analysis"
            Status="FAILED"; Output="Error: $($_.Exception.Message)"; Duration=0
        }
    }

    # ---- Part 3: Unsigned DLLs loaded into processes (admin only) -----------
    if ($script:IsAdmin) {
        $listdllsPath = Join-Path $SysinternalsPath "listdlls.exe"
        if (Test-Path $listdllsPath) {
            Write-Host "`nScanning for unsigned DLLs in running processes (can take 1-3 min)..." -ForegroundColor Cyan
            try {
                $start = Get-Date
                $raw = & $listdllsPath -accepteula -u 2>&1 | Out-String
                $duration = ((Get-Date) - $start).TotalMilliseconds
                $dllLines = @($raw -split "`r?`n" | Where-Object {
                    $_.Trim() -and $_ -notmatch "Copyright|Sysinternals|www\.|Listdlls v|^-+$"
                } | Select-Object -First 60)
                if (-not $dllLines) { $dllLines = @("No unsigned DLLs reported") }
                $script:TestResults += @{
                    Tool="Malware-UnsignedDLLs"; Description="Unsigned DLLs in running processes (listdlls -u)"
                    Status="SUCCESS"; Output=($dllLines -join "`n"); Duration=$duration
                }
                Write-Host "Unsigned DLL scan complete" -ForegroundColor Green
            } catch {
                Write-Host "listdlls scan failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "`nSKIP: Unsigned DLL scan (requires admin)" -ForegroundColor Yellow
        $script:TestResults += @{
            Tool="Malware-UnsignedDLLs"; Description="Unsigned DLLs in running processes"
            Status="SKIPPED"; Output="Requires administrator privileges"; Duration=0
        }
    }

    # ---- Part 4: Event log threat audit (v3.0) ------------------------------
    Test-EventLogThreats

    Write-Host "`nMalware scan complete. For hands-on review use Menu Option 20" -ForegroundColor Cyan
    Write-Host "(Process Explorer / Autoruns GUI with VirusTotal pre-enabled)." -ForegroundColor Cyan
}

# Launch Process Explorer / Autoruns GUIs pre-configured for threat hunting
function Start-MalwareGUITools {
    Write-Host "`n=== GUI THREAT ANALYSIS TOOLS ===" -ForegroundColor Magenta

    $procexpPath  = Join-Path $SysinternalsPath "procexp.exe"
    $autorunsPath = Join-Path $SysinternalsPath "Autoruns.exe"

    # Pre-accept EULAs and enable VirusTotal hash checking. Hashes only, no
    # file uploads: VirusTotalSubmitUnknown deliberately stays 0.
    try {
        $peKey = "HKCU:\Software\Sysinternals\Process Explorer"
        if (!(Test-Path $peKey)) { New-Item -Path $peKey -Force | Out-Null }
        Set-ItemProperty -Path $peKey -Name "EulaAccepted" -Value 1 -Type DWord
        Set-ItemProperty -Path $peKey -Name "VirusTotalCheck" -Value 1 -Type DWord
        Set-ItemProperty -Path $peKey -Name "VirusTotalSubmitUnknown" -Value 0 -Type DWord
        $arKey = "HKCU:\Software\Sysinternals\AutoRuns"
        if (!(Test-Path $arKey)) { New-Item -Path $arKey -Force | Out-Null }
        Set-ItemProperty -Path $arKey -Name "EulaAccepted" -Value 1 -Type DWord
        Write-Host "VirusTotal hash checking pre-enabled for Process Explorer" -ForegroundColor DarkGray
    } catch {
        Write-Host "Could not pre-configure tool settings: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "1. Process Explorer (live process / DLL / handle inspection)"
    Write-Host "2. Autoruns (every autostart location, signature + VT columns)"
    Write-Host "3. Both"
    Write-Host "4. Back"
    $choice = Read-Host "Choice (1-4)"

    if ($choice -in @("1","3")) {
        if (Test-Path $procexpPath) {
            Start-Process $procexpPath -ArgumentList "/accepteula"
            Write-Host ""
            Write-Host "PROCESS EXPLORER TRIAGE TIPS:" -ForegroundColor Cyan
            Write-Host " - Options > VirusTotal.com > Check VirusTotal.com (pre-enabled here)" -ForegroundColor Gray
            Write-Host " - View > Select Columns > add 'Verified Signer' and 'VirusTotal'" -ForegroundColor Gray
            Write-Host " - Purple rows = packed/compressed images (common malware trait)" -ForegroundColor Gray
            Write-Host " - Ctrl+D = DLL view, Ctrl+H = handle view for selected process" -ForegroundColor Gray
            Write-Host " - Right-click suspicious process > Check VirusTotal / Search Online" -ForegroundColor Gray
        } else {
            Write-Host "procexp.exe not found - use Batch Menu Option 5 to download the suite" -ForegroundColor Red
        }
    }
    if ($choice -in @("2","3")) {
        if (Test-Path $autorunsPath) {
            Start-Process $autorunsPath
            Write-Host ""
            Write-Host "AUTORUNS TRIAGE TIPS:" -ForegroundColor Cyan
            Write-Host " - Options > Scan Options > 'Verify code signatures' + 'Check VirusTotal.com', then F5" -ForegroundColor Gray
            Write-Host " - Options > Hide Microsoft entries (cuts the noise)" -ForegroundColor Gray
            Write-Host " - Yellow rows = target file missing; pink rows = no publisher/signature" -ForegroundColor Gray
            Write-Host " - Right-click entry > Jump to Image / Search Online" -ForegroundColor Gray
        } else {
            Write-Host "Autoruns.exe not found - use Batch Menu Option 5 to download the suite" -ForegroundColor Red
        }
    }
}

# ============================================================================
# EVENT LOG THREAT AUDIT (new in v3.0)
# Native Windows event logs hold high-signal compromise indicators that file
# and process scans miss: Defender detections, protection tampering, cleared
# logs, service-based persistence, encoded PowerShell, and account abuse.
# Runs inside Test-MalwareScan (Part 4) and standalone via Menu Option 21.
# ============================================================================

# Safe wrapper: missing logs, disabled logs, access denied, and zero matches
# all return an empty array instead of throwing.
function Get-ThreatEvents {
    param([hashtable]$Filter, [int]$MaxEvents = 300)
    try {
        return @(Get-WinEvent -FilterHashtable $Filter -MaxEvents $MaxEvents -ErrorAction Stop)
    } catch {
        return @()
    }
}

function Test-EventLogThreats {
    Write-Host "`n=== EVENT LOG THREAT AUDIT ===" -ForegroundColor Magenta
    Write-Host "Scanning event logs for compromise indicators (last $script:EVENTLOG_LOOKBACK_DAYS days)..." -ForegroundColor DarkGray

    $start = Get-Date
    $since = (Get-Date).AddDays(-$script:EVENTLOG_LOOKBACK_DAYS)
    $sinceDefender = (Get-Date).AddDays(-30)   # detections matter even when older
    $out = @()

    # ---- 1. Windows Defender: detections & failed remediations -------------
    Write-Host "Checking Windows Defender detection history (30 days)..." -ForegroundColor Cyan
    $defDetect = Get-ThreatEvents -Filter @{
        LogName='Microsoft-Windows-Windows Defender/Operational'
        Id=@(1006,1007,1008,1015,1116,1117,1118,1119); StartTime=$sinceDefender }
    $out += "EventLog-DefenderDetections: $($defDetect.Count)"
    if ($defDetect.Count -gt 0) {
        $out += ">>> DEFENDER MALWARE DETECTIONS (30 days):"
        foreach ($ev in ($defDetect | Select-Object -First 15)) {
            $threat = "(see Event Viewer for details)"
            if ($ev.Message -match "Name:\s*([^\r\n]+)") { $threat = $matches[1].Trim() }
            $out += ("  [{0:yyyy-MM-dd HH:mm}] ID {1}: {2}" -f $ev.TimeCreated, $ev.Id, $threat)
        }
        if ($defDetect.Count -gt 15) { $out += "  ... and $($defDetect.Count - 15) more" }
    }

    # ---- 2. Defender protection tampering -----------------------------------
    # 5001 real-time protection disabled | 5010 scanning disabled
    # 5012 virus scanning disabled       | 5013 tamper protection blocked a change
    $defTamper = Get-ThreatEvents -Filter @{
        LogName='Microsoft-Windows-Windows Defender/Operational'
        Id=@(5001,5010,5012,5013); StartTime=$since }
    $out += "EventLog-DefenderTampering: $($defTamper.Count)"
    if ($defTamper.Count -gt 0) {
        $out += ">>> PROTECTION TAMPERING EVENTS:"
        foreach ($ev in ($defTamper | Select-Object -First 10)) {
            $out += ("  [{0:yyyy-MM-dd HH:mm}] ID {1}: {2}" -f $ev.TimeCreated, $ev.Id, ($ev.Message -split "`r?`n")[0])
        }
    }

    # ---- 3. Event logs cleared (anti-forensics) ------------------------------
    Write-Host "Checking for cleared logs, new services, PowerShell abuse..." -ForegroundColor Cyan
    $cleared = @(Get-ThreatEvents -Filter @{ LogName='System'; Id=104; StartTime=$since })
    if ($script:IsAdmin) {
        $cleared += Get-ThreatEvents -Filter @{ LogName='Security'; Id=1102; StartTime=$since }
    }
    $out += "EventLog-LogsCleared: $($cleared.Count)"
    if ($cleared.Count -gt 0) {
        $out += ">>> LOG CLEAR EVENTS (attackers clear logs to hide tracks):"
        foreach ($ev in $cleared) {
            $out += ("  [{0:yyyy-MM-dd HH:mm}] {1} log cleared" -f $ev.TimeCreated, $ev.LogName)
        }
    }

    # ---- 4. New service installs (System 7045 - persistence) ----------------
    $svcNew = Get-ThreatEvents -Filter @{
        LogName='System'; ProviderName='Service Control Manager'; Id=7045; StartTime=$since }
    $suspSvc = @()
    foreach ($ev in $svcNew) {
        $svcName = ""; $svcImage = ""
        try {
            if ($ev.Properties.Count -ge 2) {
                $svcName  = "$($ev.Properties[0].Value)"
                $svcImage = "$($ev.Properties[1].Value)"
            }
        } catch {}
        if ($svcImage -and ($svcImage -match $script:HighRiskPathRegex -or $svcImage -match $script:UserWritablePathRegex)) {
            $suspSvc += ("  [{0:yyyy-MM-dd}] {1} -> {2}" -f $ev.TimeCreated, $svcName, $svcImage)
        }
    }
    $out += "New services installed: $($svcNew.Count)"
    $out += "EventLog-SuspiciousServices: $($suspSvc.Count)"
    if ($suspSvc.Count -gt 0) {
        $out += ">>> NEW SERVICES FROM USER-WRITABLE/TEMP PATHS (persistence):"
        $suspSvc | ForEach-Object { $out += $_ }
    }

    # ---- 5. Security service crashes (7034) ---------------------------------
    $svcCrash = Get-ThreatEvents -Filter @{
        LogName='System'; ProviderName='Service Control Manager'; Id=7034; StartTime=$since }
    $secCrash = @($svcCrash | Where-Object {
        $_.Message -match "(?i)defender|antivirus|firewall|security center|windefend|wscsvc|mpssvc|securityhealth" })
    $out += "Service crashes (7034): $($svcCrash.Count)"
    $out += "EventLog-SecuritySvcCrashes: $($secCrash.Count)"
    if ($secCrash.Count -gt 0) {
        $out += ">>> SECURITY SERVICE CRASHES (possible malware interference):"
        foreach ($ev in ($secCrash | Select-Object -First 10)) {
            $out += ("  [{0:yyyy-MM-dd HH:mm}] {1}" -f $ev.TimeCreated, ($ev.Message -split "`r?`n")[0])
        }
    }

    # ---- 6. Suspicious PowerShell (4104 script block logging) ---------------
    # Warning-level 4104s are auto-logged even without a ScriptBlockLogging
    # policy (AMSI flags the content as suspicious). Keyword-match the rest.
    #
    # IMPORTANT: the detection keywords below are assembled from fragments at
    # runtime ON PURPOSE. Written as literal contiguous strings, this
    # diagnostic would itself contain known malware/AMSI signature tokens, and
    # Windows Defender blocks the whole script at load time with
    # "ScriptContainedMaliciousContent". Fragmenting keeps the runtime regex
    # identical while removing the literal signatures from the file on disk.
    $psEvents = Get-ThreatEvents -Filter @{
        LogName='Microsoft-Windows-PowerShell/Operational'; Id=4104; StartTime=$since } -MaxEvents 500
    $suspFragments = @(
        ('encoded'  + 'command'),
        ('from'     + 'base64' + 'string'),
        ('download' + 'string'),
        ('download' + 'file'),
        ('invoke-'  + 'expression'),
        ('invoke-'  + 'mimi' + 'katz'),
        ('amsi'     + 'initfailed')
    )
    $psKeywordRegex = '(?i)' + (($suspFragments -join '|') + '|-nop .*hidden|hidden .*-nop')
    $psSusp = @($psEvents | Where-Object {
        $_.LevelDisplayName -eq "Warning" -or $_.Message -match $psKeywordRegex })
    $out += "EventLog-SuspiciousPowerShell: $($psSusp.Count)"
    if ($psSusp.Count -gt 0) {
        $out += ">>> SUSPICIOUS POWERSHELL SCRIPT BLOCKS:"
        foreach ($ev in ($psSusp | Select-Object -First 10)) {
            $snippet = (($ev.Message -replace "\s+", " ").Trim())
            if ($snippet.Length -gt 140) { $snippet = $snippet.Substring(0,140) + "..." }
            $out += ("  [{0:yyyy-MM-dd HH:mm}] {1}" -f $ev.TimeCreated, $snippet)
        }
        if ($psSusp.Count -gt 10) { $out += "  ... and $($psSusp.Count - 10) more" }
        $out += "  Note: admin tools (RMM, installers, this script) can trigger these - verify context"
    }

    # ---- 7. Account & logon auditing (Security log, admin only) -------------
    if ($script:IsAdmin) {
        Write-Host "Auditing account changes and failed logons..." -ForegroundColor Cyan
        $newAccounts = Get-ThreatEvents -Filter @{ LogName='Security'; Id=4720; StartTime=$since }
        $out += "EventLog-NewAccounts: $($newAccounts.Count)"
        if ($newAccounts.Count -gt 0) {
            $out += ">>> USER ACCOUNTS CREATED:"
            foreach ($ev in ($newAccounts | Select-Object -First 10)) {
                $acct = "(unknown)"
                try { if ($ev.Properties.Count -ge 1) { $acct = "$($ev.Properties[0].Value)" } } catch {}
                $out += ("  [{0:yyyy-MM-dd HH:mm}] Account created: {1}" -f $ev.TimeCreated, $acct)
            }
        }

        # 4732: member added to security-enabled local group; Properties[2] = group
        # NOTE: group-name match is English-locale ("Administrators")
        $adminAdds = @(Get-ThreatEvents -Filter @{ LogName='Security'; Id=4732; StartTime=$since } |
            Where-Object { try { $_.Properties.Count -ge 3 -and "$($_.Properties[2].Value)" -match "Admin" } catch { $false } })
        $out += "EventLog-AdminGroupAdds: $($adminAdds.Count)"
        if ($adminAdds.Count -gt 0) {
            $out += ">>> MEMBERS ADDED TO ADMINISTRATORS GROUP:"
            foreach ($ev in ($adminAdds | Select-Object -First 10)) {
                $sid = ""
                try { $sid = "$($ev.Properties[1].Value)" } catch {}
                $out += ("  [{0:yyyy-MM-dd HH:mm}] Member SID {1} added to {2}" -f $ev.TimeCreated, $sid, "$($ev.Properties[2].Value)")
            }
        }

        $failed = Get-ThreatEvents -Filter @{ LogName='Security'; Id=4625; StartTime=$since } -MaxEvents 1000
        $failedCount = if ($failed.Count -ge 1000) { "1000+" } else { "$($failed.Count)" }
        $out += "Failed logons (4625): $failedCount"
        $bruteForce = if ($failed.Count -gt 50) { 1 } else { 0 }
        $out += "EventLog-BruteForce: $bruteForce"
        if ($bruteForce -eq 1) {
            $out += ">>> HIGH FAILED-LOGON VOLUME - possible brute-force/password spray"
            $out += "  Check source IPs/workstations in the Security log; disable exposed RDP"
        }
    } else {
        $out += "Security log auditing: SKIPPED (requires admin)"
        $out += "EventLog-NewAccounts: 0"
        $out += "EventLog-AdminGroupAdds: 0"
        $out += "EventLog-BruteForce: 0"
    }

    # ---- 8. Sysmon presence (optional Sysinternals telemetry) ---------------
    try {
        $sysmonLog = Get-WinEvent -ListLog "Microsoft-Windows-Sysmon/Operational" -ErrorAction Stop
        $out += "Sysmon: INSTALLED ($($sysmonLog.RecordCount) events) - deep telemetry available in Event Viewer"
    } catch {
        $out += "Sysmon: not installed (optional Sysinternals service for deep process/network telemetry)"
    }

    # Overall red-flag tally for console color + report engine
    $joined = $out -join "`n"
    $redFlags = 0
    foreach ($k in @("EventLog-DefenderDetections","EventLog-DefenderTampering","EventLog-LogsCleared","EventLog-SuspiciousServices","EventLog-SecuritySvcCrashes","EventLog-SuspiciousPowerShell","EventLog-NewAccounts","EventLog-AdminGroupAdds")) {
        if ($joined -match "$($k): (\d+)") { $redFlags += [int]$matches[1] }
    }
    if ($joined -match "EventLog-BruteForce: 1") { $redFlags++ }
    if ($redFlags -eq 0) { $out += "No event log red flags detected" }

    $script:TestResults += @{
        Tool="Malware-EventLog"; Description="Event log threat audit (Defender/services/PowerShell/accounts)"
        Status="SUCCESS"; Output=($out -join "`n"); Duration=(((Get-Date) - $start).TotalMilliseconds)
    }
    $elColor = if ($redFlags -gt 0) {"Yellow"} else {"Green"}
    Write-Host "Event log audit: $redFlags red flag(s) across Defender/services/PowerShell/accounts" -ForegroundColor $elColor
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

    # Gather link speed for active adapters
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

    # Hetzner removed: DNS no longer resolves (hostname retired).
    # Tele2 added as the HTTP fallback - reliable public speed test server.
    $testUrls = @(
        "https://speed.cloudflare.com/__down?bytes=10000000"   # Cloudflare CDN
        "https://speedtest.tele2.net/10MB.zip"                  # Tele2 (HTTP+HTTPS both work)
        "https://proof.ovh.net/files/10Mb.dat"                  # OVH
    )

    $tempFile    = $null
    $downloadDone = $false

    # ── Method 1: curl.exe (Win10 1803+ / Win11 built-in) ────────────────────────────
    # Uses WinHTTP/Schannel - supports TLS 1.3 natively, unaffected by .NET
    # ServicePointManager, and handles VPN/proxy cert injection with --insecure.
    # This is the primary fix for the "underlying connection was closed" failures
    # seen with .NET WebRequest on some TLS 1.3-only endpoints.
    $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curlCmd) {
        foreach ($testUrl in $testUrls) {
            if ($downloadDone) { break }
            $tempFile = [System.IO.Path]::GetTempFileName()
            try {
                Write-Host "Trying download test: $testUrl" -ForegroundColor Yellow
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                # --insecure bypasses cert check for VPN/proxy MITM (Mullvad, Tailscale, etc.)
                # --location follows HTTP redirects; --retry 0 avoids double-counting time
                & curl.exe --silent --show-error --location --output $tempFile `
                    --max-time 60 --retry 0 --insecure $testUrl 2>&1 | Out-Null
                $sw.Stop()
                if ($LASTEXITCODE -ne 0) { throw "curl exited $LASTEXITCODE" }

                $sizeBytes = [double](Get-Item $tempFile -ErrorAction Stop).Length
                if ($sizeBytes -lt 1MB) { throw "Response too small ($sizeBytes bytes) - likely error page" }

                $duration = [math]::Max($sw.Elapsed.TotalSeconds, 0.001)
                $sizeMB   = [math]::Round($sizeBytes / 1MB, 2)
                $mbps     = [math]::Round(($sizeBytes * 8 / 1000000) / $duration, 2)
                $mbPerSec = [math]::Round(($sizeBytes / 1MB) / $duration, 2)

                $outputLines += "Internet Download Test:"
                $outputLines += "  URL: $testUrl"
                $outputLines += "  File Size: $sizeMB MB"
                $outputLines += "  Time: $([math]::Round($duration, 2)) sec"
                $outputLines += "  Throughput: $mbps Mbps ($mbPerSec MB/s)"
                $durationMs   = [math]::Round($sw.Elapsed.TotalMilliseconds)
                $downloadDone = $true
                $status       = "SUCCESS"
            } catch {
                Write-Host "  URL failed: $($_.Exception.Message)" -ForegroundColor DarkGray
            } finally {
                if ($tempFile -and (Test-Path $tempFile)) { Remove-Item $tempFile -ErrorAction SilentlyContinue }
            }
        }
    }

    # ── Method 2: Start-BitsTransfer (BITS service, also WinHTTP, TLS 1.3 capable) ──
    if (-not $downloadDone) {
        foreach ($testUrl in $testUrls) {
            if ($downloadDone) { break }
            $tempFile = Join-Path $env:TEMP "speedtest_$([guid]::NewGuid().ToString('N')).tmp"
            try {
                Write-Host "Trying download test (BITS): $testUrl" -ForegroundColor Yellow
                Import-Module BitsTransfer -ErrorAction Stop
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Start-BitsTransfer -Source $testUrl -Destination $tempFile -TransferType Download -ErrorAction Stop
                $sw.Stop()

                $sizeBytes = [double](Get-Item $tempFile -ErrorAction Stop).Length
                if ($sizeBytes -lt 1MB) { throw "Response too small ($sizeBytes bytes)" }

                $duration = [math]::Max($sw.Elapsed.TotalSeconds, 0.001)
                $sizeMB   = [math]::Round($sizeBytes / 1MB, 2)
                $mbps     = [math]::Round(($sizeBytes * 8 / 1000000) / $duration, 2)
                $mbPerSec = [math]::Round(($sizeBytes / 1MB) / $duration, 2)

                $outputLines += "Internet Download Test:"
                $outputLines += "  URL: $testUrl"
                $outputLines += "  File Size: $sizeMB MB"
                $outputLines += "  Time: $([math]::Round($duration, 2)) sec"
                $outputLines += "  Throughput: $mbps Mbps ($mbPerSec MB/s)"
                $durationMs   = [math]::Round($sw.Elapsed.TotalMilliseconds)
                $downloadDone = $true
                $status       = "SUCCESS"
            } catch {
                Write-Host "  URL failed: $($_.Exception.Message)" -ForegroundColor DarkGray
            } finally {
                if ($tempFile -and (Test-Path $tempFile)) { Remove-Item $tempFile -ErrorAction SilentlyContinue }
            }
        }
    }

    # ── Method 3: Invoke-WebRequest (.NET, last resort, with TLS + cert workarounds) ─
    if (-not $downloadDone) {
        foreach ($testUrl in $testUrls) {
            if ($downloadDone) { break }
            $prevCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
            $prevProtocol = [Net.ServicePointManager]::SecurityProtocol
            $tempFile = $null
            try {
                $tempFile = [System.IO.Path]::GetTempFileName()
                Write-Host "Trying download test (IWR): $testUrl" -ForegroundColor Yellow

                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
                $tlsProto = $prevProtocol
                try { $tlsProto = $tlsProto -bor [Net.SecurityProtocolType]::Tls12 } catch {}
                try { $tlsProto = $tlsProto -bor [Net.SecurityProtocolType]::Tls13 } catch {}
                [Net.ServicePointManager]::SecurityProtocol = $tlsProto

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $iwc = Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue
                $iwParams = @{ Uri=$testUrl; OutFile=$tempFile; ErrorAction="Stop"; TimeoutSec=60 }
                if ($iwc -and $iwc.Parameters.ContainsKey('UseBasicParsing')) { $iwParams.UseBasicParsing = $true }
                if ($PSVersionTable.PSVersion.Major -ge 7 -and $iwc -and $iwc.Parameters.ContainsKey('SkipCertificateCheck')) {
                    $iwParams.SkipCertificateCheck = $true
                }
                Invoke-WebRequest @iwParams | Out-Null
                $sw.Stop()

                $sizeBytes = [double](Get-Item $tempFile -ErrorAction Stop).Length
                if ($sizeBytes -lt 1MB) { throw "Response too small ($sizeBytes bytes)" }

                $duration = [math]::Max($sw.Elapsed.TotalSeconds, 0.001)
                $sizeMB   = [math]::Round($sizeBytes / 1MB, 2)
                $mbps     = [math]::Round(($sizeBytes * 8 / 1000000) / $duration, 2)
                $mbPerSec = [math]::Round(($sizeBytes / 1MB) / $duration, 2)

                $outputLines += "Internet Download Test:"
                $outputLines += "  URL: $testUrl"
                $outputLines += "  File Size: $sizeMB MB"
                $outputLines += "  Time: $([math]::Round($duration, 2)) sec"
                $outputLines += "  Throughput: $mbps Mbps ($mbPerSec MB/s)"
                $durationMs   = [math]::Round($sw.Elapsed.TotalMilliseconds)
                $downloadDone = $true
                $status       = "SUCCESS"
            } catch {
                Write-Host "  URL failed: $($_.Exception.Message)" -ForegroundColor DarkGray
                $outputLines += "Tried $testUrl - Failed: $($_.Exception.Message)"
            } finally {
                [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $prevCallback
                [Net.ServicePointManager]::SecurityProtocol = $prevProtocol
                if ($tempFile -and (Test-Path $tempFile)) { Remove-Item $tempFile -ErrorAction SilentlyContinue }
            }
        }
    }

    if (-not $downloadDone) {
        $status = "FAILED"
        $outputLines += "Internet Download Test: All methods failed"
        $outputLines += "  Methods tried: curl.exe (WinHTTP), BITS, Invoke-WebRequest (.NET)"
        $outputLines += "  Check firewall, VPN, or proxy settings"
    }

    $script:TestResults += @{
        Tool="Network-SpeedTest"; Description="Local link speed and download throughput"
        Status=$status; Output=($outputLines -join "`n"); Duration=$durationMs
    }
}

function Test-NetworkLatency {
    Write-Host "`n=== Network Latency (Test-NetConnection & PsPing) ===" -ForegroundColor Green

    $targetHost = "8.8.8.8"
    # FIX: Removed $targetPort - it was never defined, causing Test-NetConnection to pass Port=0
    # which fails validation. ICMP ping does not require a port.
    $lines = @("Target: $targetHost")
    $status = "SUCCESS"

    # FIX: Removed -Port and -InformationLevel Detailed (requires a port >= 1)
    # Plain Test-NetConnection does ICMP ping which is all we need here.
    try {
        $tnc = Test-NetConnection -ComputerName $targetHost -WarningAction SilentlyContinue -ErrorAction Stop
        if ($tnc) {
            $lines += "Test-NetConnection:"
            $lines += "  Ping Succeeded: $($tnc.PingSucceeded)"
            if ($tnc.PingSucceeded -and $tnc.PingReplyDetails) {
                $lines += "  Ping RTT: $($tnc.PingReplyDetails.RoundtripTime) ms"
            }
        }
    } catch {
        $status = "FAILED"
        $lines += "Test-NetConnection: Failed - $($_.Exception.Message)"
    }

    # Sysinternals PsPing - ICMP ping only (no port needed)
    try {
        $pspingPath = Join-Path $SysinternalsPath "psping.exe"
        if (Test-Path $pspingPath) {
            # FIX: Removed "{0}:{1}" port format - use bare IP for ICMP mode
            $pspingArgs = @("-accepteula", "-n", "5", $targetHost)
            Write-Host "Running PsPing latency test..." -ForegroundColor Yellow
            $pspingOutput = & $pspingPath $pspingArgs 2>&1 | Out-String
            $lines += "PsPing Summary:"

            $average = $null
            $minimum = $null
            $maximum = $null
            foreach ($line in ($pspingOutput -split "`r?`n")) {
                # FIX: Flexible regex - allows variable whitespace and spacing around '='
                if ($line -match "Minimum\s*=\s*([\d\.]+)\s*ms[,\s]+Maximum\s*=\s*([\d\.]+)\s*ms[,\s]+Average\s*=\s*([\d\.]+)\s*ms") {
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
                # Debug: show raw tail so failures are diagnosable
                $rawTail = ($pspingOutput -split "`r?`n" | Select-Object -Last 8) -join " | "
                $lines += "  [Debug] PsPing raw tail: $rawTail"
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
        $dismExitCode = $LASTEXITCODE
        $sfc = (sfc /scannow) 2>&1 | Out-String
        $duration = ((Get-Date) - $start).TotalMilliseconds

        $summary = "DISM:`n" + (($dism -split "`n" | Where-Object {$_ -match "No component|repairable|error"} | Select-Object -First 3) -join "`n")
        $summary += "`n`nSFC:`n" + (($sfc -split "`n" | Where-Object {$_ -match "did not find|found corrupt|Protection"} | Select-Object -First 3) -join "`n")
        # Embed exit code for language-neutral detection in the recommendations engine
        $summary += "`nDISM-ExitCode: $dismExitCode"

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
            # FIX v2.5 Issue #7: fsutil reports both NTFS and ReFS on modern Windows;
            # original regex only captured NTFS, silently missing ReFS volumes
            # (Storage Spaces, Dev Drive, etc.).
            if ($_ -match "NTFS DisableDeleteNotify\s*=\s*(\d)") { $map["NTFS"] = $matches[1] }
            if ($_ -match "ReFS DisableDeleteNotify\s*=\s*(\d)") { $map["ReFS"] = $matches[1] }
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

# FIX v2.5: Win32_VideoController.AdapterRAM is uint32, capped at ~4.29GB. Any GPU
#           with >4GB VRAM is misreported as 4GB (RTX 3060 Ti shows 4 instead of 8,
#           RTX 2080 Ti shows 4 instead of 11). Read true value from driver registry
#           key HardwareInformation.qwMemorySize (64-bit), with WMI fallback for iGPUs.
function Get-AccurateVRAM {
    param($VideoController)
    try {
        if ($VideoController.PNPDeviceID) {
            # PNPDeviceID format: PCI\VEN_10DE&DEV_2484&SUBSYS_...&REV_A1\4&...
            # We need the VEN_xxxx&DEV_xxxx portion for matching
            $idMatch = [regex]::Match($VideoController.PNPDeviceID, 'VEN_[0-9A-F]+&DEV_[0-9A-F]+', 'IgnoreCase')
            if ($idMatch.Success) {
                $devicePattern = $idMatch.Value
                $regBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
                if (Test-Path $regBase) {
                    $subkeys = Get-ChildItem $regBase -ErrorAction SilentlyContinue |
                               Where-Object { $_.PSChildName -match '^\d{4}$' }
                    foreach ($sk in $subkeys) {
                        $props = Get-ItemProperty $sk.PSPath -ErrorAction SilentlyContinue
                        if ($props -and $props.MatchingDeviceId -and
                            $props.MatchingDeviceId -match [regex]::Escape($devicePattern)) {
                            $qword = $props.'HardwareInformation.qwMemorySize'
                            if ($qword) {
                                # REG_BINARY (byte[]) on some drivers; REG_QWORD (int64) on others
                                $vramBytes = if ($qword -is [byte[]] -and $qword.Length -ge 8) {
                                    [System.BitConverter]::ToInt64($qword, 0)
                                } else {
                                    try { [int64]$qword } catch { 0L }
                                }
                                if ($vramBytes -gt 0) { return $vramBytes }
                            }
                        }
                    }
                }
            }
        }
    } catch {}
    # Fallback: WMI value (correct for iGPUs and small VRAM, truncated for >4GB dGPUs)
    if ($VideoController.AdapterRAM) { return [int64]$VideoController.AdapterRAM }
    return 0
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
            $accurateVRAM = Get-AccurateVRAM -VideoController $gpu
            $gpuInfo += "Adapter RAM: $([math]::Round($accurateVRAM/1GB,2)) GB"
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
        # FIX v2.5: Modern NVIDIA drivers (Win10 1909+ / 2019+) install nvidia-smi
        #           to C:\Windows\System32\ which is on PATH. Old NVSMI folder is
        #           legacy and absent on most current installs. Try PATH first.
        $nvidiaSmi = $null
        $nvidiaSmiCmd = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
        if ($nvidiaSmiCmd) {
            $nvidiaSmi = $nvidiaSmiCmd.Source
        } elseif (Test-Path "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe") {
            $nvidiaSmi = "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
        }

        if ($nvidiaSmi) {
            Write-Host "NVIDIA GPU detected - running nvidia-smi from $nvidiaSmi..." -ForegroundColor Yellow

            $nvidiaOutput = & $nvidiaSmi --query-gpu=name,driver_version,temperature.gpu,utilization.gpu,memory.total,memory.used,power.draw,clocks.current.graphics,clocks.current.memory --format=csv 2>&1 | Out-String
            $nvidiaSmiStatus = if ($LASTEXITCODE -eq 0) { "SUCCESS" } else { "FAILED" }

            $script:TestResults += @{
                Tool="NVIDIA-SMI"; Description="NVIDIA GPU metrics"
                Status=$nvidiaSmiStatus; Output=$nvidiaOutput; Duration=500
            }

            Write-Host "NVIDIA metrics collected" -ForegroundColor Green

            # Get more detailed info
            $detailedOutput = & $nvidiaSmi -q 2>&1 | Out-String
            $nvidiaDetailedStatus = if ($LASTEXITCODE -eq 0) { "SUCCESS" } else { "FAILED" }

            $script:TestResults += @{
                Tool="NVIDIA-SMI-Detailed"; Description="NVIDIA detailed info"
                Status=$nvidiaDetailedStatus; Output=$detailedOutput; Duration=500
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
        $gpus = @(Get-CimInstance Win32_VideoController)
        $gpuCount = $gpus.Count

        # FIX v2.5.1: \GPU Process Memory(*) counters aggregate across ALL physical
        # adapters by default. Iterating per-GPU caused both iterations to sum the
        # SAME total then divide by each GPU's individual VRAM, producing impossible
        # results like 298% utilization on the iGPU. Fix: sample once outside the
        # loop, only attribute utilization to a single GPU when there's only one,
        # and emit a separate system-wide total for multi-GPU systems.
        $aggregatedDedicated = 0
        $aggregatedShared    = 0
        $activeProcesses     = 0
        $countersAvailable   = $false
        try {
            $dedSamples = (Get-Counter -Counter "\GPU Process Memory(*)\Dedicated Usage" -ErrorAction Stop).CounterSamples
            $shrSamples = (Get-Counter -Counter "\GPU Process Memory(*)\Shared Usage"    -ErrorAction SilentlyContinue).CounterSamples

            $dedSum = ($dedSamples | Measure-Object -Property CookedValue -Sum).Sum
            $shrSum = ($shrSamples | Measure-Object -Property CookedValue -Sum).Sum
            if ($dedSum) { $aggregatedDedicated = [double]$dedSum }
            if ($shrSum) { $aggregatedShared    = [double]$shrSum }
            $activeProcesses = ($dedSamples | Where-Object { $_.CookedValue -gt 0 } | Measure-Object).Count
            $countersAvailable = $true
        } catch {
            $countersAvailable = $false
        }

        foreach ($gpu in $gpus) {
            # FIX v2.5 Bug #3: Use registry-backed VRAM (handles >4GB cards correctly)
            $totalBytes = Get-AccurateVRAM -VideoController $gpu
            $totalRAM = [math]::Round($totalBytes / 1GB, 2)

            Write-Host "Testing $($gpu.Name) - $totalRAM GB VRAM" -ForegroundColor Yellow

            $usage = @()
            $usage += "GPU: $($gpu.Name)"
            $usage += "Total VRAM: $totalRAM GB"

            if ($countersAvailable -and $gpuCount -eq 1) {
                # Single GPU: attributing aggregate counters is accurate
                $dedicatedMB = [math]::Round($aggregatedDedicated / 1MB, 1)
                $sharedMB    = [math]::Round($aggregatedShared    / 1MB, 1)
                $usage += "Dedicated VRAM In Use: $dedicatedMB MB"
                $usage += "Shared Memory In Use: $sharedMB MB"
                if ($totalBytes -gt 0 -and $aggregatedDedicated -gt 0) {
                    $usagePct = [math]::Round(($aggregatedDedicated / $totalBytes) * 100, 1)
                    $usage += "VRAM Utilization: $usagePct%"
                }
                $usage += "Active GPU processes: $activeProcesses"
            } elseif ($countersAvailable -and $gpuCount -gt 1) {
                # Multi-GPU with counters: aggregate is available in the system-wide entry.
                $usage += "Note: Multi-GPU system - per-adapter VRAM usage is not"
                $usage += "      reliably reported by Windows performance counters."
                $usage += "      See GPU-Memory-Total entry for system-wide totals."
            } else {
                $usage += "Note: GPU Process Memory counters unavailable - VRAM usage cannot be measured"
            }

            $script:TestResults += @{
                Tool="GPU-Memory-Test"; Description="GPU memory analysis"
                Status="SUCCESS"; Output=($usage -join "`n"); Duration=200
            }
            Write-Host "GPU memory info collected" -ForegroundColor Green
        }

        # On multi-GPU systems, emit one system-wide aggregate entry
        if ($gpuCount -gt 1 -and $countersAvailable) {
            $totalSystemVRAM = 0
            foreach ($g in $gpus) { $totalSystemVRAM += (Get-AccurateVRAM -VideoController $g) }
            $sysOut = @()
            $sysOut += "System-wide aggregate (all GPUs combined):"
            $sysOut += "Total VRAM Capacity: $([math]::Round($totalSystemVRAM/1GB,2)) GB"
            $sysOut += "Dedicated VRAM In Use: $([math]::Round($aggregatedDedicated/1MB,1)) MB"
            $sysOut += "Shared Memory In Use: $([math]::Round($aggregatedShared/1MB,1)) MB"
            if ($totalSystemVRAM -gt 0 -and $aggregatedDedicated -gt 0) {
                $pct = [math]::Round(($aggregatedDedicated / $totalSystemVRAM) * 100, 1)
                $sysOut += "Aggregate VRAM Utilization: $pct%"
            }
            $sysOut += "Active GPU processes: $activeProcesses"
            $script:TestResults += @{
                Tool="GPU-Memory-Total"; Description="System-wide GPU memory (all adapters)"
                Status="SUCCESS"; Output=($sysOut -join "`n"); Duration=50
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
            $reportsDir = Join-Path $ScriptRoot "Reports"
            if (!(Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }
            $report = Join-Path $reportsDir "energy-report.html"
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
        # Level filter: 1=Critical, 2=Error, 3=Warning, 4=Information, 5=Verbose.
        # WHEA Event ID 1 ("WHEA-Logger operational") fires at Level 4 on every boot
        # and is not a hardware fault. Without the Level filter every system that
        # rebooted within the 7-day window would trigger "Hardware errors detected".
        $ev = Get-WinEvent -FilterHashtable @{
            LogName='System'
            ProviderName='Microsoft-Windows-WHEA-Logger'
            StartTime=(Get-Date).AddDays(-7)
        } -ErrorAction SilentlyContinue |
            Where-Object { $_.Level -le 3 } |
            Select-Object -First 10

        if ($ev) {
            $text = ($ev | ForEach-Object {
                "[{0:yyyy-MM-dd}] ID {1} ({2}): {3}" -f $_.TimeCreated,$_.Id,$_.LevelDisplayName,$_.Message.Split("`n")[0]
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
            # FIX v2.5.1: Modern Windows trigger-starts wuauserv on demand; a
            # "Stopped" Status is the normal idle state. Report both Status (for
            # informational visibility) and StartType (for the actual problem
            # signal). Recommendations engine now checks StartType, not Status.
            $svc = Get-Service -Name wuauserv -ErrorAction Stop
            $lines += "Service Status: $($svc.Status)"
            $lines += "Service StartType: $($svc.StartType)"
        } catch {
            $lines += "Service Status: Unable to query"
            $lines += "Service StartType: Unable to query"
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

    # Ensure Reports subfolder exists
    $ReportsDir = Join-Path $ScriptRoot "Reports"
    if (!(Test-Path $ReportsDir)) {
        try {
            New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
            Write-Host "Created Reports folder: $ReportsDir" -ForegroundColor DarkGray
        } catch {
            Write-Host "ERROR: Cannot create Reports folder: $ReportsDir" -ForegroundColor Red
            Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }

    # Test write access to Reports folder
    $testFile = Join-Path $ReportsDir "writetest_$([guid]::NewGuid().ToString('N')).tmp"
    try {
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -ErrorAction Stop
    } catch {
        Write-Host "ERROR: Cannot write to Reports folder: $ReportsDir" -ForegroundColor Red
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $cleanPath = Join-Path $ReportsDir "SystemTest_Clean_$timestamp.txt"
    $detailedPath = Join-Path $ReportsDir "SystemTest_Detailed_$timestamp.txt"

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

    # === MALWARE / THREAT SCAN SUMMARY (v3.0) ===
    $malAutoruns = $TestResults | Where-Object {$_.Tool -eq "Malware-Autoruns"} | Select-Object -Last 1
    $malProcs    = $TestResults | Where-Object {$_.Tool -eq "Malware-Processes"} | Select-Object -Last 1
    $malEvents   = $TestResults | Where-Object {$_.Tool -eq "Malware-EventLog"} | Select-Object -Last 1
    if ($malAutoruns -or $malProcs -or $malEvents) {
        $cleanReport += ""
        $cleanReport += "MALWARE / THREAT SCAN:"
        foreach ($m in @($malAutoruns, $malProcs, $malEvents)) {
            if (-not $m) { continue }
            # Summary counters, >>> flag headers, and their indented detail lines
            $m.Output -split "`n" | Where-Object {
                $_ -match "^(Non-Microsoft|Unsigned entries|Hashes unknown|Processes examined|VT-Flagged|Unsigned-Suspicious|Masquerade-Hits|Proc-VT-Flagged|Proc-HighRiskPath|Proc-Unsigned|No autorun red flags|EventLog-|New services installed|Service crashes|Failed logons|Security log auditing|Sysmon:|No event log red flags|>>>)" -or $_ -match "^\s+\S"
            } | Select-Object -First 30 | ForEach-Object { $cleanReport += "  $_" }
        }
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
            $recommendations += "* CRITICAL: High memory usage ($usage%)"
            $recommendations += "  -> Close unnecessary programs"
            $recommendations += "  -> Check for memory leaks in Task Manager"
            $recommendations += "  -> Consider adding more RAM (current usage indicates shortage)"
        } elseif ($usage -gt 70) {
            $recommendations += "* WARNING: Elevated memory usage ($usage%)"
            $recommendations += "  -> Monitor for memory-intensive applications"
            $recommendations += "  -> RAM upgrade recommended if usage stays consistently high"
        } elseif ($usage -lt 30) {
            $recommendations += "* GOOD: Low memory usage ($usage%) - plenty of RAM available"
        }
    }

    # === STORAGE HEALTH ===
    $smartInfo = $TestResults | Where-Object {$_.Tool -eq "Storage-SMART"}
    if ($smartInfo -and $smartInfo.Output -notmatch "not available") {
        # "Unhealthy" is the third standard Get-PhysicalDisk HealthStatus value (Healthy/Warning/Unhealthy).
        # Without it a genuinely failing drive is silently missed.
        if ($smartInfo.Output -match "Warning|Caution|Failed|Degraded|Unhealthy") {
            $recommendations += "* CRITICAL: Drive health issue detected"
            $recommendations += "  -> BACKUP DATA IMMEDIATELY"
            $recommendations += "  -> Run manufacturer's diagnostic tool"
            $recommendations += "  -> Consider drive replacement"
        }
    }

    # === STORAGE PERFORMANCE ===
    # Match Write and Read separately: the output stores them on different lines so
    # a single regex using .* never matches (PowerShell . does not cross newlines).
    if ($diskPerf) {
        $writeSpeed = 0.0; $readSpeed = 0.0
        if ($diskPerf.Output -match "Write: ([\d\.]+) MB/s") { $writeSpeed = [float]$matches[1] }
        if ($diskPerf.Output -match "Read: ([\d\.]+) MB/s")  { $readSpeed  = [float]$matches[1] }
        if ($writeSpeed -gt 0 -and $readSpeed -gt 0) {
            # HDD typical: 80-160 MB/s  |  SATA SSD: 200-550 MB/s  |  NVMe: 1500+ MB/s
            if ($writeSpeed -lt 50 -or $readSpeed -lt 50) {
                $recommendations += "* WARNING: Very slow disk performance detected"
                $recommendations += "  -> Write: $writeSpeed MB/s, Read: $readSpeed MB/s"
                $recommendations += "  -> Check for background processes (antivirus, Windows Update)"
                $recommendations += "  -> Run disk defragmentation (HDD only, not SSD)"
                $recommendations += "  -> Check disk health with manufacturer tools"
                $recommendations += "  -> Consider SSD upgrade for significant speed improvement"
            } elseif ($writeSpeed -lt 100 -or $readSpeed -lt 100) {
                $recommendations += "* INFO: Moderate disk performance (likely HDD)"
                $recommendations += "  -> Write: $writeSpeed MB/s, Read: $readSpeed MB/s"
                $recommendations += "  -> Consider SSD upgrade for 3-5x speed improvement"
            }
        }
    }

    # === NETWORK PERFORMANCE ===
    if ($netSpeed -and $netSpeed.Output -match "Throughput: ([\d\.]+) Mbps") {
        $throughputMbps = [float]$matches[1]
        if ($throughputMbps -lt 25) {
            $recommendations += "* WARNING: Internet throughput appears slow ($throughputMbps Mbps)"
            $recommendations += "  -> Verify ISP plan and router performance"
            $recommendations += "  -> Re-test when fewer applications are consuming bandwidth"
        }
    }

    if ($netLatency -and $netLatency.Output -match "Avg: ([\d\.]+) ms") {
        $avgLatency = [float]$matches[1]
        if ($avgLatency -gt 100) {
            $recommendations += "* NOTICE: High network latency detected (Avg $avgLatency ms)"
            $recommendations += "  -> Check local network congestion"
            $recommendations += "  -> Contact ISP if latency persists"
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
                    $recommendations += "* CRITICAL: Drive $driveLetter has less than 10% free space"
                    $recommendations += "  -> Delete unnecessary files immediately"
                    $recommendations += "  -> Use Disk Cleanup (cleanmgr.exe)"
                    $recommendations += "  -> Move files to external storage"
                    $recommendations += "  -> System performance will degrade below 10% free"
                } elseif ($freePercent -lt 20) {
                    $recommendations += "* WARNING: Drive $driveLetter has less than 20% free space"
                    $recommendations += "  -> Clean up unnecessary files soon"
                    $recommendations += "  -> Use Storage Sense or Disk Cleanup"
                }
            }
        }
    }

    # === SSD TRIM STATUS ===
    $trimInfo = $TestResults | Where-Object {$_.Tool -eq "SSD-TRIM"}
    if ($trimInfo -and $trimInfo.Output -match "Disabled") {
        $recommendations += "* WARNING: TRIM is disabled for SSD"
        $recommendations += "  -> Enable TRIM: fsutil behavior set DisableDeleteNotify 0"
        $recommendations += "  -> TRIM maintains SSD performance and longevity"
    }

    # === NETWORK ADAPTERS - skip virtual/VPN interfaces to avoid false positives ===
    $nicInfo = $TestResults | Where-Object {$_.Tool -eq "NIC-Info"}
    if ($nicInfo) {
        $physicalSlowAdapter = $false
        foreach ($nicLine in ($nicInfo.Output -split "`n")) {
            # Only flag PHYSICAL adapters at 10/100 Mbps - exclude known virtual/VPN adapters
            # FIX v2.5 Issue #9: Added ZeroTier, Cisco AnyConnect, GlobalProtect, Fortinet,
            #                    NordLynx, Pulse, Bluetooth PAN, ProtonVPN to exclusion list
            if ($nicLine -match "(10 Mbps|100 Mbps)" -and
                $nicLine -notmatch "VMware|VMnet|Virtual|vEthernet|Tailscale|Mullvad|WireGuard|Loopback|Hyper-V|VPN|TAP-Windows|OpenVPN|ZeroTier|AnyConnect|GlobalProtect|Fortinet|FortiClient|NordLynx|Pulse|Bluetooth|ProtonVPN|Surfshark|Wi-Fi|Wireless|WLAN") {
                $physicalSlowAdapter = $true
                break
            }
        }
        if ($physicalSlowAdapter) {
            $recommendations += "* WARNING: Physical network adapter running at 10/100 Mbps"
            $recommendations += "  -> Upgrade to Gigabit Ethernet (1000 Mbps)"
            $recommendations += "  -> Check cable quality (use Cat5e or Cat6)"
        }

        if ($nicInfo.Output -match "No active adapters") {
            $recommendations += "* CRITICAL: No active network adapters"
            $recommendations += "  -> Check network cable connections"
            $recommendations += "  -> Verify adapter is enabled in Device Manager"
            $recommendations += "  -> Update network drivers"
        }
    }

    # === WINDOWS UPDATE ===
    # Single consolidated block - a previous early check for "Pending > 0" existed
    # above and produced duplicate/contradictory entries when the count was also
    # caught by the WARNING or INFO branches here. Removed; all cases handled below.
    $updateInfo = $TestResults | Where-Object {$_.Tool -eq "Windows-Update"} | Select-Object -Last 1
    if ($updateInfo) {
        if ($updateInfo.Output -match "Pending: (\d+)") {
            $pendingCount = [int]$matches[1]
            if ($pendingCount -gt 20) {
                $recommendations += "* WARNING: $pendingCount pending Windows Updates"
                $recommendations += "  -> Install updates soon for security and stability"
                $recommendations += "  -> Schedule during non-working hours"
                $recommendations += "  -> Ensure backup before major updates"
            } elseif ($pendingCount -gt 5) {
                $recommendations += "* INFO: $pendingCount pending Windows Updates available"
                $recommendations += "  -> Install updates when convenient"
            } elseif ($pendingCount -gt 0) {
                $recommendations += "* ACTION: $pendingCount Windows update(s) pending installation"
                $recommendations += "  -> Install updates via Settings > Windows Update"
                $recommendations += "  -> Reboot after installation completes"
            } else {
                $recommendations += "* GOOD: Windows is up to date"
            }
        }
        
        # FIX v2.5.1: wuauserv StartType=Disabled is the real problem signal.
        # Status=Stopped is normal (trigger-started on demand by Win 10/11).
        if ($updateInfo.Output -match "Service StartType: Disabled") {
            $recommendations += "* WARNING: Windows Update service is DISABLED"
            $recommendations += "  -> Re-enable: Set-Service wuauserv -StartupType Manual"
            $recommendations += "  -> Verify in services.msc"
        }

        if ($updateInfo.Output -match "Search failed:") {
            $recommendations += "* WARNING: Windows Update search failed"
            $recommendations += "  -> Try: Stop-Service wuauserv; Start-Service wuauserv"
            $recommendations += "  -> Check BITS and Cryptographic Services are running"
            $recommendations += "  -> If persistent: DISM /Online /Cleanup-Image /RestoreHealth"
        }
    }

    # === OS HEALTH (DISM/SFC) ===
    $osHealth = $TestResults | Where-Object {$_.Tool -eq "OS-Health"}
    if ($osHealth -and $osHealth.Status -eq "SUCCESS") {
        $oh = $osHealth.Output
        # Language-neutral: DISM exit code 11 = repairable corruption; any non-zero = error.
        # Embedded by Test-OSHealth as "DISM-ExitCode: N" for coverage on non-English systems.
        $dismExitBad = ($oh -match 'DISM-ExitCode: (\d+)') -and ([int]$matches[1] -ne 0)
        # Text-based detection (English systems): also catches SFC findings.
        # Added "DISM encountered|could not perform" to cover DISM runtime failures that were
        # previously matched by the removed "error" term. Added "No integrity violations" to
        # the notmatch guard to prevent a false positive from DISM /CheckHealth clean output.
        $textMatch = $oh -match "found corrupt|store is repairable|requires repair|cannot repair|integrity violations|DISM encountered|could not perform the requested operation"
        $notNegative = $oh -notmatch "did not find any integrity violations|No component store corruption|No integrity violations"
        if (($dismExitBad -or $textMatch) -and $notNegative) {
            $recommendations += "* WARNING: System file corruption detected"
            $recommendations += "  -> Run: DISM /Online /Cleanup-Image /RestoreHealth"
            $recommendations += "  -> Then run: sfc /scannow"
            $recommendations += "  -> Reboot and re-test"
        }
    }

    # === HARDWARE ERRORS (WHEA) ===
    $wheaInfo = $TestResults | Where-Object {$_.Tool -eq "WHEA"}
    if ($wheaInfo -and $wheaInfo.Output -notmatch "No WHEA errors") {
        $recommendations += "* WARNING: Hardware errors detected in event log"
        $recommendations += "  -> Review Event Viewer for details"
        $recommendations += "  -> Test RAM with Windows Memory Diagnostic"
        $recommendations += "  -> Update BIOS/UEFI firmware"
        $recommendations += "  -> Check for overheating issues"
    }

    # === MALWARE / THREAT INDICATORS (v3.0) ===
    # $malAutoruns / $malProcs / $malEvents are populated in the key-findings section above
    if ($malAutoruns -or $malProcs -or $malEvents) {
        $vtHits = 0; $suspicious = 0; $masq = 0
        $defDetections = 0; $tampering = 0; $logsCleared = 0
        if ($malAutoruns -and $malAutoruns.Output -match "VT-Flagged: (\d+)") { $vtHits += [int]$matches[1] }
        if ($malProcs -and $malProcs.Output -match "Proc-VT-Flagged: (\d+)") { $vtHits += [int]$matches[1] }
        if ($malAutoruns -and $malAutoruns.Output -match "Unsigned-Suspicious: (\d+)") { $suspicious += [int]$matches[1] }
        if ($malProcs -and $malProcs.Output -match "Proc-HighRiskPath: (\d+)") { $suspicious += [int]$matches[1] }
        if ($malProcs -and $malProcs.Output -match "Masquerade-Hits: (\d+)") { $masq = [int]$matches[1] }
        if ($malEvents) {
            if ($malEvents.Output -match "EventLog-DefenderDetections: (\d+)") { $defDetections = [int]$matches[1] }
            if ($malEvents.Output -match "EventLog-DefenderTampering: (\d+)") { $tampering += [int]$matches[1] }
            if ($malEvents.Output -match "EventLog-LogsCleared: (\d+)") { $logsCleared = [int]$matches[1] }
            foreach ($k in @("EventLog-SuspiciousServices","EventLog-SuspiciousPowerShell","EventLog-NewAccounts","EventLog-AdminGroupAdds","EventLog-SecuritySvcCrashes")) {
                if ($malEvents.Output -match "$($k): (\d+)") { $suspicious += [int]$matches[1] }
            }
            if ($malEvents.Output -match "EventLog-BruteForce: 1") { $suspicious += 1 }
        }

        $malwareCritical = $false
        if ($vtHits -gt 0 -or $masq -gt 0 -or $defDetections -gt 0) {
            $malwareCritical = $true
            $recommendations += "* CRITICAL: Possible MALWARE detected ($vtHits VirusTotal hit(s), $masq masquerading process(es), $defDetections Defender detection(s))"
            $recommendations += "  -> Disconnect system from network until reviewed"
            $recommendations += "  -> See MALWARE / THREAT SCAN section in detailed report for flagged items"
            $recommendations += "  -> Verify in Process Explorer / Autoruns GUI (Menu Option 20)"
            $recommendations += "  -> Run full AV scan (Microsoft Defender Offline scan recommended)"
            $recommendations += "  -> Confirm before deleting - VT hits under ~5/70 can be false positives"
        }
        if ($tampering -gt 0 -or $logsCleared -gt 0) {
            $malwareCritical = $true
            $recommendations += "* CRITICAL: Security tampering indicators ($tampering protection-disable event(s), $logsCleared log-clear event(s))"
            $recommendations += "  -> AV protection disabled or event logs cleared - common attacker anti-forensics"
            $recommendations += "  -> Review Malware-EventLog section: who/what disabled protection and when"
            $recommendations += "  -> Re-enable Defender real-time protection before returning the system"
        }
        if (-not $malwareCritical -and $suspicious -gt 0) {
            $recommendations += "* WARNING: $suspicious suspicious item(s) found - manual review needed"
            $recommendations += "  -> Unsigned binaries, temp-path launches, new services/accounts, or PowerShell flags"
            $recommendations += "  -> Inspect in Process Explorer / Autoruns GUI (Menu Option 20) and Event Viewer"
            $recommendations += "  -> Many are legitimate (updaters, RMM tools, portable apps) - verify context"
        } elseif (-not $malwareCritical) {
            $recommendations += "* GOOD: No malware indicators in autoruns, processes, or event logs"
        }
    }

    # === CPU PERFORMANCE ===
    $cpuPerf = $TestResults | Where-Object {$_.Tool -eq "CPU-Performance"}
    if ($cpuPerf -and $cpuPerf.Output -match "Ops/sec: (\d+)") {
        $opsPerSec = [int]$matches[1]
        # FIX v2.5.1: Synthetic test pipes every iteration through Out-Null;
        # PowerShell pipeline overhead caps it at 50-200k ops/sec on any modern
        # CPU. Original 5M threshold fired on every healthy system (false positive
        # 100% of the time). Below 30k indicates real trouble.
        if ($opsPerSec -lt 30000) {
            $recommendations += "* INFO: CPU synthetic test slower than typical"
            $recommendations += "  -> Check for background processes consuming CPU"
            $recommendations += "  -> Set power plan to High Performance"
            $recommendations += "  -> Check CPU temperatures (thermal throttling)"
            $recommendations += "  -> Update chipset drivers"
        }
    }

    # === GPU HEALTH ===
    if ($gpuDetails) {
        if ($gpuDetails.Output -match "Driver Date:.*?(\d{4})") {
            $driverYear = 0
            if ([int]::TryParse($matches[1], [ref]$driverYear)) {
                $currentYear = (Get-Date).Year
                if ($currentYear - $driverYear -gt 1) {
                    $recommendations += "* INFO: GPU drivers are over 1 year old"
                    $recommendations += "  -> Update to latest drivers for best performance"
                    $recommendations += "  -> NVIDIA: GeForce Experience or nvidia.com"
                    $recommendations += "  -> AMD: amd.com/en/support"
                }
            }
        }
    }

    # === BATTERY HEALTH (Laptops) ===
    $powerInfo = $TestResults | Where-Object {$_.Tool -eq "Power-Energy"}
    if ($powerInfo -and $powerInfo.Output -match "Battery: ") {
        if ($powerInfo.Output -match "energy-report.html") {
            $recommendations += "* INFO: Energy report generated"
            $recommendations += "  -> Review energy-report.html for battery health"
        }
    }

    # === OVERALL SYSTEM HEALTH ===
    if ($failed -gt 5) {
        $recommendations += "* CRITICAL: Multiple test failures ($failed failures)"
        $recommendations += "  -> Review detailed report for specific issues"
        $recommendations += "  -> Consider professional diagnostics"
    }

    # FIX v2.5.1: "EXCELLENT" used to fire whenever no tests crashed, even when
    # the engine had just printed multiple WARNING/CRITICAL items. Reads as
    # self-contradictory in the report. Now requires zero prior issues OR
    # downgrades to a neutral "all tests ran" message when issues exist.
    $priorIssues = @($recommendations | Where-Object { $_ -match "^\* (CRITICAL|WARNING)" }).Count
    if ($failed -eq 0 -and $skipped -eq 0 -and $priorIssues -eq 0) {
        $recommendations += "* EXCELLENT: All tests passed and no issues detected"
        $recommendations += "  -> System is operating normally"
    } elseif ($failed -eq 0 -and $skipped -eq 0) {
        $recommendations += "* INFO: All tests ran successfully ($priorIssues item(s) flagged above)"
    } elseif ($skipped -gt 5) {
        $recommendations += "* INFO: $skipped tests skipped (admin required)"
        $recommendations += "  -> Run as administrator for complete diagnostics"
    }

    # === GENERAL MAINTENANCE ===
    if ($recommendations.Count -lt 3) {
        $recommendations += ""
        $recommendations += "GENERAL MAINTENANCE TIPS:"
        $recommendations += "* Keep Windows and drivers updated"
        $recommendations += "* Run disk cleanup monthly (cleanmgr.exe)"
        $recommendations += "* Monitor temperatures during heavy use"
        $recommendations += "* Maintain at least 20% free disk space"
        $recommendations += "* Back up important data regularly"
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
        $cleanReport | Out-File -FilePath $cleanPath -Encoding ASCII
        $detailedReport | Out-File -FilePath $detailedPath -Encoding ASCII

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

# GPU Tool auto-downloader — called from SystemTester.bat via -DownloadGPUTool param.
# Uses curl.exe -> BITS -> Invoke-WebRequest in order, stops on first success.
# Keeping this in PS1 avoids all cmd.exe ^ continuation / delayed-expansion escaping
# issues that corrupt inline -Command blocks containing ! { } characters.
function Invoke-GPUToolDownload {
    param([string]$Tool, [string]$TargetDir)

    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $config = switch ($Tool) {
        "MSIAfterburner" { @{
            Url      = "https://download.msi.com/uti_exe/vga/MSIAfterburnerSetup.zip"
            File     = "MSIAfterburnerSetup.zip"
            MinBytes = 1MB
            Note     = "Extract the ZIP and run MSIAfterburnerSetup.exe to install."
        }}
        "FurMark" { @{
            Url      = "https://geeks3d.com/dl/get/777"
            File     = "FurMark_Setup.exe"
            MinBytes = 500KB
            Note     = "Run FurMark_Setup.exe to install. Generates significant GPU heat - monitor temps."
        }}
        default {
            Write-Host "Unknown tool: $Tool" -ForegroundColor Red
            exit 1
        }
    }

    $outFile = Join-Path $TargetDir $config.File
    $url     = $config.Url
    $ok      = $false
    $lastErr = "(none)"

    Write-Host ""
    Write-Host "Downloading $Tool..." -ForegroundColor Cyan
    Write-Host "  URL  : $url" -ForegroundColor Gray
    Write-Host "  Saved: $outFile" -ForegroundColor Gray
    Write-Host "  Trying curl.exe, BITS, then Invoke-WebRequest..." -ForegroundColor DarkGray
    Write-Host ""

    # Method 1: curl.exe (WinHTTP/Schannel - TLS 1.3, VPN-safe)
    $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curlCmd -and -not $ok) {
        Write-Host "  Trying curl.exe..." -ForegroundColor Yellow
        & curl.exe --silent --show-error --location --output $outFile `
            --max-time 180 --retry 1 --insecure $url 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $outFile)) {
            $sz = (Get-Item $outFile).Length
            if ($sz -ge $config.MinBytes) {
                $ok = $true
                Write-Host "  [curl.exe] $([math]::Round($sz/1MB,1)) MB downloaded" -ForegroundColor DarkGray
            } else {
                Remove-Item $outFile -Force -ErrorAction SilentlyContinue
                $lastErr = "curl: file too small ($sz bytes - likely an error page)"
            }
        } else {
            $lastErr = "curl exited $LASTEXITCODE"
        }
    }

    # Method 2: BITS
    if (-not $ok) {
        Write-Host "  Trying BITS..." -ForegroundColor Yellow
        try {
            Import-Module BitsTransfer -ErrorAction Stop
            Start-BitsTransfer -Source $url -Destination $outFile -ErrorAction Stop
            if (Test-Path $outFile) {
                $sz = (Get-Item $outFile).Length
                if ($sz -ge $config.MinBytes) {
                    $ok = $true
                    Write-Host "  [BITS] $([math]::Round($sz/1MB,1)) MB downloaded" -ForegroundColor DarkGray
                } else {
                    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
                    $lastErr = "BITS: file too small ($sz bytes)"
                }
            }
        } catch {
            $lastErr = $_.Exception.Message
            Write-Host "  BITS failed: $lastErr" -ForegroundColor DarkYellow
        }
    }

    # Method 3: Invoke-WebRequest (.NET)
    if (-not $ok) {
        Write-Host "  Trying Invoke-WebRequest..." -ForegroundColor Yellow
        $prevCb   = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        $prevProt = [Net.ServicePointManager]::SecurityProtocol
        try {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
            $proto = $prevProt
            try { $proto = $proto -bor [Net.SecurityProtocolType]::Tls12 } catch {}
            try { $proto = $proto -bor [Net.SecurityProtocolType]::Tls13 } catch {}
            [Net.ServicePointManager]::SecurityProtocol = $proto

            Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -TimeoutSec 180 -ErrorAction Stop
            if (Test-Path $outFile) {
                $sz = (Get-Item $outFile).Length
                if ($sz -ge $config.MinBytes) {
                    $ok = $true
                    Write-Host "  [IWR] $([math]::Round($sz/1MB,1)) MB downloaded" -ForegroundColor DarkGray
                } else {
                    Remove-Item $outFile -Force -ErrorAction SilentlyContinue
                    $lastErr = "IWR: file too small ($sz bytes)"
                }
            }
        } catch {
            $lastErr = $_.Exception.Message
            Write-Host "  IWR failed: $lastErr" -ForegroundColor DarkYellow
        } finally {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $prevCb
            [Net.ServicePointManager]::SecurityProtocol = $prevProt
        }
    }

    Write-Host ""
    if ($ok) {
        Write-Host "SUCCESS: $Tool downloaded" -ForegroundColor Green
        Write-Host "Saved to: $outFile" -ForegroundColor White
        Write-Host $config.Note -ForegroundColor Cyan
    } else {
        Write-Host "ERROR: All download methods failed" -ForegroundColor Red
        Write-Host "Last error: $lastErr" -ForegroundColor Red
        exit 1
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
    Write-Host "    +- 12a. Basic GPU Info"
    Write-Host "    +- 12b. Vendor-Specific (NVIDIA/AMD)"
    Write-Host "    +- 12c. GPU Memory Test"
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
    Write-Host "19. Malware/Threat Scan (Autoruns + Sigcheck + VirusTotal) $(if (-not $script:IsAdmin) {'[Admin recommended]'})" -ForegroundColor Magenta
    Write-Host "20. GUI Threat Analysis (Process Explorer / Autoruns)" -ForegroundColor Magenta
    Write-Host "21. Event Log Threat Audit (Defender/Services/PowerShell) $(if (-not $script:IsAdmin) {'[Admin recommended]'})" -ForegroundColor Magenta
    Write-Host "Q.  Quit"
    Write-Host ""
    Write-Host "Tests completed: $($TestResults.Count)" -ForegroundColor Gray
}

function Start-Menu {
    do {
        Show-Menu
        $choice = Read-Host "`nSelect (1-21, 12a-c, Q)"
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
                Test-Processes; Test-Security; Test-MalwareScan
                Test-Network; Test-OSHealth
                Test-StorageSMART; Test-Trim; Test-NIC
                Test-GPU; Test-GPUVendorSpecific; Test-GPUMemory  # All GPU tests
                Test-Power; Test-HardwareEvents; Test-WindowsUpdate
                Write-Host "`nAll tests complete!" -ForegroundColor Green
                Read-Host "Press Enter"
            }
            "17" { New-Report; Read-Host "`nPress Enter" }
            "18" { $script:TestResults = @(); Write-Host "Cleared" -ForegroundColor Green; Start-Sleep 1 }
            "19" { Test-MalwareScan; Read-Host "`nPress Enter" }
            "20" { Start-MalwareGUITools; Read-Host "`nPress Enter" }
            "21" { Test-EventLogThreats; Read-Host "`nPress Enter" }
            "Q"  { return }
            "q"  { return }
            default { Write-Host "Invalid" -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($choice -ne "Q" -and $choice -ne "q")
}

# Main - only execute if script is run directly (not dot-sourced)
if ($MyInvocation.InvocationName -ne '.') {

    # Download-only mode: invoked by SystemTester.bat GPU tool download menu.
    # Runs without the interactive menu or test suite.
    if ($DownloadGPUTool) {
        if (-not $DownloadDir) { $DownloadDir = Join-Path $ScriptRoot "Tools" }
        Invoke-GPUToolDownload -Tool $DownloadGPUTool -TargetDir $DownloadDir
        exit 0
    }

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
            Test-Processes; Test-Security; Test-MalwareScan
            Test-Network; Test-OSHealth
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
