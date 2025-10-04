# Simple Portable Sysinternals System Tester
# Consolidated version with additional hardware/OS diagnostics
# Created by Pacific Northwest Computers - 2025
# Fully Audited and Enhanced Version - v2.1 (EXECUTION FLOW FIX)

param(
    [string]$OutputPath = "",
    [switch]$AutoRun
)

# Constants
$script:DXDIAG_TIMEOUT_SEC = 45
$script:ENERGY_REPORT_DURATION = 15
$script:UPDATE_SEARCH_TIMEOUT_SEC = 90
$script:CPU_STRESS_DURATION_SEC = 10
$script:DOWNLOAD_URL = "https://download.sysinternals.com/files/SysinternalsSuite.zip"

# Global variables
$ScriptRoot       = Split-Path -Parent $MyInvocation.MyCommand.Path
$DriveRoot        = Split-Path -Qualifier $ScriptRoot
$DriveLetter      = $DriveRoot.TrimEnd('\')
$SysinternalsPath = Join-Path $ScriptRoot "Sysinternals"
$script:TestResults = @()
$script:IsAdmin = $false
$script:LaunchedViaBatch = $false
# Note: $script:ExternalCall will be set by the Batch file before dot-sourcing

Write-Host "-------------------------------------" -ForegroundColor Green
Write-Host "  PORTABLE SYSINTERNALS TESTER v2.1" -ForegroundColor Green
Write-Host "-------------------------------------" -ForegroundColor Green
Write-Host "Running from: $DriveLetter" -ForegroundColor Cyan

# Check for administrator privileges
function Test-AdminPrivileges {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $script:IsAdmin = $isAdmin
        return $isAdmin
    } catch {
        return $false
    }
}

# Test for launcher awareness (for logging purposes)
function Test-Launcher {
    try {
        $parentProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$((Get-Process -Id $PID).Parent.Id)" -ErrorAction Stop
        if ($parentProcess.Name -eq "cmd.exe") {
            $script:LaunchedViaBatch = $true
        }
    } catch {}
}

# Tool integrity verification (size and signature check)
function Test-ToolIntegrity {
    param([string]$ToolName)
    $toolPath = Join-Path $SysinternalsPath "$ToolName.exe"
    if (!(Test-Path $toolPath)) { return "MISSING" }

    $fileInfo = Get-Item $toolPath
    if ($fileInfo.Length -lt 50KB) { return "BAD_SIZE" }

    try {
        $signature = Get-AuthenticodeSignature $toolPath
        if ($signature.Status -eq "Valid" -and $signature.SignerCertificate.Subject -match "Microsoft Corporation") {
            return "VALID_MS"
        } elseif ($signature.Status -eq "Valid") {
            return "VALID_OTHER"
        } else {
            return "BAD_SIGNATURE"
        }
    } catch {
        return "CHECK_FAILED"
    }
}

# ----------------------------------------------------------------------
# NEW: Download Logic (To be called by Batch Option 6)
# ----------------------------------------------------------------------
function Download-SysinternalsSuite {
    Write-Host "`n Starting Sysinternals Suite Download/Update " -ForegroundColor Yellow
    
    $zipFile = Join-Path $ScriptRoot "SysinternalsSuite.zip"
    
    # 1. Create directory if needed
    if (-not (Test-Path $SysinternalsPath)) {
        Write-Host "Creating Sysinternals directory: $SysinternalsPath" -ForegroundColor Cyan
        New-Item -Path $SysinternalsPath -ItemType Directory -ErrorAction Stop | Out-Null
    }

    # 2. Download the file
    Write-Host "Downloading from: $script:DOWNLOAD_URL (Timeout: 120 s)" -ForegroundColor White
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Invoke-WebRequest -Uri $script:DOWNLOAD_URL -OutFile $zipFile -TimeoutSec 120 -ErrorAction Stop
        Write-Host "Download successful. Size: $([math]::Round((Get-Item $zipFile).Length / 1MB, 2)) MB" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Download failed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $zipFile) { Remove-Item $zipFile -ErrorAction SilentlyContinue }
        return 1
    }

    # 3. Extract the file
    Write-Host "Extracting files to: $SysinternalsPath (Overwriting existing files)" -ForegroundColor Cyan
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $SysinternalsPath, $true)
        Remove-Item $zipFile -ErrorAction SilentlyContinue
        Write-Host "Extraction and cleanup complete." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $zipFile) { Remove-Item $zipFile -ErrorAction SilentlyContinue }
        return 1
    }
    
    Write-Host "`nSUCCESS: Sysinternals Suite is ready." -ForegroundColor Green
    return 0
}

