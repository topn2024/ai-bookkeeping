# 安全配置指南

## 概述

本文档提供AI Bookkeeping项目的安全配置指南，包括密钥管理、证书配置、密码策略等重要安全措施。

---

## 🔴 立即行动项

### 1. 环境变量配置

所有敏感信息必须通过环境变量注入，**禁止硬编码在代码中**。

#### 服务器端配置

```bash
cd server
cp .env.example .env
# 编辑 .env 文件，填入实际的配置值
```

**必须配置的环境变量：**
- `POSTGRES_PASSWORD`: PostgreSQL数据库密码
- `REDIS_PASSWORD`: Redis缓存密码
- `MINIO_ROOT_PASSWORD`: MinIO对象存储密码
- `SECRET_KEY`: Flask应用密钥
- `QWEN_API_KEY`: 通义千问API密钥
- `ZHIPU_API_KEY`: 智谱AI API密钥

#### Android端配置

```bash
cd app/android
cp key.properties.example key.properties
# 编辑 key.properties，填入签名密钥信息
```

**必须配置的密钥信息：**
- `storePassword`: Keystore密码
- `keyPassword`: 密钥密码
- `keyAlias`: 密钥别名
- `storeFile`: Keystore文件路径

---

## 🛡️ 密钥轮转指南

### 为什么需要密钥轮转？

密钥轮转是安全最佳实践，定期更换密钥可以：
- 减少密钥泄露的影响范围
- 符合安全合规要求
- 降低长期使用相同密钥的风险

### 轮转频率建议

| 密钥类型 | 建议轮转频率 | 优先级 |
|---------|------------|--------|
| API密钥（第三方） | 90天 | 高 |
| 数据库密码 | 180天 | 高 |
| JWT密钥 | 365天 | 中 |
| Android签名密钥 | 不轮转* | - |

*注：Android签名密钥用于应用签名，轮转会导致应用无法升级，需谨慎处理。

### 密钥轮转步骤

#### 1. API密钥轮转（通义千问、智谱AI）

```bash
# 1. 在API提供商控制台生成新密钥
# 2. 更新.env文件
QWEN_API_KEY=new_key_here
ZHIPU_API_KEY=new_key_here

# 3. 重启服务
docker compose down
docker compose up -d

# 4. 验证服务正常
curl -X POST http://localhost:8000/api/v1/ai/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"test"}'

# 5. 确认无误后，在API提供商控制台删除旧密钥
```

#### 2. 数据库密码轮转

```bash
# 1. 生成新密码（至少16位强密码）
NEW_PASSWORD=$(openssl rand -base64 24)

# 2. 连接数据库修改密码
docker exec -it aibook-postgres psql -U ai_bookkeeping -d ai_bookkeeping
ALTER USER ai_bookkeeping WITH PASSWORD 'new_password_here';
\q

# 3. 更新.env文件
POSTGRES_PASSWORD=new_password_here
DATABASE_URL=postgresql+asyncpg://ai_bookkeeping:new_password_here@localhost:5432/ai_bookkeeping

# 4. 重启应用服务（不要重启数据库容器）
# 假设你的应用服务名为 app
docker compose restart app

# 5. 验证连接
docker compose logs app | grep -i "database"
```

#### 3. Redis密码轮转

```bash
# 1. 生成新密码
NEW_REDIS_PASSWORD=$(openssl rand -base64 24)

# 2. 更新.env文件
REDIS_PASSWORD=new_password_here
REDIS_URL=redis://:new_password_here@localhost:6379/0

# 3. 重启Redis和应用（会导致缓存清空）
docker compose down redis app
docker compose up -d redis app

# 4. 验证
docker exec -it aibook-redis redis-cli -a new_password_here ping
```

---

## 🔐 SSL/TLS证书配置

### 开发环境

开发环境可以使用自签名证书，但必须通过服务器配置下发：

```json
{
  "skip_certificate_verification": true
}
```

**注意：** 代码中默认值已改为 `false`，必须通过服务器配置明确启用。

### 生产环境

生产环境**必须使用有效的SSL证书**，推荐使用Let's Encrypt免费证书：

```bash
# 安装 certbot
sudo apt-get install certbot

# 生成证书
sudo certbot certonly --standalone -d yourdomain.com

# 配置nginx
server {
    listen 443 ssl;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # ... 其他配置
}

# 自动续期
sudo certbot renew --dry-run
```

