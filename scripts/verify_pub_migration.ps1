Write-Host "Verifying Pub cache migration..." -ForegroundColor Cyan
Write-Host ""

# Check new location
if (Test-Path 'D:\flutter_pub_cache') {
    Write-Host "[OK] New location exists: D:\flutter_pub_cache" -ForegroundColor Green
    $count = (Get-ChildItem 'D:\flutter_pub_cache' -Recurse -File -ErrorAction SilentlyContinue).Count
    Write-Host "[OK] Files migrated: $count" -ForegroundColor Green
} else {
    Write-Host "[ERROR] New location not found" -ForegroundColor Red
}

Write-Host ""

# Check old location
if (Test-Path 'C:\Users\l00629826\AppData\Local\Pub\Cache') {
    Write-Host "[WARN] Old location still exists" -ForegroundColor Yellow
} else {
    Write-Host "[OK] Old location removed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Environment variable:" -ForegroundColor Cyan
$pubCache = [Environment]::GetEnvironmentVariable('PUB_CACHE', 'User')
if ($pubCache) {
    Write-Host "PUB_CACHE = $pubCache" -ForegroundColor Green
} else {
    Write-Host "PUB_CACHE not set" -ForegroundColor Yellow
}

Write-Host ""

# Check disk space
$cDrive = Get-PSDrive -Name C
$freeGB = [math]::Round($cDrive.Free/1GB, 2)
Write-Host "C: Drive free space: ${freeGB}GB" -ForegroundColor Green
