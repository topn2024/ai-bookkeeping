# ============================================================
# AI智能记账 - Android开发环境自动安装脚本 (Windows)
# ============================================================
# 使用方法: 以管理员权限运行 PowerShell，执行此脚本
# PowerShell -ExecutionPolicy Bypass -File setup-android-dev-env.ps1
# ============================================================

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-Step { param($msg) Write-Host "`n[STEP] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "     AI智能记账 - Android开发环境安装程序" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

# 检查是否以管理员权限运行
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "请以管理员权限运行此脚本！"
    Write-Host "右键点击 PowerShell -> 以管理员身份运行"
    exit 1
}

# ============================================================
# 1. 安装 Chocolatey (Windows包管理器)
# ============================================================
Write-Step "检查/安装 Chocolatey 包管理器..."

if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Success "Chocolatey 已安装"
} else {
    Write-Host "正在安装 Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Success "Chocolatey 安装完成"
}

# ============================================================
# 2. 安装 Git
# ============================================================
Write-Step "检查/安装 Git..."

if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitVersion = git --version
    Write-Success "Git 已安装: $gitVersion"
} else {
    Write-Host "正在安装 Git..."
    choco install git -y
    refreshenv
    Write-Success "Git 安装完成"
}

# ============================================================
# 3. 安装 JDK 17 (Android开发推荐版本)
# ============================================================
Write-Step "检查/安装 JDK 17..."

$javaInstalled = $false
if (Get-Command java -ErrorAction SilentlyContinue) {
    $javaVersion = java -version 2>&1 | Select-String "version"
    if ($javaVersion -match "17") {
        Write-Success "JDK 17 已安装: $javaVersion"
        $javaInstalled = $true
    }
}

if (-not $javaInstalled) {
    Write-Host "正在安装 JDK 17 (Microsoft OpenJDK)..."
    choco install microsoft-openjdk17 -y

    # 设置 JAVA_HOME
    $javaPath = "C:\Program Files\Microsoft\jdk-17*"
    $javaHome = (Get-ChildItem $javaPath -Directory | Select-Object -First 1).FullName
    if ($javaHome) {
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")
        $env:JAVA_HOME = $javaHome
        Write-Success "JAVA_HOME 已设置: $javaHome"
    }
    refreshenv
    Write-Success "JDK 17 安装完成"
}

# ============================================================
# 4. 安装 Android Studio
# ============================================================
Write-Step "检查/安装 Android Studio..."

$androidStudioPath = "C:\Program Files\Android\Android Studio"
if (Test-Path $androidStudioPath) {
    Write-Success "Android Studio 已安装"
} else {
    Write-Host "正在安装 Android Studio..."
    Write-Warning "这可能需要较长时间，请耐心等待..."
    choco install androidstudio -y
    Write-Success "Android Studio 安装完成"
}

# ============================================================
# 5. 配置 Android SDK
# ============================================================
Write-Step "配置 Android SDK..."

$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
if (-not (Test-Path $sdkPath)) {
    Write-Warning "Android SDK 未找到，请先运行 Android Studio 完成初始化设置"
    Write-Host @"

请按以下步骤操作:
1. 打开 Android Studio
2. 完成初始向导
3. 等待 SDK 下载完成
4. 重新运行此脚本

"@
} else {
    # 设置环境变量
    [System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkPath, "User")
    [System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkPath, "User")
    $env:ANDROID_HOME = $sdkPath
    $env:ANDROID_SDK_ROOT = $sdkPath

    # 添加到 PATH
    $pathAdditions = @(
        "$sdkPath\cmdline-tools\latest\bin",
        "$sdkPath\platform-tools",
        "$sdkPath\emulator",
        "$sdkPath\tools",
        "$sdkPath\tools\bin"
    )

    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    foreach ($path in $pathAdditions) {
        if ($currentPath -notlike "*$path*") {
            $currentPath = "$currentPath;$path"
        }
    }
    [System.Environment]::SetEnvironmentVariable("Path", $currentPath, "User")

    Write-Success "Android SDK 环境变量已配置"
    Write-Host "  ANDROID_HOME: $sdkPath"
}

# ============================================================
# 6. 安装 Flutter SDK
# ============================================================
Write-Step "检查/安装 Flutter SDK..."