# Initialize environment
function Initialize-Environment {
    Write-Host "Initializing..." -ForegroundColor Yellow

    Test-AdminPrivileges | Out-Null
    Test-Launcher | Out-Null

    # Check for tools folder
    if (!(Test-Path $SysinternalsPath)) {
        Write-Host "ERROR: Sysinternals folder not found!" -ForegroundColor Red
        Write-Host "Expected location: $SysinternalsPath" -ForegroundColor Red
        Write-Host "ACTION: Use **Menu Option 6** in the batch launcher to download tools automatically." -ForegroundColor Yellow
        return $false
    }

    # Expanded CLI tools list
    $keyTools = @(
        "psinfo.exe","coreinfo.exe","pslist.exe","testlimit.exe",
        "du.exe","streams.exe","handle.exe","autorunsc.exe",
        "sigcheck.exe","contig.exe","diskext.exe","listdlls.exe","clockres.exe"
    )
    $foundTools   = 0
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
        Write-Host "ACTION: Use **Menu Option 6** in the batch launcher to download tools automatically." -ForegroundColor Yellow
        return $false
    }

    Write-Host "Found $foundTools/$($keyTools.Count) key tools in $SysinternalsPath" -ForegroundColor Green
    if ($missingTools.Count -gt 0) {
        Write-Host "WARNING: Missing tools ($($missingTools.Count) optional tests may be skipped)." -ForegroundColor Yellow
        Write-Host "ACTION: Use **Menu Option 6** in the batch launcher to update/verify your tools." -ForegroundColor DarkYellow
    }
    return $true
}

