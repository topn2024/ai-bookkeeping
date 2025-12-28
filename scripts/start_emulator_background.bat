@echo off
REM Launch emulator in background without blocking

set ANDROID_ADB_SERVER_PORT=5038

echo Starting Android Emulator in background...
start /B "" "D:\Android\Sdk\emulator\emulator.exe" -avd AI_Bookkeeping_Emulator -gpu swiftshader_indirect

echo Emulator launched. It will start in a separate window.
echo Please wait 30-60 seconds for it to fully boot.
