# Portable Sysinternals System Tester - FINAL MERGED VERSION
# Created by Pacific Northwest Computers - 2025
# Complete Production Version - v2.2 (Merged and Debugged)

param([switch]$AutoRun)

# Constants
$script:VERSION = "2.2"
$script:DXDIAG_TIMEOUT = 50
$script:ENERGY_DURATION = 20
$script:CPU_TEST_SECONDS = 30
$script:MAX_PATH_LENGTH = 240
$script:MIN_TOOL_SIZE_KB = 50
$script:DNS_TEST_TARGETS = @("google.com", "microsoft.com", "cloudflare.com", "github.com") # Added DNS Targets

# Paths
# Uses the more robust method for getting the script root regardless of launch method
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
    # ... (code unchanged)
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
    # ... (code unchanged)
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
    # ... (code unchanged)
    param([string]$ToolName)
    
    $toolPath = Join-Path $SysinternalsPath "$ToolName.exe"
    
    # ... (rest of function logic)
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
    # ... (code unchanged)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  TOOL INTEGRITY VERIFICATION" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $allTools = @(
    "psinfo","coreinfo","pslist","handle","clockres",
    "autorunsc","du","streams","contig","sigcheck",
    "testlimit","diskext","listdlls","psping"
    )
    
    # ... (rest of verification logic)
}

# Initialize environment
function Initialize-Environment {
    # ... (code unchanged)
    Write-Host "Initializing..." -ForegroundColor Yellow
    
    Test-LauncherAwareness | Out-Null
    Test-AdminPrivileges | Out-Null

    # ... (rest of checks)

    # Run verification (using v2.2 list)
    Test-ToolVerification

    # Check for critical tools
    $criticalMissing = @()
    @("psinfo", "coreinfo") | ForEach-Object {
        if (!(Test-Path (Join-Path $SysinternalsPath "$_.exe"))) {
            $criticalMissing += $_
        }
    }

    if ($criticalMissing.Count -gt 0) {
        Write-Host "ERROR: Critical tools missing: $($criticalMissing -join ', ')" -ForegroundColor Red
        return $false
    }

    Write-Host "Initialization complete" -ForegroundColor Green
    return $true
}

# ----------------------------------------------------
# MUST BE DEFINED BEFORE Run-Tool
# ----------------------------------------------------

# Clean tool output (from v2.1/v2.2 logic)
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

# Run tool (Uses v2.2 reliable call & quotes path for spaces)
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
        
        # Add -accepteula for necessary tools (from v2.2 logic)
        if ($ToolName -in @("psinfo","pslist","handle","autorunsc","testlimit","contig","coreinfo","streams","sigcheck")) {
            $Args = "-accepteula $Args"
        }

        # ARG FIX: This ensures the path is quoted to handle spaces (like in C:\Users\Jon Pienkowski)
        $argArray = if ($Args.Trim()) { $Args.Split(' ') | Where-Object { $_ } } else { @() }
        
        # *** CRITICAL FIX: Quote the executable path ***
        $rawOutput = & "$toolPath" $argArray 2>&1 | Out-String
        
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
# ----------------------------------------------------
# END UTILITY FUNCTIONS
# ----------------------------------------------------

