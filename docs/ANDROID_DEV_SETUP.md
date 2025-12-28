# Android 开发环境配置指南

本文档提供 AI智能记账 项目的 Android 开发环境完整配置指南。

## 目录

1. [系统要求](#系统要求)
2. [快速安装](#快速安装)
3. [手动安装步骤](#手动安装步骤)
4. [模拟器配置](#模拟器配置)
5. [项目运行](#项目运行)
6. [常见问题](#常见问题)

---

## 系统要求

### 硬件要求

| 配置项 | 最低要求 | 推荐配置 |
|--------|---------|---------|
| CPU | 64位处理器 | Intel i5/AMD Ryzen 5 以上 |
| 内存 | 8 GB | 16 GB 以上 |
| 硬盘空间 | 20 GB | 50 GB SSD |
| 分辨率 | 1280 x 800 | 1920 x 1080 以上 |

### 模拟器额外要求 (HAXM/WHPX)

- **Intel CPU**: 需要启用 Intel HAXM (VT-x)
- **AMD CPU**: 需要启用 Windows Hypervisor Platform (WHPX)
- **BIOS**: 需要启用虚拟化技术 (VT-x/AMD-V)

---

## 快速安装

### 方法一：自动安装脚本 (推荐)

1. 以管理员权限打开 PowerShell
2. 运行安装脚本：

```powershell
# 进入项目目录
cd D:\code\ai-bookkeeping

# 允许脚本执行
Set-ExecutionPolicy Bypass -Scope Process -Force

# 运行安装脚本
.\scripts\setup-android-dev-env.ps1
```

3. 脚本将自动安装：
   - Chocolatey (包管理器)
   - Git
   - JDK 17
   - Android Studio
   - Android SDK
   - Flutter SDK
   - Android 模拟器

### 方法二：手动安装

见下方 [手动安装步骤](#手动安装步骤)

---

## 手动安装步骤

### 1. 安装 JDK 17

**下载地址**: https://learn.microsoft.com/zh-cn/java/openjdk/download

```powershell
# 使用 Chocolatey 安装
choco install microsoft-openjdk17 -y

# 设置环境变量
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Microsoft\jdk-17.0.x", "Machine")
```

**验证安装**:
```powershell
java -version
# 应显示: openjdk version "17.x.x"
```

### 2. 安装 Android Studio

**下载地址**: https://developer.android.com/studio

1. 下载 Android Studio 安装程序
2. 运行安装程序，选择标准安装
3. 完成安装后启动 Android Studio
4. 完成初始设置向导 (会下载 Android SDK)

**初始化设置要点**:
- 选择 "Standard" 安装类型
- 接受所有 License Agreement
- 等待 SDK 下载完成 (约 2-3 GB)

### 3. 配置 Android SDK

Android Studio 安装完成后，SDK 默认位于：
```
%LOCALAPPDATA%\Android\Sdk
```

**设置环境变量**:

```powershell
# 用户环境变量
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk"
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkPath, "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkPath, "User")

# 添加到 PATH
$pathAdditions = "$sdkPath\cmdline-tools\latest\bin;$sdkPath\platform-tools;$sdkPath\emulator"
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$pathAdditions", "User")
```

**安装必要的 SDK 组件**:

通过 Android Studio -> SDK Manager 安装，或使用命令行：

```powershell
sdkmanager "platform-tools"
sdkmanager "platforms;android-34"
sdkmanager "build-tools;34.0.0"
sdkmanager "system-images;android-34;google_apis;x86_64"
sdkmanager "emulator"
sdkmanager "cmdline-tools;latest"
```

### 4. 安装 Flutter SDK

**下载地址**: https://docs.flutter.dev/get-started/install/windows

```powershell
# 1. 下载 Flutter SDK
# https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.27.2-stable.zip

# 2. 解压到 C:\flutter

# 3. 添加到 PATH
$flutterPath = "C:\flutter\bin"
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
[System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$flutterPath", "User")
```

**配置 Flutter**:

```powershell
# 配置 Android SDK 路径
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"

# 接受许可证
flutter doctor --android-licenses

# 检查环境
flutter doctor -v
```

### 5. 验证安装

运行 `flutter doctor` 检查环境：

```powershell
flutter doctor -v
```

**预期输出**:
```
[✓] Flutter (Channel stable, 3.27.x)
[✓] Windows Version (Windows 10/11)
[✓] Android toolchain - develop for Android devices (Android SDK 34.x.x)
[✓] Android Studio (version 2024.x)
[✓] VS Code / IntelliJ (可选)
[✓] Connected device (模拟器或真机)
```

---

## 模拟器配置

### 创建 Android 模拟器 (AVD)

#### 方法一：通过 Android Studio (推荐)

1. 打开 Android Studio
2. 点击 `Tools` -> `Device Manager`
3. 点击 `Create Device`
4. 选择设备配置：

| 配置项 | 推荐值 |
|--------|--------|
| Device | Pixel 6 |
| System Image | API 34 (Android 14) |
| ABI | x86_64 |
| Target | Google APIs |

5. 配置 AVD 选项：

| 配置项 | 推荐值 |
|--------|--------|
| AVD Name | Pixel_6_API_34 |
| RAM | 2048 MB |
| VM Heap | 512 MB |
| Internal Storage | 2048 MB |
| SD Card | 512 MB |

6. 点击 `Finish` 创建

#### 方法二：通过命令行

```powershell
# 列出可用的系统镜像
sdkmanager --list | Select-String "system-images"

# 下载系统镜像
sdkmanager "system-images;android-34;google_apis;x86_64"

# 创建 AVD
avdmanager create avd `
    --name "Pixel_6_API_34" `
    --package "system-images;android-34;google_apis;x86_64" `
    --device "pixel_6"

# 列出已创建的 AVD
avdmanager list avd
```

### 启动模拟器

```powershell
# 使用 Flutter 命令启动
flutter emulators --launch Pixel_6_API_34

# 或直接使用 emulator 命令
emulator -avd Pixel_6_API_34

# 后台启动 (不显示控制台)
Start-Process -FilePath "emulator" -ArgumentList "-avd Pixel_6_API_34" -WindowStyle Hidden
```

### 模拟器性能优化

#### 1. 启用 GPU 加速

编辑 AVD 配置文件 `~/.android/avd/Pixel_6_API_34.avd/config.ini`：

```ini
hw.gpu.enabled=yes
hw.gpu.mode=auto
```

#### 2. 启用快速启动

```ini
fastboot.chosenSnapshotFile=
fastboot.forceChosenSnapshotBoot=no
fastboot.forceColdBoot=no
fastboot.forceFastBoot=yes
```

#### 3. 调整内存配置

```ini
hw.ramSize=4096
vm.heapSize=576
```

### 真机调试

#### 1. 启用开发者选项

1. 进入手机 `设置` -> `关于手机`
2. 连续点击 `版本号` 7 次
3. 返回设置，进入 `开发者选项`
4. 启用 `USB 调试`

#### 2. 安装 USB 驱动

- **通用驱动**: Google USB Driver (通过 SDK Manager 安装)
- **品牌驱动**:
  - 华为: HiSuite
  - 小米: Mi PC Suite
  - OPPO/vivo: 官方助手

#### 3. 连接设备

```powershell
# 检查连接的设备
adb devices

# 预期输出
# List of devices attached
# XXXXXXXXXX    device

# 如果显示 unauthorized，需要在手机上确认调试授权
```

---

## 项目运行

### 1. 获取依赖

```powershell
cd D:\code\ai-bookkeeping
flutter pub get
```

### 2. 检查设备

```powershell
# 列出可用设备
flutter devices

# 预期输出
# 2 connected devices:
#
# Pixel 6 API 34 (mobile) • emulator-5554 • android-x64 • Android 14 (API 34) (emulator)
# Windows (desktop)       • windows       • windows-x64 • Microsoft Windows
```

### 3. 运行应用

```powershell
# 运行在默认设备
flutter run

# 指定设备运行
flutter run -d emulator-5554

# Debug 模式 (默认)
flutter run --debug

# Release 模式
flutter run --release

# Profile 模式 (性能分析)
flutter run --profile
```

### 4. 热重载和热重启

在应用运行时：
- 按 `r` - 热重载 (Hot Reload)
- 按 `R` - 热重启 (Hot Restart)
- 按 `q` - 退出

### 5. 构建 APK

```powershell
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# 输出位置
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 常见问题

### Q1: flutter doctor 显示 Android toolchain 问题

**问题**: `[!] Android toolchain - develop for Android devices`

**解决方案**:
```powershell
# 1. 确认 ANDROID_HOME 设置正确
echo $env:ANDROID_HOME

# 2. 接受许可证
flutter doctor --android-licenses

# 3. 如果 cmdline-tools 缺失
sdkmanager "cmdline-tools;latest"
```

### Q2: 模拟器启动失败 - HAXM 问题

**问题**: `Intel HAXM is required to run this AVD`

**解决方案**:

1. 检查 BIOS 是否启用虚拟化 (VT-x)
2. 安装 HAXM:
```powershell
# 通过 SDK Manager
sdkmanager "extras;intel;Hardware_Accelerated_Execution_Manager"

# 手动安装
# 运行 %LOCALAPPDATA%\Android\Sdk\extras\intel\Hardware_Accelerated_Execution_Manager\intelhaxm-android.exe
```

### Q3: AMD CPU 模拟器慢

**问题**: AMD 处理器无法使用 HAXM

**解决方案**:

1. 启用 Windows Hypervisor Platform:
```powershell
# 以管理员运行
Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All
```

2. 重启电脑

3. 配置 AVD 使用 WHPX:
```powershell
emulator -avd Pixel_6_API_34 -accel-check
```

### Q4: adb devices 显示 unauthorized

**问题**: 设备显示 `unauthorized` 状态

**解决方案**:
1. 检查手机是否弹出授权对话框
2. 点击 "允许" 并勾选 "始终允许"
3. 如仍有问题：
```powershell
adb kill-server
adb start-server
adb devices
```

### Q5: Gradle 构建失败

**问题**: `Could not determine the dependencies of task ':app:compileDebugJavaWithJavac'`

**解决方案**:
```powershell
# 清理构建缓存
flutter clean
cd android
./gradlew clean
cd ..

# 重新获取依赖
flutter pub get

# 重新构建
flutter run
```

### Q6: 网络问题导致下载失败

**问题**: SDK 或依赖下载超时

**解决方案**:

配置国内镜像源：

```powershell
# Flutter 镜像
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

# 永久设置
[System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "User")
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
```

Gradle 镜像 (编辑 `android/build.gradle`):
```groovy
allprojects {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/google' }
        google()
        mavenCentral()
    }
}
```

---

## 快速参考

### 常用命令

```powershell
# 环境检查
flutter doctor -v

# 设备管理
flutter devices
flutter emulators
flutter emulators --launch <emulator_name>

# 项目运行
flutter run
flutter run -d <device_id>
flutter run --release

# 构建
flutter build apk
flutter build apk --release
flutter build appbundle

# 清理
flutter clean
flutter pub cache repair

# 日志
flutter logs
adb logcat
```

### 环境变量总结

| 变量 | 值 |
|------|-----|
| JAVA_HOME | C:\Program Files\Microsoft\jdk-17.x.x |
| ANDROID_HOME | %LOCALAPPDATA%\Android\Sdk |
| ANDROID_SDK_ROOT | %LOCALAPPDATA%\Android\Sdk |
| PATH (新增) | C:\flutter\bin |
| PATH (新增) | %ANDROID_HOME%\platform-tools |
| PATH (新增) | %ANDROID_HOME%\emulator |
| PATH (新增) | %ANDROID_HOME%\cmdline-tools\latest\bin |

---

*文档版本: 1.0*
*最后更新: 2025年1月*
