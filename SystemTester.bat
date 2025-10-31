@echo off
setlocal enableextensions enabledelayedexpansion

:: =====================================================
:: Portable Sysinternals System Tester Launcher
:: Created by Pacific Northwest Computers - 2025
:: Production Ready Version - v2.2.1 (FIXED)
:: =====================================================

:: Constants
set "MIN_ZIP_SIZE=10000000"
set "DOWNLOAD_TIMEOUT_SEC=120"
set "SCRIPT_VERSION=2.2.1"
if not defined ST_DEBUG set "ST_DEBUG=0"
set "LAUNCH_LOG=%TEMP%\SystemTester_launcher.log"

:: =====================================================
:: Reliable admin detection and elevation
:: =====================================================
set "_ELEV_FLAG=%~1"
set "_DEBUG_FLAG=%~2"
if /i "%_DEBUG_FLAG%"=="debug" set "ST_DEBUG=1"

:: Primary admin check via PowerShell identity (works without Server service)
set "IS_ADMIN="
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)" 2^>nul`) do set "IS_ADMIN=%%A"
if /i "%IS_ADMIN%"=="True" goto :ADMIN_CONFIRMED

:: Fallback check using FLTMC (requires elevation)
fltmc >nul 2>&1 && goto :ADMIN_CONFIRMED

:: Not admin - check if this is retry after elevation attempt
if /i "%_ELEV_FLAG%"=="/elevated" (
    echo.
    echo [WARNING] Admin status could not be verified after elevation.
    echo           Continuing anyway; some tests may be limited.
    echo.
    goto :ADMIN_CONFIRMED
)

:: Request elevation
echo.
echo ========================================================
echo   Administrative privileges required for full testing
echo ========================================================
echo.
echo Some tests require administrator rights:
echo   - DISM and SFC integrity checks
echo   - Energy/battery report generation
echo   - Hardware SMART data access
echo   - System file verification
echo.
echo Requesting elevation...
echo.

set "_ELEV_ARGS=/elevated"
if "%ST_DEBUG%"=="1" set "_ELEV_ARGS=/elevated debug"
echo [%DATE% %TIME%] Elevating: "%~f0" %_ELEV_ARGS% >> "%LAUNCH_LOG%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '%_ELEV_ARGS%' -Verb RunAs -WorkingDirectory '%CD%' -WindowStyle Normal"

if errorlevel 1 (
    echo [ERROR] Failed to elevate. Run manually as administrator.
    pause
)
echo.
echo Press any key to close this window. The elevated window should now be open.
pause >nul
exit /b

:ADMIN_CONFIRMED
title Portable Sysinternals System Tester v%SCRIPT_VERSION%
color 0B

:: Change to script directory
cd /d "%~dp0" 2>nul
if errorlevel 1 (
    echo [ERROR] Cannot access directory: %~dp0
    pause
    exit /b 1
)

echo ========================================================
echo   PORTABLE SYSINTERNALS SYSTEM TESTER v%SCRIPT_VERSION%
echo ========================================================
echo.

:: Set paths
set "SCRIPT_DIR=%cd%"
set "DRIVE_LETTER=%~d0"

:: Locate PowerShell script (FIXED: Removed quotes from variable)
set SCRIPT_PS1=%SCRIPT_DIR%\SystemTester.ps1
set "SCRIPT_PS1_NAME=SystemTester.ps1"

:: Verify PowerShell script exists BEFORE checking path length
if not exist "%SCRIPT_PS1%" (
    echo [ERROR] PowerShell script not found!
    echo.
    echo Expected file: %SCRIPT_PS1%
    echo.
    echo Make sure SystemTester.ps1 is in the same directory as this batch file.
    echo.
    pause
    exit /b 1
)

