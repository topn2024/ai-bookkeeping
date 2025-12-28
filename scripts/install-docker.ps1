# ============================================================
# Docker Desktop Auto-Install Script
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       Docker Desktop Auto-Install" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Download URL
$dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
$installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

# ============================================================
# Step 1: Download
# ============================================================
Write-Host ""
Write-Host "[1/3] Downloading Docker Desktop..." -ForegroundColor Yellow
Write-Host "      URL: $dockerUrl"
Write-Host "      This may take several minutes (~500MB)..."
Write-Host ""

try {
    # Use BITS for better download experience
    $bitsSupported = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue

    if ($bitsSupported) {
        Start-BitsTransfer -Source $dockerUrl -Destination $installerPath -DisplayName "Downloading Docker Desktop"
    } else {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $dockerUrl -OutFile $installerPath -UseBasicParsing
    }

    if (Test-Path $installerPath) {
        $fileSize = [math]::Round((Get-Item $installerPath).Length / 1MB, 2)
        Write-Host "[OK] Download complete! Size: $fileSize MB" -ForegroundColor Green
    } else {
        throw "Download failed - file not found"
    }
} catch {
    Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please download manually from:" -ForegroundColor Yellow
    Write-Host "https://www.docker.com/products/docker-desktop"
    exit 1
}

# ============================================================
# Step 2: Install
# ============================================================
Write-Host ""
Write-Host "[2/3] Installing Docker Desktop..." -ForegroundColor Yellow
Write-Host "      This may take several minutes..."
Write-Host ""

try {
    # Run installer with quiet mode
    $installArgs = "install --quiet --accept-license"

    Write-Host "Running installer..."
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Host "[OK] Installation complete!" -ForegroundColor Green
    } elseif ($process.ExitCode -eq 1) {
        Write-Host "[INFO] Installation complete, but requires restart" -ForegroundColor Yellow
    } else {
        Write-Host "[WARN] Installer exit code: $($process.ExitCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[ERROR] Installation failed: $_" -ForegroundColor Red
    exit 1
}

# ============================================================
# Step 3: Cleanup and Instructions
# ============================================================
Write-Host ""
Write-Host "[3/3] Cleanup..." -ForegroundColor Yellow

# Remove installer
Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
Write-Host "[OK] Installer removed" -ForegroundColor Green

# ============================================================
# Final Instructions
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "       Docker Desktop Installation Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

Write-Host @"

IMPORTANT - Next Steps:
-----------------------
1. RESTART your computer (required for WSL2/Hyper-V)

2. After restart, Docker Desktop will start automatically
   - Wait for it to fully initialize (tray icon becomes stable)
   - First startup may take 1-2 minutes

3. Then run the server setup:
   cd D:\code\ai-bookkeeping
   .\scripts\setup-server-docker.ps1

Note: If Docker Desktop doesn't start automatically,
      launch it from the Start Menu.

"@

# Ask for restart
Write-Host ""
$restart = Read-Host "Do you want to restart now? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host "Restarting in 5 seconds..."
    Start-Sleep -Seconds 5
    Restart-Computer -Force
}
