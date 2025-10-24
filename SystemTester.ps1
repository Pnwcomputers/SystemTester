# Portable Sysinternals System Tester - Enhanced Version
# Created by Pacific Northwest Computers - 2025
# Complete Production Version - v2.3
# Enhanced with Network Speed Testing

param([switch]$AutoRun)

# Constants
$script:VERSION = "2.3"
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
    "testlimit","diskext","listdlls","psping"  # Added psping for network testing
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

    # Run verification
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

# Run tool
function Run-Tool {
    param(
        [string]$ToolName,
        [string]$Args = "",
        [string]$Description,
        [int]$TimeoutSeconds = 10
    )

    $toolPath = Join-Path $SysinternalsPath "$ToolName.exe"
    if (!(Test-Path $toolPath)) {
        Write-Host "$ToolName not found" -ForegroundColor Red
        $script:TestResults += @{
            Tool=$ToolName; Description=$Description
            Status="MISSING"; Output="Tool not found"; Duration=0
        }
        return
    }

    try {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $toolPath
        $info.Arguments = $Args
        $info.UseShellExecute = $false
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $info
        
        $start = Get-Date
        $process.Start() | Out-Null
        
        $output = ""
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        
        if ($finished) {
            $output = $process.StandardOutput.ReadToEnd()
            $error = $process.StandardError.ReadToEnd()
            if ($error) { $output += "`nERROR: $error" }
            $duration = ((Get-Date) - $start).TotalMilliseconds
            
            $script:TestResults += @{
                Tool=$ToolName; Description=$Description
                Status="SUCCESS"; Output=$output; Duration=$duration
            }
            Write-Host "$ToolName completed successfully" -ForegroundColor Green
        } else {
            $process.Kill()
            $script:TestResults += @{
                Tool=$ToolName; Description=$Description
                Status="TIMEOUT"; Output="Process timed out after $TimeoutSeconds seconds"; Duration=($TimeoutSeconds*1000)
            }
            Write-Host "$ToolName timed out" -ForegroundColor Yellow
        }
    } catch {
        $script:TestResults += @{
            Tool=$ToolName; Description=$Description
            Status="ERROR"; Output=$_.Exception.Message; Duration=0
        }
        Write-Host "$ToolName error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test: System Info
function Test-SystemInfo {
    Write-Host "`n=== System Information ===" -ForegroundColor Green
    Run-Tool -ToolName "psinfo" -Args "-s -d /accepteula" -Description "System information"
    Run-Tool -ToolName "coreinfo" -Args "-c /accepteula" -Description "CPU core information"
}

# Test: CPU
function Test-CPU {
    Write-Host "`n=== CPU Testing ===" -ForegroundColor Green
    
    # Basic CPU info
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $info = @"
Name: $($cpu.Name)
Cores: $($cpu.NumberOfCores)
Logical Processors: $($cpu.NumberOfLogicalProcessors)
Max Clock: $($cpu.MaxClockSpeed) MHz
Current Clock: $($cpu.CurrentClockSpeed) MHz
"@
        $script:TestResults += @{
            Tool="CPU-Info"; Description="CPU details"
            Status="SUCCESS"; Output=$info; Duration=50
        }
        Write-Host "CPU: $($cpu.Name)" -ForegroundColor Green
    } catch {
        Write-Host "Error getting CPU info" -ForegroundColor Red
    }
    
    Run-Tool -ToolName "pslist" -Args "-s 1" -Description "Process list snapshot"
    Run-Tool -ToolName "handle" -Args "/accepteula" -Description "Handle information" -TimeoutSeconds 5
    Run-Tool -ToolName "clockres" -Description "Clock resolution"
    
    # CPU stress test
    Write-Host "Starting CPU test ($script:CPU_TEST_SECONDS seconds)..." -ForegroundColor Yellow
    try {
        $start = Get-Date
        $maxValue = [Math]::Pow(2,20)
        $endTime = $start.AddSeconds($script:CPU_TEST_SECONDS)
        $iterations = 0
        
        while ((Get-Date) -lt $endTime) {
            $result = 1
            for ($i = 1; $i -le 100; $i++) {
                $result = ($result * $i) % $maxValue
            }
            $iterations++
        }
        
        $duration = ((Get-Date) - $start).TotalSeconds
        $opsPerSecond = [Math]::Round($iterations / $duration, 2)
        
        $script:TestResults += @{
            Tool="CPU-Stress"; Description="CPU performance test"
            Status="SUCCESS"; Output="$iterations iterations in $duration seconds`nOps/sec: $opsPerSecond"; Duration=($duration*1000)
        }
        Write-Host "CPU test: $opsPerSecond ops/sec" -ForegroundColor Green
    } catch {
        Write-Host "CPU test failed" -ForegroundColor Red
    }
}

# Test: Memory (WITH FIX)
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
    Run-Tool -ToolName "listdlls" -Args "-u" -Description "Unsigned DLLs" -TimeoutSeconds 15
}

