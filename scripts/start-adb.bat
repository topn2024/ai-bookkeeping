@echo off
REM 设置 ADB 服务器使用备用端口 5038（避免与系统服务 LogsAndAlerts 冲突）
set ANDROID_ADB_SERVER_PORT=5038
set ANDROID_HOME=D:\Android\Sdk

echo Starting ADB server on port %ANDROID_ADB_SERVER_PORT%...
"%ANDROID_HOME%\platform-tools\adb.exe" start-server

echo.
echo Checking connected devices...
"%ANDROID_HOME%\platform-tools\adb.exe" devices -l

echo.
echo ADB server is running on port %ANDROID_ADB_SERVER_PORT%
echo Use this script to run ADB/Flutter commands with correct port settings.
