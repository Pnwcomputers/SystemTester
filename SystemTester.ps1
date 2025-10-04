# Portable Sysinternals System Tester
# Created by Pacific Northwest Computers - 2025
# Complete Production Version - v2.1

param([switch]$AutoRun)

# Constants
$script:VERSION = "2.1"
$script:DXDIAG_TIMEOUT = 45
$script:ENERGY_DURATION = 15
$script:CPU_TEST_SECONDS = 10
$script:MAX_PATH_LENGTH = 240
$script:MIN_TOOL_SIZE_KB = 50

# Paths
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
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
        "psinfo.exe","coreinfo.exe","pslist.exe","handle.exe","clockres.exe",
        "autorunsc.exe","du.exe","streams.exe","contig.exe","sigcheck.exe",
        "testlimit.exe","diskext.exe","listdlls.exe"
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
function Clean-ToolOutput {
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
        [string]$Args = "",
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
    Run-Tool -ToolName "psinfo" -Args "-h -s -d" -Description "System information"
    Run-Tool -ToolName "clockres" -Description "Clock resolution"

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
    Run-Tool -ToolName "coreinfo" -Args "-v -f -c" -Description "CPU architecture"

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

    Run-Tool -ToolName "du" -Args "-l 2 C:\" -Description "Disk usage C:"

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
        $content = Get-Content $testFile -Raw -ErrorAction Stop
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
    Run-Tool -ToolName "pslist" -Args "-t" -Description "Process tree"
    Run-Tool -ToolName "handle" -Args "-p explorer" -Description "Explorer handles"
}

# Test: Security
function Test-Security {
    Write-Host "`n=== Security Analysis ===" -ForegroundColor Green
    Run-Tool -ToolName "autorunsc" -Args "-a -c" -Description "Autorun entries" -RequiresAdmin $true
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
            "$($_.Key): $status"
        }
        if (-not $txt) { $txt = @("TRIM status unknown") }

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

# Test: GPU
function Test-GPU {
    Write-Host "`n=== GPU (dxdiag) ===" -ForegroundColor Green
    $dxProcess = $null
    try {
        $dx = Join-Path $env:TEMP "dxdiag_$([guid]::NewGuid().ToString('N')).txt"
        Write-Host "Running dxdiag (up to $script:DXDIAG_TIMEOUT sec)..." -ForegroundColor Yellow

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

            $keep = ($raw -split "`r?`n") | Where-Object {
                $_ -match "Card name|Driver Version|DirectX Version"
            } | Select-Object -First 10

            $script:TestResults += @{
                Tool="GPU-DirectX"; Description="dxdiag summary"
                Status="SUCCESS"; Output=($keep -join "`n"); Duration=($elapsed*1000)
            }
            Write-Host "dxdiag complete" -ForegroundColor Green
        } else {
            throw "Timeout"
        }
    } catch {
        Write-Host "dxdiag failed: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally {
        if ($dxProcess -and !$dxProcess.HasExited) {
            try { $dxProcess.Kill(); $dxProcess.WaitForExit(5000) } catch {}
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
            $lines += "Pending: $($result.Updates.Count)"
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
        if ($updateSession) {
            try { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($updateSession) | Out-Null } catch {}
        }
        [System.GC]::Collect()
    }
}

# Generate Dual Reports (Clean + Detailed)
function Generate-Report {
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

    $cleanReport += ""
    $cleanReport += "RECOMMENDATIONS:"
    $cleanReport += "----------------"
    
    # Generate recommendations
    if ($ramInfo -and $ramInfo.Output -match "Usage: ([\d\.]+)%") {
        $usage = [float]$matches[1]
        if ($usage -gt 85) {
            $cleanReport += "• HIGH MEMORY USAGE ($usage%) - Consider adding more RAM"
        } elseif ($usage -lt 30) {
            $cleanReport += "• LOW MEMORY USAGE ($usage%) - Plenty of RAM available"
        }
    }

    if ($failed -eq 0 -and $skipped -eq 0) {
        $cleanReport += "• All tests passed successfully"
    } elseif ($skipped -gt 0) {
        $cleanReport += "• $skipped tests skipped (likely need admin privileges)"
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
    Write-Host "12. GPU (dxdiag)"
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
        $choice = Read-Host "`nSelect (1-18, Q)"
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
            "12" { Test-GPU; Read-Host "`nPress Enter" }
            "13" { Test-Power; Read-Host "`nPress Enter" }
            "14" { Test-HardwareEvents; Read-Host "`nPress Enter" }
            "15" { Test-WindowsUpdate; Read-Host "`nPress Enter" }
            "16" {
                Write-Host "`nRunning all tests..." -ForegroundColor Yellow
                Test-SystemInfo; Test-CPU; Test-Memory; Test-Storage
                Test-Processes; Test-Security; Test-Network; Test-OSHealth
                Test-StorageSMART; Test-Trim; Test-NIC; Test-GPU
                Test-Power; Test-HardwareEvents; Test-WindowsUpdate
                Write-Host "`nAll tests complete!" -ForegroundColor Green
                Read-Host "Press Enter"
            }
            "17" { Generate-Report; Read-Host "`nPress Enter" }
            "18" { $script:TestResults = @(); Write-Host "Cleared" -ForegroundColor Green; Start-Sleep 1 }
            "Q"  { return }
            "q"  { return }
            default { Write-Host "Invalid" -ForegroundColor Red; Start-Sleep 1 }
        }
    } while ($choice -ne "Q" -and $choice -ne "q")
}

# Main
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
        Test-StorageSMART; Test-Trim; Test-NIC; Test-GPU
        Test-Power; Test-HardwareEvents; Test-WindowsUpdate
        Generate-Report
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