:: Check path length
for /f %%i in ('powershell -NoProfile -Command "('%SCRIPT_DIR%').Length" 2^>nul') do set "PATH_LENGTH=%%i"
if "%PATH_LENGTH%"=="" set "PATH_LENGTH=0"
if %PATH_LENGTH% GTR 200 (
    echo [WARNING] Path is %PATH_LENGTH% chars. Move to shorter path if errors occur.
    timeout /t 2 >nul
)

echo Running from: %DRIVE_LETTER%
echo Script directory: %SCRIPT_DIR%
echo Path length: %PATH_LENGTH% characters
echo.

echo Using PowerShell script: %SCRIPT_PS1_NAME%
if "%ST_DEBUG%"=="1" (
    echo [%DATE% %TIME%] Using PS1: "%SCRIPT_PS1%" >> "%LAUNCH_LOG%"
    echo [DEBUG] Full path: %SCRIPT_PS1%
)
echo.

:: Check PowerShell version
echo Checking PowerShell...
for /f "tokens=*" %%v in ('powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()" 2^>nul') do set "PS_VERSION=%%v"
if "%PS_VERSION%"=="" (
    echo [ERROR] PowerShell not available or too old.
    echo Requires PowerShell 5.1 or later.
    pause
    exit /b 1
)
echo PowerShell version: %PS_VERSION%
echo.

:: Check for Sysinternals folder
if not exist "%SCRIPT_DIR%\Sysinternals" (
    echo [WARNING] Sysinternals folder not found!
    echo Use Menu Option 5 to download automatically.
    echo.
    timeout /t 2 >nul
)

:MENU
cls
echo ========================================================
echo   PORTABLE SYSINTERNALS SYSTEM TESTER v%SCRIPT_VERSION%
echo ========================================================
echo.
echo Drive: %DRIVE_LETTER% ^| Directory: %SCRIPT_DIR%
echo PowerShell: %PS_VERSION% ^| Admin: YES
echo.
echo --------------------------------------------------------
echo                    MAIN MENU
echo --------------------------------------------------------
echo.
echo 1. Run Interactive Menu (Recommended)
echo 2. Run ALL Tests Automatically
echo 3. Fix PowerShell Execution Policy
echo 4. Verify Tool Integrity (Signatures)
echo 5. Download/Update Sysinternals Suite
echo 6. GPU Testing Tools Manager
echo 7. Help / Troubleshooting
echo 8. Exit
echo.
echo --------------------------------------------------------
set /p "choice=Choose an option (1-8): "

if "%choice%"=="1" goto INTERACTIVE
if "%choice%"=="2" goto AUTORUN
if "%choice%"=="3" goto FIXPOLICY
if "%choice%"=="4" goto VERIFY
if "%choice%"=="5" goto DOWNLOAD
if "%choice%"=="6" goto GPU_TOOLS
if "%choice%"=="7" goto HELP
if "%choice%"=="8" goto EXIT

echo Invalid choice. Try again.
timeout /t 1 >nul
goto MENU

:INTERACTIVE
echo.
echo ========================================================
echo              STARTING INTERACTIVE MODE
echo ========================================================
echo.
pause
set "PS_EXTRA="
if "%ST_DEBUG%"=="1" set "PS_EXTRA=-NoExit"
if "%ST_DEBUG%"=="1" (
    echo [%DATE% %TIME%] Launching PS interactive >> "%LAUNCH_LOG%"
    echo [DEBUG] Command: powershell.exe -NoProfile -ExecutionPolicy Bypass %PS_EXTRA% -File "%SCRIPT_PS1%"
    echo [DEBUG] Working Directory: %CD%
    echo.
)

:: FIXED: Proper quoting with -File parameter
powershell.exe -NoProfile -ExecutionPolicy Bypass %PS_EXTRA% -File "%SCRIPT_PS1%"
set "PS_EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%PS_EXIT_CODE%"=="0" (
    echo [ERROR] Script failed with exit code: %PS_EXIT_CODE%
    echo.
    echo Troubleshooting tips:
    echo 1. Make sure SystemTester.ps1 exists in: %SCRIPT_DIR%
    echo 2. Check if execution policy is blocking scripts (use Option 3)
    echo 3. Try running with debug mode: %~nx0 /elevated debug
    echo.
    if "%ST_DEBUG%"=="1" (
        echo [DEBUG] Failed command was:
        echo powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%"
    )
    pause
) else (
    echo Completed successfully.
    timeout /t 2 >nul
)
goto MENU

