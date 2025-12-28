# Auto Migration Script - No confirmation needed
$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  Auto Migration: Gradle + Android"
Write-Host "========================================"
Write-Host ""

$gradleSource = "$env:USERPROFILE\.gradle"
$androidSource = "$env:USERPROFILE\.android"

Write-Host "Source directories:"
Write-Host "  Gradle: $gradleSource"
Write-Host "  Android: $androidSource"
Write-Host ""

$gradleExists = Test-Path $gradleSource
$androidExists = Test-Path $androidSource

if ($gradleExists) {
    $gradleSize = (Get-ChildItem $gradleSource -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $gradleSizeGB = [math]::Round($gradleSize/1GB, 2)
    Write-Host "Gradle cache size: ${gradleSizeGB}GB" -ForegroundColor Green
}

if ($androidExists) {
    $androidSize = (Get-ChildItem $androidSource -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    $androidSizeGB = [math]::Round($androidSize/1GB, 2)
    Write-Host "Android config size: ${androidSizeGB}GB" -ForegroundColor Green
}

if (-not $gradleExists -and -not $androidExists) {
    Write-Host "Nothing to migrate!" -ForegroundColor Yellow
    exit 0
}

Write-Host "`nStarting migration..." -ForegroundColor Cyan

# Migrate Gradle
if ($gradleExists) {
    Write-Host "`n[1/2] Migrating Gradle cache..." -ForegroundColor Cyan
    $gradleDest = "D:\gradle_cache"

    if (Test-Path $gradleDest) {
        Write-Host "  Removing old destination..."
        Remove-Item $gradleDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "  Moving files..."
    $null = robocopy $gradleSource $gradleDest /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NJH /NJS

    if ($LASTEXITCODE -le 7) {
        Write-Host "  [OK] Files moved" -ForegroundColor Green

        Write-Host "  Setting GRADLE_USER_HOME env var..."
        [Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'D:\gradle_cache', 'User')
        Write-Host "  [OK] Gradle migration complete" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Exit code: $LASTEXITCODE" -ForegroundColor Red
    }
}

# Migrate Android
if ($androidExists) {
    Write-Host "`n[2/2] Migrating Android config..." -ForegroundColor Cyan
    $androidDest = "D:\Android\.android"
    $androidParent = "D:\Android"

    if (-not (Test-Path $androidParent)) {
        New-Item -ItemType Directory -Path $androidParent -Force | Out-Null
    }

    if (Test-Path $androidDest) {
        Write-Host "  Removing old destination..."
        Remove-Item $androidDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "  Moving files..."
    $null = robocopy $androidSource $androidDest /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NJH /NJS

    if ($LASTEXITCODE -le 7) {
        Write-Host "  [OK] Files moved" -ForegroundColor Green

        Write-Host "  Creating symbolic link..."
        $null = cmd /c mklink /D "$androidSource" "$androidDest" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Symbolic link created" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Symlink failed but files are migrated" -ForegroundColor Yellow
        }

        Write-Host "  [OK] Android migration complete" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Exit code: $LASTEXITCODE" -ForegroundColor Red
    }
}

Write-Host "`n========================================"
Write-Host "  MIGRATION COMPLETE" -ForegroundColor Green
Write-Host "========================================"

$cDrive = Get-PSDrive -Name C
$freeGB = [math]::Round($cDrive.Free/1GB, 2)
$totalGB = [math]::Round(($cDrive.Used + $cDrive.Free)/1GB, 2)
$usedPercent = [math]::Round(($cDrive.Used/($cDrive.Used + $cDrive.Free))*100, 1)

Write-Host "`nC: Drive: ${freeGB}GB free / ${totalGB}GB total (${usedPercent}% used)" -ForegroundColor Green

Write-Host "`nNEXT STEPS:"
Write-Host "  1. Restart terminal/IDE"
Write-Host "  2. Run: flutter doctor -v"
Write-Host "  3. Test build: flutter build apk"
Write-Host ""
