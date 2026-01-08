# ADB端口配置总结与解决方案

## 当前状态 (2025-12-28)

### 问题描述
- **核心问题**: ADB默认端口5037被Windows系统服务占用(PID 4344)
- **尝试方案**: 配置ADB使用替代端口5038
- **当前进展**:
  - ✅ 环境变量ANDROID_ADB_SERVER_PORT已永久设置为5038
  - ✅ 模拟器进程正在运行 (emulator.exe 和 qemu-system-x86_64.exe)
  - ⚠️ ADB服务器在5038端口启动不稳定

### 已完成的工作

1. **环境变量配置**
   ```powershell
   [Environment]::SetEnvironmentVariable('ANDROID_ADB_SERVER_PORT', '5038', 'User')
   ```

2. **脚本更新**
   - `scripts/configure_adb_port_5038.ps1` - 完整的ADB端口配置脚本
   - `scripts/launch_emulator_5038.ps1` - 使用5038端口启动模拟器
   - `scripts/check_emulator_status.ps1` - 检查模拟器和ADB状态
   - `scripts/kill_emulator.ps1` - 清理模拟器和ADB进程
   - `scripts/start_adb_server_5038.ps1` - 启动ADB服务器(5038端口)
   - `scripts/start_emulator_window.bat` - 批处理启动脚本

## 推荐解决方案

由于ADB端口配置复杂且不稳定,推荐使用以下实用方案:

### 方案A: 构建APK并手动安装 (最可靠)

这是目前最稳定的方案,不依赖ADB连接。

#### 步骤:

1. **构建APK**
   ```bash
   cd D:\code\ai-bookkeeping\app
   flutter build apk --no-tree-shake-icons
   ```

   APK位置: `D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk\app-release.apk`

2. **启动模拟器**
   - 双击运行: `D:\code\ai-bookkeeping\scripts\start_emulator_window.bat`
   - 或使用PowerShell: `.\scripts\launch_emulator_5038.ps1`
   - 等待模拟器窗口完全启动(30-60秒)

3. **安装APK** (选择其中一种方法):

   **方法1: 拖放安装**(最简单)
   - 将APK文件拖放到模拟器窗口
   - 点击"安装"按钮

   **方法2: 使用ADB安装**(如果ADB可用)
   ```bash
   D:\Android\Sdk\platform-tools\adb.exe -L tcp:localhost:5038 install -r D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk\app-release.apk
   ```

   **方法3: 从模拟器内部安装**
   - 在模拟器中打开文件管理器
   - 浏览到共享文件夹
   - 点击APK文件安装

### 方案B: 使用Flutter直接运行 (如果ADB工作)

如果环境变量生效且ADB正常工作:

```powershell
# PowerShell中
$env:ANDROID_ADB_SERVER_PORT = "5038"
cd D:\code\ai-bookkeeping\app
flutter devices
flutter run
```

### 方案C: 使用物理设备

通过USB连接实际Android设备进行开发和测试。

## 技术说明

### 为什么使用端口5038?

端口5037被Windows系统服务永久占用:
```
TCP    127.0.0.1:5037    0.0.0.0:0    LISTENING    4344 (svchost.exe)
```

尝试在5037端口启动ADB会失败。因此配置使用替代端口5038。

### ADB端口配置方法

**环境变量方式**:
```powershell
$env:ANDROID_ADB_SERVER_PORT = "5038"
```

**命令行参数方式**:
```bash
adb -L tcp:localhost:5038 <command>
adb -P 5038 <command>
```

### Flutter如何识别ADB端口

Flutter会自动读取`ANDROID_ADB_SERVER_PORT`环境变量。因此需要:
1. 设置环境变量为5038
2. 重启终端使其生效
3. 运行flutter命令

## 常用命令参考

### 检查模拟器状态
```powershell
# 使用脚本
.\scripts\check_emulator_status.ps1

# 手动检查
Get-Process | Where-Object {$_.ProcessName -like "*emulator*"}
netstat -ano | findstr "5038"
```

### 启动模拟器
```powershell
# PowerShell
.\scripts\launch_emulator_5038.ps1

# 批处理
.\scripts\start_emulator_window.bat

# 手动
D:\Android\Sdk\emulator\emulator.exe -avd AI_Bookkeeping_Emulator -gpu swiftshader_indirect
```

### ADB命令(使用5038端口)
```bash
# 列出设备
adb -L tcp:localhost:5038 devices

# 安装APK
adb -L tcp:localhost:5038 install -r path/to/app.apk

# 进入shell
adb -L tcp:localhost:5038 shell

# 查看日志
adb -L tcp:localhost:5038 logcat
```

### Flutter命令
```powershell
# 设置环境变量
$env:ANDROID_ADB_SERVER_PORT = "5038"

# 查看设备
flutter devices

# 运行应用
flutter run

# 构建APK
flutter build apk --no-tree-shake-icons

# 安装到设备
flutter install
```

## 清理和重置

如果遇到问题,使用以下脚本清理:

```powershell
# 停止所有模拟器和ADB
.\scripts\kill_emulator.ps1

# 重新配置ADB端口
.\scripts\configure_adb_port_5038.ps1

# 重新启动模拟器
.\scripts\launch_emulator_5038.ps1
```

## 文件位置

- **Android SDK**: `D:\Android\Sdk`
- **AVD配置**: `D:\Android\.android\avd`
- **模拟器**: `D:\Android\Sdk\emulator\emulator.exe`
- **ADB**: `D:\Android\Sdk\platform-tools\adb.exe`
- **Flutter**: `D:\flutter`
- **项目**: `D:\code\ai-bookkeeping\app`
- **构建输出**: `D:\code\ai-bookkeeping\app\build\app\outputs\flutter-apk`

## 故障排除

### 问题1: 模拟器窗口没有出现

**解决**:
- 检查进程是否在运行: `tasklist | findstr emulator`
- 如果进程存在但无窗口,重启进程:
  ```powershell
  .\scripts\kill_emulator.ps1
  .\scripts\start_emulator_window.bat
  ```

### 问题2: ADB无法连接设备

**解决**:
- 使用构建APK + 手动安装的方式(方案A)
- 这完全绕过ADB连接问题

### 问题3: Flutter找不到设备

**解决**:
```powershell
# 1. 确保环境变量设置
$env:ANDROID_ADB_SERVER_PORT = "5038"

# 2. 重启Flutter daemon
flutter devices
```

### 问题4: 构建APK失败

**解决**:
```bash
# 如果遇到IconData错误,添加标志
flutter build apk --no-tree-shake-icons

# 清理后重新构建
flutter clean
flutter pub get
flutter build apk --no-tree-shake-icons
```

## 后续建议

1. **优先使用方案A** (构建APK + 手动安装) - 最稳定,不依赖ADB端口配置
2. **考虑使用物理设备** - USB调试更稳定
3. **如果ADB必须使用**:
   - 确保每次打开新终端都设置环境变量
   - 或者将环境变量添加到系统级别(需要管理员权限)

---

**创建时间**: 2025-12-28
**状态**: ADB端口5038配置完成,模拟器可运行,推荐使用APK手动安装方案