:AUTORUN
echo.
echo ========================================================
echo           RUNNING ALL TESTS AUTOMATICALLY
echo ========================================================
echo.
echo This will run 15 test suites and generate reports.
echo May take 10-30 minutes depending on your system.
echo.
pause
echo.
set "PS_EXTRA="
if "%ST_DEBUG%"=="1" set "PS_EXTRA=-NoExit"
if "%ST_DEBUG%"=="1" (
    echo [%DATE% %TIME%] Launching PS autorun >> "%LAUNCH_LOG%"
    echo [DEBUG] Command: powershell.exe -NoProfile -ExecutionPolicy Bypass %PS_EXTRA% -File "%SCRIPT_PS1%" -AutoRun
    echo [DEBUG] Working Directory: %CD%
    echo.
)

:: FIXED: Proper quoting with -File parameter and arguments
powershell.exe -NoProfile -ExecutionPolicy Bypass %PS_EXTRA% -File "%SCRIPT_PS1%" -AutoRun
set "PS_EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%PS_EXIT_CODE%"=="0" (
    echo [ERROR] Tests failed with exit code: %PS_EXIT_CODE%
    echo.
    echo Troubleshooting tips:
    echo 1. Make sure SystemTester.ps1 exists in: %SCRIPT_DIR%
    echo 2. Check if execution policy is blocking scripts (use Option 3)
    echo 3. Try running with debug mode: %~nx0 /elevated debug
    echo.
    if "%ST_DEBUG%"=="1" (
        echo [DEBUG] Failed command was:
        echo powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -AutoRun
    )
    pause
) else (
    echo All tests completed. Check directory for reports.
    timeout /t 3 >nul
)
goto MENU

:FIXPOLICY
echo.
echo ========================================================
echo          FIXING POWERSHELL EXECUTION POLICY
echo ========================================================
echo.
echo Current policy:
powershell -NoProfile -Command "Get-ExecutionPolicy -List | Format-Table -AutoSize"
echo.
echo Setting to RemoteSigned for CurrentUser...
powershell -NoProfile -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"
echo.
echo New policy:
powershell -NoProfile -Command "Get-ExecutionPolicy -List | Format-Table -AutoSize"
echo.
echo Done! Execution policy updated.
echo.
pause
goto MENU

:VERIFY
echo.
echo ========================================================
echo          VERIFYING TOOL INTEGRITY
echo ========================================================
echo.
echo This will check digital signatures of all Sysinternals tools...
echo.
pause

if not exist "%SCRIPT_DIR%\Sysinternals" (
    echo [ERROR] Sysinternals folder not found!
    echo Use Menu Option 5 to download first.
    echo.
    pause
    goto MENU
)

echo Checking tools in: %SCRIPT_DIR%\Sysinternals
echo.

:: Use PowerShell to verify all tools
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$tools = @('Autoruns', 'cpustres', 'Coreinfo', 'DiskView', 'RAMMap', 'Testlimit', 'Whois', 'DiskExt', 'Listdlls', 'ProcDump', 'procexp'); ^
$sysinternalsPath = '%SCRIPT_DIR%\Sysinternals'; ^
$results = @(); ^
foreach ($tool in $tools) { ^
    $toolPath = Join-Path $sysinternalsPath \"$tool.exe\"; ^
    if (Test-Path $toolPath) { ^
        $sig = Get-AuthenticodeSignature $toolPath -ErrorAction SilentlyContinue; ^
        $fileInfo = Get-Item $toolPath; ^
        $status = 'UNKNOWN'; ^
        if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -match 'Microsoft') { ^
            $status = 'VALID (MS)'; ^
        } elseif ($sig.Status -eq 'Valid') { ^
            $status = 'VALID (Other)'; ^
        } elseif ($sig.Status -eq 'NotSigned') { ^
            $status = 'NOT SIGNED'; ^
        } else { ^
            $status = \"BAD: $($sig.Status)\"; ^
        } ^
        $results += [PSCustomObject]@{ ^
            Tool = $tool; ^
            Status = $status; ^
            'Size (KB)' = [math]::Round($fileInfo.Length / 1KB, 1); ^
        }; ^
    } else { ^
        $results += [PSCustomObject]@{ ^
            Tool = $tool; ^
            Status = 'MISSING'; ^
            'Size (KB)' = 0; ^
        }; ^
    } ^
}; ^
$results | Format-Table -AutoSize"

