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
set "SCRIPT_VERSION=2.3"

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
set "SCRIPT_PS1=%SCRIPT_DIR%\SystemTester.ps1"

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

:: Check for Sysinternals folder
if not exist "%SCRIPT_DIR%\Sysinternals" (
    echo [WARNING] Sysinternals folder not found!
    echo Use Menu Option 5 to download automatically.
    echo.
    timeout /t 2 >nul
)

:: Check for PSPing specifically (for network speed tests)
if exist "%SCRIPT_DIR%\Sysinternals\psping.exe" (
    echo [INFO] PSPing detected - Full network speed tests available
) else (
    echo [INFO] PSPing not found - Basic network tests only
    echo       Download Sysinternals Suite for full network testing
)
echo.

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
echo 6. Help / Troubleshooting
echo 7. Exit
echo.
echo --------------------------------------------------------
set /p "choice=Choose an option (1-7): "

if "%choice%"=="1" goto INTERACTIVE
if "%choice%"=="2" goto AUTORUN
if "%choice%"=="3" goto FIXPOLICY
if "%choice%"=="4" goto VERIFY
if "%choice%"=="5" goto DOWNLOAD
if "%choice%"=="6" goto HELP
if "%choice%"=="7" goto EXIT

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
echo This will run 16 test suites and generate reports.
echo May take 10-30 minutes depending on your system.
echo.
echo Tests include: System Info, CPU, RAM, Storage, Network,
echo Network Speed (NEW), Processes, Security, and more...
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

:HELP
cls
echo ========================================================
echo         HELP / TROUBLESHOOTING GUIDE v%SCRIPT_VERSION%
echo ========================================================
echo.
echo NEW IN v2.3:
echo   - Network Speed Testing with PSPing and Test-NetConnection
echo   - Local and Internet connectivity tests
echo   - Bandwidth capacity testing
echo   - DNS resolution speed measurements
echo   - Network MTU discovery
echo   - Gateway and latency testing
echo.
echo NEW IN v2.1-2.2:
echo   - Tool integrity verification (digital signatures)
echo   - Dual report system (Clean + Detailed)
echo   - Fixed memory usage calculation bug
echo   - Launcher awareness detection
echo   - Enhanced error messages
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
echo    This was a bug in v2.08 - FIXED in v2.1+
echo.
echo 6. NETWORK SPEED TESTS LIMITED
echo    Cause: PSPing.exe not found
echo    Solution: Download Sysinternals Suite (Option 5)
echo    PSPing enables: Bandwidth testing, TCP latency
echo.
echo 7. TESTS TAKE TOO LONG
echo    Expected durations:
echo    - CPU Test: 10 seconds
echo    - Network Speed: 30-60 seconds
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
echo FEATURES:
echo --------------------------------------------------------
echo.
echo NETWORK SPEED TESTING (NEW):
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
