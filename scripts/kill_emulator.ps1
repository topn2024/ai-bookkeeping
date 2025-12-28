# Kill all emulator processes
Write-Host "Killing emulator processes..." -ForegroundColor Yellow

$procs = Get-Process | Where-Object {$_.ProcessName -like "*emulator*" -or $_.ProcessName -like "*qemu*"}
if ($procs) {
    $procs | ForEach-Object {
        Write-Host "  Killing: $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Gray
        Stop-Process -Id $_.Id -Force
    }
    Write-Host "[OK] Emulator processes killed" -ForegroundColor Green
} else {
    Write-Host "[INFO] No emulator processes found" -ForegroundColor Cyan
}

# Also kill ADB
Write-Host ""
Write-Host "Killing ADB servers..." -ForegroundColor Yellow
D:\Android\Sdk\platform-tools\adb.exe -P 5037 kill-server 2>$null
D:\Android\Sdk\platform-tools\adb.exe -L tcp:localhost:5038 kill-server 2>$null
Get-Process | Where-Object {$_.ProcessName -eq "adb"} | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "[OK] ADB servers killed" -ForegroundColor Green
Write-Host ""