echo.
echo ========================================================
echo Verification complete!
echo.
echo Legend:
echo   VALID (MS)    = Valid Microsoft signature
echo   VALID (Other) = Valid non-Microsoft signature  
echo   NOT SIGNED    = No digital signature
echo   MISSING       = File not found
echo   BAD           = Invalid or corrupted signature
echo.
echo If tools show as MISSING or BAD, use Option 5 to re-download.
echo.
pause
goto MENU

:DOWNLOAD
echo.
echo ========================================================
echo       DOWNLOAD/UPDATE SYSINTERNALS SUITE
echo ========================================================
echo.
echo This will download the complete Sysinternals Suite (~30MB)
echo from Microsoft's official server.
echo.
echo Target directory: %SCRIPT_DIR%\Sysinternals\
echo.
set /p "confirm=Continue? (Y/N): "
if /i not "%confirm%"=="Y" goto MENU

echo.
echo Downloading Sysinternals Suite...
echo This may take 1-3 minutes depending on your connection.
echo.

:: Create Sysinternals directory if it doesn't exist
if not exist "%SCRIPT_DIR%\Sysinternals" mkdir "%SCRIPT_DIR%\Sysinternals"

:: Download using PowerShell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
"$ProgressPreference = 'SilentlyContinue'; ^
$url = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'; ^
$zipFile = '%SCRIPT_DIR%\SysinternalsSuite.zip'; ^
$extractPath = '%SCRIPT_DIR%\Sysinternals'; ^
Write-Host 'Downloading from: $url' -ForegroundColor Cyan; ^
try { ^
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^
    Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing -TimeoutSec %DOWNLOAD_TIMEOUT_SEC%; ^
    $fileSize = (Get-Item $zipFile).Length; ^
    Write-Host \"Downloaded: $([math]::Round($fileSize/1MB,1)) MB\" -ForegroundColor Green; ^
    if ($fileSize -lt %MIN_ZIP_SIZE%) { ^
        Write-Host '[ERROR] Downloaded file is too small. Check internet connection.' -ForegroundColor Red; ^
        exit 1; ^
    } ^
    Write-Host 'Extracting files...' -ForegroundColor Cyan; ^
    Add-Type -Assembly System.IO.Compression.FileSystem; ^
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $extractPath, $true); ^
    Write-Host 'Extraction complete!' -ForegroundColor Green; ^
    Remove-Item $zipFile -Force; ^
    Write-Host 'Cleanup complete!' -ForegroundColor Green; ^
    exit 0; ^
} catch { ^
    Write-Host \"[ERROR] $($_.Exception.Message)\" -ForegroundColor Red; ^
    exit 1; ^
}"

if errorlevel 1 (
    echo.
    echo [ERROR] Download/extraction failed!
    echo.
    echo Possible causes:
    echo 1. No internet connection
    echo 2. Firewall blocking downloads
    echo 3. Proxy server issues
    echo.
    echo Manual download instructions:
    echo 1. Visit: https://download.sysinternals.com/files/SysinternalsSuite.zip
    echo 2. Download the ZIP file
    echo 3. Extract to: %SCRIPT_DIR%\Sysinternals\
    echo.
) else (
    echo.
    echo ========================================================
    echo Download and installation successful!
    echo ========================================================
    echo.
    echo Tools installed in: %SCRIPT_DIR%\Sysinternals\
    echo.
    echo Run Option 4 to verify tool integrity.
    echo.
)
pause
goto MENU

