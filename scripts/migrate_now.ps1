# Emergency Migration Script - Gradle + Android Config
# Simplified version

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  Emergency Migration: Gradle + Android"
Write-Host "========================================"
Write-Host ""

# Check source directories
$gradleSource = "$env:USERPROFILE\.gradle"
$androidSource = "$env:USERPROFILE\.android"

Write-Host "Checking source directories..."

$gradleExists = Test-Path $gradleSource
$androidExists = Test-Path $androidSource

if ($gradleExists) {
    $gradleSize = (Get-ChildItem $gradleSource -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $gradleSizeGB = [math]::Round($gradleSize/1GB, 2)
    Write-Host "[+] Gradle cache: ${gradleSizeGB}GB" -ForegroundColor Green
} else {
    Write-Host "[!] Gradle cache not found" -ForegroundColor Yellow
}

if ($androidExists) {
    $androidSize = (Get-ChildItem $androidSource -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $androidSizeGB = [math]::Round($androidSize/1GB, 2)
    Write-Host "[+] Android config: ${androidSizeGB}GB" -ForegroundColor Green
} else {
    Write-Host "[!] Android config not found" -ForegroundColor Yellow
}

if (-not $gradleExists -and -not $androidExists) {
    Write-Host "`nNothing to migrate!" -ForegroundColor Yellow
    exit 0
}

Write-Host "`nStart migration? (y/n): " -NoNewline
$confirm = Read-Host
if ($confirm -ne 'y') {
    Write-Host "Cancelled"
    exit 0
}

# Migrate Gradle cache
if ($gradleExists) {
    Write-Host "`n========== Migrating Gradle Cache ==========" -ForegroundColor Cyan
    $gradleDest = "D:\gradle_cache"

    if (Test-Path $gradleDest) {
        Write-Host "Removing existing destination..."
        Remove-Item $gradleDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Moving files (this may take a few minutes)..."
    robocopy $gradleSource $gradleDest /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NJH /NJS | Out-Null

    if ($LASTEXITCODE -le 7) {
        Write-Host "[SUCCESS] Gradle cache migrated!" -ForegroundColor Green

        Write-Host "Setting environment variable GRADLE_USER_HOME..."
        [Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'D:\gradle_cache', 'User')
        Write-Host "[SUCCESS] Environment variable set" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Migration may have issues, exit code: $LASTEXITCODE" -ForegroundColor Yellow
    }
}

# Migrate Android config
if ($androidExists) {
    Write-Host "`n========== Migrating Android Config ==========" -ForegroundColor Cyan
    $androidDest = "D:\Android\.android"
    $androidParent = "D:\Android"

    if (-not (Test-Path $androidParent)) {
        New-Item -ItemType Directory -Path $androidParent -Force | Out-Null
    }

    if (Test-Path $androidDest) {
        Write-Host "Removing existing destination..."
        Remove-Item $androidDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Moving files (this may take a few minutes)..."
    robocopy $androidSource $androidDest /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NJH /NJS | Out-Null

    if ($LASTEXITCODE -le 7) {
        Write-Host "[SUCCESS] Android config migrated!" -ForegroundColor Green

        Write-Host "Creating symbolic link..."
        cmd /c mklink /D "$androidSource" "$androidDest" 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "[SUCCESS] Symbolic link created" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Failed to create symlink, but files migrated" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[WARNING] Migration may have issues, exit code: $LASTEXITCODE" -ForegroundColor Yellow
    }
}

# Show results
Write-Host "`n========================================"
Write-Host "  Migration Complete!"
Write-Host "========================================"

# Check C drive space
$cDrive = Get-PSDrive -Name C
$freeGB = [math]::Round($cDrive.Free/1GB, 2)
$totalGB = [math]::Round(($cDrive.Used + $cDrive.Free)/1GB, 2)
$usedPercent = [math]::Round(($cDrive.Used/($cDrive.Used + $cDrive.Free))*100, 1)

Write-Host "`nC: Drive Status:"
Write-Host "  Free Space: ${freeGB}GB / ${totalGB}GB" -ForegroundColor Green
Write-Host "  Used: ${usedPercent}%" -ForegroundColor Green

Write-Host "`nNext Steps:"
Write-Host "  1. Restart command prompt for env vars to take effect"
Write-Host "  2. Run 'flutter doctor -v' to verify"
Write-Host "  3. Rebuild your project"
Write-Host ""