$flutterPath = "C:\flutter"
if (Test-Path "$flutterPath\bin\flutter.bat") {
    Write-Success "Flutter 已安装"
} else {
    Write-Host "正在下载 Flutter SDK..."

    # 创建目录
    if (-not (Test-Path "C:\flutter")) {
        New-Item -ItemType Directory -Path "C:\flutter" -Force | Out-Null
    }

    # 下载最新稳定版
    $flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.2-stable.zip"
    $zipPath = "$env:TEMP\flutter.zip"

    Write-Host "下载中... (约1GB，请耐心等待)"
    Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath -UseBasicParsing

    Write-Host "解压中..."
    Expand-Archive -Path $zipPath -DestinationPath "C:\" -Force
    Remove-Item $zipPath -Force

    Write-Success "Flutter SDK 下载完成"
}

# 添加 Flutter 到 PATH
$flutterBinPath = "C:\flutter\bin"
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$flutterBinPath*") {
    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterBinPath", "User")
    $env:Path = "$env:Path;$flutterBinPath"
}
Write-Success "Flutter PATH 已配置"

# ============================================================
# 7. 安装 Android SDK 组件
# ============================================================
Write-Step "安装必要的 Android SDK 组件..."

if (Test-Path "$sdkPath\cmdline-tools\latest\bin\sdkmanager.bat") {
    Write-Host "正在安装 SDK 组件..."

    $sdkmanager = "$sdkPath\cmdline-tools\latest\bin\sdkmanager.bat"

    # 接受许可证
    Write-Host "接受 Android SDK 许可证..."
    echo "y" | & $sdkmanager --licenses 2>$null

    # 安装必要组件
    $components = @(
        "platform-tools",
        "platforms;android-34",
        "build-tools;34.0.0",
        "system-images;android-34;google_apis;x86_64",
        "emulator"
    )

    foreach ($component in $components) {
        Write-Host "  安装: $component"
        & $sdkmanager $component --verbose 2>$null
    }

    Write-Success "SDK 组件安装完成"
} else {
    Write-Warning "sdkmanager 未找到，请通过 Android Studio 安装 SDK 组件"
}

# ============================================================
# 8. 创建 Android 模拟器
# ============================================================
Write-Step "创建 Android 模拟器..."

if (Test-Path "$sdkPath\emulator\emulator.exe") {
    $avdmanager = "$sdkPath\cmdline-tools\latest\bin\avdmanager.bat"

    if (Test-Path $avdmanager) {
        # 检查是否已存在模拟器
        $existingAvds = & $avdmanager list avd 2>$null

        if ($existingAvds -notmatch "Pixel_6_API_34") {
            Write-Host "创建 Pixel 6 API 34 模拟器..."

            echo "no" | & $avdmanager create avd `
                --name "Pixel_6_API_34" `
                --package "system-images;android-34;google_apis;x86_64" `
                --device "pixel_6" `
                --force 2>$null

            Write-Success "模拟器 Pixel_6_API_34 创建完成"
        } else {
            Write-Success "模拟器 Pixel_6_API_34 已存在"
        }
    }
} else {
    Write-Warning "模拟器未安装，请通过 Android Studio 安装"
}

# ============================================================
# 9. Flutter 配置
# ============================================================
Write-Step "配置 Flutter..."

# 刷新环境变量
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    # 配置 Flutter
    flutter config --android-sdk $sdkPath 2>$null
    flutter config --no-analytics 2>$null

    # 接受许可证
    Write-Host "接受 Flutter Android 许可证..."
    echo "y`ny`ny`ny`ny`ny`ny`ny" | flutter doctor --android-licenses 2>$null

    Write-Success "Flutter 配置完成"
} else {
    Write-Warning "请重启 PowerShell 后运行 flutter doctor"
}

# ============================================================
# 10. 最终检查
# ============================================================
Write-Step "运行环境检查..."

Write-Host "`n============================================================"
Write-Host "                    环境安装完成！" -ForegroundColor Green
Write-Host "============================================================"

Write-Host @"

下一步操作:
-----------
1. 关闭并重新打开 PowerShell (刷新环境变量)

2. 运行环境检查:
   flutter doctor -v

3. 启动模拟器:
   flutter emulators --launch Pixel_6_API_34

4. 运行项目:
   cd D:\code\ai-bookkeeping
   flutter run

如果遇到问题:
-------------
- 确保已完成 Android Studio 初始化向导
- 运行 'flutter doctor' 查看详细诊断
- 检查 ANDROID_HOME 环境变量是否正确设置

环境变量设置:
-------------
ANDROID_HOME = $sdkPath
JAVA_HOME = $env:JAVA_HOME
Flutter = C:\flutter\bin

"@
