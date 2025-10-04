@echo off
setlocal enableextensions enabledelayedexpansion

:: =====================================================
:: Portable Sysinternals System Tester Launcher
:: Created by Pacific Northwest Computers - 2025
:: Audited and Enhanced Version - v2.3.5 (EXECUTION FLOW FIX)
:: =====================================================

:: =====================================================
:: Stable self-elevation (no infinite loops, Home-safe)
:: =====================================================
set "_ELEV_FLAG=%~1"

:: Check if running as administrator by looking for admin group SID
whoami /groups 2>nul | findstr /c:"S-1-5-32-544" >nul 2>&1
if errorlevel 1 (
    :: Not elevated - check if this is a re-launch attempt
    if /i "%_ELEV_FLAG%"=="/elevated" (
        echo.
        echo [ERROR] Elevation failed or was cancelled.
        echo         Right-click this file and choose "Run as administrator".
        echo         Or check User Account Control settings.
     
        echo.
        pause
        exit /b 1
    )
    
    :: First attempt - request elevation
    echo.
    echo ========================================================
    echo   Administrative privileges required for full testing
    echo ========================================================
    echo.
    echo Some tests require administrator rights:
    echo   - DISM and SFC integrity checks
    echo   - Energy/battery report generation
 
    echo   - Hardware SMART data access
    - System file verification
    echo.
    echo Requesting elevation...
    echo.
    
    :: Use PowerShell to elevate (more reliable than runas)
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath '%~f0' -ArgumentList '/elevated' -Verb RunAs -WindowStyle Normal"
    
    if errorlevel 1 (
        echo [ERROR] Failed to request elevation.
        echo         Please run this file as administrator manually.
        pause
    )
    exit /b
)

:: =====================================================
:: We're elevated from here on
:: =====================================================
title Portable Sysinternals System Tester Launcher v2.3.5
color 0B

:: Work from the script folder (prevents System32 drift on elevation)
cd /d "%~dp0" 2>nul
if errorlevel 1 (
    echo [ERROR] Cannot change to script directory: %~dp0
    echo         Check permissions and path length.
    pause
    exit /b 1
)

echo ========================================================
echo      PORTABLE SYSINTERNALS SYSTEM TESTER LAUNCHER
echo ========================================================
echo.
:: Resolve script directory and drive letter
set "SCRIPT_DIR=%cd%"
set "DRIVE_LETTER=%~d0"

:: Construct path to PowerShell script
set "SCRIPT_PS1=%SCRIPT_DIR%\SystemTester.ps1"

echo Running from: %DRIVE_LETTER%
echo Script directory: %SCRIPT_DIR%
echo PowerShell script: %SCRIPT_PS1%
echo.
:: Validate the PowerShell script exists
if not exist "%SCRIPT_PS1%" (
    echo [ERROR] PowerShell script not found.
    echo         Expected: %SCRIPT_PS1%
    echo.
    echo Please ensure SystemTester.ps1 is in the same folder as this launcher.
    echo.
    pause
    exit /b 1
)

:: Check PowerShell availability and version
echo Checking PowerShell availability...
powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell is not available on this system.
    echo   
    echo       This launcher requires Windows PowerShell 5.1 or later.
    echo.
    echo Please install Windows Management Framework 5.1 or later.
    echo.
    pause
    exit /b 1
)

:: Get and display PowerShell version
for /f "tokens=*" %%v in ('powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"') do (
    set "PS_VERSION=%%v"
)
echo PowerShell version: %PS_VERSION%
echo.
:: Check if Sysinternals folder exists
if not exist "%SCRIPT_DIR%\Sysinternals" (
    echo [WARNING] Sysinternals folder not found!
    echo           Expected location: %SCRIPT_DIR%\Sysinternals\
    echo.
    echo ACTION: Use Menu Option 6 to download tools automatically.
    echo.
    timeout /t 3 >nul
)

:MENU
cls
echo ========================================================
echo      PORTABLE SYSINTERNALS SYSTEM TESTER LAUNCHER
echo ========================================================
echo.
echo Drive: %DRIVE_LETTER% ^| Directory: %SCRIPT_DIR%
echo PowerShell Version: %PS_VERSION%
echo Status: Running with Administrator privileges
echo.
echo --------------------------------------------------------
echo                    MAIN MENU
echo --------------------------------------------------------
echo.
echo 1. Run with Interactive Menu (Recommended)
echo 2. Run ALL Tests Automatically
echo 3. Generate Report from Previous Test Results
echo 4. Fix PowerShell Execution Policy (CurrentUser)
echo 5. Verify Sysinternals Tools Installation (Integrity Check)
echo 6. Download/Update Sysinternals Suite (Auto)
echo 7. Show Help / Troubleshooting
echo 8. Exit
echo.
echo --------------------------------------------------------
set /p "choice=Choose an option (1-8): "

:: Validate input is a number between 1-8
echo %choice%| findstr /r "^[1-8]$" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Invalid choice. Please enter a number between 1 and 8.
    timeout /t 2 >nul
    goto MENU
)

if "%choice%"=="1" goto INTERACTIVE
if "%choice%"=="2" goto AUTORUN
if "%choice%"=="3" goto REPORT_ONLY
if "%choice%"=="4" goto FIXPOLICY
if "%choice%"=="5" goto VERIFY_TOOLS
if "%choice%"=="6" goto DOWNLOAD_TOOLS
if "%choice%"=="7" goto HELP
if "%choice%"=="8" goto EXIT

