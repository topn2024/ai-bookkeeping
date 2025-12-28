# 开发环境迁移到D盘 - 快速指南

## 快速开始

### 1. 试运行(推荐第一次执行)
```powershell
# 查看迁移计划,不实际执行
.\scripts\migrate_to_d_drive.ps1 -All -DryRun
```

### 2. 执行迁移

#### 一次性迁移所有内容(推荐)
```powershell
# 需要管理员权限(因为要迁移JDK)
.\scripts\migrate_to_d_drive.ps1 -All
```

#### 分步迁移(可选)

**紧急释放空间(不需要管理员权限)**
```powershell
# 迁移Gradle缓存 (13.3GB) 和 Android配置 (5.8GB)
.\scripts\migrate_to_d_drive.ps1 -GradleOnly -AndroidOnly
```

**后续可选迁移**
```powershell
# 迁移Pub缓存 (0.78GB)
.\scripts\migrate_to_d_drive.ps1 -PubOnly

# 迁移JDK (0.3GB) - 需要管理员权限
# 以管理员身份运行PowerShell,然后执行:
.\scripts\migrate_to_d_drive.ps1 -JdkOnly
```

## 迁移前检查清单

- [ ] 关闭所有IDE (Android Studio, VSCode等)
- [ ] 关闭所有模拟器
- [ ] 停止所有Gradle构建进程
- [ ] 确保D盘有足够空间 (至少20GB)
- [ ] (可选) 备份重要配置

## 迁移后验证

```powershell
# 1. 验证环境变量
echo $env:GRADLE_USER_HOME
echo $env:PUB_CACHE
echo $env:JAVA_HOME

# 2. 验证Flutter环境
flutter doctor -v

# 3. 验证Java
java -version

# 4. 清理并重新构建项目
cd D:\code\ai-bookkeeping\app
flutter clean
flutter pub get
flutter build apk
```

## 预期效果

| 项目 | 迁移前 | 迁移后 |
|------|--------|--------|
| C盘使用率 | 96.7% (剩余3.34GB) | ~77% (剩余~23GB) |
| Gradle缓存 | C盘 13.3GB | D盘 |
| Android配置 | C盘 5.8GB | D盘 |
| Pub缓存 | C盘 0.78GB | D盘 |
| Java JDK | C盘 0.3GB | D盘 |

## 常见问题

### Q: 迁移失败怎么办?
A: 脚本会保留原文件,只有成功后才删除。如果失败,检查错误信息并手动恢复。

### Q: 需要重启电脑吗?
A: 不需要重启电脑,但需要重启命令行窗口和IDE。

### Q: 会影响现有项目吗?
A: 不会。迁移的是全局缓存和工具,项目代码不受影响。

### Q: 可以只迁移部分内容吗?
A: 可以。使用 `-GradleOnly`、`-AndroidOnly` 等参数选择性迁移。

### Q: 迁移后可以删除C盘的原目录吗?
A: 脚本使用 `/MOVE` 参数,已经自动删除了原目录。对于Android配置,会创建符号链接指向新位置。

## 技术支持

如有问题,请查看详细文档: `C盘迁移建议.md`
