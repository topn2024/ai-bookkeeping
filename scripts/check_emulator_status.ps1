# Check Android Emulator Status

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Android Emulator Status Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check emulator processes
Write-Host "[1] Emulator Processes:" -ForegroundColor Yellow
$emulatorProc = Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"}
if ($emulatorProc) {
    Write-Host "  [OK] Emulator process running:" -ForegroundColor Green
    $emulatorProc | Select-Object ProcessName, Id, @{Name='Memory(MB)';Expression={[math]::Round($_.WorkingSet64/1MB,0)}} | Format-Table
} else {
    Write-Host "  [X] No emulator process found" -ForegroundColor Red
}

Write-Host ""
Write-Host "[2] ADB Server Status:" -ForegroundColor Yellow
$adbPort = Get-NetTCPConnection -LocalPort 5038 -State Listen -ErrorAction SilentlyContinue
if ($adbPort) {
    Write-Host "  [OK] ADB server running on port 5038 (PID: $($adbPort.OwningProcess))" -ForegroundColor Green
} else {
    Write-Host "  [X] ADB server not running on port 5038" -ForegroundColor Red
    Write-Host "      Run: .\scripts\configure_adb_port_5038.ps1" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[3] Connected Devices:" -ForegroundColor Yellow
$env:ANDROID_ADB_SERVER_PORT = "5038"
$devices = D:\Android\Sdk\platform-tools\adb.exe -L tcp:localhost:5038 devices 2>&1
Write-Host $devices

Write-Host ""
Write-Host "[4] Emulator Boot Status:" -ForegroundColor Yellow
$env:ANDROID_ADB_SERVER_PORT = "5038"
$bootComplete = D:\Android\Sdk\platform-tools\adb.exe -L tcp:localhost:5038 shell getprop sys.boot_completed 2>&1
if ($bootComplete -match "1") {
    Write-Host "  [OK] Emulator fully booted!" -ForegroundColor Green
} elseif ($bootComplete -match "offline") {
    Write-Host "  [WAIT] Emulator is still booting..." -ForegroundColor Yellow
    Write-Host "        Please wait and run this script again in 30 seconds" -ForegroundColor Gray
} else {
    Write-Host "  [WAIT] Boot status: $bootComplete" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
