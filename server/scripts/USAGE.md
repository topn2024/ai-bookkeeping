# 数据库重置脚本使用指南

## 快速开始

### 1. 确保环境准备就绪

```bash
cd /home/finch/work/code/ai-bookkeeping/server

# 激活虚拟环境
source .venv/bin/activate

# 确认环境变量已配置
cat .env | grep DATABASE_URL
```

### 2. 运行重置脚本

```bash
# 方式一：使用交互式脚本（推荐）
./scripts/reset_db.sh

# 方式二：直接运行 Python 脚本
python3 scripts/reset_database.py --mode init
```

### 3. 验证结果

```bash
python3 scripts/verify_database.py
```

## 完整示例

```bash
# 1. 进入项目目录
cd /home/finch/work/code/ai-bookkeeping/server

# 2. 激活虚拟环境
source .venv/bin/activate

# 3. 重建数据库并初始化系统数据
python3 scripts/reset_database.py --mode init

# 4. 验证初始化结果
python3 scripts/verify_database.py

# 5. 测试登录
# 管理后台: http://localhost:8001/admin
# 用户名: admin
# 密码: admin123
```

## 三种模式详解

### Mode: clean

仅重建表结构，不初始化任何数据。

```bash
python3 scripts/reset_database.py --mode clean
```

**适用场景：**
- 表结构更新后需要重建
- 需要空白数据库进行测试

**结果：**
- ✅ 删除所有表
- ✅ 重新创建所有表
- ❌ 无系统数据
- ❌ 无测试数据

### Mode: init（推荐）

重建表并初始化系统数据。

```bash
python3 scripts/reset_database.py --mode init
```

**适用场景：**
- 测试环境重置
- 表结构更新后重建
- 日常开发环境重置

**结果：**
- ✅ 删除并重建所有表
- ✅ 23个系统分类（餐饮、购物等）
- ✅ 5个管理员角色
- ✅ 40+管理员权限
- ✅ 默认管理员账号（admin/admin123）
- ❌ 无测试数据

### Mode: full

完整重置，包含测试数据。

```bash
python3 scripts/reset_database.py --mode full
```

**适用场景：**
- 首次设置开发环境
- 需要示例数据进行功能测试
- 演示环境准备

**结果：**
- ✅ 执行 init 模式的所有操作
- ✅ 测试用户（13800138000/test123）
- ✅ 4个账户（现金、银行卡、支付宝、微信）
- ✅ 5笔交易记录
- ✅ 1个月度预算

## 跳过确认提示

在 CI/CD 或自动化脚本中使用：

```bash
python3 scripts/reset_database.py --mode full --confirm
```

⚠️ **警告：** 这会跳过确认提示，直接执行删除操作！

## 常见问题

### Q: 提示 "ModuleNotFoundError: No module named 'sqlalchemy'"

**A:** 需要先激活虚拟环境：

```bash
source .venv/bin/activate
```

### Q: 提示 "数据库连接失败"

**A:** 检查环境变量和数据库服务：

```bash
# 检查环境变量
cat .env | grep DATABASE_URL

# 检查数据库服务
docker ps | grep postgres
# 或
systemctl status postgresql
```

### Q: 如何在不同环境使用不同的数据库？

**A:** 使用不同的 .env 文件：

```bash
# 开发环境
cp .env.dev .env
python3 scripts/reset_database.py --mode full

# 测试环境
cp .env.test .env
python3 scripts/reset_database.py --mode init
```

### Q: 可以只初始化某些数据吗？

**A:** 目前不支持。如需自定义，可以：

1. 使用 `--mode clean` 重建表
2. 手动运行特定的初始化函数
3. 或修改脚本添加自定义模式

### Q: 如何备份数据？

**A:** 在重置前使用 pg_dump：

```bash
# 备份数据库
pg_dump -h localhost -U your_user -d your_db > backup.sql

# 重置数据库
python3 scripts/reset_database.py --mode init

# 如需恢复
psql -h localhost -U your_user -d your_db < backup.sql
```

## 脚本执行流程

```
开始
  ↓
显示警告信息
  ↓
用户确认（输入 YES）
  ↓
删除所有表 (DROP ALL TABLES)
  ↓
创建所有表 (CREATE ALL TABLES)
  ↓
[如果 mode = init 或 full]
  ↓
初始化系统分类
  ↓
初始化管理员角色和权限
  ↓
创建默认管理员
  ↓
[如果 mode = full]
  ↓
创建测试用户
  ↓
创建示例数据
  ↓
完成
```

## 初始化数据详情

### 系统分类（23个）

**支出分类（16个）：**
餐饮、购物、交通、娱乐、医疗、住房、教育、通讯、服饰、美容、运动、旅游、数码、宠物、礼物、其他

**收入分类（7个）：**
工资、奖金、投资、兼职、红包、退款、其他

### 管理员角色（5个）

1. **super_admin** - 超级管理员（所有权限）
2. **operator** - 运营管理员（用户和数据管理）
3. **analyst** - 数据分析员（只读权限）
4. **customer_service** - 客服专员（用户支持）
5. **auditor** - 审计员（日志查看）

### 测试数据（仅 full 模式）

**测试用户：**
- 手机：13800138000
- 邮箱：test@example.com
- 密码：test123
- 昵称：测试用户

**账户（4个）：**
- 现金：¥1,000.00
- 工商银行：¥5,000.00
- 支付宝：¥2,000.00
- 微信：¥500.00

**交易（5笔）：**
- 收入：工资 ¥8,000.00
- 支出：午餐 ¥45.50
- 支出：买衣服 ¥299.00
- 支出：打车 ¥15.00
- 支出：晚餐 ¥68.00

**预算（1个）：**
- 月度预算：¥3,000.00

## 相关文档

- [详细文档](./README.md)
- [快速开始](./QUICKSTART.md)
- [更新说明](./CHANGELOG.md)
