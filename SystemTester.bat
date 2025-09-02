@echo off
setlocal enabledelayedexpansion

:: ===========================
:: Stable self-elevation block
:: ===========================
REM 1) Check if we're already elevated
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    echo Please click "Yes" in the UAC prompt that appears.
    echo.
    
    REM Re-launch this batch file with elevation
    powershell.exe -NoProfile -Command ^
      "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    
    REM Exit the non-elevated instance
    exit /b
)

REM 2) We're now elevated - show confirmation
echo Administrative privileges confirmed.
echo Current directory: %~dp0
echo.


:: ===========================
:: From here on, we are elevated
:: ===========================
title Portable Sysinternals System Tester Launcher
color 0B

:: Pin working dir to script folder (handles double-clicks)
pushd "%~dp0"

title Portable Sysinternals System Tester Launcher
color 0B

echo ========================================================
echo         PORTABLE SYSINTERNALS SYSTEM TESTER
echo ========================================================
echo.

REM Get current directory and drive
set "SCRIPT_DIR=%~dp0"
set "DRIVE_LETTER=%~d0"

echo Running from: %DRIVE_LETTER%
echo Script location: %SCRIPT_DIR%
echo.

REM Check if PowerShell script exists
if not exist "%SCRIPT_DIR%SystemTester.ps1" (
    echo ERROR: SystemTester.ps1 not found!
    echo Please make sure SystemTester.ps1 is in the same folder as this batch file.
    echo.
    pause
    exit /b 1
)

echo Checking PowerShell availability...
powershell -Command "Write-Host 'PowerShell is available'" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available on this system.
    echo This script requires PowerShell to run.
    echo.
    pause
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
echo 2. Run All Tests Automatically  
echo 3. Run with Output to Thumb Drive
echo 4. Fix PowerShell Execution Policy (Admin Required)
echo 5. Show Help/Troubleshooting
echo 6. Exit
echo.
set /p "choice=Choose an option (1-6): "

if "%choice%"=="1" goto INTERACTIVE
if "%choice%"=="2" goto AUTORUN  
if "%choice%"=="3" goto THUMBDRIVE
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
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%SystemTester.ps1"
if errorlevel 1 (
    echo.
    echo Script encountered an error. Check the output above.
    pause
)
goto MENU

:AUTORUN
echo.
echo Running All Tests Automatically...
echo.
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%SystemTester.ps1" -AutoRun
if errorlevel 1 (
    echo.
    echo Script encountered an error. Check the output above.
    pause
)
goto MENU

:THUMBDRIVE
echo.
echo Running with Output to Thumb Drive...
echo.
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%SystemTester.ps1" -OutputToThumbDrive
if errorlevel 1 (
    echo.
    echo Script encountered an error. Check the output above.
    pause
)
goto MENU

:FIXPOLICY
echo.
echo Attempting to fix PowerShell execution policy...
echo This requires administrator privileges.
echo.
powershell -Command "Start-Process PowerShell -ArgumentList '-Command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; Write-Host Execution policy updated successfully; pause' -Verb RunAs"
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
echo 1. SCRIPT WINDOW CLOSES IMMEDIATELY
echo    - This batch launcher should prevent that issue
echo    - Alternative: Run from PowerShell console manually
echo.
echo 2. EXECUTION POLICY ERRORS
echo    - Use Option 4 to fix execution policy
echo    - Or run PowerShell as Administrator and run:
echo      Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
echo.
echo 3. SYSINTERNALS TOOLS NOT FOUND
echo    - Download Sysinternals Suite from Microsoft
echo    - Extract to: %SCRIPT_DIR%Sysinternals\
echo    - Or extract directly to: %SCRIPT_DIR%
echo.
echo 4. PERMISSION ERRORS
echo    - Try running as Administrator
echo    - Check if thumb drive is write-protected
echo.
echo 5. SCRIPT FREEZES OR HANGS  
echo    - Some tools may take time on slower systems
echo    - Press Ctrl+C to cancel if needed
echo.
echo SETUP CHECKLIST:
echo [x] SystemTester.ps1 in same folder as this batch file
echo [ ] Sysinternals tools in Sysinternals subfolder
echo [ ] PowerShell execution policy set to RemoteSigned
echo [ ] Running with appropriate permissions
echo.
echo RECOMMENDED FOLDER STRUCTURE:
echo %DRIVE_LETTER%
echo ├── SystemTester.ps1
echo ├── RunSystemTester.bat (this file)  
echo ├── Sysinternals\
echo │   ├── psinfo.exe
echo │   ├── coreinfo.exe
echo │   ├── pslist.exe
echo │   └── (other tools...)
echo └── TestResults\ (auto-created)
echo.
pause
goto MENU

:EXIT
echo.
echo Thank you for using Portable Sysinternals System Tester!
echo.
timeout /t 2 >nul
exit /b 0
