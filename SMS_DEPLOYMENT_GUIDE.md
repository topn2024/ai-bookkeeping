# 短信验证功能部署指南

## 一、功能概述

本次更新为AI记账应用添加了完整的短信验证功能，支持：

1. **发送短信验证码** - 支持三种场景：
   - 登录 (login)
   - 注册 (register)
   - 重置密码 (reset_password)

2. **短信验证码登录** - 使用手机号+验证码登录，支持自动注册新用户

3. **安全特性**：
   - 6位数字验证码，10分钟有效期
   - Redis存储，自动过期
   - 速率限制（3次/分钟）
   - 验证码使用后自动删除
   - 不透露用户是否存在（安全设计）

---

## 二、服务器部署步骤

### 2.1 在服务器39.105.12.124上安装依赖

```bash
# SSH登录服务器
ssh root@39.105.12.124

# 切换到应用用户
su - ai-bookkeeping

# 激活虚拟环境
source /home/ai-bookkeeping/venv/bin/activate

# 安装阿里云SMS SDK
cd /home/ai-bookkeeping/app/server
pip install --no-cache-dir alibabacloud-dysmsapi20170525==2.0.24
```

### 2.2 配置阿里云短信服务

#### 2.2.1 在阿里云控制台完成以下配置

1. **开通短信服务**
   - 登录阿里云控制台 https://www.aliyun.com/
   - 进入"短信服务"产品页
   - 开通短信服务

2. **申请短信签名**
   - 签名名称：`AI智能记账`（或其他已备案的名称）
   - 签名类型：网站/App
   - 提交相关资质文件
   - 等待审核通过（通常1-2个工作日）

3. **申请短信模板**
   - 模板类型：验证码
   - 模板内容示例：
     ```
     您的验证码是：${code}，有效期10分钟，请勿泄露给他人。【AI智能记账】
     ```
   - 提交审核
   - 记录模板CODE（例如：SMS_123456789）

4. **获取AccessKey**
   - 从阿里云控制台获取：
     - AccessKeyId: `YOUR_ALIYUN_ACCESS_KEY_ID` (示例，请替换为实际值)
     - AccessKeySecret: `YOUR_ALIYUN_ACCESS_KEY_SECRET` (示例，请替换为实际值)

#### 2.2.2 更新服务器环境变量

```bash
# 编辑.env文件
vi /home/ai-bookkeeping/app/server/.env

# 添加以下配置（追加到文件末尾）
ALIYUN_ACCESS_KEY_ID=YOUR_ALIYUN_ACCESS_KEY_ID  # 替换为实际的AccessKey ID
ALIYUN_ACCESS_KEY_SECRET=YOUR_ALIYUN_ACCESS_KEY_SECRET  # 替换为实际的AccessKey Secret
ALIYUN_SMS_SIGN_NAME=AI智能记账
ALIYUN_SMS_TEMPLATE_CODE=SMS_XXXXXXXXX  # 替换为实际的模板CODE
ALIYUN_SMS_REGION=cn-hangzhou

# 保存退出
:wq
```

### 2.3 上传代码到服务器

```bash
# 在本地代码目录执行
cd /Users/beihua/code/baiji/ai-bookkeeping

# 同步server目录到服务器
rsync -avz --exclude='__pycache__' --exclude='*.pyc' \
    server/ root@39.105.12.124:/home/ai-bookkeeping/app/server/

# 或使用git拉取（如果代码已提交）
ssh root@39.105.12.124
su - ai-bookkeeping
cd /home/ai-bookkeeping/app
git pull origin master
```

### 2.4 重启服务

```bash
# SSH登录服务器
ssh root@39.105.12.124

# 重启API服务
systemctl restart ai-bookkeeping-api@8000
systemctl restart ai-bookkeeping-api@8001
systemctl restart ai-bookkeeping-admin

# 检查服务状态
systemctl status ai-bookkeeping-api@8000
systemctl status ai-bookkeeping-api@8001

# 查看日志
tail -f /var/log/ai-bookkeeping/api-8000.log
```

---

## 三、API接口文档

### 3.1 发送短信验证码

**接口**: `POST /api/v1/auth/sms-code`

**请求体**:
```json
{
  "phone": "13800138000",
  "scene": "login"
}
```