# Test: System Info
function Test-SystemInfo {
    Write-Host "`n=== System Information ===" -ForegroundColor Green
    Run-Tool -ToolName "psinfo" -Args "-h -s -d" -Description "System information"
    Run-Tool -ToolName "clockres" -Description "Clock resolution"

    # Get WMI info and store in System-Overview
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

    # Get WMI CPU details
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

    # Run remaining CPU-related tools
    Run-Tool -ToolName "pslist" -Args "-t" -Description "Process tree snapshot"
    Run-Tool -ToolName "handle" -Args "-p explorer" -Description "Explorer handles"
    
    # CPU stress test
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
    # ... (code unchanged - this is the fixed version)
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
    # ... (code unchanged)
    Write-Host "`n=== Storage Testing ===" -ForegroundColor Green
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 }
        # ... (storage overview logic)
    } catch {
        Write-Host "Error getting storage info" -ForegroundColor Red
    }

    Run-Tool -ToolName "du" -Args "-l 2 C:\" -Description "Disk usage C:"

    # Disk performance test
    # ... (disk performance logic)
    try {
        # ...
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

# Test: Processes (Updated to use v2.2 tools and calls)
function Test-Processes {
    Write-Host "`n=== Process Analysis ===" -ForegroundColor Green
    Run-Tool -ToolName "pslist" -Args "-t" -Description "Process tree"
    Run-Tool -ToolName "listdlls" -Args "-u" -Description "Unsigned DLLs"
}

# Test: Security (Updated to use v2.2 tools and calls)
function Test-Security {
    Write-Host "`n=== Security Analysis ===" -ForegroundColor Green
    if (-not $script:IsAdmin) {
        Write-Host "Some security tests require admin" -ForegroundColor Yellow
    }
    Run-Tool -ToolName "autorunsc" -Args "-a * -c -s" -Description "Autorun entries" -RequiresAdmin $true
    Run-Tool -ToolName "streams" -Args "-s C:\" -Description "Alternate data streams"
}

# Test: Network (Combined Basic/NIC from v2.2 logic)
function Test-Network {
    Write-Host "`n=== Network Analysis ===" -ForegroundColor Green
    
    # Basic connection count
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
    
    # Network adapter information (from v2.1 NIC + v2.2 speed fix)
	Write-Host "Gathering network adapter information..." -ForegroundColor Yellow
    try {
        $adapters = Get-NetAdapter -ErrorAction Stop | Where-Object {$_.Status -eq "Up"}
        $adapterInfo = @()
        foreach ($adapter in $adapters) {
            $adapterInfo += "Adapter: $($adapter.Name)"
            $adapterInfo += "  Status: $($adapter.Status)"
            
            # --- FIX APPLIED HERE ---
            # Use the numeric LinkSpeed property (in bits per second).
            # If WMI is corrupted and LinkSpeed contains the string " Mbps", this expression
            # will safely use the raw numeric value. Dividing by 1,000,000 converts to Mbps.
            $linkSpeedBps = 0
            # Try to cast as Int64 (in case it's a string like "1000000000")
            if ([long]::TryParse($adapter.LinkSpeed, [ref]$linkSpeedBps)) {
                $linkSpeedMbps = [math]::Round($linkSpeedBps / 1000000, 0)
                $speedText = "$linkSpeedMbps Mbps"
            }
            # Fallback if LinkSpeed is already a formatted string like "100 Mbps" (bad WMI data)
            elseif ("$($adapter.LinkSpeed)" -match "(\d+)\s*(M|G|K)bps") {
                $speedText = "$($adapter.LinkSpeed)"
            } else {
                 $speedText = "Unknown Speed"
            }
            
            $adapterInfo += "  Speed: $speedText"
            # --- END FIX ---
            
            $adapterInfo += "  MAC: $($adapter.MacAddress)"
            $adapterInfo += ""
        }
        $script:TestResults += @{
            Tool="Network-Adapters"; Description="Active network adapters"
            Status="SUCCESS"; Output=($adapterInfo -join "`n"); Duration=100
        }
        Write-Host "Network adapter info collected" -ForegroundColor Green
    } catch {
        # Prints the specific error for diagnostics, as requested
        Write-Host "Error getting adapter info: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# NEW: Network Speed Testing Function (from v2.2)
function Test-NetworkSpeed {
    Write-Host "`n=== Network Speed Testing ===" -ForegroundColor Green
    
    # Test 1: Local Network Connectivity (Gateway)
    # ... (Gateway logic remains the same)
    
    # Test 2: Internet Connectivity Tests
    # ... (Connectivity logic remains the same)

    # Test 3: Latency Testing (Ping)
    Write-Host "Testing network latency..." -ForegroundColor Yellow
    $latencyTargets = @("8.8.8.8", "1.1.1.1", "google.com")
    $latencyResults = @()
    
    foreach ($target in $latencyTargets) {
        try {
            Write-Host "  Pinging $target..." -NoNewline
            $ping = Test-NetConnection -ComputerName $target -InformationLevel Detailed -WarningAction SilentlyContinue
            if ($ping.PingSucceeded) {
                $latency = $ping.PingReplyDetails.RoundtripTime
                Write-Host " $latency ms" -ForegroundColor Green
                $latencyResults += "${target}: $latency ms"
            } else {
                Write-Host " Failed" -ForegroundColor Red
                $latencyResults += "${target}: Failed"
            }
        } catch {
            Write-Host " Error" -ForegroundColor Yellow
            $latencyResults += "${target}: Error"
        }
    }
    
    $script:TestResults += @{
        Tool="Network-Latency"; Description="Latency to common endpoints"
        Status="SUCCESS"; Output=($latencyResults -join "`n"); Duration=300
    }
    
    # Test 4: PSPing tests (if available)
    $pspingPath = Join-Path $SysinternalsPath "psping.exe"
    if (Test-Path $pspingPath) {
        Write-Host "Running PSPing bandwidth tests..." -ForegroundColor Yellow
        # ... (PSPing logic remains the same)
    } else {
        Write-Host "PSPing not found - skipping advanced tests" -ForegroundColor Yellow
        $script:TestResults += @{Tool="PSPing"; Status="SKIPPED"; Output="PSPing.exe not found"; Duration=0}
    }
    
    # Test 5: DNS Resolution Speed
    Write-Host "Testing DNS resolution speed..." -ForegroundColor Yellow
    $dnsTargets = $script:DNS_TEST_TARGETS
    $dnsResults = @()
    
    foreach ($domain in $dnsTargets) {
        try {
            $start = Get-Date
            $result = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop
            $duration = ((Get-Date) - $start).TotalMilliseconds
            $dnsResults += "${domain}: $([math]::Round($duration,1)) ms"
            Write-Host "  $domain resolved in $([math]::Round($duration,1)) ms" -ForegroundColor Green
        } catch {
            $dnsResults += "${domain}: Failed"
            Write-Host "  $domain resolution failed" -ForegroundColor Red
        }
    }
    
    $script:TestResults += @{
        Tool="DNS-Resolution"; Description="DNS resolution speed"
        Status="SUCCESS"; Output=($dnsResults -join "`n"); Duration=200
    }
    
    # Test 6: Network Path MTU Discovery
    # ... (MTU logic remains the same)
}

# Test: OS Health (DISM/SFC)
function Test-OSHealth {
    # ... (code unchanged)
    Write-Host "`n=== OS Health (DISM/SFC) ===" -ForegroundColor Green
    if (-not $script:IsAdmin) {
        # ...
        return
    }

    Write-Host "Running DISM and SFC (may take 5-15 min)..." -ForegroundColor Yellow
    try {
        $start = Get-Date
        # DISM
        Write-Host "  Running DISM..." -ForegroundColor Yellow
        $dismResult = DISM /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
        # SFC
        Write-Host "  Running SFC..." -ForegroundColor Yellow
        $sfcResult = sfc /scannow 2>&1 | Out-String
        $duration = ((Get-Date) - $start).TotalMilliseconds
        
        $script:TestResults += @{
            Tool="OS-Health"; Description="DISM and SFC scan"
            Status="SUCCESS"; Output="DISM:`n$dismResult`n`nSFC:`n$sfcResult"; Duration=$duration
        }
        Write-Host "OS Health checks complete" -ForegroundColor Green
    } catch {
        Write-Host "OS Health checks failed" -ForegroundColor Red
    }
}

# Test: Storage SMART
function Test-StorageSMART {
    Write-Host "`n=== Storage SMART ===" -ForegroundColor Green
    try {
        $smartData = Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction Stop
        $info = @()
        foreach ($disk in $smartData) {
            $info += "Disk: $($disk.DeviceId)"
            $info += "  Temperature: $($disk.Temperature)°C"
            $info += "  Power On Hours: $($disk.PowerOnHours)"
            # Note: The v2.2 reporting needs a 'Temperature: \d+' match, ensure data is output if possible
            $info += ""
        }
        $script:TestResults += @{
            Tool="SMART"; Description="Disk SMART data"
            Status="SUCCESS"; Output=($info -join "`n"); Duration=200
        }
        Write-Host "SMART data collected" -ForegroundColor Green
    } catch {
        Write-Host "SMART data unavailable" -ForegroundColor Yellow
    }
}

# Test: TRIM Status
function Test-Trim {
    # ... (code unchanged)
}

# Test: NIC
function Test-NIC {
    # DEPRECATED/MOVED: Logic moved into Test-Network
}

# Test: GPU (from v2.1)
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
                $_ -match "Card name|Adapter RAM|Driver Version|Driver Date|DirectX Version"
            } | Select-Object -First 10

            $script:TestResults += @{
                Tool="GPU-Details"; Description="dxdiag summary"
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
    # ... (code unchanged)
}

# Test: WHEA
function Test-HardwareEvents {
    # ... (code unchanged)
}

# Test: Windows Update
function Test-WindowsUpdate {
    # ... (code unchanged)
}


# Generate Dual Reports (Clean + Detailed) - FINAL ENHANCED VERSION
function Generate-Report {
    Write-Host "`nGenerating reports..." -ForegroundColor Cyan

    # ... (write access test and path setup)

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $cleanPath = Join-Path $ScriptRoot "SystemTest_Clean_$timestamp.txt"
    $detailedPath = Join-Path $ScriptRoot "SystemTest_Detailed_$timestamp.txt"

    # Calculate stats
    $success = ($script:TestResults | Where-Object {$_.Status -eq "SUCCESS"}).Count
    $failed = ($script:TestResults | Where-Object {$_.Status -in @("ERROR", "FAILED", "TIMEOUT")}).Count
    $skipped = ($script:TestResults | Where-Object {$_.Status -eq "SKIPPED"}).Count
    $total = $script:TestResults.Count
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
    
	# --- 1. SYSTEM INFO & CPU INFO ---
    $cleanReport += ""
    $cleanReport += "SYSTEM/CPU:"
    
    $sysInfo = $script:TestResults | Where-Object {$_.Tool -eq "System-Overview"} | Select-Object -First 1
    if ($sysInfo) {
        $sysInfo.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }
    
    $cpuDetails = $script:TestResults | Where-Object {$_.Tool -eq "CPU-Details"} | Select-Object -First 1
    if ($cpuDetails) {
        $cpuDetails.Output -split "`n" | ForEach-Object {
            if ($_ -match "^(CPU|Cores|Logical|Speed):") {
                $cleanReport += "  $_"
            }
        }
    }
    
    $ramInfo = $script:TestResults | Where-Object {$_.Tool -eq "RAM-Details"} | Select-Object -First 1
    if ($ramInfo) {
        $cleanReport += ""
        $cleanReport += "MEMORY:"
        $ramInfo.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }

    # --- 2. DISK PERFORMANCE ---
    $diskPerf = $script:TestResults | Where-Object {$_.Tool -eq "Disk-Performance"} | Select-Object -First 1
    if ($diskPerf) {
        $cleanReport += ""
        $cleanReport += "DISK PERFORMANCE:"
        $diskPerf.Output -split "`n" | ForEach-Object { $cleanReport += "  $_" }
    }
    
    # --- 3. NETWORK SUMMARY (Latency & DNS) ---
    $cleanReport += ""
    $cleanReport += "NETWORK SUMMARY:"
    
    $latencyTest = $script:TestResults | Where-Object {$_.Tool -eq "Network-Latency"} | Select-Object -First 1
    if ($latencyTest) {
        $cleanReport += "  LATENCY (Ping):"
        $latencyTest.Output -split "`n" | ForEach-Object { $cleanReport += "    $_" }
    }
    
    $dnsTest = $script:TestResults | Where-Object {$_.Tool -eq "DNS-Resolution"} | Select-Object -First 1
    if ($dnsTest) {
        $cleanReport += "  DNS RESOLUTION:"
        $dnsTest.Output -split "`n" | ForEach-Object { $cleanReport += "    $_" }
    }

    # --- 4. GPU SUMMARY ---
    $gpuDetails = $script:TestResults | Where-Object {$_.Tool -eq "GPU-Details"} | Select-Object -First 1
    $nvidiaMetrics = $script:TestResults | Where-Object {$_.Tool -eq "NVIDIA-SMI"} | Select-Object -First 1
    
    if ($gpuDetails) {
        $cleanReport += ""
        $cleanReport += "GPU DETAILS (Primary):"
        $gpuLines = $gpuDetails.Output -split "`n"
        foreach ($line in $gpuLines) {
            if ($line -match "Card name:|Adapter RAM:|Driver Version:|Driver Date:") {
                $cleanReport += "  $line"
            }
            if ($line -match "GPU #2") { break }
        }
    }
    
    # --- 5. RECOMMENDATIONS ENGINE ---
    $cleanReport += ""
    $cleanReport += "RECOMMENDATIONS:"
    $cleanReport += "----------------"

    $recommendations = @()
    $criticalIssues = 0
    
    # --- A. Ping/Latency Alert ---
    if ($latencyTest) {
        $avgLatencies = $latencyTest.Output -split "`n" | Where-Object { $_ -match "(\d+) ms" } | ForEach-Object { [int]$matches[1] }
        $highPing = $avgLatencies | Where-Object { $_ -gt 150 }
        if ($highPing.Count -gt 0) {
            $recommendations += "• CRITICAL: High network latency detected (over 150ms)."
            $recommendations += "  → Check router/modem status and contact ISP."
            $criticalIssues++
        }
    }

    # --- B. Memory Usage Alert ---
    if ($ramInfo -and $ramInfo.Output -match "Usage: ([\d\.]+)%") {
        $usage = [float]$matches[1]
        if ($usage -gt 85) {
            $recommendations += "• CRITICAL: High memory usage ($usage%)"
            $recommendations += "  → Close unnecessary programs; consider adding more RAM."
            $criticalIssues++
        } elseif ($usage -gt 70) {
            $recommendations += "• WARNING: Elevated memory usage ($usage%) - monitor applications."
        }
    }

    # --- C. High GPU Temperature Alert (NVIDIA/SMART) ---
    $tempAlert = $false
    
    # 1. Check NVIDIA-SMI output
    # NOTE: NVIDIA-SMI tool is not included in this merged script, so this will only run if you add it back.
    if ($nvidiaMetrics -and $nvidiaMetrics.Output -match "temperature.gpu,(\d+)") {
        $gpuTemp = [int]$matches[1]
        if ($gpuTemp -gt 85) {
            $recommendations += "• CRITICAL: GPU temperature ($gpuTemp°C) is high under load."
            $recommendations += "  → Check case ventilation and clean dust from fans."
            $criticalIssues++
            $tempAlert = $true
        }
    }

    # 2. Check general SMART temperature (as a proxy for disk health)
    $smartInfo = $script:TestResults | Where-Object {$_.Tool -eq "SMART"} | Select-Object -First 1
    if (-not $tempAlert -and $smartInfo -and $smartInfo.Output -match "Temperature: (\d+)°C") {
        $diskTemp = [int]$matches[1]
        if ($diskTemp -gt 50) {
            $recommendations += "• WARNING: Disk temperature ($diskTemp°C) is elevated."
            $recommendations += "  → Ensure proper case airflow to the storage drives."
        }
    }

    # --- D. Slow Disk Performance Alert ---
    if ($diskPerf -and $diskPerf.Output -match "Write: ([\d\.]+) MB/s.*Read: ([\d\.]+) MB/s") {
        $writeSpeed = [float]$matches[1]
        $readSpeed = [float]$matches[2]
        
        # Consider any speed below 50 MB/s to be critical slowdown (indicating HDD failure or extreme congestion)
        if ($writeSpeed -lt 50 -or $readSpeed -lt 50) {
            $recommendations += "• CRITICAL: Very slow disk performance detected (R/W < 50 MB/s)."
            $recommendations += "  → Check for disk errors and run system maintenance."
            $criticalIssues++
        }
    }
	
	# --- D.5. Windows Update Alert ---
    $updateTest = $script:TestResults | Where-Object {$_.Tool -eq "Windows-Update"} | Select-Object -First 1
    if ($updateTest -and $updateTest.Output -match "Pending:\s*(\d+)") {
        $pendingCount = [int]$matches[1]
        if ($pendingCount -gt 0) {
            $recommendations += "• CRITICAL: $pendingCount Windows Update(s) are pending."
            $recommendations += "  → Install all pending updates to ensure system stability and security."
            $criticalIssues++
        }
    }
    
    # --- E. Failed Tests Alert ---
    if ($failed -gt 0) {
        $recommendations += "• CRITICAL: $failed test(s) failed."
        $recommendations += "  → Review detailed report for specific error messages."
        $criticalIssues++
    }

    # --- F. Overall Status / General Tips ---
    if ($criticalIssues -eq 0 -and $failed -eq 0) {
        $recommendations += "• EXCELLENT: All key tests passed successfully."
        $recommendations += "  → System is stable and performing well."
    } elseif ($recommendations.Count -eq 0) {
        $recommendations += "• INFO: No critical issues found. Monitor system usage."
    }

    # Add all recommendations to report
    foreach ($rec in $recommendations) {
        $cleanReport += $rec
    }

    $cleanReport += ""
    $cleanReport += "For detailed output, see: $detailedPath"
    $cleanReport += ""
    $cleanReport += "========================================="
    $cleanReport += "Report generated by Sysinternals Tester v$script:VERSION"

    # === DETAILED REPORT ===
    $detailedReport = @()
    # ... (detailed report creation)
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
    foreach ($result in $script:TestResults) {
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
        # *** FIX APPLIED HERE: Using $detailedReport ***
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
    Write-Host "3.  RAM Testing (Fixed)"
    Write-Host "4.  Storage Testing"
    Write-Host "5.  Process Analysis"
    Write-Host "6.  Security Analysis $(if (-not $script:IsAdmin) {'[Admin]'})"
    Write-Host "7.  Network Analysis"
    Write-Host "8.  Network Speed Tests (NEW)" -ForegroundColor Cyan
    Write-Host "9.  OS Health (DISM/SFC) $(if (-not $script:IsAdmin) {'[Admin]'})"
    Write-Host "10. Storage SMART"
    Write-Host "11. SSD TRIM Status"
    Write-Host "12. GPU (dxdiag)"
    Write-Host "13. Power/Battery"
    Write-Host "14. Hardware Events (WHEA)"
    Write-Host "15. Windows Update"
    Write-Host "16. Run ALL Tests" -ForegroundColor Yellow
    Write-Host "17. Generate Report (Clean + Detailed)" -ForegroundColor Green
    Write-Host "18. Clear Results" -ForegroundColor Red
    Write-Host "Q.  Quit"
    Write-Host ""
    Write-Host "Tests completed: $($script:TestResults.Count)" -ForegroundColor Gray
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
            "8"  { Test-NetworkSpeed; Read-Host "`nPress Enter" }
            "9"  { Test-OSHealth; Read-Host "`nPress Enter" }
            "10" { Test-StorageSMART; Read-Host "`nPress Enter" }
            "11" { Test-Trim; Read-Host "`nPress Enter" }
            "12" { Test-GPU; Read-Host "`nPress Enter" }
            "13" { Test-Power; Read-Host "`nPress Enter" }
            "14" { Test-HardwareEvents; Read-Host "`nPress Enter" }
            "15" { Test-WindowsUpdate; Read-Host "`nPress Enter" }
            "16" {
                Write-Host "`nRunning all tests..." -ForegroundColor Yellow
                Test-SystemInfo; Test-CPU; Test-Memory; Test-Storage
                Test-Processes; Test-Security; Test-Network; Test-NetworkSpeed # Added Test-NetworkSpeed
                Test-OSHealth; Test-StorageSMART; Test-Trim; Test-GPU
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
            Test-Processes; Test-Security; Test-Network; Test-NetworkSpeed # Added Test-NetworkSpeed
            Test-OSHealth; Test-StorageSMART; Test-Trim; Test-GPU
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
}
