# C盘空间优化 - 开发环境迁移建议

## 当前磁盘空间状况

### C盘 (系统盘)
- **已用**: 96.66GB / 100GB (96.7% 已使用) ⚠️ **空间严重不足!**
- **剩余**: 3.34GB

### D盘 (数据盘)
- **已用**: 97.84GB / 356.31GB (27.5% 已使用)
- **剩余**: 258.47GB ✅ **空间充裕**

---

## 当前开发环境位置

### ✅ 已在D盘 (无需迁移)
| 工具 | 位置 |
|------|------|
| Flutter SDK | D:\flutter |
| Android SDK | D:\Android\Sdk |

### ⚠️ 仍在C盘 (建议迁移)
| 工具/缓存 | 当前位置 | 占用空间 | 优先级 |
|-----------|----------|----------|--------|
| **Gradle缓存** | C:\Users\l00629826\\.gradle | **13.3GB** | 🔴 **高** |
| **Android配置** | C:\Users\l00629826\\.android | **5.8GB** | 🔴 **高** |
| **Pub缓存** | C:\Users\l00629826\AppData\Local\Pub\Cache | **0.78GB** | 🟡 中 |
| **Java JDK** | C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot | **0.3GB** | 🟡 中 |
| GitHub CLI | C:\Program Files\GitHub CLI | 0.05GB | 🟢 低 |

**预计可释放空间**: **约 20.23GB**

---

## 详细迁移方案

### 1. Gradle缓存迁移 (可释放 13.3GB) 🔴

**当前位置**: `C:\Users\l00629826\.gradle`
**建议迁移到**: `D:\gradle_cache`

**迁移步骤**:
```powershell
# 1. 创建新目录
mkdir D:\gradle_cache

# 2. 复制现有缓存(可选,也可以直接删除让Gradle重新下载)
robocopy C:\Users\l00629826\.gradle D:\gradle_cache /E /MOVE

# 3. 设置环境变量
[Environment]::SetEnvironmentVariable('GRADLE_USER_HOME', 'D:\gradle_cache', 'User')
```

**注意事项**:
- 迁移后首次构建可能需要重新下载一些依赖
- 确保项目的`gradle.properties`没有硬编码路径

---

### 2. Android配置迁移 (可释放 5.8GB) 🔴

**当前位置**: `C:\Users\l00629826\.android`
**建议迁移到**: `D:\Android\.android`

**迁移步骤**:
```powershell
# 1. 创建新目录
mkdir D:\Android\.android

# 2. 移动配置文件
robocopy C:\Users\l00629826\.android D:\Android\.android /E /MOVE

# 3. 创建符号链接
cmd /c mklink /D C:\Users\l00629826\.android D:\Android\.android
```

**包含内容**:
- AVD虚拟设备镜像
- Android模拟器配置
- 调试密钥和证书

---

### 3. Pub缓存迁移 (可释放 0.78GB) 🟡

**当前位置**: `C:\Users\l00629826\AppData\Local\Pub\Cache`
**建议迁移到**: `D:\flutter_pub_cache`

**迁移步骤**:
```powershell
# 1. 创建新目录
mkdir D:\flutter_pub_cache

# 2. 移动缓存
robocopy C:\Users\l00629826\AppData\Local\Pub\Cache D:\flutter_pub_cache /E /MOVE

# 3. 设置环境变量
[Environment]::SetEnvironmentVariable('PUB_CACHE', 'D:\flutter_pub_cache', 'User')

# 4. 让Flutter使用新路径
flutter config --pub-cache D:\flutter_pub_cache
```

---

### 4. Java JDK迁移 (可释放 0.3GB) 🟡

**当前位置**: `C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot`
**建议迁移到**: `D:\Java\jdk-17`

**迁移步骤**:
```powershell
# 1. 创建目标目录
mkdir D:\Java

# 2. 移动JDK (需要管理员权限)
robocopy "C:\Program Files\Eclipse Adoptium\jdk-17.0.13.11-hotspot" D:\Java\jdk-17 /E /MOVE

# 3. 更新系统环境变量JAVA_HOME
[Environment]::SetEnvironmentVariable('JAVA_HOME', 'D:\Java\jdk-17', 'Machine')

# 4. 更新Flutter的JDK配置
flutter config --jdk-dir="D:\Java\jdk-17"
```

**注意事项**:
- 需要管理员权限
- 迁移后需要重启命令行或IDE
- 确保PATH环境变量中的Java路径也更新

---

## 推荐迁移顺序

### 紧急优先 (立即执行)
1. **Gradle缓存** (13.3GB) - 占用最大,迁移后立即释放空间
2. **Android配置** (5.8GB) - 包含AVD镜像,占用较大

完成后可立即释放 **19.1GB** 空间,C盘剩余空间将达到 **22.44GB**

### 次要优先 (建议执行)
3. **Pub缓存** (0.78GB) - Flutter包缓存,迁移简单
4. **Java JDK** (0.3GB) - 需要管理员权限,影响较小

---

## 迁移后的目录结构

```
D:\
├── flutter\                          # Flutter SDK (已存在)
├── Android\
│   ├── Sdk\                         # Android SDK (已存在)
│   └── .android\                    # Android配置 (迁移后)
├── gradle_cache\                    # Gradle缓存 (迁移后)
├── flutter_pub_cache\               # Pub缓存 (迁移后)
└── Java\
    └── jdk-17\                      # Java JDK (迁移后)
```

---

## 环境变量清单

迁移后需要设置/更新的环境变量:

| 变量名 | 值 | 类型 |
|--------|-----|------|
| GRADLE_USER_HOME | D:\gradle_cache | User |
| PUB_CACHE | D:\flutter_pub_cache | User |
| JAVA_HOME | D:\Java\jdk-17 | Machine |

---

## 迁移后验证

执行以下命令验证环境配置:

```bash
# 验证Flutter环境
flutter doctor -v

# 验证Java
java -version
echo %JAVA_HOME%

# 验证Gradle
gradle --version

# 验证Pub缓存
flutter pub cache list
```

---

## 注意事项

1. **备份重要数据**: 在迁移前建议备份重要配置
2. **关闭相关进程**: 迁移时关闭Android Studio、VSCode等IDE
3. **管理员权限**: 某些操作需要管理员权限
4. **测试应用**: 迁移后重新构建和测试应用确保正常运行
5. **环境变量生效**: 某些环境变量更改需要重启系统或重新登录

---

## 快速执行脚本

如果需要,我可以为你生成自动化迁移脚本,一键完成所有迁移操作。

**预期收益**:
- C盘释放空间: **约20GB**
- C盘使用率: 从96.7% 降至 **约77%**
- 后续开发缓存将在D盘积累,不再占用C盘空间
