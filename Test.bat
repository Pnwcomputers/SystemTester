@echo off
title System Tester - Minimal Version
color 0B

:: Skip elevation for testing
cd /d "%~dp0"

:MENU
cls
echo ========================================
echo   SYSTEM TESTER MENU - MINIMAL TEST
echo ========================================
echo.
echo If you see this menu, the batch file works!
echo.
echo 1. Try to launch PowerShell script
echo 2. Exit
echo.
set /p "choice=Choose (1-2): "

if "%choice%"=="1" goto LAUNCH
if "%choice%"=="2" goto EXIT

echo Invalid choice
timeout /t 1 >nul
goto MENU

:LAUNCH
echo.
echo Attempting to launch SystemTester.ps1...
echo Location: %~dp0SystemTester.ps1
echo.
if not exist "%~dp0SystemTester.ps1" (
    echo ERROR: SystemTester.ps1 not found!
    echo.
    pause
    goto MENU
)
echo File found! Launching with -NoExit so you can see errors...
echo.
pause
powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass -File "%~dp0SystemTester.ps1"
goto MENU

:EXIT
echo.
echo Exiting...
timeout /t 1 >nul
exit /b 0
