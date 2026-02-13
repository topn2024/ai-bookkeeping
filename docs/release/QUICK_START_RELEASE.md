# 🚀 快速开始 - 发布新版本 2.0.3

## 第一步：安装依赖（仅首次需要）

```bash
cd /Users/beihua/code/baiji/ai-bookkeeping
pip install -r requirements-release.txt
```

## 第二步：使用交互式发布（最简单）

```bash
./release.sh
```

按提示操作即可！

## 或者：使用命令行直接发布

### 不带补丁（首次发布或无旧版本）

```bash
python3 auto_release.py \
  --version 2.0.3 \
  --code 43 \
  --base-url http://160.202.238.29:8000 \
  --release-notes RELEASE_NOTES_2.0.3.md
```

### 带补丁（从2.0.2升级到2.0.3）

首先确保旧版本APK存在：

```bash
ls dist/ai_bookkeeping_2.0.2.apk
```

然后运行：

```bash
python3 auto_release.py \
  --version 2.0.3 \
  --code 43 \
  --previous-version 2.0.2 \
  --previous-code 42 \
  --base-url http://160.202.238.29:8000 \
  --release-notes RELEASE_NOTES_2.0.3.md
```

## 重要提示

1. **服务器地址**: 根据实际情况修改 `--base-url`
   - 本地开发: `http://localhost:8000`
   - 远程服务器: `http://160.202.238.29:8000`

2. **管理员密码**: 脚本会提示输入，不需要在命令行中指定

3. **发布说明**: 已经创建了 `RELEASE_NOTES_2.0.3.md`

4. **自动保存**: 成功后APK会自动保存到 `dist/ai_bookkeeping_2.0.3.apk`

## 执行过程

脚本会自动完成：
- ✅ 清理和构建APK（约2-5分钟）
- ✅ 生成增量补丁（如果有旧版本）
- ✅ 登录管理后台
- ✅ 创建版本记录
- ✅ 上传APK到MinIO
- ✅ 上传补丁（如果有）
- ✅ 发布版本

**预计总时间**: 5-10分钟

## 故障排查

### 如果登录失败
- 检查服务器是否运行: `curl http://160.202.238.29:8000/health`
- 确认管理员密码正确

### 如果构建失败
```bash
cd app
flutter clean
flutter pub get
flutter doctor  # 检查环境
```

### 如果上传超时
- 检查网络连接
- 确认MinIO服务运行正常

## 完成后

1. **测试更新**: 在旧版本APP中检查应用内更新
2. **验证安装**: 下载并安装新版本
3. **测试功能**: 验证密码找回邮件功能是否正常

## 需要帮助？

查看详细文档：
```bash
cat AUTO_RELEASE_GUIDE.md
```

或者：
```bash
python3 auto_release.py --help
```
