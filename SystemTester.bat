@echo off
setlocal enableextensions enabledelayedexpansion

:: =====================================================
:: Stable self-elevation (no infinite loops, Home-safe)
::   - Checks Local Admin SID instead of relying on
::     Server service (net session) which can be disabled
:: =====================================================
set "_ELEV_FLAG=%~1"
whoami /groups | findstr /c:"S-1-5-32-544" >nul 2>&1
if errorlevel 1 (
    if /i "%_ELEV_FLAG%"=="/elevated" (
        echo.
        echo [ERROR] Elevation failed or was cancelled.
        echo        Right-click this file and choose "Run as administrator".
        echo.
        pause
        exit /b 1
    )
    echo Requesting administrative privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process -FilePath '%~f0' -ArgumentList '/elevated %*' -Verb RunAs"
    exit /b
)

:: =====================================================
:: We're elevated from here on
:: =====================================================
title Portable Sysinternals System Tester Launcher
color 0B

:: Work from the script folder (prevents System32 drift)
pushd "%~dp0"

echo ========================================================
echo         PORTABLE SYSINTERNALS SYSTEM TESTER
echo ========================================================
echo.

:: Resolve script dir and drive
set "SCRIPT_DIR=%cd%\"
set "DRIVE_LETTER=%~d0"

:: Pick the correct PS1 (prefer the new device-grouped file if present)
set "SCRIPT_PS1=%SCRIPT_DIR%SystemTester_device_grouped.ps1"
if not exist "%SCRIPT_PS1%" set "SCRIPT_PS1=%SCRIPT_DIR%SystemTester.ps1"

echo Running from: %DRIVE_LETTER%
echo Script location: %SCRIPT_DIR%
echo PowerShell script: %SCRIPT_PS1%
echo.

:: Validate the PowerShell script exists
if not exist "%SCRIPT_PS1%" (
    echo [ERROR] PowerShell script not found.
    echo         Expected: SystemTester_device_grouped.ps1 or SystemTester.ps1
    echo.
    pause
    popd
    exit /b 1
)

echo Checking PowerShell availability...
powershell -NoProfile -Command "$PSVersionTable.PSVersion.ToString()" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell is not available on this system.
    echo         This launcher requires Windows PowerShell 5.1 or PowerShell 7+.
    echo.
    pause
    popd
    exit /b 1
)
echo PowerShell found!
echo.

:MENU
cls
echo ========================================================
echo         PORTABLE SYSINTERNALS SYSTEM TESTER
echo ========================================================
echo.
echo Running from: %DRIVE_LETTER%
echo.
echo 1. Run with Interactive Menu
echo 2. Run ALL Tests Automatically (Classic Order)
echo 3. Run ALL Tests Automatically (Grouped by Device)
echo 4. Fix PowerShell Execution Policy (CurrentUser)
echo 5. Show Help / Troubleshooting
echo 6. Exit
echo.
set /p "choice=Choose an option (1-6): "

if "%choice%"=="1" goto INTERACTIVE
if "%choice%"=="2" goto AUTORUN_CLASSIC
if "%choice%"=="3" goto AUTORUN_DEVICE
if "%choice%"=="4" goto FIXPOLICY
if "%choice%"=="5" goto HELP
if "%choice%"=="6" goto EXIT

echo Invalid choice. Please try again.
timeout /t 2 >nul
goto MENU

:INTERACTIVE
echo.
echo Starting Interactive Mode...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%"
if errorlevel 1 (
    echo.
    echo [ERROR] Script encountered an error. Check the output above.
    pause
)
goto MENU

:AUTORUN_CLASSIC
echo.
echo Running ALL tests automatically (Classic Order)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -AutoRun
if errorlevel 1 (
    echo.
    echo [ERROR] Script encountered an error. Check the output above.
    pause
)
goto MENU

:AUTORUN_DEVICE
echo.
echo Running ALL tests automatically (Grouped by Device)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PS1%" -AutoRunByDevice
if errorlevel 1 (
    echo.
    echo [ERROR] Script encountered an error. Check the output above.
    pause
)
goto MENU

:FIXPOLICY
echo.
echo Setting PowerShell execution policy for CurrentUser to RemoteSigned...
echo (Already elevated; no extra UAC prompt should appear.)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host 'Execution policy updated successfully'; Start-Sleep -Seconds 2"
echo.
echo If successful, you can now run the script normally.
pause
goto MENU

:HELP
cls
echo ========================================================
echo                   HELP / TROUBLESHOOTING
echo ========================================================
echo.
echo COMMON ISSUES AND SOLUTIONS:
echo.
echo 1. SCRIPT WINDOW CLOSES OR "CRASHES"
echo    - Run from an open Command Prompt to see messages.
echo    - This launcher pauses on failures.
echo.
echo 2. EXECUTION POLICY ERRORS
echo    - Use Option 4 to set CurrentUser to RemoteSigned.
echo    - Or run manually:
echo      PowerShell: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
echo.
echo 3. SYSINTERNALS TOOLS NOT FOUND
echo    - Place Sysinternals Suite under: %SCRIPT_DIR%Sysinternals\
echo.
echo 4. PERMISSION ERRORS
echo    - This launcher self-elevates via UAC.
echo.
echo NOTES:
echo - Option 2 = original "classic" sequence.
echo - Option 3 = runs tests grouped by device (CPU->RAM->Disks/Volumes->NICs->GPU->Battery->System).
echo.
pause
goto MENU

:EXIT
echo.
echo Thank you for using Portable Sysinternals System Tester!
echo.
timeout /t 1 >nul
popd
exit /b 0
