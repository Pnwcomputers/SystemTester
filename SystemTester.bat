@echo off
setlocal enableextensions enabledelayedexpansion

:: =====================================================
:: Portable Sysinternals System Tester Launcher
:: Created by Pacific Northwest Computers - 2025
:: Audited and Enhanced Version
:: =====================================================

:: =====================================================
:: Stable self-elevation (no infinite loops, Home-safe)
::   - Checks Local Admin SID instead of relying on
::     Server service (net session) which can be disabled
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
        echo         Or check User Account Control (UAC) settings.
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
    echo   - System file verification
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
title Portable Sysinternals System Tester Launcher
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
    echo         This launcher requires Windows PowerShell 5.1 or later.
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
    echo The script will prompt you to create this folder on first run.
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
echo 5. Verify Sysinternals Tools Installation
echo 6. Show Help / Troubleshooting
echo 7. Exit
echo.
echo --------------------------------------------------------
set /p "choice=Choose an option (1-7): "

:: Validate input is a number between 1-7
echo %choice%| findstr /r "^[1-7]$" >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Invalid choice. Please enter a number between 1 and 7.
    timeout /t 2 >nul
    goto MENU
)

if "%choice%"=="1" goto INTERACTIVE
if "%choice%"=="2" goto AUTORUN
if "%choice%"=="3" goto REPORT_ONLY
if "%choice%"=="4" goto FIXPOLICY
if "%choice%"=="5" goto VERIFY_TOOLS
if "%choice%"=="6" goto HELP
if "%choice%"=="7" goto EXIT

:: Fallback (should never reach here due to validation)
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto MENU

:INTERACTIVE
echo.
echo ========================================================
echo              STARTING INTERACTIVE MODE
echo ========================================================
echo.
echo The interactive menu allows you to:
echo   - Select individual tests to run
echo   - View test categories before running
echo   - Generate reports when ready
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
echo This will run the following test suites:
echo   1. System Information
echo   2. CPU Testing (Performance and Info)
echo   3. RAM Testing (Memory Analysis)
echo   4. Hard Drive/SSD Testing
echo   5. Process Analysis
echo   6. Security Analysis
echo   7. Network Analysis
echo   8. OS Health (DISM/SFC)
echo   9. Storage SMART / Reliability
echo  10. SSD TRIM Status
echo  11. NIC Snapshot
echo  12. GPU / DirectX
echo  13. Power/Battery + Energy Report
echo  14. Hardware Error Events (WHEA)
echo  15. Windows Update Status
echo.
echo This may take several minutes depending on your system.
echo A report will be generated automatically when complete.
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
echo This option is only useful if you have run tests in the
echo current PowerShell session without generating a report.
echo.
echo If you haven't run any tests yet, this will show an error.
echo.
echo Press any key to continue, or Ctrl+C to cancel...
pause >nul
echo.

:: Run script with a custom parameter to just generate report
:: Note: This requires the PowerShell script to retain results
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Write-Host 'Note: This feature requires keeping the PowerShell window open.' -ForegroundColor Yellow; Write-Host 'If you closed the test window, please run tests again.' -ForegroundColor Yellow; Start-Sleep -Seconds 3"

echo.
echo To use this feature properly:
echo   1. Keep the PowerShell test window open
echo   2. Run your desired tests
echo   3. Select option to generate report
echo.
pause
goto MENU

:FIXPOLICY
echo.
echo ========================================================
echo          FIXING POWERSHELL EXECUTION POLICY
echo ========================================================
echo.
echo Current execution policy will be changed to RemoteSigned
echo for the CurrentUser scope. This allows locally created
echo scripts to run without being signed.
echo.
echo This is safe and only affects your user account.
echo.
echo Press any key to continue, or Ctrl+C to cancel...
pause >nul
echo.

:: Show current policy first
echo Current Execution Policy:
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ExecutionPolicy -List | Format-Table -AutoSize"
echo.

:: Set new policy
echo Setting CurrentUser policy to RemoteSigned...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop; Write-Host 'SUCCESS: Execution policy updated successfully!' -ForegroundColor Green } catch { Write-Host 'ERROR: Failed to update policy - ' $_.Exception.Message -ForegroundColor Red }"

echo.
echo New Execution Policy:
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ExecutionPolicy -List | Format-Table -AutoSize"
echo.
pause
goto MENU

:VERIFY_TOOLS
echo.
echo ========================================================
echo       VERIFYING SYSINTERNALS TOOLS INSTALLATION
echo ========================================================
echo.

set "SYSINT_DIR=%SCRIPT_DIR%\Sysinternals"

if not exist "%SYSINT_DIR%" (
    echo [ERROR] Sysinternals folder does not exist!
    echo         Expected: %SYSINT_DIR%
    echo.
    echo SETUP INSTRUCTIONS:
    echo 1. Download Sysinternals Suite from:
    echo    https://download.sysinternals.com/files/SysinternalsSuite.zip
    echo.
    echo 2. Extract the ZIP file
    echo.
    echo 3. Copy all .exe files to: %SYSINT_DIR%\
    echo.
    echo 4. Run this verification again
    echo.
    pause
    goto MENU
)

echo Checking for key Sysinternals tools...
echo.

:: List of critical tools
set "FOUND=0"
set "MISSING=0"

