# ============================================================
# Development Environment Diagnostic Script
# ============================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          Development Environment Diagnostic" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

$issues = @()

# ============================================================
# 1. Check Java
# ============================================================
Write-Host "[1/7] Checking Java..." -ForegroundColor Yellow

if (Get-Command java -ErrorAction SilentlyContinue) {
    $javaVersion = java -version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] $javaVersion" -ForegroundColor Green

    if ($env:JAVA_HOME) {
        Write-Host "  [OK] JAVA_HOME = $env:JAVA_HOME" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] JAVA_HOME not set" -ForegroundColor Yellow
        $issues += "JAVA_HOME not set"
    }
} else {
    Write-Host "  [FAIL] Java not installed" -ForegroundColor Red
    $issues += "Java not installed"
}

# ============================================================
# 2. Check Android SDK
# ============================================================
Write-Host ""
Write-Host "[2/7] Checking Android SDK..." -ForegroundColor Yellow

$androidHome = $env:ANDROID_HOME
if (-not $androidHome) {
    $androidHome = "$env:LOCALAPPDATA\Android\Sdk"
}

if (Test-Path $androidHome) {
    Write-Host "  [OK] Android SDK path: $androidHome" -ForegroundColor Green

    # Check key components
    $components = @(
        @{ Name = "platform-tools"; Path = "$androidHome\platform-tools" },
        @{ Name = "emulator"; Path = "$androidHome\emulator" },
        @{ Name = "build-tools"; Path = "$androidHome\build-tools" },
        @{ Name = "cmdline-tools"; Path = "$androidHome\cmdline-tools" }
    )

    foreach ($comp in $components) {
        if (Test-Path $comp.Path) {
            Write-Host "  [OK] $($comp.Name) installed" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] $($comp.Name) not installed" -ForegroundColor Yellow
            $issues += "$($comp.Name) not installed"
        }
    }

    if (-not $env:ANDROID_HOME) {
        Write-Host "  [WARN] ANDROID_HOME env var not set" -ForegroundColor Yellow
        $issues += "ANDROID_HOME not set"
    }
} else {
    Write-Host "  [FAIL] Android SDK not found" -ForegroundColor Red
    $issues += "Android SDK not installed"
}

# ============================================================
# 3. Check Flutter
# ============================================================
Write-Host ""
Write-Host "[3/7] Checking Flutter..." -ForegroundColor Yellow

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    $flutterVersion = flutter --version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] $flutterVersion" -ForegroundColor Green

    $flutterPath = (Get-Command flutter).Source
    Write-Host "  [OK] Path: $flutterPath" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Flutter not installed or not in PATH" -ForegroundColor Red
    $issues += "Flutter not installed"
}

# ============================================================
# 4. Check Git
# ============================================================
Write-Host ""
Write-Host "[4/7] Checking Git..." -ForegroundColor Yellow

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitVersion = git --version
    Write-Host "  [OK] $gitVersion" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Git not installed" -ForegroundColor Red
    $issues += "Git not installed"
}

# ============================================================
# 5. Check ADB
# ============================================================
Write-Host ""
Write-Host "[5/7] Checking ADB..." -ForegroundColor Yellow

$adbPath = "$androidHome\platform-tools\adb.exe"
if (Test-Path $adbPath) {
    $adbVersion = & $adbPath version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] $adbVersion" -ForegroundColor Green

    # Check connected devices
    Write-Host ""
    Write-Host "  Connected devices:" -ForegroundColor Cyan
    $devices = & $adbPath devices 2>&1
    $devices | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  [WARN] ADB not found" -ForegroundColor Yellow
}

# ============================================================
# 6. Check Emulator
# ============================================================
Write-Host ""
Write-Host "[6/7] Checking Android Emulator..." -ForegroundColor Yellow

$emulatorPath = "$androidHome\emulator\emulator.exe"
if (Test-Path $emulatorPath) {
    Write-Host "  [OK] Emulator installed" -ForegroundColor Green

    Write-Host ""
    Write-Host "  Available AVDs:" -ForegroundColor Cyan
    $avds = & $emulatorPath -list-avds 2>&1
    if ($avds) {
        $avds | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
    } else {
        Write-Host "    (No AVD found)" -ForegroundColor Yellow
        $issues += "No Android emulator created"
    }
} else {
    Write-Host "  [WARN] Emulator not installed" -ForegroundColor Yellow
    $issues += "Android Emulator not installed"
}

# ============================================================
# 7. Check Virtualization
# ============================================================
Write-Host ""
Write-Host "[7/7] Checking Virtualization..." -ForegroundColor Yellow

try {
    $hyperv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($hyperv -and $hyperv.State -eq "Enabled") {
        Write-Host "  [OK] Hyper-V enabled" -ForegroundColor Green
    }

    $whpx = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -ErrorAction SilentlyContinue
    if ($whpx -and $whpx.State -eq "Enabled") {
        Write-Host "  [OK] Windows Hypervisor Platform enabled" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] Windows Hypervisor Platform not enabled (needed for AMD)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [INFO] Cannot check virtualization (needs admin)" -ForegroundColor Gray
}

# Check HAXM (Intel)
$haxmPath = "$androidHome\extras\intel\Hardware_Accelerated_Execution_Manager"
if (Test-Path $haxmPath) {
    Write-Host "  [OK] Intel HAXM installed" -ForegroundColor Green
}

# ============================================================
# Run Flutter Doctor
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Flutter Doctor:" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    flutter doctor
}

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ($issues.Count -eq 0) {
    Write-Host ""
    Write-Host "  [OK] Development environment is complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Start emulator: .\scripts\start-emulator.ps1"
    Write-Host "  2. Run project:    .\scripts\run-android.ps1"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "  Found $($issues.Count) issue(s):" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "To fix:"
    Write-Host "  Run: .\scripts\setup-android-dev-env.ps1"
    Write-Host ""
}
