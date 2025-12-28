# Complete ADB Port 5038 Configuration Script
# This script permanently configures ADB to use port 5038 instead of 5037

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ADB Port 5038 Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Define paths
$adbPath = "D:\Android\Sdk\platform-tools\adb.exe"

# Step 1: Set environment variable permanently
Write-Host "[Step 1/6] Setting permanent environment variable..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable('ANDROID_ADB_SERVER_PORT', '5038', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_ADB_SERVER_PORT', '5038', 'Machine')
$env:ANDROID_ADB_SERVER_PORT = "5038"
Write-Host "  ANDROID_ADB_SERVER_PORT = 5038 (User + Machine + Session)" -ForegroundColor Green
Write-Host ""

# Step 2: Kill all existing ADB processes
Write-Host "[Step 2/6] Stopping all ADB processes..." -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -eq 'adb'} | ForEach-Object {
    Write-Host "  Killing ADB process PID $($_.Id)" -ForegroundColor Gray
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 2
Write-Host "  All ADB processes stopped" -ForegroundColor Green
Write-Host ""

# Step 3: Kill servers on both ports
Write-Host "[Step 3/6] Killing ADB servers on both ports..." -ForegroundColor Yellow
& $adbPath -P 5037 kill-server 2>$null
& $adbPath -P 5038 kill-server 2>$null
Start-Sleep -Seconds 2
Write-Host "  ADB servers killed" -ForegroundColor Green
Write-Host ""

# Step 4: Start ADB server on port 5038 using -L option
Write-Host "[Step 4/6] Starting ADB server on port 5038..." -ForegroundColor Yellow
Write-Host "  Using command: adb -L tcp:localhost:5038 fork-server server" -ForegroundColor Gray

# Start the ADB server process in background
$processInfo = New-Object System.Diagnostics.ProcessStartInfo
$processInfo.FileName = $adbPath
$processInfo.Arguments = "-L tcp:localhost:5038 fork-server server --reply-fd 1"
$processInfo.UseShellExecute = $false
$processInfo.RedirectStandardOutput = $true
$processInfo.RedirectStandardError = $true
$processInfo.CreateNoWindow = $true
$processInfo.EnvironmentVariables["ANDROID_ADB_SERVER_PORT"] = "5038"

$process = New-Object System.Diagnostics.Process
$process.StartInfo = $processInfo

try {
    $process.Start() | Out-Null
    Write-Host "  ADB server process started (PID: $($process.Id))" -ForegroundColor Green
    Start-Sleep -Seconds 3
} catch {
    Write-Host "  Error starting ADB server: $_" -ForegroundColor Red
}

Write-Host ""

# Step 5: Verify server is running
Write-Host "[Step 5/6] Verifying ADB server..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# Check network ports
$port5038 = Get-NetTCPConnection -LocalPort 5038 -State Listen -ErrorAction SilentlyContinue
$port5037 = Get-NetTCPConnection -LocalPort 5037 -State Listen -ErrorAction SilentlyContinue

if ($port5038) {
    Write-Host "  [OK] Port 5038 is LISTENING" -ForegroundColor Green
    Write-Host "      Process ID: $($port5038.OwningProcess)" -ForegroundColor Gray
} else {
    Write-Host "  [WARN] Port 5038 is NOT listening" -ForegroundColor Red
    Write-Host "  Trying alternative method..." -ForegroundColor Yellow

    # Alternative: Start server using nodaemon in background job
    $job = Start-Job -ScriptBlock {
        param($adb)
        $env:ANDROID_ADB_SERVER_PORT = "5038"
        & $adb -L tcp:localhost:5038 nodaemon server 2>&1
    } -ArgumentList $adbPath

    Write-Host "  Started ADB server as background job (ID: $($job.Id))" -ForegroundColor Gray
    Start-Sleep -Seconds 3

    # Check again
    $port5038 = Get-NetTCPConnection -LocalPort 5038 -State Listen -ErrorAction SilentlyContinue
    if ($port5038) {
        Write-Host "  [OK] Port 5038 is now LISTENING" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Failed to start ADB on port 5038" -ForegroundColor Red
    }
}

if ($port5037) {
    Write-Host "  [INFO] Port 5037 is occupied by PID $($port5037.OwningProcess)" -ForegroundColor Yellow
    Write-Host "      (System service - this is why we use 5038)" -ForegroundColor Gray
}

Write-Host ""

# Step 6: Test ADB connectivity
Write-Host "[Step 6/6] Testing ADB connectivity..." -ForegroundColor Yellow
$env:ANDROID_ADB_SERVER_PORT = "5038"
$devices = & $adbPath -L tcp:localhost:5038 devices 2>&1
Write-Host "  $devices" -ForegroundColor Gray

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage instructions:" -ForegroundColor Cyan
Write-Host "  All ADB commands should now use port 5038" -ForegroundColor White
Write-Host "  Run commands like this:" -ForegroundColor White
Write-Host "    adb -L tcp:localhost:5038 devices" -ForegroundColor Gray
Write-Host "    adb -L tcp:localhost:5038 shell" -ForegroundColor Gray
Write-Host ""
Write-Host "For Flutter:" -ForegroundColor Cyan
Write-Host "  flutter devices" -ForegroundColor Gray
Write-Host "  flutter run" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTE: Restart your terminal/IDE for environment variables to fully take effect" -ForegroundColor Yellow
Write-Host ""