# Test: Security
function Test-Security {
    Write-Host "`n=== Security Analysis ===" -ForegroundColor Green
    if (-not $script:IsAdmin) {
        Write-Host "Some security tests require admin" -ForegroundColor Yellow
    }
    Run-Tool -ToolName "autorunsc" -Args "-a * -c -s" -Description "Autorun entries" -TimeoutSeconds 30
    Run-Tool -ToolName "streams" -Args "-s C:\" -Description "Alternate data streams" -TimeoutSeconds 20
}

# NEW ENHANCED: Test Network with Speed Testing
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
    
    # Network adapter information
    Write-Host "Gathering network adapter information..." -ForegroundColor Yellow
    try {
        $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
        $adapterInfo = @()
        foreach ($adapter in $adapters) {
            $adapterInfo += "Adapter: $($adapter.Name)"
            $adapterInfo += "  Status: $($adapter.Status)"
            $adapterInfo += "  Speed: $([math]::Round($adapter.LinkSpeed / 1000000, 0)) Mbps"
            $adapterInfo += "  MAC: $($adapter.MacAddress)"
            $adapterInfo += ""
        }
        $script:TestResults += @{
            Tool="Network-Adapters"; Description="Active network adapters"
            Status="SUCCESS"; Output=($adapterInfo -join "`n"); Duration=100
        }
        Write-Host "Network adapter info collected" -ForegroundColor Green
    } catch {
        Write-Host "Error getting adapter info" -ForegroundColor Yellow
    }
}