:GPU_TOOLS
cls
echo ========================================================
echo           GPU TESTING TOOLS MANAGER
echo ========================================================
echo.
echo This manager helps you:
echo - Check if vendor-specific tools are installed
echo - Get download links for GPU testing software
echo - Verify GPU driver information
echo.
echo --------------------------------------------------------
echo                    GPU TOOLS MENU
echo --------------------------------------------------------
echo.
echo 1. Check NVIDIA Tools (nvidia-smi)
echo 2. Check AMD Tools
echo 3. Recommended GPU Testing Tools
echo 4. Return to Main Menu
echo.
echo --------------------------------------------------------
set /p "gpu_choice=Choose an option (1-4): "

if "%gpu_choice%"=="1" goto GPU_TOOLS_NVIDIA
if "%gpu_choice%"=="2" goto GPU_TOOLS_AMD
if "%gpu_choice%"=="3" goto GPU_TOOLS_RECOMMEND
if "%gpu_choice%"=="4" goto MENU

echo Invalid choice. Try again.
timeout /t 1 >nul
goto GPU_TOOLS

:GPU_TOOLS_NVIDIA
cls
echo ========================================================
echo             NVIDIA TOOLS VERIFICATION
echo ========================================================
echo.

:: Check for nvidia-smi
where nvidia-smi >nul 2>&1
if errorlevel 1 (
    echo [!] nvidia-smi not found in PATH
    echo.
    echo Checking common NVIDIA installation locations...
    
    set "NVIDIA_SMI_FOUND="
    if exist "C:\Windows\System32\nvidia-smi.exe" (
        set "NVIDIA_SMI_FOUND=C:\Windows\System32\nvidia-smi.exe"
        echo [OK] Found at: C:\Windows\System32\nvidia-smi.exe
    )
    if exist "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" (
        set "NVIDIA_SMI_FOUND=C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
        echo [OK] Found at: C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe
    )
    
    if defined NVIDIA_SMI_FOUND (
        echo.
        echo Running nvidia-smi...
        echo ========================================================
        "!NVIDIA_SMI_FOUND!"
        echo ========================================================
    ) else (
        echo [!] nvidia-smi not found in common locations
    )
) else (
    echo [OK] nvidia-smi found in PATH
    echo.
    echo Running nvidia-smi...
    echo ========================================================
    nvidia-smi
    echo ========================================================
)

if not defined NVIDIA_SMI_FOUND (
    echo.
    echo This tool is included with NVIDIA GPU drivers.
    echo.
    echo If you have an NVIDIA GPU but nvidia-smi is missing:
    echo 1. Update your NVIDIA drivers from:
    echo    https://www.nvidia.com/Download/index.aspx
    echo 2. Or use GeForce Experience ^(for gaming GPUs^)
    echo.
    echo If you don't have an NVIDIA GPU, this is normal.
)

echo.
echo --------------------------------------------------------
echo OTHER NVIDIA TOOLS:
echo --------------------------------------------------------
echo.
echo - NVIDIA Control Panel (included with drivers)
echo - GeForce Experience (for gaming GPUs)
echo - NVIDIA Inspector (advanced overclocking)
echo.
pause
goto GPU_TOOLS

:GPU_TOOLS_AMD
cls
echo ========================================================
echo             AMD TOOLS VERIFICATION
echo ========================================================
echo.

:: Check for AMD GPU
set "AMD_COUNT="
for /f %%A in ('powershell -NoProfile -Command "(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object { Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue } | Where-Object { $_.DriverDesc -match 'AMD|Radeon' }).Count" 2^>nul') do set "AMD_COUNT=%%A"
if not defined AMD_COUNT set "AMD_COUNT=0"

