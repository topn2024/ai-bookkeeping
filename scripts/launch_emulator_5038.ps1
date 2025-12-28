# Launch Android Emulator with ADB on port 5038

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Launching Android Emulator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Set ADB port
$env:ANDROID_ADB_SERVER_PORT = "5038"
Write-Host "[1/4] Set ANDROID_ADB_SERVER_PORT = 5038" -ForegroundColor Green

# Kill old processes
Write-Host ""
Write-Host "[2/4] Cleaning up old emulator processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"} | Stop-Process -Force -ErrorAction SilentlyContinue 2>$null

# Ensure ADB server is running on port 5038
Write-Host ""
Write-Host "[3/4] Ensuring ADB server is running on port 5038..." -ForegroundColor Yellow
$adbPort = Get-NetTCPConnection -LocalPort 5038 -State Listen -ErrorAction SilentlyContinue
if (-not $adbPort) {
    Write-Host "      Starting ADB server..." -ForegroundColor Gray
    D:\Android\Sdk\platform-tools\adb.exe -L tcp:localhost:5038 fork-server server
    Start-Sleep -Seconds 3
} else {
    Write-Host "      ADB server already running" -ForegroundColor Gray
}

# Launch emulator
Write-Host ""
Write-Host "[4/4] Launching emulator..." -ForegroundColor Yellow
Write-Host "      AVD: AI_Bookkeeping_Emulator" -ForegroundColor Gray
Write-Host "      This will open in a new window..." -ForegroundColor Gray
Write-Host ""

$emulatorPath = "D:\Android\Sdk\emulator\emulator.exe"
$avdName = "AI_Bookkeeping_Emulator"

# Start emulator in background
Start-Process -FilePath $emulatorPath -ArgumentList "-avd", $avdName, "-gpu", "swiftshader_indirect" -WindowStyle Normal

Write-Host "[OK] Emulator is starting..." -ForegroundColor Green
Write-Host ""
Write-Host "Please wait 30-60 seconds for the emulator to fully boot." -ForegroundColor Yellow
Write-Host ""
Write-Host "To check status:" -ForegroundColor Cyan
Write-Host "  adb -L tcp:localhost:5038 devices" -ForegroundColor Gray
Write-Host ""
Write-Host "To run your app:" -ForegroundColor Cyan
Write-Host '  $env:ANDROID_ADB_SERVER_PORT = "5038"' -ForegroundColor Gray
Write-Host "  flutter devices" -ForegroundColor Gray
Write-Host "  flutter run" -ForegroundColor Gray
Write-Host ""
