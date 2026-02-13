# 构建和发布新版本指南

## 📋 前置条件

- Flutter SDK 已安装
- Android SDK 已配置
- 签名密钥已配置（用于release版本）

## 🔨 步骤1: 构建APK

### 方式A: 构建release版本（推荐用于发布）

```bash
cd /Users/beihua/code/baiji/ai-bookkeeping/app

# 清理之前的构建
flutter clean

# 获取依赖
flutter pub get

# 构建release版本APK
flutter build apk --release

# APK输出路径: build/app/outputs/flutter-apk/app-release.apk
```

### 方式B: 构建split APKs（按架构分离，体积更小）

```bash
flutter build apk --release --split-per-abi

# 会生成多个APK:
# - app-armeabi-v7a-release.apk (32位ARM)
# - app-arm64-v8a-release.apk (64位ARM，推荐)
# - app-x86_64-release.apk (x86模拟器)
```

## 📦 步骤2: 使用发布脚本

### 找到构建的APK

```bash
ls -lh /Users/beihua/code/baiji/ai-bookkeeping/app/build/app/outputs/flutter-apk/
```

### 运行发布脚本

```bash
cd /Users/beihua/code/baiji/ai-bookkeeping

# 如果有上一个版本的APK，可以生成增量补丁
python3 scripts/publish_version.py \
  app/build/app/outputs/flutter-apk/app-release.apk \
  --version 2.0.3 \
  --code 43 \
  --previous-apk ./dist/ai_bookkeeping_2.0.2.apk \
  --previous-version 2.0.2 \
  --previous-code 42 \
  --release-notes RELEASE_NOTES_2.0.3.md

# 如果没有上一个版本
python3 scripts/publish_version.py \
  app/build/app/outputs/flutter-apk/app-release.apk \
  --version 2.0.3 \
  --code 43 \
  --release-notes RELEASE_NOTES_2.0.3.md
```

## 📤 步骤3: 上传和发布

发布脚本会生成：
- `dist/ai_bookkeeping_2.0.3.apk` - 新版本APK
- `dist/version_2.0.3.json` - 版本元数据
- `dist/patch_2.0.2_to_2.0.3.patch` - 增量更新补丁（如果提供了旧版本）

### 上传到存储

根据脚本输出的提示：
1. 上传APK到MinIO存储
2. 上传patch文件到MinIO存储
3. 通过管理后台创建版本记录

## 🧪 步骤4: 测试

在测试设备上安装新APK：

```bash
# 通过ADB安装
adb install -r app/build/app/outputs/flutter-apk/app-release.apk

# 或者将APK复制到设备手动安装
```

测试密码找回功能：
1. 点击"忘记密码"
2. 输入邮箱地址
3. 检查是否收到验证码邮件
4. 输入验证码并重置密码
5. 使用新密码登录

## 📝 当前版本信息

- **版本名称**: 2.0.3
- **版本号**: 43
- **更新内容**: 修复密码找回邮件发送问题

## ⚠️ 注意事项

1. **签名密钥**: Release版本必须使用正确的签名密钥，否则无法覆盖安装
2. **版本号递增**: 确保version code大于之前的版本
3. **测试验证**: 发布前务必在测试设备上验证所有功能
4. **备份旧版**: 保留旧版本APK以便生成增量补丁

## 🔍 常见问题

### Q: 构建失败？
```bash
flutter doctor  # 检查环境
flutter clean && flutter pub get  # 清理重新获取依赖
```

### Q: 签名密钥错误？
检查 `app/android/key.properties` 配置是否正确

### Q: APK体积太大？
使用 `--split-per-abi` 选项构建分架构APK

### Q: 如何查看APK信息？
```bash
# 使用aapt查看APK信息
aapt dump badging app-release.apk | grep version
```
