@echo off
setlocal

set ANDROID_ADB_SERVER_PORT=5038
set ANDROID_HOME=D:\Android\Sdk
set APK_PATH=D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk\app-debug.apk

echo ===============================================
echo   AI 记账应用 - APK 安装器
echo ===============================================
echo.

REM 检查 APK 文件
echo [1/6] 检查 APK 文件...
if not exist "%APK_PATH%" (
    echo 错误：APK 文件不存在！
    echo 路径：%APK_PATH%
    pause
    exit /b 1
)
echo ✓ APK 文件存在
echo.

REM 停止 ADB
echo [2/6] 停止 ADB 服务器...
"%ANDROID_HOME%\platform-tools\adb.exe" kill-server 2>nul
echo.

REM 等待
echo [3/6] 等待 3 秒...
timeout /t 3 /nobreak >nul
echo.

REM 启动 ADB
echo [4/6] 启动 ADB 服务器（端口 %ANDROID_ADB_SERVER_PORT%）...
"%ANDROID_HOME%\platform-tools\adb.exe" start-server
echo.

REM 等待设备
echo [5/6] 等待设备连接...
echo 请确保模拟器已完全启动（能看到 Android 桌面）
echo.
timeout /t 10 /nobreak
echo.

REM 显示设备
echo 当前连接的设备：
"%ANDROID_HOME%\platform-tools\adb.exe" devices -l
echo.

echo 如果上方显示 'emulator-5554 device'，请按任意键继续安装
echo 如果显示 'offline' 或没有设备，请：
echo   1. 等待模拟器完全启动
echo   2. 重新运行此脚本
echo.
pause
echo.

REM 安装 APK
echo [6/6] 正在安装 APK...
echo 这可能需要 30-60 秒，请稍候...
echo.
"%ANDROID_HOME%\platform-tools\adb.exe" install -r "%APK_PATH%"

if %errorlevel% equ 0 (
    echo.
    echo ===============================================
    echo   ✓ 安装成功！
    echo ===============================================
    echo.
    echo 现在可以在模拟器中找到 "AI Bookkeeping" 应用
    echo 或运行以下命令启动应用：
    echo.
    echo   adb shell am start -n com.example.ai_bookkeeping/.MainActivity
    echo.
) else (
    echo.
    echo ===============================================
    echo   × 安装失败
    echo ===============================================
    echo.
    echo 可能的原因：
    echo   1. 设备未连接或 offline
    echo   2. APK 文件损坏
    echo   3. 设备存储空间不足
    echo.
    echo 解决方法：
    echo   1. 确保模拟器完全启动
    echo   2. 重启 ADB：adb kill-server 然后 adb start-server
    echo   3. 重新运行此脚本
    echo.
)

pause
