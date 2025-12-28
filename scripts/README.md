# Flutter 开发环境配置说明

## 问题背景

Windows 系统服务 `LogsAndAlerts` 占用了 ADB 默认端口 5037，导致 Android 调试桥（ADB）无法正常启动。

## 解决方案

本项目已配置 ADB 使用备用端口 **5038**，避免与系统服务冲突。

## 使用方法

### 方式一：使用启动脚本（推荐）

在项目根目录下打开命令行，运行：

```bash
scripts\flutter-dev.bat
```

此脚本会：
1. 自动设置 ADB 端口为 5038
2. 启动 ADB 服务器
3. 显示可用设备
4. 进入 Flutter 开发环境命令行

在此命令行中，您可以正常使用所有 Flutter 命令：
- `flutter devices` - 查看连接的设备
- `flutter run` - 运行应用
- `flutter build apk` - 构建 APK
- 等等

### 方式二：手动设置环境变量

如果您使用其他终端或 IDE，需要设置以下环境变量：

```bash
set ANDROID_ADB_SERVER_PORT=5038
```

然后正常使用 Flutter 命令。

## 配置文件说明

- `start-adb.bat` - 仅启动 ADB 服务器脚本
- `flutter-dev.bat` - 完整的 Flutter 开发环境启动脚本
- `adb.bat` - ADB 包装脚本（已添加到 PATH）

## 环境变量配置

已为用户账户设置以下环境变量：
- `ANDROID_ADB_SERVER_PORT=5038` - ADB 服务器端口
- PATH 中添加了 `D:\code\ai-bookkeeping\scripts` - 使 adb.bat 优先于原始 adb.exe

## IDE 配置

### Android Studio
无需特殊配置，使用 `flutter-dev.bat` 启动的命令行即可。

### VS Code
在 VS Code 中打开项目前，先运行 `flutter-dev.bat`，然后从该命令行启动 VS Code：
```bash
code .
```

## 测试连接

1. 启动 Android 模拟器：
   ```bash
   flutter emulators --launch Medium_Phone_API_36
   ```

2. 检查设备连接：
   ```bash
   adb devices
   flutter devices
   ```

3. 运行应用：
   ```bash
   cd app
   flutter run
   ```

## 故障排除

如果遇到设备连接问题：

1. 重启 ADB 服务器：
   ```bash
   scripts\start-adb.bat
   ```

2. 检查端口占用：
   ```bash
   netstat -ano | findstr "5038"
   ```

3. 确认环境变量：
   ```bash
   echo %ANDROID_ADB_SERVER_PORT%
   ```

4. 重新启动模拟器并重新连接