**参数说明**:
- `phone`: 手机号（11位，必填）
- `scene`: 场景（可选值：`login` | `register` | `reset_password`，默认：`login`）

**响应示例**:
```json
{
  "success": true,
  "message": "验证码已发送，请注意查收短信",
  "expires_in": 600
}
```

**速率限制**: 3次/分钟（已在中间件配置）

---

### 3.2 短信验证码登录

**接口**: `POST /api/v1/auth/sms-login`

**请求体**:
```json
{
  "phone": "13800138000",
  "code": "123456",
  "auto_register": true
}
```

**参数说明**:
- `phone`: 手机号（11位，必填）
- `code`: 6位验证码（必填）
- `auto_register`: 如果用户不存在是否自动注册（可选，默认：`true`）

**响应示例**:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "phone": "13800138000",
    "email": null,
    "nickname": "用户8000",
    "avatar_url": null,
    "member_level": 0,
    "member_expire_at": null,
    "created_at": "2026-01-12T12:00:00Z"
  }
}
```

---

## 四、功能测试

### 4.1 测试环境准备

```bash
# 开启DEBUG模式查看验证码（仅用于测试）
vi /home/ai-bookkeeping/app/server/.env

# 添加或修改
DEBUG=true

# 重启服务
systemctl restart ai-bookkeeping-api@8000
```

### 4.2 测试用例

#### 测试1：发送验证码（新用户注册）

```bash
curl -X POST https://39.105.12.124/api/v1/auth/sms-code \
  -k \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "13800138000",
    "scene": "register"
  }'

# 预期响应
{
  "success": true,
  "message": "验证码已发送，请注意查收短信",
  "expires_in": 600
}

# 在服务器日志中查看验证码（DEBUG模式）
tail -f /var/log/ai-bookkeeping/api-8000.log
# 输出示例：[DEV] SMS code for 13800138000 (register): 123456
```

#### 测试2：短信验证码登录（自动注册）

```bash
curl -X POST https://39.105.12.124/api/v1/auth/sms-login \
  -k \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "13800138000",
    "code": "123456",
    "auto_register": true
  }'

# 预期响应：返回JWT token和用户信息
```

#### 测试3：重复使用验证码（应失败）

```bash
# 再次使用相同验证码登录
curl -X POST https://39.105.12.124/api/v1/auth/sms-login \
  -k \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "13800138000",
    "code": "123456",
    "auto_register": true
  }'

# 预期响应：400 Bad Request
{
  "detail": "验证码无效或已过期"
}
```

#### 测试4：速率限制测试

```bash
# 快速发送4次请求
for i in {1..4}; do
  curl -X POST https://39.105.12.124/api/v1/auth/sms-code \
    -k \
    -H "Content-Type: application/json" \
    -d '{"phone": "13800138000", "scene": "login"}'
  echo ""
done

# 预期：第4次请求被速率限制拦截（429 Too Many Requests）
```

### 4.3 生产环境配置

测试完成后，关闭DEBUG模式：

```bash
vi /home/ai-bookkeeping/app/server/.env

# 修改
DEBUG=false

# 重启服务
systemctl restart ai-bookkeeping-api@8000
systemctl restart ai-bookkeeping-api@8001
```

---

## 五、技术架构说明

### 5.1 文件结构

```
server/
├── app/
│   ├── api/
│   │   └── v1/
│   │       └── auth.py                    # ✅ 新增SMS端点
│   ├── core/
│   │   └── config.py                      # ✅ 新增SMS配置
│   ├── schemas/
│   │   └── user.py                        # ✅ 新增SMS schemas
│   ├── services/
│   │   ├── notification_email_service.py  # 现有邮件服务
│   │   └── notification_sms_service.py    # ✅ 新增SMS服务
│   └── middleware/
│       └── rate_limit.py                  # 已配置SMS端点限流
└── requirements.txt                       # ✅ 新增SMS SDK依赖
```

### 5.2 Redis键命名规范

```
# 短信验证码
sms_code:{scene}:{phone}
示例：sms_code:login:13800138000
TTL：600秒（10分钟）

