@echo off
REM Flutter 开发环境启动脚本
REM 设置 ADB 使用备用端口 5038

set ANDROID_ADB_SERVER_PORT=5038
set ANDROID_HOME=D:\Android\Sdk

REM 启动 ADB 服务器
echo Starting ADB server on port %ANDROID_ADB_SERVER_PORT%...
"%ANDROID_HOME%\platform-tools\adb.exe" start-server

REM 切换到 app 目录
cd /d D:\code\ai-bookkeeping\app

REM 显示可用设备
echo.
echo Available devices:
flutter devices

echo.
echo Flutter development environment ready!
echo You can now run: flutter run, flutter build, etc.
echo.

REM 保持环境变量并进入交互式命令行
cmd /k
