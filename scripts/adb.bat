@echo off
REM ADB wrapper script - forces use of port 5038 to avoid conflict with LogsAndAlerts service
set ANDROID_ADB_SERVER_PORT=5038
"D:\Android\Sdk\platform-tools\adb.exe" %*
