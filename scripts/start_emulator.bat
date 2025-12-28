@echo off
echo ========================================
echo  Starting Android Emulator
echo ========================================
echo.

REM Set alternative ADB port
set ANDROID_ADB_SERVER_PORT=5038

echo Using ADB port: %ANDROID_ADB_SERVER_PORT%
echo.

REM Kill any existing ADB server
echo Killing existing ADB servers...
D:\Android\Sdk\platform-tools\adb.exe -P 5037 kill-server 2>nul
D:\Android\Sdk\platform-tools\adb.exe -P 5038 kill-server 2>nul
echo.

REM Start ADB server on alternative port
echo Starting ADB server on port 5038...
D:\Android\Sdk\platform-tools\adb.exe -P 5038 start-server
echo.

REM Start emulator in background
echo Starting emulator: AI_Bookkeeping_Emulator
echo This will open in a new window...
echo.
start "Android Emulator" D:\Android\Sdk\emulator\emulator.exe -avd AI_Bookkeeping_Emulator -gpu swiftshader_indirect

REM Wait a bit for emulator to start
timeout /t 10 /nobreak

REM Check devices
echo.
echo Checking for connected devices...
D:\Android\Sdk\platform-tools\adb.exe -P 5038 devices

echo.
echo ========================================
echo Emulator is starting...
echo Wait about 30-60 seconds for it to fully boot
echo.
echo To check status: adb -P 5038 devices
echo To connect Flutter: flutter run
echo ========================================
