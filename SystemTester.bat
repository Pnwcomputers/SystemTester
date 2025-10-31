@echo off
setlocal enableextensions enabledelayedexpansion

:: =====================================================
:: Portable Sysinternals System Tester Launcher
:: Created by Pacific Northwest Computers - 2025
:: Production Ready Version - v2.2 (FIXED)
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

if %errorlevel% neq 0 (
    echo [ERROR] Failed to elevate. Run manually as administrator.
    pause
)
exit /b

:ADMIN_CONFIRMED
title Portable Sysinternals System Tester v%SCRIPT_VERSION%
color 0B

:: Change to script directory
cd /d "%~dp0" 2>nul
if %errorlevel% neq 0 (
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
set "SCRIPT_PS1=%SCRIPT_DIR%\SystemTester.ps1"

:: Check path length
for /f %%i in ('powershell -NoProfile -Command "[int](Get-Item '%~dp0').FullName.Length" 2^>nul') do set "PATH_LENGTH=%%i"
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
if not exist "%SCRIPT_PS1%" (
    echo [ERROR] PowerShell script not found: %SCRIPT_PS1%
    echo.
    echo Ensure SystemTester.ps1 is in the same folder.
    echo.
    pause
    exit /b 1
)

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

:: FIXED: Check for Sysinternals folder (removed duplicate)
if not exist "%SCRIPT_DIR%\Sysinternals" (
    echo [WARNING] Sysinternals folder not found!
    echo Use Menu Option 5 to download automatically.
    echo.
    timeout /t 2 >nul
) else (
    :: Check for PSPing specifically (for network speed tests)
    if exist "%SCRIPT_DIR%\Sysinternals\psping.exe" (
        echo [INFO] PSPing detected - Full network speed tests available
    ) else (
        echo [INFO] PSPing not found - Basic network tests only
        echo       Download Sysinternals Suite for full network testing
    )
    echo.
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
if %errorlevel% neq 0 (
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
if %errorlevel% neq 0 (
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
echo ABOUT EXECUTION POLICY:
echo RemoteSigned allows local scripts to run without signing,
echo but requires downloaded scripts to be digitally signed.
echo This is a good balance of security and functionality.
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
powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%SCRIPT_PS1%'; Test-ToolVerification"
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
echo NOTE: Includes PSPing for advanced network speed testing
echo.
set /p "confirm=Proceed? (Y/N): "
if /i not "%confirm%"=="Y" goto MENU

echo.
echo Downloading...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DOWNLOAD_URL%' -OutFile '%ZIP_FILE%' -TimeoutSec %DOWNLOAD_TIMEOUT_SEC%; Write-Host 'Download complete' -ForegroundColor Green } catch { Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"

if %errorlevel% neq 0 (
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

del "%ZIP_FILE%" 2>nul
echo.
set "TOOL_COUNT=0"
for %%F in ("%SYSINT_DIR%\*.exe") do set /a TOOL_COUNT+=1
echo [SUCCESS] %TOOL_COUNT% tools installed in %SYSINT_DIR%
echo.

:: Check specifically for PSPing
if exist "%SYSINT_DIR%\psping.exe" (
    echo [SUCCESS] PSPing installed - Network speed tests enabled!
) else (
    echo [WARNING] PSPing not found - Basic network tests only
)

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

:: FIXED: Check GPU-Z with size validation
if exist "%GPUZ_PATH%" (
    for %%A in ("%GPUZ_PATH%") do set "GPUZ_SIZE=%%~zA"
    if !GPUZ_SIZE! GTR 1000000 (
        echo [OK] GPU-Z.exe - Installed ^(!GPUZ_SIZE! bytes^)
    ) else (
        echo [!] GPU-Z.exe - File exists but seems corrupted ^(!GPUZ_SIZE! bytes^)
        echo     Expected size: ^>1MB. Re-download recommended.
    )
) else (
    echo [ ] GPU-Z.exe - Not installed
)

if exist "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe" (
    echo [OK] NVIDIA System Management Interface
) else (
    echo [ ] NVIDIA-SMI - Not installed ^(NVIDIA GPU drivers^)
)

:: FIXED: Check for AMD tools (check ALL registry subkeys)
set "AMD_FOUND="
for /f "tokens=*" %%K in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s 2^>nul ^| find "HKEY_"') do (
    reg query "%%K" /v DriverDesc 2>nul | find /i "AMD" >nul 2>&1
    if not errorlevel 1 (
        set "AMD_FOUND=YES"
        goto :AMD_FOUND
    )
    reg query "%%K" /v DriverDesc 2>nul | find /i "Radeon" >nul 2>&1
    if not errorlevel 1 (
        set "AMD_FOUND=YES"
        goto :AMD_FOUND
    )
)
:AMD_FOUND
if defined AMD_FOUND (
    echo [OK] AMD GPU Drivers - Installed
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
    for %%A in ("%GPUZ_PATH%") do (
        set "GPUZ_SIZE=%%~zA"
        echo Size: !GPUZ_SIZE! bytes
        if !GPUZ_SIZE! LSS 1000000 (
            echo [WARNING] File seems too small. May be corrupted.
            echo           Expected size: ^>1MB
            echo           Re-download if GPU-Z doesn't work properly.
        ) else (
            echo [OK] File size looks good
        )
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
    if %errorlevel% neq 0 (
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
echo Expected file size: 5-10 MB
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

:: FIXED: Check for AMD GPU (check ALL registry subkeys)
set "AMD_FOUND="
set "AMD_NAME="
set "AMD_DRIVER_VERSION="
set "AMD_DRIVER_DATE="
set "AMD_COUNT=0"

echo Scanning for AMD GPUs in all registry locations...
echo.

for /f "tokens=*" %%K in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" /s 2^>nul ^| find "HKEY_"') do (
    for /f "tokens=2*" %%a in ('reg query "%%K" /v DriverDesc 2^>nul ^| find "DriverDesc"') do (
        echo %%b | find /i "AMD" >nul 2>&1
        if not errorlevel 1 (
            set "AMD_FOUND=YES"
            set /a AMD_COUNT+=1
            
            echo [AMD GPU #!AMD_COUNT!]
            echo Device: %%b
            
            :: Get driver version
            for /f "tokens=2*" %%v in ('reg query "%%K" /v DriverVersion 2^>nul ^| find "DriverVersion"') do (
                echo Driver Version: %%w
            )
            
            :: Get driver date
            for /f "tokens=2*" %%d in ('reg query "%%K" /v DriverDate 2^>nul ^| find "DriverDate"') do (
                echo Driver Date: %%d
            )
            
            :: Get registry key location
            echo Registry Key: %%K
            echo.
        ) else (
            echo %%b | find /i "Radeon" >nul 2>&1
            if not errorlevel 1 (
                set "AMD_FOUND=YES"
                set /a AMD_COUNT+=1
                
                echo [AMD GPU #!AMD_COUNT!]
                echo Device: %%b
                
                :: Get driver version
                for /f "tokens=2*" %%v in ('reg query "%%K" /v DriverVersion 2^>nul ^| find "DriverVersion"') do (
                    echo Driver Version: %%w
                )
                
                :: Get driver date
                for /f "tokens=2*" %%d in ('reg query "%%K" /v DriverDate 2^>nul ^| find "DriverDate"') do (
                    echo Driver Date: %%d
                )
                
                :: Get registry key location
                echo Registry Key: %%K
                echo.
            )
        )
    )
)

if defined AMD_FOUND (
    echo ========================================================
    echo Total AMD GPUs detected: %AMD_COUNT%
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
    echo 3. Check Device Manager for display adapters
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
echo - Safe temps vary by GPU model - check manufacturer specs
echo - General guidance: Stop if over 85C ^(many GPUs^)
echo - Some AMD GPUs safe to 110C junction temperature
echo - Laptop users: Use caution with stress tests
echo.
echo ALWAYS check your specific GPU's safe temperature range
echo from the manufacturer before stress testing!
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
echo NEW IN v2.2 (FIXED):
echo   - Tool integrity verification (digital signatures)
echo   - Dual report system (Clean + Detailed)
echo   - Fixed memory usage calculation bug
echo   - Launcher awareness detection
echo   - Enhanced GPU testing with vendor-specific tools
echo   - GPU Tools Manager (Menu Option 6)
echo   - FIXED: AMD GPU detection now checks ALL registry keys
echo   - FIXED: GPU-Z size validation added
echo   - FIXED: Removed duplicate Sysinternals check
echo   - FIXED: Consistent errorlevel checking
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
echo    This was a bug in earlier versions - FIXED in v2.1+
echo.
echo 6. NETWORK SPEED TESTS LIMITED
echo    Cause: PSPing.exe not found
echo    Solution: Download Sysinternals Suite (Option 5)
echo    PSPing enables: Bandwidth testing, TCP latency
echo.
echo 7. TESTS TAKE TOO LONG
echo    Expected durations:
echo    - CPU Test: 30 seconds
echo    - Disk Test: 10-30 seconds  
echo    - Energy Report: 20 seconds (configurable)
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
echo 10. AMD GPU NOT DETECTED
echo     FIXED: Script now checks ALL registry subkeys
echo     If still not detected:
echo     - Update AMD drivers
echo     - Check Device Manager
echo     - Verify GPU is enabled
echo.
echo 11. GPU-Z FILE CORRUPTED
echo     FIXED: Script now validates file size
echo     Expected: 5-10 MB
echo     If corrupted, re-download from TechPowerUp
echo.
echo --------------------------------------------------------
echo FEATURES:
echo --------------------------------------------------------
echo.
echo NETWORK SPEED TESTING:
echo   - Gateway connectivity tests
echo   - Internet endpoint testing (Google, Cloudflare, MS)
echo   - Latency measurements to multiple servers
echo   - PSPing bandwidth capacity testing
echo   - DNS resolution speed testing
echo   - MTU path discovery
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
echo Thank you for using Portable Sysinternals System Tester!
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