for %%t in (psinfo.exe coreinfo.exe pslist.exe handle.exe du.exe streams.exe autorunsc.exe clockres.exe) do (
    if exist "%SYSINT_DIR%\%%t" (
        echo [FOUND] %%t
        set /a FOUND+=1
    ) else (
        echo [MISSING] %%t
        set /a MISSING+=1
    )
)

echo.
echo --------------------------------------------------------
echo Summary: %FOUND% found, %MISSING% missing
echo --------------------------------------------------------
echo.

if %MISSING% GTR 0 (
    echo [WARNING] Some tools are missing.
    echo           The script will skip tests for missing tools.
    echo.
    echo To install missing tools:
    echo 1. Download Sysinternals Suite
    echo 2. Extract all .exe files to: %SYSINT_DIR%\
    echo.
) else (
    echo [SUCCESS] All key tools are present!
    echo           You're ready to run tests.
    echo.
)

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
echo    - Open Command Prompt first (cmd.exe)
echo    - Drag this batch file into the window
echo    - This launcher now pauses on errors automatically
echo.
echo --------------------------------------------------------
echo 2. EXECUTION POLICY ERRORS
echo --------------------------------------------------------
echo    Error: "cannot be loaded because running scripts is disabled"
echo.
echo    Solution:
echo    - Use Menu Option 4 to fix automatically
echo    - Or manually run in PowerShell as Administrator:
echo      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
echo.
echo --------------------------------------------------------
echo 3. SYSINTERNALS TOOLS NOT FOUND
echo --------------------------------------------------------
echo    Error: "Sysinternals folder not found" or tools skipped
echo.
echo    Solution:
echo    - Use Menu Option 5 to verify installation
echo    - Download from: https://live.sysinternals.com
echo    - Extract all .exe files to: %SCRIPT_DIR%\Sysinternals\
echo.
echo --------------------------------------------------------
echo 4. PERMISSION / ACCESS DENIED ERRORS
echo --------------------------------------------------------
echo    Solution:
echo    - This launcher auto-elevates (requires UAC prompt)
echo    - Some tests require administrator rights:
echo      * DISM and SFC scans
echo      * Energy report generation
echo      * Hardware SMART data
echo      * Windows Update queries
echo.
echo --------------------------------------------------------
echo 5. WINDOWS UPDATE CHECK FAILS
echo --------------------------------------------------------
echo    Error: Windows Update COM object errors
echo.
echo    Solution:
echo    - Ensure Windows Update service is running:
echo      services.msc -^> Windows Update -^> Start
echo    - Check if Windows Update is corrupted:
echo      Run "DISM /Online /Cleanup-Image /RestoreHealth"
echo    - May require administrator rights
echo.
echo --------------------------------------------------------
echo 6. TESTS TAKE TOO LONG
echo --------------------------------------------------------
echo    Some tests are intentionally slow:
echo    - CPU Performance Test: 10 seconds
echo    - Power/Energy Report: 15 seconds  
echo    - Windows Update Search: 30-60 seconds
echo    - DISM/SFC Scans: 5-15 minutes
echo.
echo --------------------------------------------------------
echo 7. REPORTS NOT GENERATING
echo --------------------------------------------------------
echo    Solution:
echo    - Check script directory write permissions
echo    - Ensure tests have been run first
echo    - Look for .txt files in: %SCRIPT_DIR%
echo.
echo --------------------------------------------------------
echo              FEATURE DESCRIPTIONS
echo --------------------------------------------------------
echo.
echo NEW IN THIS VERSION:
echo   - Windows Update Status checking (pending updates, history)
echo   - Enhanced error handling throughout
echo   - Better compatibility with PowerShell 7
echo   - Improved SMART data collection
echo   - Network adapter detailed info
echo.
echo TEST CATEGORIES:
echo   System Info    : OS, hardware overview, clock resolution
echo   CPU Tests      : Architecture, performance, top processes
echo   RAM Tests      : Capacity, modules, usage, performance
echo   Storage Tests  : Drives, SMART, TRIM, fragmentation
echo   Processes      : Process tree, handle analysis
echo   Security       : Autorun entries, startup items
echo   Network        : Connections, adapter status, speeds
echo   OS Health      : DISM integrity, SFC verification
echo   GPU/Graphics   : DirectX info, video card details
echo   Power          : Battery status, energy efficiency
echo   Hardware Events: WHEA error logging
echo   Windows Update : Pending updates, history, service status
echo.
echo --------------------------------------------------------
echo                  SUPPORT RESOURCES
echo --------------------------------------------------------
echo.
echo Sysinternals Documentation:
echo   https://docs.microsoft.com/sysinternals
echo.
echo PowerShell Execution Policy:
echo   https://docs.microsoft.com/powershell/execution-policies
echo.
echo Windows Update Troubleshooting:
echo   https://support.microsoft.com/windows-update
echo.
echo For script issues, check:
echo   - Event Viewer (Windows Logs -^> Application)
echo   - PowerShell transcript logs (if enabled)
echo.
pause
goto MENU

:EXIT
echo.
echo ========================================================
echo Thank you for using Portable Sysinternals System Tester!
echo ========================================================
echo.
echo Reports are saved in: %SCRIPT_DIR%
echo Look for files: SystemTest_Clean_*.txt
echo                 SystemTest_Detailed_*.txt
echo                 energy-report.html (if power test run)
echo.
echo Visit https://sysinternals.com for tool updates
echo.
timeout /t 2 >nul
exit /b 0