---

## 📱 Android签名密钥管理

### 初始生成

```bash
cd scripts
./generate_keystore.sh
```

这将生成：
- `app/android/keystore/release.keystore` - 签名密钥文件
- `app/android/key.properties` - 密钥配置文件

### 密钥备份

**极其重要：** 签名密钥丢失将导致应用无法更新！

```bash
# 1. 备份到安全位置（不要提交到Git）
cp app/android/keystore/release.keystore ~/backups/ai-bookkeeping-$(date +%Y%m%d).keystore

# 2. 记录密钥信息
Keystore密码: [记录在密码管理器中]
别名: ai-bookkeeping-release
密钥密码: [记录在密码管理器中]

# 3. 定期验证备份可用
keytool -list -v -keystore ~/backups/ai-bookkeeping-20260109.keystore
```

### 密钥泄露应对

如果签名密钥泄露：

1. **立即评估影响**：密钥泄露意味着任何人都可以发布伪造的应用更新
2. **通知用户**：通过官方渠道告知用户只从官方应用商店下载
3. **向应用商店报告**：Google Play/App Store可以协助处理
4. **考虑发布新应用**：极端情况下可能需要更换包名发布新应用

**预防措施：**
- 密钥文件仅存储在安全的本地环境和备份位置
- 使用强密码保护密钥
- 限制访问权限（文件权限600）
- 定期审计密钥访问记录

---

## 🔒 密码策略

### 密码强度要求

所有密码必须满足：
- 最小长度16位
- 包含大小写字母、数字和特殊字符
- 不包含常见词汇或个人信息
- 不重复使用其他系统的密码

### 推荐的密码生成方法

```bash
# 方法1：使用openssl生成（24字符，base64编码）
openssl rand -base64 24

# 方法2：使用python生成（32字符，URL安全）
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 方法3：使用pwgen生成（20字符，包含特殊字符）
pwgen -s -y 20 1
```

---

## ☁️ 云环境密钥管理

对于生产环境，强烈建议使用专业的密钥管理服务：

### AWS Secrets Manager

```bash
# 存储密钥
aws secretsmanager create-secret \
    --name aibook/postgres/password \
    --secret-string "your_password_here"

# 在应用中读取
import boto3
client = boto3.client('secretsmanager')
response = client.get_secret_value(SecretId='aibook/postgres/password')
password = response['SecretString']
```

### HashiCorp Vault

```bash
# 存储密钥
vault kv put secret/aibook postgres_password="your_password"

# 在应用中读取
vault kv get -field=postgres_password secret/aibook
```

### Google Secret Manager

```bash
# 存储密钥
gcloud secrets create postgres-password --data-file=-

# 在应用中读取
gcloud secrets versions access latest --secret="postgres-password"
```

---

## ✅ 安全检查清单

部署前请确认：

- [ ] 所有`.env`文件都已添加到`.gitignore`
- [ ] 没有硬编码的密码、API密钥或证书
- [ ] 生产环境SSL证书验证已启用（`skip_certificate_verification: false`）
- [ ] Android签名密钥已安全备份
- [ ] 数据库、Redis等服务使用强密码
- [ ] 所有第三方API密钥已从提供商处正确获取
- [ ] JWT密钥使用强随机字符串
- [ ] 服务器防火墙已正确配置（仅开放必要端口）
- [ ] 日志中不包含敏感信息
- [ ] 定期备份策略已建立

---

## 🚨 安全事件响应

### 发现密钥泄露时：

1. **立即轮转泄露的密钥**（按照上述轮转步骤）
2. **审查Git历史**：检查密钥是否被提交到版本控制
   ```bash
   git log --all --full-history -- path/to/sensitive/file
   ```
3. **审查访问日志**：确定是否有异常访问
4. **通知相关方**：如果涉及用户数据，可能需要通知用户
5. **更新安全措施**：分析root cause，防止再次发生

### 紧急联系

- 技术负责人: [填写联系方式]
- 安全团队: [填写联系方式]
- 云服务商支持: [填写支持渠道]

---

## 📚 相关文档

- [Android开发环境配置指南](./Android开发环境配置指南.md)
- [服务器部署配置](./服务器部署配置.md)
- [.env.example](../server/.env.example)
- [key.properties.example](../app/android/key.properties.example)

---

**最后更新：** 2026-01-09
**负责人：** 开发团队
**审核周期：** 每季度

