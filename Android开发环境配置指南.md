# Android 开发环境配置指南

## 当前环境状态

### 已完成配置
- ✅ Flutter 项目已创建
- ✅ Android 项目目录已存在
- ✅ 基本的 Gradle 配置已完成
- ✅ 使用阿里云 Maven 镜像源
- ✅ NDK 配置完成（支持 bspatch）
- ✅ compileSdk: 36, targetSdk: 35
- ✅ Flutter SDK 路径: `/Users/beihua/tools/flutter`

### 需要配置的环境
- ❌ Java JDK（必需）
- ❌ Android SDK（必需）
- ❌ Flutter 环境变量
- ❌ Android 签名证书（发布必需）

---

## 一、安装 Java JDK

### 方式 1：使用 Homebrew（推荐）
```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 Java 17（推荐用于 Android 开发）
brew install openjdk@17

# 创建符号链接
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk

# 配置环境变量（添加到 ~/.zshrc 或 ~/.bash_profile）
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc

# 重新加载配置
source ~/.zshrc
```

### 方式 2：手动下载安装
从 [Oracle JDK](https://www.oracle.com/java/technologies/downloads/) 或 [OpenJDK](https://adoptium.net/) 下载适合 macOS 的 JDK 17 安装包。

### 验证安装
```bash
java -version
javac -version
```

---

## 二、安装 Android SDK

### 方式 1：通过 Android Studio（推荐）

1. 下载 Android Studio
   - 访问：https://developer.android.com/studio
   - 下载适合 macOS 的版本

2. 安装并启动 Android Studio
   - 按照引导完成初始设置
   - 等待 SDK 组件下载完成

3. 配置 SDK
   - 打开 Android Studio > Settings/Preferences > Appearance & Behavior > System Settings > Android SDK
   - 安装以下组件：
     - Android SDK Platform 35 (API Level 35)
     - Android SDK Platform 36 (API Level 36)
     - Android SDK Build-Tools 35.0.0
     - Android SDK Command-line Tools
     - Android SDK Platform-Tools
     - Android Emulator
     - NDK (Side by side) 26.x.x

4. 配置环境变量
```bash
# 添加到 ~/.zshrc 或 ~/.bash_profile
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/build-tools/35.0.0' >> ~/.zshrc

# 重新加载配置
source ~/.zshrc
```

### 方式 2：仅安装 SDK（不安装 Android Studio）
```bash
# 使用 Homebrew
brew install --cask android-commandlinetools

# 设置环境变量
export ANDROID_HOME=$HOME/Library/Android/sdk
mkdir -p $ANDROID_HOME/cmdline-tools
# 将下载的工具移动到 latest 目录
mv cmdline-tools $ANDROID_HOME/cmdline-tools/latest

# 安装 SDK 组件
sdkmanager "platform-tools" "platforms;android-35" "platforms;android-36" "build-tools;35.0.0" "ndk;26.1.10909125"
```

### 验证安装
```bash
adb --version
sdkmanager --list
```

---

## 三、配置 Flutter 环境

### 1. 验证 Flutter SDK 路径
```bash
ls -la /Users/beihua/tools/flutter
```

### 2. 配置环境变量
```bash
# 添加到 ~/.zshrc 或 ~/.bash_profile
echo 'export FLUTTER_HOME=/Users/beihua/tools/flutter' >> ~/.zshrc
echo 'export PATH=$FLUTTER_HOME/bin:$PATH' >> ~/.zshrc

# 重新加载配置
source ~/.zshrc
```

### 3. 运行 Flutter Doctor
```bash
flutter doctor
```

### 4. 接受 Android 许可协议
```bash
flutter doctor --android-licenses
```

### 5. 查看 Flutter 配置
```bash
flutter doctor -v
```

---

## 四、创建签名证书

### 1. 生成 Release 签名证书
```bash
# 进入项目的 android 目录
cd /Users/beihua/code/baiji/ai-bookkeeping/app/android

# 创建 keystore 目录
mkdir -p keystore

# 生成签名密钥
keytool -genkey -v -keystore keystore/release.keystore \
  -alias ai-bookkeeping-release \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass [你的密钥库密码] \
  -keypass [你的密钥密码]
```

**注意事项：**
- 请妥善保管密钥库密码和密钥密码
- 建议使用密码管理工具保存
- 签名密钥文件不要提交到 Git 仓库

### 2. 创建密钥配置文件
在 `app/android/` 目录下创建 `key.properties` 文件（参考下一步）

---

## 五、更新 local.properties

编辑 `app/android/local.properties` 文件：

```properties
flutter.sdk=/Users/beihua/tools/flutter
sdk.dir=/Users/beihua/Library/Android/sdk
ndk.dir=/Users/beihua/Library/Android/sdk/ndk/26.1.10909125
```

---

## 六、验证环境配置

### 1. 进入 Flutter 项目目录
```bash
cd /Users/beihua/code/baiji/ai-bookkeeping/app
```

### 2. 获取依赖
```bash
flutter pub get
```

### 3. 清理并重新构建
```bash
flutter clean
flutter build apk --debug
```

### 4. 运行应用（连接设备或模拟器）
```bash
# 查看可用设备
flutter devices

# 运行应用
flutter run
```

---

## 七、常见问题解决

### 问题 1：Command not found: flutter
**解决方案：**
```bash
# 确保 Flutter 路径正确添加到 PATH
echo $PATH | grep flutter
# 如果没有，重新添加环境变量并重启终端
```

### 问题 2：Unable to locate a Java Runtime
**解决方案：**
- 确保按照第一步正确安装了 Java JDK
- 检查 JAVA_HOME 是否正确设置

### 问题 3：Android SDK not found
**解决方案：**
- 确保 ANDROID_HOME 环境变量正确设置
- 检查 local.properties 中的 sdk.dir 路径是否正确

### 问题 4：License not accepted
**解决方案：**
```bash
flutter doctor --android-licenses
# 输入 'y' 接受所有许可协议
```

### 问题 5：Gradle build failed
**解决方案：**
```bash
# 清理 Gradle 缓存
cd app/android
./gradlew clean

# 或者删除 build 目录
rm -rf build
rm -rf app/build
```

---

## 八、环境变量配置总结

将以下内容添加到 `~/.zshrc` 或 `~/.bash_profile`：

```bash
# Java
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH="$JAVA_HOME/bin:$PATH"

# Android SDK
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/build-tools/35.0.0

# Flutter SDK
export FLUTTER_HOME=/Users/beihua/tools/flutter
export PATH=$FLUTTER_HOME/bin:$PATH

# Gradle（可选，提升构建速度）
export GRADLE_USER_HOME=$HOME/.gradle
export GRADLE_OPTS="-Xmx2048m -XX:MaxMetaspaceSize=512m"
```

重新加载配置：
```bash
source ~/.zshrc  # 如果使用 zsh
# 或
source ~/.bash_profile  # 如果使用 bash
```

---

## 九、下一步

环境配置完成后，可以：

1. **开发调试**
   ```bash
   flutter run
   ```

2. **构建 APK**
   ```bash
   # Debug 版本
   flutter build apk --debug

   # Release 版本（需要签名配置）
   flutter build apk --release
   ```

3. **构建 App Bundle**
   ```bash
   flutter build appbundle --release
   ```

4. **查看构建产物**
   - APK: `app/build/app/outputs/flutter-apk/`
   - AAB: `app/build/app/outputs/bundle/release/`

---

## 十、推荐的开发工具

1. **Android Studio** - Android 官方 IDE
2. **VS Code** - 轻量级编辑器（推荐安装 Flutter 和 Dart 插件）
3. **Genymotion** - 快速的 Android 模拟器
4. **Vysor** - 在电脑上控制真机设备

---

**配置完成后，请运行 `flutter doctor -v` 检查所有项是否正常。**
