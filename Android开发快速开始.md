# Android 开发环境快速开始指南

本指南将帮助你快速完成 Android 开发环境配置，5 步即可开始开发。

---

## 第一步：安装 Java JDK

### macOS (推荐使用 Homebrew)

```bash
# 安装 Java 17
brew install openjdk@17

# 创建符号链接
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# 配置环境变量
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 验证安装
java -version
```

---

## 第二步：安装 Android Studio 和 SDK

1. **下载 Android Studio**
   - 访问：https://developer.android.com/studio
   - 下载 macOS 版本

2. **安装 Android Studio**
   - 双击 `.dmg` 文件
   - 拖拽到 Applications 文件夹
   - 启动 Android Studio

3. **首次运行配置**
   - 选择 "Standard" 安装类型
   - 等待 SDK 组件下载完成（约 2-3 GB）

4. **安装必要的 SDK 组件**
   - 打开 Android Studio
   - Settings > Appearance & Behavior > System Settings > Android SDK
   - 勾选以下组件：
     - ✅ Android SDK Platform 35
     - ✅ Android SDK Platform 36
     - ✅ Android SDK Build-Tools 35.0.0
     - ✅ Android SDK Command-line Tools
     - ✅ Android SDK Platform-Tools
   - 点击 "Apply" 下载

5. **配置环境变量**

```bash
# 添加 Android SDK 环境变量
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.zshrc
source ~/.zshrc

# 验证安装
adb --version
```

---

## 第三步：配置 Flutter 环境

```bash
# 配置 Flutter 环境变量
echo 'export FLUTTER_HOME=/Users/beihua/tools/flutter' >> ~/.zshrc
echo 'export PATH=$FLUTTER_HOME/bin:$PATH' >> ~/.zshrc
source ~/.zshrc

# 验证 Flutter 安装
flutter doctor

# 接受 Android 许可协议
flutter doctor --android-licenses
# 输入 'y' 接受所有协议

# 查看详细信息
flutter doctor -v
```

预期输出示例：
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.x.x, on macOS ...)
[✓] Android toolchain - develop for Android devices (Android SDK version 35.0.0)
[✓] Xcode - develop for iOS and macOS (Xcode 15.x)
[✓] Chrome - develop for the web
[✓] Android Studio (version 2024.x)
[✓] VS Code (version 1.x.x)
[✓] Connected device (1 available)

• No issues found!
```

---

## 第四步：生成签名密钥（用于 Release 版本）

```bash
# 进入项目目录
cd /Users/beihua/code/baiji/ai-bookkeeping

# 运行密钥生成脚本
./scripts/generate_keystore.sh
```

按照提示输入：
- 密钥库密码（至少 6 位，请妥善保管）
- 密钥密码（至少 6 位，可与密钥库密码相同）
- 证书信息（姓名、组织等，可直接回车使用默认值）

**重要提示：**
- 🔐 请务必记住密码，建议使用密码管理工具保存
- 📦 密钥文件会自动保存到 `app/android/keystore/release.keystore`
- 🚫 密钥文件不会被提交到 Git 仓库（已配置 .gitignore）

---

## 第五步：验证环境并构建应用

```bash
# 进入应用目录
cd /Users/beihua/code/baiji/ai-bookkeeping/app

# 获取依赖
flutter pub get

# 清理缓存
flutter clean

# 构建 Debug 版本（测试环境是否正常）
flutter build apk --debug
```

如果构建成功，你会看到：
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk (xx.x MB)
```

**构建 Release 版本：**
```bash
# 构建 Release APK（使用签名密钥）
flutter build apk --release

# 构建 Release App Bundle（用于 Google Play 发布）
flutter build appbundle --release
```

---

## 连接设备并运行应用

### 使用真机

1. **启用开发者选项**
   - 设置 > 关于手机 > 连续点击"版本号" 7次

2. **启用 USB 调试**
   - 设置 > 开发者选项 > USB 调试（开启）

3. **连接手机到电脑**
   ```bash
   # 检查设备是否连接
   flutter devices

   # 运行应用
   flutter run
   ```

### 使用模拟器

```bash
# 创建模拟器（首次需要）
flutter emulators

# 启动模拟器
flutter emulators --launch <模拟器名称>

# 或者在 Android Studio 中启动
# Tools > Device Manager > 选择设备 > 启动

# 运行应用
flutter run
```

---

## 常用开发命令

```bash
# 运行应用（Debug 模式）
flutter run

# 运行应用（Release 模式）
flutter run --release

# 热重载（应用运行时按 'r'）
r

# 热重启（应用运行时按 'R'）
R

# 查看日志
flutter logs

# 清理构建缓存
flutter clean

# 更新依赖
flutter pub get

# 分析代码
flutter analyze

# 格式化代码
flutter format .
```

---

## 构建产物位置

- **Debug APK**: `app/build/app/outputs/flutter-apk/app-debug.apk`
- **Release APK**: `app/build/app/outputs/flutter-apk/app-release.apk`
- **App Bundle**: `app/build/app/outputs/bundle/release/app-release.aab`

---

## 快速检查清单

配置完成后，请确认以下所有项都是 ✅：

- [ ] `java -version` 显示 Java 17
- [ ] `flutter --version` 显示 Flutter 版本
- [ ] `flutter doctor` 无错误提示
- [ ] `adb --version` 显示 adb 版本
- [ ] 签名密钥已生成（`app/android/keystore/release.keystore` 存在）
- [ ] 可以成功运行 `flutter build apk --debug`
- [ ] 可以在设备或模拟器上运行应用

---

## 遇到问题？

### 问题 1：flutter command not found
```bash
# 检查 Flutter 路径
ls /Users/beihua/tools/flutter/bin/flutter

# 重新添加环境变量
export PATH="/Users/beihua/tools/flutter/bin:$PATH"
source ~/.zshrc
```

### 问题 2：Android SDK not found
```bash
# 检查 SDK 路径
ls $HOME/Library/Android/sdk

# 更新 local.properties
echo "sdk.dir=$HOME/Library/Android/sdk" > app/android/local.properties
```

### 问题 3：License not accepted
```bash
flutter doctor --android-licenses
# 输入 'y' 接受所有协议
```

### 问题 4：构建失败
```bash
# 清理并重新构建
cd app
flutter clean
flutter pub get
flutter build apk --debug
```

---

## 下一步

环境配置完成！你现在可以：

1. **开始开发**
   ```bash
   flutter run
   ```

2. **修改代码**
   - 主要代码在 `app/lib/` 目录
   - 使用热重载 (`r`) 快速查看更改

3. **发布应用**
   - 构建 Release 版本
   - 上传到应用商店

4. **学习资源**
   - Flutter 官方文档：https://flutter.dev/docs
   - Dart 语言指南：https://dart.dev/guides
   - Flutter Cookbook：https://flutter.dev/docs/cookbook

---

**祝你开发愉快！🚀**

如需详细配置说明，请参考 `Android开发环境配置指南.md`