if not "!AMD_COUNT!"=="0" (
    echo [OK] AMD GPU Detected: !AMD_COUNT! device^(s^)
    echo.
    echo AMD Driver Information:
    echo ========================================================
    powershell -NoProfile -Command "Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object { $info = Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue; if ($info.DriverDesc -match 'AMD|Radeon') { '{0}: {1}' -f $_.PSChildName,$info.DriverDesc; if ($info.DriverVersion) { '  Driver Version: {0}' -f $info.DriverVersion }; if ($info.DriverDate) { '  Driver Date: {0}' -f $info.DriverDate }; '' } }"
    echo ========================================================
    echo.
    echo NOTE: AMD doesn't provide a command-line tool like
    echo       nvidia-smi by default.
    echo.
    echo AMD Tools available:
    echo - AMD Radeon Software (included with drivers)
    echo - AMD Cleanup Utility (for driver issues)
    echo.
    echo Update drivers from:
    echo https://www.amd.com/en/support
) else (
    echo [!] AMD GPU not detected
    echo.
    echo If you have an AMD GPU but it's not detected:
    echo 1. Update AMD drivers from: https://www.amd.com/en/support
    echo 2. Use AMD Auto-Detect tool
    echo.
    echo If you don't have an AMD GPU, this is normal.
)

echo.
pause
goto GPU_TOOLS

:GPU_TOOLS_RECOMMEND
cls
echo ========================================================
echo        RECOMMENDED GPU TESTING TOOLS
echo ========================================================
echo.
echo --------------------------------------------------------
echo MONITORING ^& DIAGNOSTICS:
echo --------------------------------------------------------
echo.
echo 1. GPU-Z (TechPowerUp)
echo    - Real-time monitoring
echo    - Sensor logging
echo    - BIOS extraction
echo    URL: https://www.techpowerup.com/gpuz/
echo.
echo 2. HWiNFO64
echo    - Comprehensive system monitoring
echo    - GPU sensors included
echo    URL: https://www.hwinfo.com/
echo.
echo 3. MSI Afterburner
echo    - Overclocking
echo    - Real-time monitoring
echo    - On-screen display
echo    URL: https://www.msi.com/Landing/afterburner
echo.
echo --------------------------------------------------------
echo STRESS TESTING:
echo --------------------------------------------------------
echo.
echo 4. FurMark (Geeks3D)
echo    - GPU stress test
echo    - WARNING: Generates significant heat!
echo    - Use carefully on laptops
echo    URL: https://geeks3d.com/furmark/
echo.
echo 5. Unigine Heaven/Valley/Superposition
echo    - Benchmark ^& stress test
echo    - Beautiful graphics
echo    URL: https://benchmark.unigine.com/
echo.
echo 6. OCCT (GPU Test)
echo    - Error detection
echo    - Stability testing
echo    URL: https://www.ocbase.com/
echo.
echo --------------------------------------------------------
echo BENCHMARKING:
echo --------------------------------------------------------
echo.
echo 7. 3DMark (UL Solutions)
echo    - Industry standard benchmark
echo    - Free basic version available
echo    URL: https://benchmarks.ul.com/3dmark
echo.
echo 8. UserBenchmark
echo    - Quick comparative benchmark
echo    - Free
echo    URL: https://www.userbenchmark.com/
echo.
echo --------------------------------------------------------
echo IMPORTANT WARNINGS:
echo --------------------------------------------------------
echo.
echo - Stress tests generate SIGNIFICANT HEAT
echo - Monitor temperatures during tests
echo - Ensure adequate cooling
echo - Stop if temps exceed 85C (GPU) / 95C (hotspot)
echo - Laptop users: Use caution with stress tests
echo.
echo ========================================================
echo.
pause
goto GPU_TOOLS

