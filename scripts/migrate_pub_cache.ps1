# Migrate Pub Cache to D drive

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  Migrating Pub Cache to D drive"
Write-Host "========================================"
Write-Host ""

$pubSource = "$env:LOCALAPPDATA\Pub\Cache"
$pubDest = "D:\flutter_pub_cache"

Write-Host "Source: $pubSource"
Write-Host "Destination: $pubDest"
Write-Host ""

if (-not (Test-Path $pubSource)) {
    Write-Host "[ERROR] Pub cache not found at source location" -ForegroundColor Red
    exit 1
}

# Calculate size
Write-Host "Calculating size..."
$files = Get-ChildItem $pubSource -Recurse -File -ErrorAction SilentlyContinue
$totalSize = ($files | Measure-Object -Property Length -Sum).Sum
$sizeGB = [math]::Round($totalSize/1GB, 2)
$fileCount = $files.Count

Write-Host "Pub cache size: ${sizeGB}GB ($fileCount files)" -ForegroundColor Green
Write-Host ""

# Create destination if needed
if (-not (Test-Path $pubDest)) {
    Write-Host "Creating destination directory..."
    New-Item -ItemType Directory -Path $pubDest -Force | Out-Null
} else {
    Write-Host "[WARN] Destination already exists, removing..." -ForegroundColor Yellow
    Remove-Item $pubDest -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $pubDest -Force | Out-Null
}

Write-Host "Moving Pub cache (this may take a few minutes)..."
Write-Host ""

# Use robocopy to move files
$result = robocopy $pubSource $pubDest /E /MOVE /R:3 /W:5 /MT:8 /NFL /NDL /NJH /NJS

if ($LASTEXITCODE -le 7) {
    Write-Host "[SUCCESS] Pub cache moved!" -ForegroundColor Green

    # Set environment variable
    Write-Host ""
    Write-Host "Setting PUB_CACHE environment variable..."
    [Environment]::SetEnvironmentVariable('PUB_CACHE', 'D:\flutter_pub_cache', 'User')
    Write-Host "[SUCCESS] Environment variable set" -ForegroundColor Green

    # Configure Flutter
    Write-Host ""
    Write-Host "Configuring Flutter to use new cache location..."
    try {
        D:\flutter\bin\flutter config --pub-cache D:\flutter_pub_cache | Out-Null
        Write-Host "[SUCCESS] Flutter configured" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Flutter config failed: $_" -ForegroundColor Yellow
    }

} else {
    Write-Host "[ERROR] Migration failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Migration Complete!"
Write-Host "========================================"
Write-Host ""

# Check C drive space
$cDrive = Get-PSDrive -Name C
$freeGB = [math]::Round($cDrive.Free/1GB, 2)
$totalGB = [math]::Round(($cDrive.Used + $cDrive.Free)/1GB, 2)
$usedPercent = [math]::Round(($cDrive.Used/($cDrive.Used + $cDrive.Free))*100, 1)

Write-Host "C: Drive: ${freeGB}GB free / ${totalGB}GB total (${usedPercent}% used)" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Restart your terminal/IDE for changes to take effect"
Write-Host ""