# NEW: Network Speed Testing Function
function Test-NetworkSpeed {
    Write-Host "`n=== Network Speed Testing ===" -ForegroundColor Green
    
    # Test 1: Local Network Connectivity with Test-NetConnection
    Write-Host "Testing local network connectivity..." -ForegroundColor Yellow
    try {
        # Test gateway
        $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -First 1).NextHop
        if ($gateway) {
            $gatewayTest = Test-NetConnection -ComputerName $gateway -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($gatewayTest) {
                Write-Host "Gateway ($gateway) is reachable" -ForegroundColor Green
                $script:TestResults += @{
                    Tool="Gateway-Test"; Description="Local gateway connectivity"
                    Status="SUCCESS"; Output="Gateway $gateway is reachable"; Duration=100
                }
            } else {
                Write-Host "Gateway ($gateway) is not reachable" -ForegroundColor Red
                $script:TestResults += @{
                    Tool="Gateway-Test"; Description="Local gateway connectivity"
                    Status="FAILED"; Output="Gateway $gateway is not reachable"; Duration=100
                }
            }
        }
    } catch {
        Write-Host "Could not test gateway" -ForegroundColor Yellow
    }
    
    # Test 2: Internet Connectivity Tests
    Write-Host "Testing internet connectivity..." -ForegroundColor Yellow
    $internetTargets = @(
        @{Name="Google DNS"; Target="8.8.8.8"; Port=53},
        @{Name="Cloudflare DNS"; Target="1.1.1.1"; Port=53},
        @{Name="Google"; Target="google.com"; Port=443},
        @{Name="Microsoft"; Target="microsoft.com"; Port=443}
    )
    
    $connectivityResults = @()
    foreach ($target in $internetTargets) {
        try {
            Write-Host "  Testing $($target.Name)..." -NoNewline
            $result = Test-NetConnection -ComputerName $target.Target -Port $target.Port -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($result) {
                Write-Host " OK" -ForegroundColor Green
                $connectivityResults += "$($target.Name): Reachable"
            } else {
                Write-Host " Failed" -ForegroundColor Red
                $connectivityResults += "$($target.Name): Unreachable"
            }
        } catch {
            Write-Host " Error" -ForegroundColor Yellow
            $connectivityResults += "$($target.Name): Error"
        }
    }
    
    $script:TestResults += @{
        Tool="Internet-Connectivity"; Description="Internet endpoint tests"
        Status="SUCCESS"; Output=($connectivityResults -join "`n"); Duration=500
    }
    
    # Test 3: Latency Testing with Test-NetConnection
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
                $latencyResults += "$target: $latency ms"
            } else {
                Write-Host " Failed" -ForegroundColor Red
                $latencyResults += "$target: Failed"
            }
        } catch {
            Write-Host " Error" -ForegroundColor Yellow
            $latencyResults += "$target: Error"
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
        
        # Latency test with PSPing
        Write-Host "  PSPing latency test to Google DNS..." -ForegroundColor Yellow
        try {
            $pspingResult = & $pspingPath -n 10 -w 0 -q 8.8.8.8:53 2>&1
            $pspingOutput = $pspingResult -join "`n"
            
            # Extract average latency from PSPing output
            if ($pspingOutput -match "Average = ([\d.]+)ms") {
                $avgLatency = $matches[1]
                Write-Host "  Average latency: $avgLatency ms" -ForegroundColor Green
                $script:TestResults += @{
                    Tool="PSPing-Latency"; Description="PSPing latency test to 8.8.8.8"
                    Status="SUCCESS"; Output="Average latency: $avgLatency ms`n`nFull output:`n$pspingOutput"; Duration=10000
                }
            } else {
                $script:TestResults += @{
                    Tool="PSPing-Latency"; Description="PSPing latency test"
                    Status="SUCCESS"; Output=$pspingOutput; Duration=10000
                }
            }
        } catch {
            Write-Host "  PSPing latency test failed" -ForegroundColor Yellow
            $script:TestResults += @{
                Tool="PSPing-Latency"; Description="PSPing latency test"
                Status="ERROR"; Output=$_.Exception.Message; Duration=0
            }
        }
        
        # Bandwidth test with PSPing (TCP)
        Write-Host "  PSPing bandwidth test..." -ForegroundColor Yellow
        Write-Host "  Note: This tests connection capacity, not actual throughput" -ForegroundColor DarkGray
        try {
            # Using port 80 for HTTP as it's commonly open
            $bandwidthResult = & $pspingPath -b -l 8k -n 100 -h 10 google.com:80 2>&1
            $bandwidthOutput = $bandwidthResult -join "`n"
            
            $script:TestResults += @{
                Tool="PSPing-Bandwidth"; Description="PSPing bandwidth capacity test"
                Status="SUCCESS"; Output=$bandwidthOutput; Duration=5000
            }
            
            Write-Host "  Bandwidth test completed" -ForegroundColor Green
        } catch {
            Write-Host "  PSPing bandwidth test failed" -ForegroundColor Yellow
            $script:TestResults += @{
                Tool="PSPing-Bandwidth"; Description="PSPing bandwidth test"
                Status="ERROR"; Output=$_.Exception.Message; Duration=0
            }
        }
    } else {
        Write-Host "PSPing not found - skipping advanced tests" -ForegroundColor Yellow
        Write-Host "Download PSPing from Sysinternals for bandwidth testing" -ForegroundColor Yellow
        $script:TestResults += @{
            Tool="PSPing"; Description="PSPing tests"
            Status="SKIPPED"; Output="PSPing.exe not found in Sysinternals folder"; Duration=0
        }
    }
    
    # Test 5: DNS Resolution Speed
    Write-Host "Testing DNS resolution speed..." -ForegroundColor Yellow
    $dnsTargets = @("google.com", "microsoft.com", "cloudflare.com", "github.com")
    $dnsResults = @()
    
    foreach ($domain in $dnsTargets) {
        try {
            $start = Get-Date
            $result = Resolve-DnsName -Name $domain -Type A -ErrorAction Stop
            $duration = ((Get-Date) - $start).TotalMilliseconds
            $dnsResults += "$domain: $([math]::Round($duration,1)) ms"
            Write-Host "  $domain resolved in $([math]::Round($duration,1)) ms" -ForegroundColor Green
        } catch {
            $dnsResults += "$domain: Failed"
            Write-Host "  $domain resolution failed" -ForegroundColor Red
        }
    }
    
    $script:TestResults += @{
        Tool="DNS-Resolution"; Description="DNS resolution speed"
        Status="SUCCESS"; Output=($dnsResults -join "`n"); Duration=200
    }
    
    # Test 6: Network Path MTU Discovery
    Write-Host "Checking network MTU..." -ForegroundColor Yellow
    try {
        $mtuTest = ping -f -l 1472 8.8.8.8 -n 1 2>&1
        if ($mtuTest -match "Packet needs to be fragmented") {
            Write-Host "  Standard MTU (1500) may be too large" -ForegroundColor Yellow
            $mtuResult = "MTU may need adjustment - fragmentation detected"
        } else {
            Write-Host "  Standard MTU (1500) works" -ForegroundColor Green
            $mtuResult = "Standard MTU (1500 bytes) is working"
        }
        
        $script:TestResults += @{
            Tool="MTU-Check"; Description="Network MTU verification"
            Status="SUCCESS"; Output=$mtuResult; Duration=100
        }
    } catch {
        Write-Host "  Could not test MTU" -ForegroundColor Yellow
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
            $info += "  Wear: $($disk.Wear)%"
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
    Write-Host "`n=== SSD TRIM Status ===" -ForegroundColor Green
    try {
        $trimResult = fsutil behavior query DisableDeleteNotify 2>&1
        $script:TestResults += @{
            Tool="TRIM"; Description="SSD TRIM status"
            Status="SUCCESS"; Output=$trimResult; Duration=50
        }
        Write-Host "TRIM status checked" -ForegroundColor Green
    } catch {
        Write-Host "TRIM status unavailable" -ForegroundColor Yellow
    }
}

