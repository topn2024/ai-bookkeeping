# ============================================================
# Android 模拟器快速启动脚本
# ============================================================

param(
    [string]$AvdName = "Pixel_6_API_34",
    [switch]$Cold,
    [switch]$WipeData,
    [switch]$NoWindow
)

$ErrorActionPreference = "SilentlyContinue"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "           Android Emulator 快速启动" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 检查 ANDROID_HOME
$androidHome = $env:ANDROID_HOME
if (-not $androidHome) {
    $androidHome = "$env:LOCALAPPDATA\Android\Sdk"
}

$emulatorPath = "$androidHome\emulator\emulator.exe"

if (-not (Test-Path $emulatorPath)) {
    Write-Host "[ERROR] 未找到 Android Emulator" -ForegroundColor Red
    Write-Host "请确保已安装 Android SDK 并配置 ANDROID_HOME 环境变量"
    exit 1
}

# 列出可用的 AVD
Write-Host "`n可用的模拟器:" -ForegroundColor Yellow
& $emulatorPath -list-avds

# 检查指定的 AVD 是否存在
$avds = & $emulatorPath -list-avds
if ($avds -notcontains $AvdName) {
    Write-Host "`n[ERROR] 模拟器 '$AvdName' 不存在" -ForegroundColor Red
    Write-Host "请使用 Android Studio Device Manager 创建模拟器"
    exit 1
}

# 构建启动参数
$args = @("-avd", $AvdName)

if ($Cold) {
    $args += "-no-snapshot-load"
    Write-Host "启动模式: 冷启动 (不加载快照)" -ForegroundColor Yellow
}

if ($WipeData) {
    $args += "-wipe-data"
    Write-Host "启动模式: 清除数据" -ForegroundColor Yellow
}

if ($NoWindow) {
    $args += "-no-window"
    Write-Host "启动模式: 无窗口 (headless)" -ForegroundColor Yellow
}

# GPU 加速
$args += @("-gpu", "auto")

Write-Host "`n正在启动模拟器: $AvdName" -ForegroundColor Green
Write-Host "请等待模拟器窗口出现..."

# 启动模拟器
Start-Process -FilePath $emulatorPath -ArgumentList $args

# 等待模拟器启动
Write-Host "`n等待模拟器启动完成..." -ForegroundColor Yellow

$adbPath = "$androidHome\platform-tools\adb.exe"
$timeout = 120
$elapsed = 0

while ($elapsed -lt $timeout) {
    Start-Sleep -Seconds 2
    $elapsed += 2

    $bootComplete = & $adbPath shell getprop sys.boot_completed 2>$null
    if ($bootComplete -eq "1") {
        Write-Host "`n[OK] 模拟器启动完成! (耗时 $elapsed 秒)" -ForegroundColor Green
        break
    }

    Write-Host "." -NoNewline
}

if ($elapsed -ge $timeout) {
    Write-Host "`n[WARN] 模拟器启动超时，但可能仍在启动中" -ForegroundColor Yellow
}

# 显示设备信息
Write-Host "`n已连接的设备:" -ForegroundColor Cyan
& $adbPath devices

Write-Host @"

============================================================
模拟器已就绪！

常用命令:
---------
flutter devices          # 查看设备列表
flutter run              # 运行应用
adb shell                # 进入模拟器 Shell
adb logcat               # 查看日志

关闭模拟器:
----------
adb emu kill             # 命令行关闭
或直接关闭模拟器窗口

============================================================
"@