# 邮件验证码（现有）
password_reset:{email}
TTL：600秒（10分钟）
```

### 5.3 速率限制配置

已在 `app/middleware/rate_limit.py` 中配置：

```python
ENDPOINT_RATE_LIMITS = {
    "POST:/api/v1/auth/sms-code": RateLimitConfig(3, 60),  # 3次/分钟
    "POST:/api/v1/auth/sms-login": RateLimitConfig(10, 60),  # 10次/分钟
}
```

### 5.4 安全考虑

1. **不透露用户是否存在**
   - 登录/重置密码场景：即使手机号不存在，也返回成功
   - 注册场景：明确提示手机号已注册

2. **验证码单次使用**
   - 验证成功后立即从Redis删除
   - 防止重放攻击

3. **速率限制**
   - 防止短信轰炸
   - 防止暴力破解

4. **验证码安全性**
   - 6位随机数字
   - 仅在DEBUG模式下记录日志
   - 生产环境不记录验证码

---

## 六、故障排查

### 6.1 SMS发送失败

**症状**: 返回成功但未收到短信

**检查步骤**:

```bash
# 1. 检查日志
tail -100 /var/log/ai-bookkeeping/api-8000.log | grep SMS

# 2. 检查配置
cat /home/ai-bookkeeping/app/server/.env | grep ALIYUN

# 3. 测试阿里云凭证
python3 << EOF
from alibabacloud_dysmsapi20170525.client import Client
from alibabacloud_tea_openapi.models import Config

config = Config(
    access_key_id="YOUR_ACCESS_KEY_ID",  # 替换为实际的AccessKey ID
    access_key_secret="YOUR_ACCESS_KEY_SECRET"  # 替换为实际的AccessKey Secret
)
config.endpoint = "dysmsapi.aliyuncs.com"
client = Client(config)
print("Client created successfully")
EOF
```

**常见问题**:
- AccessKey权限不足 → 在阿里云控制台检查RAM权限
- 短信签名未审核通过 → 检查签名状态
- 短信模板未审核通过 → 检查模板状态
- 手机号格式错误 → 检查是否为11位数字
- 短信余额不足 → 检查阿里云账户余额

### 6.2 验证码过期

**症状**: 提示"验证码无效或已过期"

**解决方案**:
```bash
# 检查Redis连接
redis-cli -h localhost -p 6379 -a 6cmta6qGn5tjYctVBBkb ping

# 查看验证码（DEBUG模式）
redis-cli -h localhost -p 6379 -a 6cmta6qGn5tjYctVBBkb
> KEYS sms_code:*
> TTL sms_code:login:13800138000
> GET sms_code:login:13800138000
```

---

## 七、运维建议

### 7.1 监控指标

建议监控以下指标：

```bash
# 短信发送成功率
grep "SMS sent successfully" /var/log/ai-bookkeeping/api-8000.log | wc -l

# 短信发送失败次数
grep "Failed to send SMS" /var/log/ai-bookkeeping/api-8000.log | wc -l

# 验证码验证失败次数
grep "验证码错误" /var/log/ai-bookkeeping/api-8000.log | wc -l
```

### 7.2 成本控制

阿里云短信计费：
- 国内短信：约0.045元/条
- 建议设置月度预算上限
- 配置告警阈值

### 7.3 备份方案

如果短信服务不可用，用户仍可使用：
- 邮箱+密码登录
- OAuth登录（微信、Apple、Google）

---

## 八、后续优化建议

1. **短信模板管理**
   - 支持多种短信模板（营销、通知等）
   - 配置化模板参数

2. **国际化支持**
   - 支持国际手机号
   - 多语言短信内容

3. **监控告警**
   - 短信发送失败率告警
   - 验证码验证失败率告警
   - 成本超额告警

4. **用户体验优化**
   - 语音验证码备选方案
   - 验证码倒计时提示
   - 重发验证码冷却时间

---

## 附录：环境变量完整配置

```bash
# 阿里云短信配置
ALIYUN_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID  # 替换为实际的AccessKey ID
ALIYUN_ACCESS_KEY_SECRET=YOUR_ACCESS_KEY_SECRET  # 替换为实际的AccessKey Secret
ALIYUN_SMS_SIGN_NAME=AI智能记账
ALIYUN_SMS_TEMPLATE_CODE=SMS_XXXXXXXXX  # 需替换为实际模板CODE
ALIYUN_SMS_REGION=cn-hangzhou
```

**部署完成时间**: 2026-01-12
**版本**: v1.0
**联系人**: AI Assistant