# Test: Network Adapters
function Test-NIC {
    Write-Host "`n=== Network Adapters ===" -ForegroundColor Green
    try {
        $nics = Get-NetAdapter -ErrorAction Stop
        $info = @()
        foreach ($nic in $nics) {
            $info += "$($nic.Name): $($nic.Status) - $($nic.LinkSpeed)"
        }
        $script:TestResults += @{
            Tool="NIC"; Description="Network adapter details"
            Status="SUCCESS"; Output=($info -join "`n"); Duration=100
        }
        Write-Host "NIC details collected" -ForegroundColor Green
    } catch {
        Write-Host "NIC details unavailable" -ForegroundColor Yellow
    }
}

# Test: Power
function Test-Power {
    Write-Host "`n=== Power/Battery ===" -ForegroundColor Green
    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction Stop
        if ($battery) {
            $info = @"
Status: $($battery.BatteryStatus)
Charge: $($battery.EstimatedChargeRemaining)%
Runtime: $($battery.EstimatedRunTime) minutes
"@
            $script:TestResults += @{
                Tool="Battery"; Description="Battery status"
                Status="SUCCESS"; Output=$info; Duration=50
            }
            Write-Host "Battery: $($battery.EstimatedChargeRemaining)%" -ForegroundColor Green
        } else {
            Write-Host "No battery detected (desktop)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Power info unavailable" -ForegroundColor Yellow
    }
}

# Test: Hardware Events
function Test-HardwareEvents {
    Write-Host "`n=== Hardware Events (WHEA) ===" -ForegroundColor Green
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='System'; ID=17,18,19,20,47} -MaxEvents 10 -ErrorAction Stop
        $info = @()
        foreach ($event in $events) {
            $info += "$($event.TimeCreated): $($event.Message.Split("`n")[0])"
        }
        if ($info.Count -eq 0) {
            $info = @("No recent hardware errors")
        }
        $script:TestResults += @{
            Tool="WHEA"; Description="Hardware error events"
            Status="SUCCESS"; Output=($info -join "`n"); Duration=200
        }
        Write-Host "Hardware events checked" -ForegroundColor Green
    } catch {
        Write-Host "No hardware events found" -ForegroundColor Green
    }
}

# Test: Windows Update
function Test-WindowsUpdate {
    Write-Host "`n=== Windows Update ===" -ForegroundColor Green
    try {
        $updates = Get-HotFix | Select-Object -Last 5
        $info = @()
        foreach ($update in $updates) {
            $info += "$($update.HotFixID) - Installed: $($update.InstalledOn)"
        }
        $script:TestResults += @{
            Tool="Updates"; Description="Recent Windows updates"
            Status="SUCCESS"; Output=($info -join "`n"); Duration=100
        }
        Write-Host "Update history collected" -ForegroundColor Green
    } catch {
        Write-Host "Update info unavailable" -ForegroundColor Yellow
    }
}

