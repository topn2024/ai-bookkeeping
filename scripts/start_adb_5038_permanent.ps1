# Permanently configure and start ADB on port 5038
# This script ensures ADB ALWAYS uses port 5038, never 5037

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Configure ADB to use Port 5038" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Set environment variable for current session
$env:ANDROID_ADB_SERVER_PORT = "5038"
Write-Host "[1/5] Set ANDROID_ADB_SERVER_PORT=5038 for current session" -ForegroundColor Green

# Step 2: Verify permanent environment variable (already set)
$permanentPort = [Environment]::GetEnvironmentVariable('ANDROID_ADB_SERVER_PORT', 'User')
if ($permanentPort -eq "5038") {
    Write-Host "[2/5] Permanent environment variable confirmed: $permanentPort" -ForegroundColor Green
} else {
    Write-Host "[2/5] Setting permanent environment variable..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable('ANDROID_ADB_SERVER_PORT', '5038', 'User')
    Write-Host "      Permanent environment variable set to 5038" -ForegroundColor Green
}

# Step 3: Kill all ADB servers
Write-Host ""
Write-Host "[3/5] Killing all ADB servers..." -ForegroundColor Yellow
D:\Android\Sdk\platform-tools\adb.exe -P 5037 kill-server 2>$null
D:\Android\Sdk\platform-tools\adb.exe -P 5038 kill-server 2>$null
Start-Sleep -Seconds 2
Write-Host "      All ADB servers stopped" -ForegroundColor Gray

# Step 4: Start ADB server on port 5038
Write-Host ""
Write-Host "[4/5] Starting ADB server on port 5038..." -ForegroundColor Yellow
$output = D:\Android\Sdk\platform-tools\adb.exe -P 5038 start-server 2>&1
Write-Host "      $output" -ForegroundColor Gray

# Step 5: Verify it's running on correct port
Write-Host ""
Write-Host "[5/5] Verifying ADB server..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

$port5038 = netstat -ano | Select-String "127.0.0.1:5038.*LISTENING"
$port5037 = netstat -ano | Select-String "127.0.0.1:5037.*LISTENING"

if ($port5038) {
    Write-Host "      [OK] ADB server is running on port 5038" -ForegroundColor Green
    Write-Host "      $port5038" -ForegroundColor Gray
} else {
    Write-Host "      [WARN] ADB server NOT detected on port 5038" -ForegroundColor Red
}

if ($port5037) {
    $pid = ($port5037 -split '\s+')[-1]
    Write-Host ""
    Write-Host "      [INFO] Port 5037 is occupied by PID $pid (system service)" -ForegroundColor Yellow
    Write-Host "      This is normal - we're using 5038 instead" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ADB Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "From now on, ALL commands should use port 5038:" -ForegroundColor Cyan
Write-Host "  adb devices" -ForegroundColor Gray
Write-Host "  flutter devices" -ForegroundColor Gray
Write-Host "  flutter run" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTE: Close and reopen your terminal for permanent settings to take effect" -ForegroundColor Yellow
Write-Host ""
