# 最简单的安装方法 - 拖拽安装

## 📱 APK 文件位置

```
D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk\app-debug.apk
```

文件大小：约 147 MB

## 🚀 安装步骤（超简单）

### 方法 1：拖拽安装（推荐，最简单）

1. **打开文件管理器**
   - 按 `Win + E` 打开文件管理器
   - 导航到：`D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk\`

2. **找到 APK 文件**
   - 文件名：`app-debug.apk`
   - 大小：约 147 MB

3. **拖拽到模拟器**
   - 确保 Android 模拟器窗口已打开并显示桌面
   - 用鼠标**拖动** `app-debug.apk` 文件
   - **拖放到**模拟器窗口上
   - 等待几秒钟，APK 会自动安装

4. **完成！**
   - 在模拟器的应用抽屉中找到 "AI Bookkeeping"
   - 点击图标启动应用

---

### 方法 2：使用安装脚本

1. **双击运行：**
   ```
   D:\code\ai-bookkeeping\scripts\install-apk.bat
   ```

2. **按照屏幕提示操作**
   - 脚本会自动检查 APK 文件
   - 启动 ADB 服务
   - 等待设备连接
   - 安装 APK

3. **如果提示设备 offline：**
   - 等待模拟器完全启动（显示桌面）
   - 重新运行脚本

---

### 方法 3：使用 ADB 命令（手动）

1. **打开命令提示符（CMD）**

2. **设置环境变量：**
```cmd
set ANDROID_ADB_SERVER_PORT=5038
```

3. **启动 ADB：**
```cmd
D:\Android\Sdk\platform-tools\adb.exe kill-server
D:\Android\Sdk\platform-tools\adb.exe start-server
```

4. **等待 10 秒，然后检查设备：**
```cmd
D:\Android\Sdk\platform-tools\adb.exe devices
```

**预期输出：**
```
List of devices attached
emulator-5554          device
```

5. **安装 APK：**
```cmd
D:\Android\Sdk\platform-tools\adb.exe install -r D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk\app-debug.apk
```

---

## ⚠️ 故障排除

### 问题 1：找不到模拟器窗口

**解决方法：**

1. 打开 Android Studio
2. 点击 Tools → AVD Manager
3. 找到 `AI_Bookkeeping_Emulator`
4. 点击 ▶️ 启动按钮
5. 等待模拟器窗口出现

或使用命令行启动：
```cmd
D:\Android\Sdk\emulator\emulator.exe -avd AI_Bookkeeping_Emulator
```

### 问题 2：拖拽后没有反应

**可能原因：**
- 模拟器还在启动中
- 需要等待模拟器完全加载（显示桌面）

**解决方法：**
1. 等待 30-60 秒让模拟器完全启动
2. 再次尝试拖拽 APK

### 问题 3：ADB 显示 device offline

**解决方法：**

**方案 A：重启 ADB**
```cmd
set ANDROID_ADB_SERVER_PORT=5038
adb kill-server
timeout /t 5
adb start-server
timeout /t 10
adb devices
```

**方案 B：重启模拟器**
1. 关闭模拟器窗口
2. 重新启动模拟器
3. 等待完全启动后再安装

### 问题 4：APK 文件不存在

**解决方法：重新构建 APK**

```cmd
cd D:\code\ai-bookkeeping\app
flutter clean
flutter pub get
flutter build apk --debug
```

构建完成后，APK 会在：
```
D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk\app-debug.apk
```

---

## 🎯 验证安装

安装成功后，您可以：

1. **在模拟器中查看应用列表**
   - 点击应用抽屉图标
   - 查找 "AI Bookkeeping"

2. **使用命令查看已安装包：**
```cmd
set ANDROID_ADB_SERVER_PORT=5038
adb shell pm list packages | findstr bookkeeping
```

应该看到：
```
package:com.example.ai_bookkeeping
```

3. **启动应用：**
```cmd
adb shell am start -n com.example.ai_bookkeeping/.MainActivity
```

---

## 💡 推荐方法

**强烈推荐使用方法 1（拖拽安装）：**
- ✅ 最简单
- ✅ 不需要命令行
- ✅ 不需要等待 ADB 连接
- ✅ 成功率最高

**当拖拽方法无效时，使用方法 2（安装脚本）**

**技术用户可以使用方法 3（ADB 命令）**

---

## 📝 注意事项

1. **确保模拟器完全启动** - 这是最重要的！
   - 能看到 Android 桌面
   - 能点击应用抽屉
   - 等待约 60-90 秒

2. **APK 文件较大**（147 MB）
   - 拖拽安装可能需要 30-60 秒
   - ADB 安装也需要类似时间

3. **端口配置**
   - ADB 使用端口 5038（而非默认 5037）
   - 所有 ADB 命令前都需要设置环境变量

---

## ✨ 安装后

应用安装成功后，您可以：

1. **直接在模拟器中使用**
2. **修改代码后重新构建和安装**
3. **查看应用日志：**
   ```cmd
   adb logcat | findstr "flutter"
   ```

**祝使用愉快！** 🎉