# Generate Report
function Generate-Report {
    Write-Host "`n=== Generating Report ===" -ForegroundColor Green
    
    if ($TestResults.Count -eq 0) {
        Write-Host "No test results to report" -ForegroundColor Yellow
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $cleanPath = Join-Path $ScriptRoot "SystemReport_Clean_$timestamp.txt"
    $detailedPath = Join-Path $ScriptRoot "SystemReport_Detailed_$timestamp.txt"

    # Stats
    $total = $TestResults.Count
    $success = ($TestResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
    $failed = ($TestResults | Where-Object { $_.Status -in @("ERROR","TIMEOUT","FAILED") }).Count
    $skipped = ($TestResults | Where-Object { $_.Status -eq "SKIPPED" }).Count

    # Clean Report
    $cleanReport = @()
    $cleanReport += "========================================="
    $cleanReport += "  SYSTEM TEST REPORT v$script:VERSION"
    $cleanReport += "  CLEAN SUMMARY"
    $cleanReport += "========================================="
    $cleanReport += "Date: $(Get-Date)"
    $cleanReport += "Computer: $env:COMPUTERNAME"
    $cleanReport += "User: $env:USERNAME"
    $cleanReport += ""
    $cleanReport += "TEST SUMMARY:"
    $cleanReport += "  Total Tests: $total"
    $cleanReport += "  Successful: $success"
    $cleanReport += "  Failed: $failed"
    $cleanReport += "  Skipped: $skipped"
    $cleanReport += "  Success Rate: $([math]::Round(($success/$total)*100,1))%"
    $cleanReport += ""
    $cleanReport += "KEY FINDINGS:"
    
    # Extract key metrics
    $cpuTest = $TestResults | Where-Object { $_.Tool -eq "CPU-Info" } | Select-Object -First 1
    if ($cpuTest) {
        $cleanReport += $cpuTest.Output
    }
    
    $ramTest = $TestResults | Where-Object { $_.Tool -eq "RAM-Details" } | Select-Object -First 1
    if ($ramTest) {
        $cleanReport += "`nRAM:"
        $cleanReport += $ramTest.Output
    }
    
    $storageTest = $TestResults | Where-Object { $_.Tool -eq "Storage-Overview" } | Select-Object -First 1
    if ($storageTest) {
        $cleanReport += "`nSTORAGE:"
        $cleanReport += $storageTest.Output
    }
    
    $networkTests = $TestResults | Where-Object { $_.Tool -like "*Network*" -or $_.Tool -like "*Latency*" }
    if ($networkTests) {
        $cleanReport += "`nNETWORK:"
        foreach ($test in $networkTests) {
            $cleanReport += "  $($test.Description):"
            $cleanReport += "    $($test.Output -split "`n" | Select-Object -First 3 | ForEach-Object { $_.Trim() } | Where-Object { $_ })"
        }
    }
    
    $cleanReport += ""
    $cleanReport += "========================================="
    $cleanReport += "Report generated by Sysinternals Tester v$script:VERSION"

    # Detailed Report
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
    Write-Host "3.  RAM Testing (Fixed)"
    Write-Host "4.  Storage Testing"
    Write-Host "5.  Process Analysis"
    Write-Host "6.  Security Analysis $(if (-not $script:IsAdmin) {'[Admin]'})"
    Write-Host "7.  Network Analysis"
    Write-Host "8.  Network Speed Tests (NEW)" -ForegroundColor Cyan
    Write-Host "9.  OS Health (DISM/SFC) $(if (-not $script:IsAdmin) {'[Admin]'})"
    Write-Host "10. Storage SMART"
    Write-Host "11. SSD TRIM Status"
    Write-Host "12. Network Adapters"
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
            "8"  { Test-NetworkSpeed; Read-Host "`nPress Enter" }
            "9"  { Test-OSHealth; Read-Host "`nPress Enter" }
            "10" { Test-StorageSMART; Read-Host "`nPress Enter" }
            "11" { Test-Trim; Read-Host "`nPress Enter" }
            "12" { Test-NIC; Read-Host "`nPress Enter" }
            "13" { Test-Power; Read-Host "`nPress Enter" }
            "14" { Test-HardwareEvents; Read-Host "`nPress Enter" }
            "15" { Test-WindowsUpdate; Read-Host "`nPress Enter" }
            "16" {
                Write-Host "`nRunning all tests..." -ForegroundColor Yellow
                Test-SystemInfo; Test-CPU; Test-Memory; Test-Storage
                Test-Processes; Test-Security; Test-Network; Test-NetworkSpeed
                Test-OSHealth; Test-StorageSMART; Test-Trim; Test-NIC
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
            Test-Processes; Test-Security; Test-Network; Test-NetworkSpeed
            Test-OSHealth; Test-StorageSMART; Test-Trim; Test-NIC
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