:HELP
cls
echo ========================================================
echo         HELP / TROUBLESHOOTING GUIDE v%SCRIPT_VERSION%
echo ========================================================
echo.
echo NEW IN v2.2.1:
echo   - FIXED: PowerShell script launching issues
echo   - FIXED: Better error handling and debug output
echo   - Enhanced path quoting for special characters
echo.
echo PREVIOUS FEATURES (v2.2):
echo   - Tool integrity verification (digital signatures)
echo   - Dual report system (Clean + Detailed)
echo   - Fixed memory usage calculation bug
echo   - Launcher awareness detection
echo   - Enhanced GPU testing with vendor-specific tools
echo   - GPU Tools Manager (Menu Option 6)
echo.
echo --------------------------------------------------------
echo COMMON ISSUES:
echo --------------------------------------------------------
echo.
echo 1. SCRIPT WON'T LAUNCH AFTER ADMIN PROMPT
echo    FIXED in v2.2.1 - Use this updated batch file
echo    Problem was improper path quoting in PowerShell commands
echo.
echo 2. EXECUTION POLICY ERRORS
echo    Solution: Use Menu Option 3
echo.
echo 3. SYSINTERNALS TOOLS NOT FOUND
echo    Solution: Use Menu Option 5 to download
echo.
echo 4. TOOLS MAY BE CORRUPTED
echo    Solution: Use Menu Option 4 to verify integrity
echo              Then Option 5 to re-download if needed
echo.
echo 5. DOWNLOAD FAILS
echo    Causes: Firewall, proxy, no internet
echo    Solution: Manual download from:
echo    https://download.sysinternals.com/files/SysinternalsSuite.zip
echo    Extract to: %SCRIPT_DIR%\Sysinternals\
echo.
echo 6. MEMORY SHOWS 100%% (but Task Manager shows less)
echo    This was a bug in v2.08 - FIXED in v2.2
echo.
echo 7. TESTS TAKE TOO LONG
echo    Expected durations:
echo    - CPU Test: 10 seconds
echo    - Energy Report: 15 seconds
echo    - Windows Update: 30-90 seconds
echo    - DISM/SFC: 5-15 minutes each
echo.
echo 8. REPORTS NOT GENERATED
echo    - Check write permissions
echo    - Ensure tests completed
echo    - Look for SystemTest_Clean_*.txt
echo.
echo 9. PATH TOO LONG
echo    Current: %PATH_LENGTH% characters
echo    Limit: 260 characters
echo    Solution: Move to C:\SysTest\
echo.
echo --------------------------------------------------------
echo DEBUG MODE:
echo --------------------------------------------------------
echo.
echo To enable detailed logging, run:
echo    %~nx0 /elevated debug
echo.
echo This will keep the PowerShell window open and show
echo the exact commands being executed.
echo.
echo --------------------------------------------------------
echo FEATURES:
echo --------------------------------------------------------
echo.
echo REPORT TYPES:
echo   Clean Report - Summary with key findings
echo   Detailed Report - Full output from all tests
echo.
echo TOOL VERIFICATION:
echo   Checks digital signatures of all tools
echo   Validates file sizes
echo   Identifies Microsoft-signed vs others
echo.
echo GPU TESTING:
echo   Enhanced multi-GPU support
echo   NVIDIA-SMI integration
echo   AMD driver detection
echo   GPU-Z download assistant
echo.
echo ADMIN DETECTION:
echo   Auto-elevates on startup
echo   Skips admin-required tests when not elevated
echo   Shows clear warnings about limitations
echo.
echo SUPPORT:
echo   https://docs.microsoft.com/sysinternals
echo.
pause
goto MENU

:EXIT
echo.
echo ========================================================
echo Thank you for using PNW Computers' Portable Sysinternals System Tester!
echo                    Version %SCRIPT_VERSION%
echo ========================================================
echo.
echo Reports saved in: %SCRIPT_DIR%
echo   - SystemTest_Clean_*.txt (summary)
echo   - SystemTest_Detailed_*.txt (full output)
echo   - energy-report.html (if power test ran)
echo.
pause
exit /b 0
