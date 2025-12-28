# Start ADB on port 5038

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting ADB on port 5038" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set environment variable for this session
$env:ANDROID_ADB_SERVER_PORT = "5038"
Write-Host "Set ANDROID_ADB_SERVER_PORT = 5038" -ForegroundColor Green

# Kill any existing ADB servers
Write-Host ""
Write-Host "Killing existing ADB servers..."
D:\Android\Sdk\platform-tools\adb.exe -P 5037 kill-server 2>$null
D:\Android\Sdk\platform-tools\adb.exe -P 5038 kill-server 2>$null

# Start ADB server
Write-Host ""
Write-Host "Starting ADB server on port 5038..." -ForegroundColor Yellow
$output = D:\Android\Sdk\platform-tools\adb.exe start-server 2>&1
Write-Host $output

# Verify
Write-Host ""
Write-Host "Verifying ADB server..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
$devices = D:\Android\Sdk\platform-tools\adb.exe devices
Write-Host $devices

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ADB Server Status:" -ForegroundColor Cyan

# Check port
$port = netstat -ano | Select-String "5038"
if ($port) {
    Write-Host "[OK] ADB listening on port 5038" -ForegroundColor Green
    Write-Host $port
} else {
    Write-Host "[WARN] Port 5038 not found in netstat" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "To use this ADB server, set:" -ForegroundColor Yellow
Write-Host '  $env:ANDROID_ADB_SERVER_PORT = "5038"' -ForegroundColor Gray
Write-Host "  OR use: adb -P 5038 <command>" -ForegroundColor Gray
Write-Host ""
