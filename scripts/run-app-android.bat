@echo off
REM 在 Android 模拟器上运行 AI 记账应用

setlocal

set ANDROID_ADB_SERVER_PORT=5038
set ANDROID_HOME=D:\Android\Sdk

echo ===== AI Bookkeeping App Runner (Android) =====
echo.

REM 启动 ADB 服务器
echo [1/5] Starting ADB server on port %ANDROID_ADB_SERVER_PORT%...
"%ANDROID_HOME%\platform-tools\adb.exe" start-server
echo.

REM 检查设备连接
echo [2/5] Checking connected devices...
"%ANDROID_HOME%\platform-tools\adb.exe" devices -l
echo.

REM 切换到 app 目录
cd /d D:\code\ai-bookkeeping\app

REM 清理之前的构建
echo [3/5] Cleaning previous build...
flutter clean
echo.

REM 获取依赖
echo [4/5] Getting dependencies...
flutter pub get
echo.

REM 运行应用
echo [5/5] Building and running app on Android emulator...
echo This may take a few minutes for the first build...
echo.
flutter run -d emulator-5554

echo.
echo Done!
pause