:: Fallback (should never reach here due to validation)
echo Invalid choice.
Please try again.
timeout /t 2 >nul
goto MENU

:INTERACTIVE
echo.
echo ========================================================
echo              STARTING INTERACTIVE MODE
echo ========================================================
echo.
echo Press any key to launch...
pause >nul
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%"

if errorlevel 1 (
    echo.
    echo [ERROR] Script encountered an error (exit code: %errorlevel%).
    echo         Check the output above for details.
    echo.
    pause
) else (
    echo.
    echo Script completed successfully.
    timeout /t 2 >nul
)
goto MENU

:AUTORUN
echo.
echo ========================================================
echo           RUNNING ALL TESTS AUTOMATICALLY
echo ========================================================
echo.
echo Press any key to start, or Ctrl+C to cancel...
pause >nul
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -AutoRun

if errorlevel 1 (
    echo.
    echo [ERROR] Script encountered an error (exit code: %errorlevel%).
    echo         Check the output above for details.
    echo.
    pause
) else (
    echo.
    echo All tests completed successfully.
    echo Check the script directory for generated reports.
    timeout /t 3 >nul
)
goto MENU

:REPORT_ONLY
echo.
echo ========================================================
echo         GENERATE REPORT FROM PREVIOUS RESULTS
echo ========================================================
echo.
echo Press any key to continue, or Ctrl+C to cancel...
pause >nul
echo.
:: Simple launch of the main script, relying on the user to run tests first.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%"

echo.
echo Note: This relies on tests being run in the preceding PowerShell session.
pause
goto MENU

:FIXPOLICY
echo.
echo ========================================================
echo          FIXING POWERSHELL EXECUTION POLICY
echo ========================================================
echo.
echo Press any key to continue, or Ctrl+C to cancel...
pause >nul
echo.
:: Simple execution is stable
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop; Write-Host 'SUCCESS: Policy set to RemoteSigned.' -ForegroundColor Green; Write-Host 'Press Enter to continue'; $null=Read-Host"

echo.
pause
goto MENU

:VERIFY_TOOLS
echo.
echo ========================================================
echo      VERIFYING SYSINTERNALS TOOLS INTEGRITY (v2.3.5)
echo ========================================================
echo.
echo Press any key to continue...
pause >nul
echo.
:: FIX: Define the variable first, then dot-source and call function.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$script:ExternalCall = $true; . '%SCRIPT_PS1%' ; Test-ToolVerification ; Write-Host 'Verification complete. Press Enter to continue...'; $null=Read-Host"

pause
goto MENU

:DOWNLOAD_TOOLS
echo.
echo ========================================================
echo      DOWNLOAD/UPDATE SYSINTERNALS SUITE AUTOMATICALLY
echo ========================================================
echo.
set "SYSINT_DIR=%SCRIPT_DIR%\Sysinternals"
set "DOWNLOAD_URL=https://download.sysinternals.com/files/SysinternalsSuite.zip"

echo This will download the latest Sysinternals Suite.
echo.
set /p "confirm=Proceed with download? (Y/N): "
if /i not "!confirm!"=="Y" (
    echo Download cancelled.
    timeout /t 2 >nul
    goto MENU
)

echo.
echo Starting download and extraction...
echo.

:: FIX (v2.3.5): Define the variable first, then dot-source and call function.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$script:ExternalCall = $true; . '%SCRIPT_PS1%' ; Download-SysinternalsSuite ; Write-Host 'Download process finished. Press Enter to continue...'; $null=Read-Host"

echo.
pause
goto MENU

:HELP
cls
echo ========================================================
echo                HELP / TROUBLESHOOTING GUIDE
echo ========================================================
echo.
echo COMMON ISSUES AND SOLUTIONS:
echo.
echo --------------------------------------------------------
echo 1. SCRIPT WINDOW CLOSES IMMEDIATELY OR "CRASHES"
echo --------------------------------------------------------
echo    Solution:
echo    - This version (v2.3.5) uses the most stable command structure.
echo    - If a window still closes instantly, your system has a deeper problem.
echo    - Open Command Prompt first (cmd.exe) and drag this batch file into it.
echo.
echo --------------------------------------------------------
echo 2. EXECUTION POLICY ERRORS
echo --------------------------------------------------------
echo    Error: "cannot be loaded because running scripts is disabled"
echo.
echo    Solution:
echo    - Use Menu Option 4 to fix automatically
echo.
echo --------------------------------------------------------
echo 3. SYSINTERNALS TOOLS NOT FOUND
echo --------------------------------------------------------
echo    Error: "Sysinternals folder not found" or tools skipped
echo.
echo    Solution:
echo    - Use Menu Option 6 to download automatically
echo.
echo --------------------------------------------------------
echo 4. PERMISSION / ACCESS DENIED ERRORS
echo --------------------------------------------------------
echo    Solution:
echo    - This launcher auto-elevates (requires UAC prompt)
echo.
echo --------------------------------------------------------
echo 5. REPORTS NOT GENERATING
echo --------------------------------------------------------
echo    Solution:
    - Check script directory write permissions
    - Ensure tests have been run first
echo.
pause
goto MENU

:EXIT
echo.
echo ========================================================
echo Thank you for using Portable Sysinternals System Tester!
echo ========================================================
echo.
timeout /t 2 >nul
exit /b 0
