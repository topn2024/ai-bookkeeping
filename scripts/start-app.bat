@echo off
setlocal

REM 设置环境变量
set ANDROID_ADB_SERVER_PORT=5038
set ANDROID_HOME=D:\Android\Sdk

echo ===============================================
echo   AI 记账应用启动器
echo ===============================================
echo.

REM 1. 启动 ADB
echo [1/4] 启动 ADB 服务器（端口 %ANDROID_ADB_SERVER_PORT%）...
"%ANDROID_HOME%\platform-tools\adb.exe" start-server
echo.

REM 2. 检查设备
echo [2/4] 检查连接的设备...
"%ANDROID_HOME%\platform-tools\adb.exe" devices -l
echo.

REM 等待用户确认设备已连接
echo 请确认上方显示了 emulator-5554 且状态为 device
echo 如果没有，请等待模拟器完全启动后按任意键继续
pause
echo.

REM 3. 切换到 app 目录
cd /d D:\code\ai-bookkeeping\app

REM 4. 运行应用
echo [3/4] 检测可用设备...
flutter devices
echo.

echo [4/4] 启动应用...
echo 正在构建并安装应用到 Android 模拟器...
echo 首次构建可能需要 3-5 分钟，请耐心等待...
echo.

flutter run -d all

echo.
echo 完成！
pause
