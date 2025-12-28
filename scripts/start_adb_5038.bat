@echo off
echo ========================================
echo  Starting ADB on Port 5038
echo ========================================
echo.

REM Set the ADB server port
set ANDROID_ADB_SERVER_PORT=5038

echo [1/3] Environment variable set: ANDROID_ADB_SERVER_PORT=%ANDROID_ADB_SERVER_PORT%
echo.

echo [2/3] Killing existing ADB servers...
D:\Android\Sdk\platform-tools\adb.exe -P 5037 kill-server 2>nul
D:\Android\Sdk\platform-tools\adb.exe -P 5038 kill-server 2>nul
timeout /t 2 /nobreak >nul
echo       Done
echo.

echo [3/3] Starting ADB server on port 5038...
D:\Android\Sdk\platform-tools\adb.exe -P 5038 start-server
echo.

echo ========================================
echo  Verifying ADB Server
echo ========================================
echo.
timeout /t 2 /nobreak >nul

netstat -ano | findstr "5038.*LISTENING"
if %errorlevel% == 0 (
    echo [OK] ADB server is running on port 5038
) else (
    echo [ERROR] ADB server failed to start on port 5038
)
echo.
