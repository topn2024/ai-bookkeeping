@echo off
echo ========================================
echo  Starting Android Emulator
echo ========================================
echo.

REM Set ADB port
set ANDROID_ADB_SERVER_PORT=5038

echo Using ADB port: 5038
echo.

REM Ensure ADB server is running on port 5038
echo Checking ADB server...
D:\Android\Sdk\platform-tools\adb.exe -L tcp:localhost:5038 devices >nul 2>&1
echo ADB server ready
echo.

echo Starting emulator: AI_Bookkeeping_Emulator
REM Start emulator directly (this will open a window)
start "Android Emulator" /D "D:\Android\Sdk\emulator" emulator.exe -avd AI_Bookkeeping_Emulator -gpu swiftshader_indirect

echo.
echo Emulator window should open shortly...
echo Please wait 30-60 seconds for it to fully boot.
echo.
pause
