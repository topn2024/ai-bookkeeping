# Android Development Environment Installation Script
# Run this script in PowerShell as Administrator

Write-Host "=== Android Development Environment Setup ===" -ForegroundColor Cyan

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: This script should be run as Administrator for best results" -ForegroundColor Yellow
}

# Check winget
Write-Host "`nChecking winget..." -ForegroundColor Yellow
try {
    $wingetVersion = winget --version
    Write-Host "Winget version: $wingetVersion" -ForegroundColor Green
} catch {
    Write-Host "Winget not found. Please install App Installer from Microsoft Store first." -ForegroundColor Red
    exit 1
}

# 1. Install Java JDK 17
Write-Host "`n[1/4] Installing Java JDK 17 (Eclipse Temurin)..." -ForegroundColor Yellow
winget install EclipseAdoptium.Temurin.17.JDK --accept-package-agreements --accept-source-agreements

# 2. Install Android Studio
Write-Host "`n[2/4] Installing Android Studio..." -ForegroundColor Yellow
winget install Google.AndroidStudio --accept-package-agreements --accept-source-agreements

# 3. Install Flutter SDK
Write-Host "`n[3/4] Installing Flutter SDK..." -ForegroundColor Yellow
winget install Google.Flutter --accept-package-agreements --accept-source-agreements

# 4. Install Git (required for Flutter)
Write-Host "`n[4/4] Checking Git..." -ForegroundColor Yellow
$gitInstalled = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitInstalled) {
    Write-Host "Installing Git..." -ForegroundColor Yellow
    winget install Git.Git --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "Git already installed" -ForegroundColor Green
}

# Refresh environment variables
Write-Host "`nRefreshing environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Set ANDROID_HOME if not set
$androidHome = [System.Environment]::GetEnvironmentVariable("ANDROID_HOME", "User")
if (-not $androidHome) {
    $defaultAndroidPath = "$env:LOCALAPPDATA\Android\Sdk"
    Write-Host "Setting ANDROID_HOME to $defaultAndroidPath" -ForegroundColor Yellow
    [System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $defaultAndroidPath, "User")
}

Write-Host "`n=== Installation Complete ===" -ForegroundColor Green
Write-Host @"

Next Steps:
1. Close and reopen your terminal to refresh environment variables
2. Open Android Studio and complete the initial setup wizard
3. In Android Studio, go to Tools > SDK Manager and install:
   - Android SDK Platform (latest)
   - Android SDK Build-Tools
   - Android Emulator
   - Android SDK Platform-Tools
4. Run 'flutter doctor' to verify the installation
5. Accept Android licenses with: flutter doctor --android-licenses

"@ -ForegroundColor Cyan
