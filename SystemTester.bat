@echo off
setlocal enableextensions enabledelayedexpansion

:: =====================================================
:: Portable Sysinternals System Tester Launcher
:: Created by Pacific Northwest Computers - 2025
:: Production Ready Version - v2.2
:: =====================================================

:: Constants
set "MIN_ZIP_SIZE=10000000"
set "DOWNLOAD_TIMEOUT_SEC=120"
set "SCRIPT_VERSION=2.2"

:: =====================================================
:: Reliable admin detection and elevation
:: =====================================================
set "_ELEV_FLAG=%~1"

:: Use net session for reliable admin check
net session >nul 2>&1
if %errorlevel% == 0 goto :ADMIN_CONFIRMED

:: Not admin - check if this is retry after elevation attempt
if /i "%_ELEV_FLAG%"=="/elevated" (
    echo.
    echo [ERROR] Elevation failed or was cancelled.
    echo         Right-click and choose "Run as administrator"
    echo.
    pause
    exit /b 1
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

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -ArgumentList '/elevated' -Verb RunAs"

if errorlevel 1 (
    echo [ERROR] Failed to elevate. Run manually as administrator.
    pause
)
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

:: Locate PowerShell script (supports legacy and _FIXED names)
set "SCRIPT_PS1="
set "SCRIPT_PS1_NAME="
if exist "%SCRIPT_DIR%\SystemTester_FIXED.ps1" (
    set "SCRIPT_PS1=%SCRIPT_DIR%\SystemTester_FIXED.ps1"
    set "SCRIPT_PS1_NAME=SystemTester_FIXED.ps1"
) else if exist "%SCRIPT_DIR%\SystemTester.ps1" (
    set "SCRIPT_PS1=%SCRIPT_DIR%\SystemTester.ps1"
    set "SCRIPT_PS1_NAME=SystemTester.ps1"
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

:: Verify PowerShell script exists
if "%SCRIPT_PS1%"=="" (
    echo [ERROR] PowerShell script not found in: %SCRIPT_DIR%
    echo.
    echo Expected one of the following files:
    echo   - SystemTester_FIXED.ps1
    echo   - SystemTester.ps1
    echo.
    echo If you renamed the script, restore one of the supported names.
    echo.
    pause
    exit /b 1
)

echo Using PowerShell script: %SCRIPT_PS1_NAME%
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%"
echo.
if errorlevel 1 (
    echo [ERROR] Script failed (code: %errorlevel%)
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -AutoRun
echo.
if errorlevel 1 (
    echo [ERROR] Tests failed (code: %errorlevel%)
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
powershell -NoProfile -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'SUCCESS' -ForegroundColor Green"
echo.
pause
goto MENU

:VERIFY
echo.
echo ========================================================
echo       TOOL INTEGRITY VERIFICATION
echo ========================================================
echo.
echo This will check digital signatures and file sizes
echo of all Sysinternals tools in your installation.
echo.
pause
echo.
:: Call the PowerShell function for tool verification
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { . '%SCRIPT_PS1%'; Test-ToolVerification; exit 0 } catch { Write-Error $_; exit 1 }"
if errorlevel 1 (
    echo.
    echo [ERROR] Verification encountered an issue. Review output above.
) else (
    echo.
    echo Verification complete.
)
echo.
pause
goto MENU

:DOWNLOAD
echo.
echo ========================================================
echo      DOWNLOAD/UPDATE SYSINTERNALS SUITE
echo ========================================================
echo.
set "SYSINT_DIR=%SCRIPT_DIR%\Sysinternals"
set "ZIP_FILE=%SCRIPT_DIR%\SysinternalsSuite.zip"
set "DOWNLOAD_URL=https://download.sysinternals.com/files/SysinternalsSuite.zip"

echo This will download ~35MB from Microsoft.
echo Target: %SYSINT_DIR%
echo.
set /p "confirm=Proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto MENU

echo.
echo Downloading...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%ZIP_FILE%' -TimeoutSec %DOWNLOAD_TIMEOUT_SEC%; Write-Host 'Download complete' -ForegroundColor Green } catch { Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"

if errorlevel 1 (
    echo.
    echo Download failed. Check internet connection.
    if exist "%ZIP_FILE%" del "%ZIP_FILE%" 2>nul
    pause
    goto MENU
)

if not exist "%ZIP_FILE%" (
    echo [ERROR] Download failed - file not created
    pause
    goto MENU
)

for %%A in ("%ZIP_FILE%") do set "FILE_SIZE=%%~zA"
if %FILE_SIZE% LSS %MIN_ZIP_SIZE% (
    echo [ERROR] File too small (%FILE_SIZE% bytes^)
    del "%ZIP_FILE%" 2>nul
    pause
    goto MENU
)

echo File downloaded: %FILE_SIZE% bytes
echo.
echo Extracting...
if not exist "%SYSINT_DIR%" mkdir "%SYSINT_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%SYSINT_DIR%' -Force; Write-Host 'Extracted successfully' -ForegroundColor Green"

if errorlevel 1 (
    echo [ERROR] Extraction failed. Remove any partial files and retry.
    if exist "%ZIP_FILE%" del "%ZIP_FILE%" 2>nul
    pause
    goto MENU
)

del "%ZIP_FILE%" 2>nul
echo.
set "TOOL_COUNT=0"
for %%F in ("%SYSINT_DIR%\*.exe") do set /a TOOL_COUNT+=1
echo [SUCCESS] %TOOL_COUNT% tools installed in %SYSINT_DIR%
echo.
echo TIP: Use Menu Option 4 to verify tool integrity
echo.
pause
goto MENU

:GPU_TOOLS
cls
echo ========================================================
echo          GPU TESTING TOOLS MANAGER
echo ========================================================
echo.
set "GPU_TOOLS_DIR=%SCRIPT_DIR%\Tools"
set "GPUZ_PATH=%GPU_TOOLS_DIR%\GPU-Z.exe"
set "GPUZ_URL=https://www.techpowerup.com/gpuz/"
set "GPUZ_SIZE="

echo GPU Tools Directory: %GPU_TOOLS_DIR%
echo.
echo --------------------------------------------------------
echo AVAILABLE GPU TESTING TOOLS:
echo --------------------------------------------------------
echo.
echo 1. GPU-Z (TechPowerUp) - Detailed GPU monitoring
echo 2. Check NVIDIA Drivers/Tools
echo 3. Check AMD Drivers/Tools  
echo 4. Download Recommendations
echo 5. Return to Main Menu
echo.
echo --------------------------------------------------------
echo INSTALLED TOOLS:
echo --------------------------------------------------------
if exist "%GPUZ_PATH%" (
    for %%A in ("%GPUZ_PATH%") do set "GPUZ_SIZE=%%~zA"
    if not defined GPUZ_SIZE set "GPUZ_SIZE=0"
    if !GPUZ_SIZE! LSS 500000 (
        echo [!] GPU-Z.exe - File appears incomplete (!GPUZ_SIZE! bytes)
    ) else (
        echo [OK] GPU-Z.exe - Installed (!GPUZ_SIZE! bytes)
    )
) else (
    echo [ ] GPU-Z.exe - Not installed
)

if exist "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" (
    echo [OK] NVIDIA System Management Interface
) else (
    echo [ ] NVIDIA-SMI - Not installed ^(NVIDIA GPU drivers^)
)

:: Check for AMD tools
set "AMD_COUNT="
for /f %%A in ('powershell -NoProfile -Command "(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object { Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue } | Where-Object { $_.DriverDesc -match 'AMD|Radeon' }).Count" 2^>nul') do set "AMD_COUNT=%%A"
if not defined AMD_COUNT set "AMD_COUNT=0"
if not "!AMD_COUNT!"=="0" (
    echo [OK] AMD GPU Drivers - Detected (!AMD_COUNT! device^(s^))
) else (
    echo [ ] AMD GPU Drivers - Not detected
)

echo.
set /p "gpu_choice=Choose an option (1-5): "

if "%gpu_choice%"=="1" goto GPU_TOOLS_GPUZ
if "%gpu_choice%"=="2" goto GPU_TOOLS_NVIDIA
if "%gpu_choice%"=="3" goto GPU_TOOLS_AMD
if "%gpu_choice%"=="4" goto GPU_TOOLS_RECOMMEND
if "%gpu_choice%"=="5" goto MENU

echo Invalid choice.
timeout /t 1 >nul
goto GPU_TOOLS

:GPU_TOOLS_GPUZ
cls
echo ========================================================
echo              GPU-Z INSTALLATION
echo ========================================================
echo.

if exist "%GPUZ_PATH%" (
    echo GPU-Z is already installed at:
    echo %GPUZ_PATH%
    echo.
    set "GPUZ_SIZE="
    for %%A in ("%GPUZ_PATH%") do set "GPUZ_SIZE=%%~zA"
    if not defined GPUZ_SIZE set "GPUZ_SIZE=0"
    echo Size: !GPUZ_SIZE! bytes
    if !GPUZ_SIZE! LSS 500000 (
        echo WARNING: File size is unusually small. Re-download recommended.
        echo.
    )
    echo.
    set /p "run_gpuz=Run GPU-Z now? (Y/N): "
    if /i "!run_gpuz!"=="Y" (
        echo.
        echo Launching GPU-Z...
        start "" "%GPUZ_PATH%"
        timeout /t 2 >nul
    )
    goto GPU_TOOLS
)

echo GPU-Z is FREE software from TechPowerUp.
echo.
echo DOWNLOAD INSTRUCTIONS:
echo ----------------------
echo 1. Visit: %GPUZ_URL%
echo 2. Click "Download" button
echo 3. Save the file
echo 4. IMPORTANT: Save it as: %GPUZ_PATH%
echo.
echo Creating Tools directory...
if not exist "%GPU_TOOLS_DIR%" (
    mkdir "%GPU_TOOLS_DIR%" 2>nul
    if errorlevel 1 (
        echo [ERROR] Cannot create directory: %GPU_TOOLS_DIR%
        pause
        goto GPU_TOOLS
    )
    echo [OK] Directory created
)

echo.
echo Opening download page in browser...
start "" "%GPUZ_URL%"
echo.
echo ========================================================
echo MANUAL INSTALLATION STEPS:
echo ========================================================
echo.
echo 1. Download GPU-Z from the webpage that just opened
echo 2. Save it to: %GPU_TOOLS_DIR%
echo 3. Rename it to: GPU-Z.exe
echo.
echo Full path should be: %GPUZ_PATH%
echo.
echo NOTE: TechPowerUp doesn't provide direct download links,
echo       so manual download is required.
echo.
pause
goto GPU_TOOLS

:GPU_TOOLS_NVIDIA
cls
echo ========================================================
echo           NVIDIA TOOLS VERIFICATION
echo ========================================================
echo.

set "NVIDIA_SMI=C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
set "NVIDIA_DRIVERS=C:\Program Files\NVIDIA Corporation"

if exist "%NVIDIA_SMI%" (
    echo [OK] NVIDIA System Management Interface found
    echo.
    echo Running nvidia-smi...
    echo ========================================================
    "%NVIDIA_SMI%" --query-gpu=name,driver_version,memory.total --format=csv
    echo ========================================================
    echo.
    echo Full nvidia-smi output:
    "%NVIDIA_SMI%"
) else (
    echo [!] NVIDIA-SMI not found
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
echo NEW IN v2.2:
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
echo 1. EXECUTION POLICY ERRORS
echo    Solution: Use Menu Option 3
echo.
echo 2. SYSINTERNALS TOOLS NOT FOUND
echo    Solution: Use Menu Option 5 to download
echo.
echo 3. TOOLS MAY BE CORRUPTED
echo    Solution: Use Menu Option 4 to verify integrity
echo              Then Option 5 to re-download if needed
echo.
echo 4. DOWNLOAD FAILS
echo    Causes: Firewall, proxy, no internet
echo    Solution: Manual download from:
echo    https://download.sysinternals.com/files/SysinternalsSuite.zip
echo    Extract to: %SCRIPT_DIR%\Sysinternals\
echo.
echo 5. MEMORY SHOWS 100%% (but Task Manager shows less)
echo    This was a bug in v2.08 - FIXED in v2.2
echo.
echo 6. TESTS TAKE TOO LONG
echo    Expected durations:
echo    - CPU Test: 10 seconds
echo    - Energy Report: 15 seconds
echo    - Windows Update: 30-90 seconds
echo    - DISM/SFC: 5-15 minutes each
echo.
echo 7. REPORTS NOT GENERATED
echo    - Check write permissions
echo    - Ensure tests completed
echo    - Look for SystemTest_Clean_*.txt
echo.
echo 8. PATH TOO LONG
echo    Current: %PATH_LENGTH% characters
echo    Limit: 260 characters
echo    Solution: Move to C:\SysTest\
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
timeout /t 2 >nul
exit /b 0
