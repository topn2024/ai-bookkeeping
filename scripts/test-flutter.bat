@echo off
set ANDROID_ADB_SERVER_PORT=5038
set ANDROID_HOME=D:\Android\Sdk

echo Testing Flutter device detection...
echo.

cd /d D:\code\ai-bookkeeping\app

flutter devices --verbose
echo.

pause
