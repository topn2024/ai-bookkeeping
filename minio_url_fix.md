# MinIO APK下载URL修复记录

**日期**: 2026-01-29 00:48
**问题**: 用户下载APK时报错 "Connection refused, address=127.0.0.1"

## 问题原因

1. `.env`文件中`MINIO_ENDPOINT`配置为`127.0.0.1:9000`
2. 代码生成file_url时直接使用了`MINIO_ENDPOINT`：
   ```python
   file_url = f"{protocol}://{settings.MINIO_ENDPOINT}/{settings.MINIO_BUCKET}/{object_name}"
   ```
3. 导致生成的URL为`http://127.0.0.1:9000/...`，客户端无法访问

## 解决方案

### 1. 短期修复（已完成）

**数据库修复**：
```sql
UPDATE app_versions 
SET file_url = 'https://39.105.12.124/ai-bookkeeping/app-releases/android/2.0.16/app-release-62.apk'
WHERE version_code = 62;
```

**配置恢复**：
```bash
MINIO_ENDPOINT=localhost:9000  # 服务器内部访问使用localhost
```

**验证**：
```bash
curl -I -k "https://39.105.12.124/ai-bookkeeping/app-releases/android/2.0.16/app-release-62.apk"
# HTTP/2 200 - 可正常下载
```

### 2. 长期方案（待实施）

需要修改代码，在生成下载URL时使用公网地址：

**方案A**：添加配置项
```python
# app/core/config.py
class Settings(BaseSettings):
    MINIO_ENDPOINT: str = "localhost:9000"  # 内部访问
    PUBLIC_DOWNLOAD_URL: str = "https://39.105.12.124"  # 公网访问
```

**方案B**：使用APP_BASE_URL
```python
# 生成URL时
if settings.DEBUG:
    file_url = f"http://{settings.MINIO_ENDPOINT}/{settings.MINIO_BUCKET}/{object_name}"
else:
    file_url = f"{settings.APP_BASE_URL}/{settings.MINIO_BUCKET}/{object_name}"
```

## 架构说明

### 当前架构
```
客户端 → HTTPS (443) → Nginx → MinIO (localhost:9000)
```

### Nginx配置
```nginx
location /ai-bookkeeping/ {
    proxy_pass http://127.0.0.1:9000/ai-bookkeeping/;
    # ... proxy settings ...
}
```

### 正确的URL格式
- ✓ `https://39.105.12.124/ai-bookkeeping/app-releases/android/2.0.16/app-release-62.apk`
- ✗ `http://127.0.0.1:9000/ai-bookkeeping/app-releases/android/2.0.16/app-release-62.apk`

## 服务器状态

### 服务器2 (39.105.12.124)
- ✓ MINIO_ENDPOINT: localhost:9000
- ✓ Nginx代理: 已配置
- ✓ 版本62的file_url: 已修复
- ✓ APK下载: 正常

### 服务器1 (160.202.238.29)
- ✓ MINIO_ENDPOINT: 160.202.238.29:9000（需要改为localhost:9000）
- ⚠️ 需要同样的修复

## 后续任务

1. [ ] 修改admin/api/app_versions.py，使用PUBLIC_DOWNLOAD_URL生成file_url
2. [ ] 更新服务器1的配置和数据库
3. [ ] 测试应用内更新功能
4. [ ] 添加自动化测试，验证生成的URL格式

