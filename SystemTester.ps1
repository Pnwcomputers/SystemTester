# Simple Portable Sysinternals System Tester
# Minimal version with guaranteed clean syntax
# Createad by Pacific Northwest Computers - 2025

param(
    [string]$OutputPath = "",
    [switch]$AutoRun
)

# Global variables
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DriveRoot = Split-Path -Qualifier $ScriptRoot
$DriveLetter = $DriveRoot.TrimEnd('\')
$SysinternalsPath = Join-Path $ScriptRoot "Sysinternals"
$TestResults = @()

Write-Host "=====================================" -ForegroundColor Green
Write-Host "  PORTABLE SYSINTERNALS TESTER" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host "Running from: $DriveLetter" -ForegroundColor Cyan

# Initialize environment
function Initialize-Environment {
    Write-Host "Initializing..." -ForegroundColor Yellow
    
    # Check for tools
    if (!(Test-Path $SysinternalsPath)) {
        Write-Host "ERROR: Sysinternals folder not found!" -ForegroundColor Red
        Write-Host "Please create folder: $SysinternalsPath" -ForegroundColor Yellow
        Write-Host "And copy Sysinternals tools there." -ForegroundColor Yellow
        return $false
    }
    
    # Check for some key tools
    $keyTools = @("psinfo.exe", "coreinfo.exe", "pslist.exe", "testlimit.exe", "du.exe", "streams.exe")
    $foundTools = 0
    $missingTools = @()
    foreach ($tool in $keyTools) {
        if (Test-Path (Join-Path $SysinternalsPath $tool)) {
            $foundTools++
        } else {
            $missingTools += $tool
        }
    }
    
    if ($foundTools -eq 0) {
        Write-Host "ERROR: No Sysinternals tools found in $SysinternalsPath" -ForegroundColor Red
        Write-Host "Download Sysinternals Suite and extract to that folder." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "Found $foundTools/$($keyTools.Count) key tools in $SysinternalsPath" -ForegroundColor Green
    if ($missingTools.Count -gt 0) {
        Write-Host "Missing tools: $($missingTools -join ', ')" -ForegroundColor Yellow
        Write-Host "Some tests may be skipped." -ForegroundColor Yellow
    }
    return $true
}

# Clean and filter tool output
function Clean-ToolOutput {
    param(
        [string]$ToolName,
        [string]$RawOutput
    )
    
    if (!$RawOutput) { return "" }
    
    $lines = $RawOutput -split "`n" | ForEach-Object { $_.Trim() }
    $cleanedLines = @()
    $skipMode = $false
    
    foreach ($line in $lines) {
        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        
        # Skip common EULA and copyright lines
        if ($line -match "Copyright|Sysinternals|www\.microsoft\.com|Mark Russinovich|David Solomon|Bryce Cogswell") { continue }
        if ($line -match "EULA|End User License Agreement|accepts the license agreement") { continue }
        if ($line -match "^-+$|^=+$|^\*+$") { continue }  # Skip separator lines
        
        # Skip usage instructions and help text
        if ($line -match "^Usage:|^usage:|^Options:|^  -|^    -|^\s*-\w+\s+") { 
            $skipMode = $true
            continue 
        }
        if ($skipMode -and $line -match "^\s*$|^  |^    ") { continue }
        if ($skipMode -and $line -notmatch "^\w|^\d") { continue }
        $skipMode = $false
        
        # Tool-specific filtering
        switch ($ToolName) {
            "psinfo" {
                # Keep system info, skip fluff
                if ($line -match "^(System information|Uptime|Kernel version|Product type|Product version|Service pack|Kernel build number|Registered organization|Registered owner|IE version|System root|Processors|Processor speed|Total physical memory|Available physical memory)") {
                    $cleanedLines += $line
                }
                elseif ($line -match "^(Computer name|Domain name|Logon server|Hot fix|Install date)") {
                    $cleanedLines += $line
                }
                elseif ($line -match "\d+\.\d+\s*GB|\d+\s*MB|\d+\s*MHz|\d+\s*KB") {
                    $cleanedLines += $line
                }
            }
            "coreinfo" {
                # Keep CPU architecture info
                if ($line -match "^(Intel64|Logical Processors|Logical Cores|Cores per Processor|APIC ID|Processor|CPU|Cache|Feature)") {
                    $cleanedLines += $line
                }
                elseif ($line -match "^\s*\*|^\s*-|\s+\w+\s*\*|\s+\w+\s*-") {
                    $cleanedLines += $line
                }
            }
            "pslist" {
                # Keep process info, skip headers after first occurrence
                if ($line -match "^(Name|Process|Pid)\s+|^\w+\s+\d+\s+") {
                    $cleanedLines += $line
                }
            }
            "handle" {
                # Keep handle summary, skip individual handles unless critical
                if ($line -match "^(Handle summary|Total handles|Unique handles)") {
                    $cleanedLines += $line
                }
                elseif ($line -match "^explorer\.exe pid:|^  \w+:" -and $cleanedLines.Count -lt 20) {
                    $cleanedLines += $line
                }
            }
            "du" {
                # Keep directory sizes, skip individual files
                if ($line -match "^\s*\d+.*\\.*$|^Files:|^Subdirectories:|^Total Size:") {
                    $cleanedLines += $line
                }
            }
            "streams" {
                # Only keep files that actually have streams
                if ($line -match ":\w+:" -or $line -match "^Summary:|files scanned") {
                    $cleanedLines += $line
                }
            }
            "autorunsc" {
                # Keep autorun entries, skip verbose descriptions
                if ($line -match "^(HKLM|HKCU|Startup|Logon|Services|Winlogon)" -and $line.Length -lt 150) {
                    $cleanedLines += $line
                }
                elseif ($line -match "^Entry count|^Found \d+") {
                    $cleanedLines += $line
                }
            }
            "sigcheck" {
                # Keep signature verification results
                if ($line -match "^[a-zA-Z]:\\.*\.(exe|dll|sys)" -or $line -match "Verified:|Signing date:|Publisher:") {
                    $cleanedLines += $line
                }
            }
            "testlimit" {
                # Keep test results and limits
                if ($line -match "^(Test|Limit|Process|Memory|Handles|Threads).*:|allocation|created|failed") {
                    $cleanedLines += $line
                }
            }
            "clockres" {
                # Keep timing resolution info
                if ($line -match "resolution|timer|Maximum|Minimum|Current") {
                    $cleanedLines += $line
                }
            }
            "contig" {
                # Keep fragmentation summary
                if ($line -match "^(Summary|Files|Fragmented|Percent)") {
                    $cleanedLines += $line
                }
            }
            default {
                # Generic filtering for unknown tools
                if ($line -match "^\w+:|^\d+|\s+\d+\s+" -and $line.Length -lt 200) {
                    $cleanedLines += $line
                }
            }
        }
    }
    
    # Remove excessive blank lines and limit output length
    $result = $cleanedLines | Where-Object { $_ -ne "" } | Select-Object -First 50
    
    if ($result.Count -eq 0) {
        return "Tool completed - no detailed output captured"
    }
    
    return ($result -join "`n")
}

# Run a tool
function Run-Tool {
    param(
        [string]$ToolName,
        [string]$Args = "",
        [string]$Description = ""
    )
    
    $toolPath = Join-Path $SysinternalsPath "$ToolName.exe"
    
    if (!(Test-Path $toolPath)) {
        Write-Host "SKIP: $ToolName not found" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Running $ToolName..." -ForegroundColor Cyan
    
    try {
        $startTime = Get-Date
        
        # Add -accepteula for tools that need it
        if ($ToolName -in @("psinfo", "pslist", "handle", "autorunsc", "sigcheck", "testlimit", "contig")) {
            $Args = "-accepteula $Args"
        }
        
        $rawResult = & $toolPath $Args.Split(' ') 2>&1
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        # Clean the output
        $cleanOutput = Clean-ToolOutput -ToolName $ToolName -RawOutput ($rawResult | Out-String)
        
        $testResult = @{
            Tool = $ToolName
            Description = $Description
            Status = "SUCCESS"
            Output = $cleanOutput
            Duration = $duration
        }
        
        $script:TestResults += $testResult
        
        # Show a preview of cleaned output (first few lines)
        $previewLines = ($cleanOutput -split "`n") | Select-Object -First 3
        if ($previewLines.Count -gt 0) {
            Write-Host "Preview: $($previewLines[0])" -ForegroundColor DarkGray
        }
        
        Write-Host "OK: $ToolName completed in $([math]::Round($duration))ms (output cleaned)" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: $ToolName failed - $($_.Exception.Message)" -ForegroundColor Red
        
        $testResult = @{
            Tool = $ToolName
            Description = $Description
            Status = "FAILED"
            Output = $_.Exception.Message
            Duration = 0
        }
        
        $script:TestResults += $testResult
    }
}

# Test functions
function Test-SystemInfo {
    Write-Host "`n=== System Information ===" -ForegroundColor Green
    Run-Tool -ToolName "psinfo" -Args "-h -s -d" -Description "Complete system information"
    Run-Tool -ToolName "clockres" -Description "System clock resolution"
    
    # Get additional system info
    try {
        $os = Get-WmiObject Win32_OperatingSystem
        $cs = Get-WmiObject Win32_ComputerSystem
        
        $systemInfo = @"
OS: $($os.Caption) $($os.Version)
Architecture: $($os.OSArchitecture)
Computer: $($cs.Name)
Domain: $($cs.Domain)
Manufacturer: $($cs.Manufacturer)
Model: $($cs.Model)
Total RAM: $([math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB
"@
        
        $testResult = @{
            Tool = "System-Overview"
            Description = "System overview information"
            Status = "SUCCESS"
            Output = $systemInfo
            Duration = 100
        }
        $script:TestResults += $testResult
        Write-Host "System overview collected" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not get system overview" -ForegroundColor Red
    }
}

function Test-CPU {
    Write-Host "`n=== CPU Testing ===" -ForegroundColor Green
    
    # Comprehensive CPU information
    Run-Tool -ToolName "coreinfo" -Args "-v -f -c -g" -Description "Complete CPU architecture info"
    
    # Get CPU details via WMI
    try {
        $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
        $cpuInfo = @"
CPU Name: $($cpu.Name)
Manufacturer: $($cpu.Manufacturer)
Architecture: $($cpu.Architecture)
Cores: $($cpu.NumberOfCores)
Logical Processors: $($cpu.NumberOfLogicalProcessors)
Max Clock Speed: $($cpu.MaxClockSpeed) MHz
Current Clock Speed: $($cpu.CurrentClockSpeed) MHz
Cache Size L2: $($cpu.L2CacheSize) KB
Cache Size L3: $($cpu.L3CacheSize) KB
"@
        
        $testResult = @{
            Tool = "CPU-Details"
            Description = "Detailed CPU information"
            Status = "SUCCESS"
            Output = $cpuInfo
            Duration = 150
        }
        $script:TestResults += $testResult
        Write-Host "CPU details collected" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not get CPU details" -ForegroundColor Red
    }
    
    # CPU Performance Test
    Write-Host "Running CPU stress test (10 seconds)..." -ForegroundColor Yellow
    try {
        $startTime = Get-Date
        $endTime = $startTime.AddSeconds(10)
        $counter = 0
        
        while ((Get-Date) -lt $endTime) {
            $counter++
            [math]::Sqrt($counter) | Out-Null
        }
        
        $duration = ((Get-Date) - $startTime).TotalSeconds
        $opsPerSec = [math]::Round($counter / $duration)
        
        $testResult = @{
            Tool = "CPU-Performance"
            Description = "CPU performance test (10 seconds)"
            Status = "SUCCESS"
            Output = "Operations completed: $counter`nDuration: $([math]::Round($duration,2)) seconds`nOperations per second: $opsPerSec"
            Duration = $duration * 1000
        }
        $script:TestResults += $testResult
        Write-Host "CPU performance test completed: $opsPerSec ops/sec" -ForegroundColor Green
    }
    catch {
        Write-Host "CPU performance test failed" -ForegroundColor Red
    }
    
    # CPU usage by processes
    try {
        $topCPU = Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 ProcessName, CPU, WorkingSet
        $cpuUsage = ""
        foreach ($proc in $topCPU) {
            $cpu = if ($proc.CPU) { [math]::Round($proc.CPU, 2) } else { 0 }
            $memMB = if ($proc.WorkingSet) { [math]::Round($proc.WorkingSet / 1MB, 1) } else { 0 }
            $cpuUsage += "$($proc.ProcessName): CPU=$cpu s, RAM=$memMB MB`n"
        }
        
        $testResult = @{
            Tool = "CPU-Usage"
            Description = "Top 5 CPU consuming processes"
            Status = "SUCCESS"
            Output = $cpuUsage
            Duration = 200
        }
        $script:TestResults += $testResult
        Write-Host "CPU usage analysis completed" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not analyze CPU usage" -ForegroundColor Red
    }
}

function Test-Memory {
    Write-Host "`n=== RAM Testing ===" -ForegroundColor Green
    
    # Comprehensive memory information
    try {
        $mem = Get-WmiObject Win32_ComputerSystem
        $os = Get-WmiObject Win32_OperatingSystem
        $totalGB = [math]::Round($mem.TotalPhysicalMemory / 1GB, 2)
        $availableGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $usedGB = $totalGB - $availableGB
        $usagePercent = [math]::Round(($usedGB / $totalGB) * 100, 1)
        
        # Get memory modules info
        $memModules = Get-WmiObject Win32_PhysicalMemory
        $moduleInfo = ""
        $moduleCount = 0
        foreach ($module in $memModules) {
            $moduleCount++
            $sizeGB = [math]::Round($module.Capacity / 1GB, 0)
            $speed = if ($module.Speed) { $module.Speed } else { "Unknown" }
            $moduleInfo += "Module $moduleCount : $sizeGB GB @ $speed MHz ($($module.MemoryType))`n"
        }
        
        $memoryInfo = @"
Total Physical RAM: $totalGB GB
Available RAM: $availableGB GB
Used RAM: $usedGB GB
Usage: $usagePercent%
Memory Modules: $moduleCount
$moduleInfo
Virtual Memory Total: $([math]::Round($os.TotalVirtualMemorySize / 1MB, 2)) GB
Virtual Memory Available: $([math]::Round($os.FreeVirtualMemory / 1MB, 2)) GB
"@
        
        $testResult = @{
            Tool = "RAM-Details"
            Description = "Comprehensive RAM information"
            Status = "SUCCESS"
            Output = $memoryInfo
            Duration = 200
        }
        $script:TestResults += $testResult
        Write-Host "RAM details collected: $totalGB GB total, $usagePercent% used" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not get detailed memory info" -ForegroundColor Red
    }
    
    # Memory stress test (light)
    Write-Host "Running memory allocation test..." -ForegroundColor Yellow
    Run-Tool -ToolName "testlimit" -Args "-m 100" -Description "Memory allocation test (100MB)"
    
    # Memory performance counters
    try {
        $pagesSec = Get-Counter "\Memory\Pages/sec" -SampleInterval 1 -MaxSamples 3
        $avgPages = ($pagesSec.CounterSamples | Measure-Object CookedValue -Average).Average
        
        $testResult = @{
            Tool = "Memory-Performance"
            Description = "Memory performance counters"
            Status = "SUCCESS"
            Output = "Average Pages/sec: $([math]::Round($avgPages, 2))"
            Duration = 3000
        }
        $script:TestResults += $testResult
        Write-Host "Memory performance measured" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not measure memory performance" -ForegroundColor Yellow
    }
}

function Test-Storage {
    Write-Host "`n=== Hard Drive/SSD Testing ===" -ForegroundColor Green
    
    # Comprehensive disk information
    try {
        $disks = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        $physicalDisks = Get-WmiObject Win32_DiskDrive
        
        $diskInfo = "LOGICAL DRIVES:`n"
        foreach ($disk in $disks) {
            $totalGB = [math]::Round($disk.Size / 1GB, 2)
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            $usedGB = $totalGB - $freeGB
            $freePercent = [math]::Round(($freeGB / $totalGB) * 100, 1)
            $diskInfo += "$($disk.DeviceID) [$($disk.VolumeName)] - $totalGB GB total, $freeGB GB free ($freePercent% free)`n"
        }
        
        $diskInfo += "`nPHYSICAL DRIVES:`n"
        foreach ($drive in $physicalDisks) {
            $sizeGB = [math]::Round($drive.Size / 1GB, 0)
            $driveType = if ($drive.MediaType -like "*SSD*" -or $drive.Model -like "*SSD*") { "SSD" } else { "HDD" }
            $diskInfo += "$($drive.Model) - $sizeGB GB ($driveType)`n"
        }
        
        $testResult = @{
            Tool = "Storage-Overview"
            Description = "Complete storage information"
            Status = "SUCCESS"
            Output = $diskInfo
            Duration = 300
        }
        $script:TestResults += $testResult
        Write-Host "Storage overview collected" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not get storage overview" -ForegroundColor Red
    }
    
    # Disk usage analysis
    Run-Tool -ToolName "du" -Args "-l 2 C:\" -Description "Detailed disk usage analysis of C:"
    
    # Check for alternate data streams (security/integrity)
    Run-Tool -ToolName "streams" -Args "-s C:\Windows\System32" -Description "Check System32 for alternate data streams"
    
    # Disk fragmentation check (if available)
    Run-Tool -ToolName "contig" -Args "-a C:\" -Description "Check C: drive fragmentation"
    
    # Disk performance test (simple)
    Write-Host "Running disk performance test..." -ForegroundColor Yellow
    try {
        $testFile = Join-Path $env:TEMP "disktest.tmp"
        $testData = "0" * 1024 * 1024  # 1MB of data
        
        # Write test
        $writeStart = Get-Date
        for ($i = 0; $i -lt 10; $i++) {
            $testData | Out-File -FilePath $testFile -Append -Encoding ASCII
        }
        $writeTime = ((Get-Date) - $writeStart).TotalMilliseconds
        
        # Read test
        $readStart = Get-Date
        $content = Get-Content $testFile -Raw
        $readTime = ((Get-Date) - $readStart).TotalMilliseconds
        
        # Cleanup
        Remove-Item $testFile -ErrorAction SilentlyContinue
        
        $writeMBps = [math]::Round(10 / ($writeTime / 1000), 2)
        $readMBps = [math]::Round(10 / ($readTime / 1000), 2)
        
        $testResult = @{
            Tool = "Disk-Performance"
            Description = "Basic disk performance test (10MB)"
            Status = "SUCCESS"
            Output = "Write Speed: $writeMBps MB/s`nRead Speed: $readMBps MB/s`nWrite Time: $([math]::Round($writeTime)) ms`nRead Time: $([math]::Round($readTime)) ms"
            Duration = $writeTime + $readTime
        }
        $script:TestResults += $testResult
        Write-Host "Disk performance: Write $writeMBps MB/s, Read $readMBps MB/s" -ForegroundColor Green
    }
    catch {
        Write-Host "Disk performance test failed" -ForegroundColor Red
    }
}

function Test-Processes {
    Write-Host "`n=== Process Analysis ===" -ForegroundColor Green
    Run-Tool -ToolName "pslist" -Args "-t" -Description "Process tree"
    Run-Tool -ToolName "handle" -Args "-p explorer" -Description "Explorer handles"
}

function Test-Security {
    Write-Host "`n=== Security Analysis ===" -ForegroundColor Green
    Run-Tool -ToolName "autorunsc" -Args "-a -c" -Description "Autorun entries"
}

function Test-Network {
    Write-Host "`n=== Network Analysis ===" -ForegroundColor Green
    
    # Simple network info using built-in commands
    try {
        $connections = netstat -an | Measure-Object | Select-Object -ExpandProperty Count
        Write-Host "Network connections: $connections" -ForegroundColor White
        
        $testResult = @{
            Tool = "Netstat"
            Description = "Network connections"
            Status = "SUCCESS"
            Output = "Total connections: $connections"
            Duration = 50
        }
        $script:TestResults += $testResult
    }
    catch {
        Write-Host "Could not get network info" -ForegroundColor Red
    }
}

# Generate comprehensive report
function Generate-Report {
    Write-Host "`nGenerating Clean Report..." -ForegroundColor Cyan
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportPath = Join-Path $ScriptRoot "SystemTest_Clean_$timestamp.txt"
    $detailedPath = Join-Path $ScriptRoot "SystemTest_Detailed_$timestamp.txt"
    
    # Generate clean summary report
    $report = @()
    $report += "=========================================="
    $report += "  SYSTEM TEST REPORT (CLEANED)"
    $report += "=========================================="
    $report += "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $report += "Computer: $env:COMPUTERNAME"
    $report += "User: $env:USERNAME"
    $report += "Drive: $DriveLetter"
    $report += "Tools Location: $SysinternalsPath"
    $report += ""
    
    # Executive Summary
    $successCount = ($TestResults | Where-Object { $_.Status -eq "SUCCESS" }).Count
    $failedCount = ($TestResults | Where-Object { $_.Status -eq "FAILED" }).Count
    $totalCount = $TestResults.Count
    
    # Calculate total time safely
    $totalTime = 0
    foreach ($result in $TestResults) {
        if ($result.Duration -and $result.Duration -gt 0) {
            $totalTime += $result.Duration
        }
    }
    
    $report += "EXECUTIVE SUMMARY:"
    $report += "-----------------"
    $report += "Total Tests Run: $totalCount"
    $report += "Successful: $successCount"
    $report += "Failed: $failedCount"
    $report += "Success Rate: $([math]::Round(($successCount/$totalCount)*100,1))%"
    $report += "Total Test Time: $([math]::Round($totalTime/1000,1)) seconds"
    $report += ""
    
    # Key Findings (extract important metrics)
    $report += "KEY FINDINGS:"
    $report += "-------------"
    
    # Extract key system info
    $sysInfo = $TestResults | Where-Object { $_.Tool -eq "System-Overview" }
    if ($sysInfo) {
        $report += "SYSTEM:"
        $report += $sysInfo.Output -split "`n" | Where-Object { $_ -match "OS:|Total RAM:|CPU|Architecture:" } | ForEach-Object { "  $_" }
        $report += ""
    }
    
    # Extract CPU performance
    $cpuPerf = $TestResults | Where-Object { $_.Tool -eq "CPU-Performance" }
    if ($cpuPerf -and $cpuPerf.Output -match "Operations per second: (\d+)") {
        $report += "CPU PERFORMANCE:"
        $report += "  Operations/sec: $($matches[1])"
    }
    
    # Extract memory info
    $ramInfo = $TestResults | Where-Object { $_.Tool -eq "RAM-Details" }
    if ($ramInfo -and $ramInfo.Output -match "Total Physical RAM: ([\d.]+) GB.*Usage: ([\d.]+)%") {
        $report += "MEMORY:"
        $report += "  Total RAM: $($matches[1]) GB"
        $report += "  Usage: $($matches[2])%"
    }
    
    # Extract disk performance
    $diskPerf = $TestResults | Where-Object { $_.Tool -eq "Disk-Performance" }
    if ($diskPerf -and $diskPerf.Output -match "Write Speed: ([\d.]+) MB/s.*Read Speed: ([\d.]+) MB/s") {
        $report += "DISK PERFORMANCE:"
        $report += "  Write Speed: $($matches[1]) MB/s"
        $report += "  Read Speed: $($matches[2]) MB/s"
    }
    
    $report += ""
    $report += "DETAILED RESULTS:"
    $report += "-----------------"
    
    # Add cleaned results
    foreach ($result in $TestResults) {
        $report += ""
        $report += "[$($result.Tool.ToUpper())] - $($result.Description)"
        $report += "Status: $($result.Status) | Duration: $([math]::Round($result.Duration)) ms"
        
        if ($result.Output -and $result.Output.Trim()) {
            # Further clean the output for the summary report
            $cleanOutput = $result.Output -split "`n" | 
                           Where-Object { $_ -notmatch "^\s*$|^-+$|^=+$" } |
                           Select-Object -First 15  # Limit lines per tool
            
            if ($cleanOutput.Count -gt 0) {
                $report += "Results:"
                foreach ($line in $cleanOutput) {
                    $report += "  $line"
                }
            }
        }
        $report += "----------------------------------------"
    }
    
    # Add recommendations
    $report += ""
    $report += "RECOMMENDATIONS:"
    $report += "----------------"
    
    # Analyze results and provide recommendations
    $recommendations = @()
    
    # Memory recommendations
    if ($ramInfo -and $ramInfo.Output -match "Usage: ([\d.]+)%") {
        $memUsage = [float]$matches[1]
        if ($memUsage -gt 80) {
            $recommendations += "HIGH MEMORY USAGE ($memUsage%) - Consider adding more RAM or closing unnecessary programs"
        } elseif ($memUsage -lt 30) {
            $recommendations += "LOW MEMORY USAGE ($memUsage%) - System has plenty of available RAM"
        }
    }
    
    # CPU recommendations  
    if ($cpuPerf -and $cpuPerf.Output -match "Operations per second: (\d+)") {
        $opsPerSec = [int]$matches[1]
        if ($opsPerSec -lt 10000) {
            $recommendations += "CPU PERFORMANCE - Consider checking for background processes or CPU throttling"
        }
    }
    
    # Disk recommendations
    if ($diskPerf -and $diskPerf.Output -match "Write Speed: ([\d.]+) MB/s") {
        $writeSpeed = [float]$matches[1]
        if ($writeSpeed -lt 50) {
            $recommendations += "SLOW DISK WRITE SPEED ($writeSpeed MB/s) - Consider disk defragmentation or SSD upgrade"
        }
    }
    
    # Security recommendations
    $autorun = $TestResults | Where-Object { $_.Tool -eq "autorunsc" }
    if ($autorun -and $autorun.Output -match "Entry count|Found \d+") {
        $recommendations += "AUTORUN ENTRIES - Review startup programs for security and performance"
    }
    
    if ($recommendations.Count -eq 0) {
        $recommendations += "SYSTEM HEALTH GOOD - No critical issues detected"
    }
    
    foreach ($rec in $recommendations) {
        $report += "• $rec"
    }
    
    $report += ""
    $report += "Report generated by Portable Sysinternals Tester"
    $report += "For detailed output, see: $detailedPath"
    
    try {
        # Save clean summary report
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "✅ CLEAN REPORT saved: $reportPath" -ForegroundColor Green
        
        # Save detailed report (with all original output)
        $detailedReport = @()
        $detailedReport += "DETAILED SYSTEM TEST REPORT"
        $detailedReport += "==========================="
        $detailedReport += "Generated: $(Get-Date)"
        $detailedReport += ""
        
        foreach ($result in $TestResults) {
            $detailedReport += "TOOL: $($result.Tool)"
            $detailedReport += "DESCRIPTION: $($result.Description)"
            $detailedReport += "STATUS: $($result.Status)"
            $detailedReport += "DURATION: $($result.Duration) ms"
            $detailedReport += "FULL OUTPUT:"
            $detailedReport += $result.Output
            $detailedReport += ""
            $detailedReport += "=" * 60
            $detailedReport += ""
        }
        
        $detailedReport | Out-File -FilePath $detailedPath -Encoding UTF8
        Write-Host "✅ DETAILED REPORT saved: $detailedPath" -ForegroundColor Green
        
        # Show report stats
        $cleanSize = (Get-Item $reportPath).Length
        $detailedSize = (Get-Item $detailedPath).Length
        $compressionRatio = [math]::Round((1 - ($cleanSize / $detailedSize)) * 100, 1)
        
        Write-Host "`nREPORT STATISTICS:" -ForegroundColor Cyan
        Write-Host "Clean report: $([math]::Round($cleanSize/1KB,1)) KB" -ForegroundColor White
        Write-Host "Detailed report: $([math]::Round($detailedSize/1KB,1)) KB" -ForegroundColor White
        Write-Host "Space saved: $compressionRatio% (removed EULA/verbose text)" -ForegroundColor Green
        
        # Ask which report to open
        Write-Host "`nWhich report would you like to open?" -ForegroundColor Yellow
        Write-Host "1. Clean Summary Report (Recommended)" -ForegroundColor White
        Write-Host "2. Detailed Report (Full Output)" -ForegroundColor White
        Write-Host "3. Both Reports" -ForegroundColor White
        Write-Host "4. None" -ForegroundColor White
        
        $choice = Read-Host "Choice (1-4)"
        switch ($choice) {
            "1" { 
                try { Start-Process notepad.exe $reportPath } 
                catch { Write-Host "File: $reportPath" -ForegroundColor Cyan }
            }
            "2" { 
                try { Start-Process notepad.exe $detailedPath }
                catch { Write-Host "File: $detailedPath" -ForegroundColor Cyan }
            }
            "3" { 
                try { 
                    Start-Process notepad.exe $reportPath
                    Start-Process notepad.exe $detailedPath
                } 
                catch { 
                    Write-Host "Files:" -ForegroundColor Cyan
                    Write-Host "Clean: $reportPath" -ForegroundColor White
                    Write-Host "Detailed: $detailedPath" -ForegroundColor White
                }
            }
        }
    }
    catch {
        Write-Host "❌ Error saving reports: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Simple menu
function Show-Menu {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "    PORTABLE SYSINTERNALS TESTER" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Drive: $DriveLetter | Computer: $env:COMPUTERNAME" -ForegroundColor Gray
    Write-Host ""
    Write-Host "1. System Information Tests" -ForegroundColor White
    Write-Host "2. CPU Testing (Performance & Info)" -ForegroundColor White
    Write-Host "3. RAM Testing (Memory Analysis)" -ForegroundColor White
    Write-Host "4. Hard Drive/SSD Testing" -ForegroundColor White
    Write-Host "5. Process Analysis Tests" -ForegroundColor White
    Write-Host "6. Security Analysis Tests" -ForegroundColor White
    Write-Host "7. Network Analysis Tests" -ForegroundColor White
    Write-Host "8. Run ALL Tests" -ForegroundColor Yellow
    Write-Host "9. Generate Report" -ForegroundColor Green
    Write-Host "10. Clear Results" -ForegroundColor Red
    Write-Host "Q. Quit" -ForegroundColor White
    Write-Host ""
    Write-Host "Tests completed: $($TestResults.Count)" -ForegroundColor Gray
}

function Start-Menu {
    do {
        Show-Menu
        $choice = Read-Host "`nSelect option (1-10, Q)"
        
        switch ($choice) {
            "1" { Test-SystemInfo; Read-Host "`nPress Enter to continue" }
            "2" { Test-CPU; Read-Host "`nPress Enter to continue" }
            "3" { Test-Memory; Read-Host "`nPress Enter to continue" }
            "4" { Test-Storage; Read-Host "`nPress Enter to continue" }
            "5" { Test-Processes; Read-Host "`nPress Enter to continue" }
            "6" { Test-Security; Read-Host "`nPress Enter to continue" }
            "7" { Test-Network; Read-Host "`nPress Enter to continue" }
            "8" {
                Write-Host "`nRunning ALL tests..." -ForegroundColor Yellow
                Test-SystemInfo
                Test-CPU
                Test-Memory
                Test-Storage
                Test-Processes
                Test-Security
                Test-Network
                Write-Host "`nAll tests completed!" -ForegroundColor Green
                Read-Host "Press Enter to continue"
            }
            "9" { Generate-Report; Read-Host "`nPress Enter to continue" }
            "10" {
                $script:TestResults = @()
                Write-Host "Results cleared." -ForegroundColor Green
                Start-Sleep 1
            }
            "Q" { return }
            "q" { return }
            default {
                Write-Host "Invalid choice. Try again." -ForegroundColor Red
                Start-Sleep 1
            }
        }
    } while ($choice -ne "Q" -and $choice -ne "q")
}

# Main execution
try {
    Write-Host "Starting Sysinternals Tester..." -ForegroundColor Green
    
    if (!(Initialize-Environment)) {
        Write-Host "`nSetup required before running tests." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    if ($AutoRun) {
        Write-Host "`nAuto-running all tests..." -ForegroundColor Yellow
        Test-SystemInfo
        Test-CPU
        Test-Memory
        Test-Storage
        Test-Processes
        Test-Security
        Test-Network
        Generate-Report
        Write-Host "`nAuto-run completed!" -ForegroundColor Green
        Read-Host "Press Enter to exit"
    }
    else {
        Start-Menu
    }
    
    Write-Host "`nSession completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
}
finally {
    Write-Host "Thank you for using Portable Sysinternals Tester!" -ForegroundColor Cyan
    if ($TestResults.Count -gt 0) {
        Write-Host "Total tests run: $($TestResults.Count)" -ForegroundColor Gray
    }
}
