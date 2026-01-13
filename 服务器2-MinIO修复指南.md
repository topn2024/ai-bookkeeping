# 服务器2 MinIO配置修复指南

## 问题描述

服务器2 (39.105.12.124) 的MinIO配置中 `MINIO_ENDPOINT` 设置为 `localhost:9000`，导致：
- 生成的 `file_url` 为 `http://localhost:9000/...`
- 外部无法访问和下载APK文件
- 版本同步脚本无法从服务器2下载APK

## 当前状态

| 服务器 | 版本 | file_url | 状态 |
|-------|------|----------|------|
| 服务器2 (主) | 2.0.7+49 | `http://localhost:9000/...` | ❌ 外部无法访问 |
| 服务器1 (备份) | 2.0.9+51 | `http://160.202.238.29:9000/...` | ✅ 正常 |

**临时解决方案**: App的多服务器检查会自动选择服务器1的更高版本(2.0.9+51)，当前用户不受影响。

## 修复方案

### 方案1: 完整自动修复（推荐）

#### 步骤1: 登录服务器2
```bash
ssh root@39.105.12.124
# 或使用其他有sudo权限的账号
```

#### 步骤2: 下载并执行修复脚本
```bash
# 从本地上传脚本
scp /Users/beihua/code/baiji/ai-bookkeeping/scripts/fix_server2_complete.sh root@39.105.12.124:/tmp/

# 在服务器上执行
sudo bash /tmp/fix_server2_complete.sh
```

脚本会自动完成：
1. ✅ 备份 `.env` 文件
2. ✅ 更新 `MINIO_ENDPOINT` 配置
3. ✅ 重启后端服务
4. ✅ 更新数据库中所有现有版本记录的URL
5. ✅ 验证修复结果

### 方案2: 手动修复

#### 步骤1: 更新环境配置

```bash
# 登录服务器2
ssh root@39.105.12.124

# 备份配置文件
cp /home/ai-bookkeeping/app/server/.env /home/ai-bookkeeping/app/server/.env.backup

# 编辑配置文件
sudo nano /home/ai-bookkeeping/app/server/.env

# 找到并修改这一行：
# MINIO_ENDPOINT=localhost:9000
# 改为：
# MINIO_ENDPOINT=39.105.12.124:9000

# 保存并退出 (Ctrl+X, Y, Enter)
```

#### 步骤2: 重启服务

```bash
sudo systemctl restart ai-bookkeeping

# 检查服务状态
sudo systemctl status ai-bookkeeping
```

#### 步骤3: 更新数据库中的现有记录

```bash
# 连接到PostgreSQL数据库
sudo -u postgres psql -d ai_bookkeeping

# 执行以下SQL
UPDATE app_versions
SET
    file_url = REPLACE(file_url, 'localhost:9000', '39.105.12.124:9000'),
    updated_at = NOW()
WHERE file_url LIKE '%localhost:9000%';

UPDATE app_versions
SET
    patch_file_url = REPLACE(patch_file_url, 'localhost:9000', '39.105.12.124:9000'),
    updated_at = NOW()
WHERE patch_file_url LIKE '%localhost:9000%';

-- 查看修复结果
SELECT version_name, version_code, file_url
FROM app_versions
WHERE file_url LIKE '%39.105.12.124:9000%'
ORDER BY version_code DESC
LIMIT 5;

-- 退出
\q
```

### 方案3: 仅修复数据库记录（快速临时方案）

如果只想快速修复当前已发布的版本记录，可以仅执行SQL更新：

```bash
# 从本地执行（需要配置远程数据库访问）
# 或上传SQL文件到服务器执行

scp /Users/beihua/code/baiji/ai-bookkeeping/scripts/fix_server2_minio_database.sql root@39.105.12.124:/tmp/

ssh root@39.105.12.124
sudo -u postgres psql -d ai_bookkeeping -f /tmp/fix_server2_minio_database.sql
```

**注意**: 这种方法只修复现有记录，未来上传的版本仍会使用localhost地址。

## 验证修复

### 1. 检查API返回的URL

```bash
# 从本地执行
TOKEN=$(curl -k -s -X POST "https://39.105.12.124/admin/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' | \
    python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])') && \
curl -k -s "https://39.105.12.124/admin/app-versions/latest" \
    -H "Authorization: Bearer $TOKEN" | \
    python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"版本: {d['version_name']}+{d['version_code']}\"); print(f\"URL: {d['file_url']}\")"
```

**预期输出**:
```
版本: 2.0.7+49
URL: http://39.105.12.124:9000/ai-bookkeeping/app-releases/android/2.0.7/app-release-49.apk
```

### 2. 测试APK下载

```bash
# 测试URL是否可访问
curl -I http://39.105.12.124:9000/ai-bookkeeping/app-releases/android/2.0.7/app-release-49.apk
```

**预期输出**: 返回200 OK或302重定向

### 3. 测试版本同步

```bash
# 从本地执行
cd /Users/beihua/code/baiji/ai-bookkeeping
./scripts/sync_version.sh --auto --dry-run
```

**预期输出**: 能够成功下载APK（预览模式会跳过实际下载）

## 修复后的效果

1. ✅ 新上传的APK会使用正确的公网地址 `http://39.105.12.124:9000/...`
2. ✅ 现有版本的URL已修复，可以正常下载
3. ✅ 版本同步脚本可以正常工作
4. ✅ App的多服务器检查功能完全正常

## 常见问题

### Q: 为什么不能通过API更新file_url？
A: 后端API不支持PATCH/PUT更新版本记录的file_url字段（这是设计上的限制，防止误操作）。必须通过数据库直接更新。

### Q: 修复后是否需要重新发布版本？
A: 不需要。只要修复了URL配置和数据库记录，现有版本就可以正常下载。

### Q: 修复期间会影响用户吗？
A: 不会。App会自动从服务器1（版本更高）获取更新，用户体验不受影响。

### Q: MinIO的9000端口是否需要开放防火墙？
A: 是的，需要确保9000端口允许外部访问：
```bash
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --reload
```

## 脚本文件列表

修复所需的脚本已创建在项目中：

- `scripts/fix_server2_complete.sh` - 完整自动修复脚本（在服务器上执行）
- `scripts/fix_server2_minio_database.sql` - SQL修复脚本（仅修复数据库）
- `scripts/remote_fix_server2.sh` - 远程修复脚本（从本地执行，需SSH访问）

## 联系支持

如果修复过程中遇到问题，请检查：
1. 服务器日志: `sudo journalctl -u ai-bookkeeping -f`
2. PostgreSQL日志: `sudo tail -f /var/log/postgresql/postgresql-*.log`
3. MinIO服务状态: `sudo systemctl status minio`

---

**创建时间**: 2026-01-13
**最后更新**: 2026-01-13
