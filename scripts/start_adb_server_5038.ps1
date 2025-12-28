# Simple ADB Server Starter for Port 5038
# Keeps the ADB server running in the foreground

$env:ANDROID_ADB_SERVER_PORT = "5038"
$adbPath = "D:\Android\Sdk\platform-tools\adb.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ADB Server on Port 5038" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting ADB server..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
Write-Host ""

# Run ADB server in nodaemon mode (foreground)
& $adbPath -L tcp:localhost:5038 nodaemon server