# ... (Clean-ToolOutput, Run-Tool functions remain unchanged from original logic) ...
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
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Skip common boilerplate
        if ($line -match "Copyright|Sysinternals|www\.microsoft\.com|Mark Russinovich|David Solomon|Bryce Cogswell") { continue }
        if ($line -match "EULA|End User License Agreement|accepts the license agreement") { continue }
        if ($line -match "^-+$|^=+$|^\*+$") { continue }

        # Skip usage/help blocks
        if ($line -match "^Usage:|^usage:|^Options:|^  -|^    -|^\s*-\w+\s+") {
            $skipMode = $true
            continue
        }
        if ($skipMode -and $line -match "^\s*$|^  |^    ") { continue }
        if ($skipMode -and $line -notmatch "^\w|^\d") { continue }
        $skipMode = $false

        switch ($ToolName) {
            "psinfo" {
                if ($line -match "^(System information|Uptime|Kernel version|Product type|Product version|Service pack|Kernel build number|Registered organization|Registered owner|IE version|System root|Processors|Processor speed|Total physical memory|Available physical memory|Computer name|Domain name|Logon server|Hot fix|Install date)") {
                    $cleanedLines += $line
                } elseif ($line -match "\d+\.\d+\s*GB|\d+\s*MB|\d+\s*MHz|\d+\s*KB") {
                    $cleanedLines += $line
                }
            }
            "coreinfo" {
                if ($line -match "^(Intel64|Logical Processors|Logical Cores|Cores per Processor|APIC ID|Processor|CPU|Cache|Feature)") {
                    $cleanedLines += $line
                } elseif ($line -match "^\s*\*|^\s*-|\s+\w+\s*\*|\s+\w+\s*-") {
                    $cleanedLines += $line
                }
            }
            "pslist" {
                if ($line -match "^(Name|Process|Pid)\s+|^\w+\s+\d+\s+") { $cleanedLines += $line }
            }
            "handle" {
                if ($line -match "^(Handle summary|Total handles|Unique handles)") { $cleanedLines += $line }
                elseif ($line -match "^explorer\.exe pid:|^  \w+:" -and $cleanedLines.Count -lt 20) { $cleanedLines += $line }
            }
            "du" {
                if ($line -match "^\s*\d+.*\\.*$|^Files:|^Subdirectories:|^Total Size:") { $cleanedLines += $line }
            }
            "streams" {
                if ($line -match ":\w+:" -or $line -match "^Summary:|files scanned") { $cleanedLines += $line }
            }
            "autorunsc" {
                if ($line -match "^(HKLM|HKCU|Startup|Logon|Services|Winlogon)" -and $line.Length -lt 150) { $cleanedLines += $line }
                elseif ($line -match "^Entry count|^Found \d+") { $cleanedLines += $line }
            }
            "sigcheck" {
                if ($line -match "^[a-zA-Z]:\\.*\.(exe|dll|sys)" -or $line -match "Verified:|Signing date:|Publisher:") { $cleanedLines += $line }
            }
            "testlimit" {
                if ($line -match "^(Test|Limit|Process|Memory|Handles|Threads).*:|allocation|created|failed") { $cleanedLines += $line }
            }
            "clockres" {
                if ($line -match "resolution|timer|Maximum|Minimum|Current") { $cleanedLines += $line }
            }
            "contig" {
                if ($line -match "^(Summary|Files|Fragmented|Percent)") { $cleanedLines += $line }
            }
            default {
                if ($line -match "^\w+:|^\d+|\s+\d+\s+" -and $line.Length -lt 200) { $cleanedLines += $line }
            }
        }
    }

    $result = $cleanedLines | Where-Object { $_ -ne "" } | Select-Object -First 50
    if ($result.Count -eq 0) { return "Tool completed - no detailed output captured" }
    return ($result -join "`n")
}

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
        if ($ToolName -in @("psinfo","pslist","handle","autorunsc","sigcheck","testlimit","contig")) {
            $Args = "-accepteula $Args"
        }
        
        # Split arguments properly, handling empty strings
        $argArray = if ($Args.Trim()) { $Args.Split(' ') | Where-Object { $_ } } else { @() }
        $rawResult = & $toolPath $argArray 2>&1
        $duration  = ((Get-Date) - $startTime).TotalMilliseconds
        $cleanOutput = Clean-ToolOutput -ToolName $ToolName -RawOutput ($rawResult | Out-String)

        $script:TestResults += @{
            Tool=$ToolName; Description=$Description; Status="SUCCESS"
            Output=$cleanOutput; Duration=$duration
        }

        $previewLines = ($cleanOutput -split "`n") | Select-Object -First 3
        if ($previewLines.Count -gt 0) {
            Write-Host "Preview: $($previewLines[0])" -ForegroundColor DarkGray
        }
        Write-Host "OK: $ToolName completed in $([math]::Round($duration))ms (output cleaned)" -ForegroundColor Green
    }
    catch {
        $script:TestResults += @{
            Tool=$ToolName; Description=$Description; Status="FAILED"
            Output=$_.Exception.Message; Duration=0
        }
        Write-Host "ERROR: $ToolName failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ----------------------------
# NEW: Tool Verification (For Menu Option 5)
# ----------------------------
function Test-ToolVerification {
    Write-Host "`n Verifying Key Sysinternals Tool Integrity " -ForegroundColor Green
    Write-Host "This performs file size and digital signature checks." -ForegroundColor Yellow

    $keyTools = @(
        "psinfo","coreinfo","pslist","handle","du","streams",
        "autorunsc","sigcheck","testlimit","contig","clockres"
    )
    $results = @{}

    foreach ($tool in $keyTools) {
        Write-Host "Checking $tool..." -ForegroundColor Cyan
        $status = Test-ToolIntegrity -ToolName $tool
        $results[$tool] = $status
    }

    $missingCount = $results.GetEnumerator() | Where-Object { $_.Value -eq "MISSING" } | Measure-Object | Select-Object -ExpandProperty Count
    $badSigCount = $results.GetEnumerator() | Where-Object { $_.Value -match "BAD_SIZE|BAD_SIGNATURE|CHECK_FAILED" } | Measure-Object | Select-Object -ExpandProperty Count
    $validMsCount = $results.GetEnumerator() | Where-Object { $_.Value -eq "VALID_MS" } | Measure-Object | Select-Object -ExpandProperty Count

    $summaryOutput = @(
        "--- Verification Summary ---",
        "Total Tools Checked: $($keyTools.Count)",
        "Valid Signature (Microsoft): $validMsCount",
        "Missing Tools: $missingCount",
        "Integrity/Signature Failed: $badSigCount",
        "----------------------------"
    )

    $output = ($summaryOutput + "") + ($results.GetEnumerator() | ForEach-Object { 
        $status = switch ($_.Value) {
            "VALID_MS" { "SUCCESS: Valid Microsoft Signature" }
            "VALID_OTHER" { "WARNING: Valid Non-Microsoft Signature" }
            "MISSING" { "ERROR: Tool Missing (Use Option 6)" }
            "BAD_SIZE" { "ERROR: File Size Too Small" }
            "BAD_SIGNATURE" { "ERROR: Invalid Digital Signature" }
            default { "ERROR: Check Failed" }
        }
        "  $($_.Key): $status"
    })

    # Display status
    Write-Host "`n"
    $summaryOutput | ForEach-Object { Write-Host $_ -ForegroundColor White }
    if ($missingCount -gt 0 -or $badSigCount -gt 0) {
        Write-Host "ACTION: Use **Option 6** in the batch launcher to download/update tools." -ForegroundColor Red
        return 1
    } else {
        Write-Host "SUCCESS: All key tools verified!" -ForegroundColor Green
        return 0
    }
}

# ----------------------------------------------------------------------
# NEW: Fix Execution Policy (for Batch Option 4)
# ----------------------------------------------------------------------
function Fix-ExecutionPolicy {
    Write-Host "`n Fixing PowerShell Execution Policy " -ForegroundColor Yellow
    Write-Host "Current execution policy will be changed to RemoteSigned for CurrentUser scope." -ForegroundColor White
    
    Write-Host "`nCurrent Execution Policy:" -ForegroundColor Cyan
    Get-ExecutionPolicy -List | Format-Table -AutoSize
    
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        Write-Host "`nSUCCESS: Execution policy updated successfully!" -ForegroundColor Green
        Write-Host "`nNew Execution Policy:" -ForegroundColor Cyan
        Get-ExecutionPolicy -List | Format-Table -AutoSize
        return 0
    } catch {
        Write-Host "`nERROR: Failed to update policy - $($_.Exception.Message)" -ForegroundColor Red
        return 1
    }
}

# (Test-* functions, Generate-Report, Show-Menu, Start-Menu functions remain unchanged)

# Main execution
# CRITICAL FIX: This block is now wrapped in a conditional that prevents it from running 
# if the Batch file sets $script:ExternalCall = $true before dot-sourcing.
if (-not $script:ExternalCall) {
    try {
        Write-Host "Starting Sysinternals Tester v2.1..." -ForegroundColor Green

        if (!(Initialize-Environment)) {
            Write-Host "`nSetup required before running tests." -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit 1
        }

        if ($AutoRun) {
            Write-Host "`nAuto-running all tests..." -ForegroundColor Yellow
            Test-SystemInfo; Test-CPU; Test-Memory; Test-Storage; Test-Processes; Test-Security; Test-Network
            Test-OSHealth; Test-StorageSMART; Test-Trim; Test-NIC; Test-GPU; Test-Power; Test-HardwareEvents; Test-WindowsUpdate
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
        Write-Host "`nCRITICAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
    finally {
        Write-Host "Thank you for using Portable Sysinternals Tester v2.1!" -ForegroundColor Cyan
        if ($script:TestResults.Count -gt 0) {
            Write-Host "Total tests run: $($script:TestResults.Count)" -ForegroundColor Gray
        }
    }
}
