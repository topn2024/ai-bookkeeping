@echo off
:: Android Development Environment Installer
:: This script will open PowerShell as Administrator to install the required tools

echo ============================================
echo   Android Development Environment Installer
echo ============================================
echo.
echo This will install:
echo   - Java JDK 17 (Eclipse Temurin)
echo   - Android Studio
echo   - Flutter SDK
echo   - Git (if not installed)
echo.
echo Press any key to continue or Ctrl+C to cancel...
pause > nul

:: Run PowerShell script as Administrator
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0install-android-env.ps1\"' -Verb RunAs"

echo.
echo Installation started in a new Administrator window.
echo Please follow the prompts in that window.
pause
