@echo off
REM 运行 AI 记账 App 在 Android 模拟器上

set ANDROID_ADB_SERVER_PORT=5038
set ANDROID_HOME=D:\Android\Sdk

echo ===== AI Bookkeeping App Runner =====
echo.

REM 启动 ADB 服务器
echo [1/4] Starting ADB server on port %ANDROID_ADB_SERVER_PORT%...
"%ANDROID_HOME%\platform-tools\adb.exe" start-server >nul 2>&1

REM 检查设备连接
echo [2/4] Checking connected devices...
"%ANDROID_HOME%\platform-tools\adb.exe" devices -l

echo.
echo [3/4] Building and running Flutter app...
cd /d D:\code\ai-bookkeeping\app

REM 运行 Flutter 应用
flutter run

echo.
echo [4/4] Done!
pause
