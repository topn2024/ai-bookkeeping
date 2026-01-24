# 快速开始 - 数据库重置

⚠️ **重要：此脚本会删除所有表并重新创建，支持表结构变更**

## 方式一：使用交互式脚本（推荐）

```bash
cd server
./scripts/reset_db.sh
```

然后根据提示选择模式：
- 选项 1: 仅重建表结构
- 选项 2: 重建表并初始化系统数据（推荐）
- 选项 3: 完整重置（含测试数据）

## 方式二：直接使用 Python 脚本

```bash
cd server

# 重建表并初始化系统数据（推荐）
python3 scripts/reset_database.py --mode init

# 完整重置（含测试数据）
python3 scripts/reset_database.py --mode full

# 仅重建表结构
python3 scripts/reset_database.py --mode clean
```

## 常见使用场景

### 场景 1：开发环境初始化

```bash
# 首次设置开发环境
cd server
python3 scripts/reset_database.py --mode full
```

这将创建：
- 系统预设分类
- 管理员角色和权限
- 默认管理员账号（admin/admin123）
- 测试用户账号（13800138000/test123）
- 示例交易数据

### 场景 2：表结构变更后重建

```bash
# 当数据库模型发生变化时（添加字段、修改类型等）
cd server
python3 scripts/reset_database.py --mode init
```

这将：
- 删除所有旧表
- 根据最新模型创建新表
- 初始化系统数据

### 场景 3：测试环境重置

```bash
# 重置测试环境
cd server
python3 scripts/reset_database.py --mode init
```

这将：
- 删除所有表和数据
- 重新创建所有表
- 初始化系统分类
- 创建管理员角色
- 创建默认管理员账号

### 场景 4：CI/CD 自动化测试

```bash
# 在 CI/CD 脚本中使用
cd server
python3 scripts/reset_database.py --mode full --confirm
```

`--confirm` 参数会跳过确认提示，适合自动化场景。

## 初始化后的账号

### 管理后台登录

- URL: http://localhost:8001/admin
- 用户名: `admin`
- 密码: `admin123`

### 用户端登录（仅 full 模式）

- 手机号: `13800138000`
- 密码: `test123`

或

- 邮箱: `test@example.com`
- 密码: `test123`

## 注意事项

⚠️ **重要：**
1. 此脚本会**删除所有表并重新创建**，所有数据将永久丢失
2. 仅用于测试环境，切勿在生产环境使用
3. 执行前请确认 DATABASE_URL 指向正确的数据库
4. 支持表结构变更，当模型更新后可直接使用此脚本重建

## 故障排除

### 问题：数据库连接失败

```bash
# 检查环境变量
cat .env | grep DATABASE_URL

# 确保数据库服务运行中
docker ps | grep postgres
```

### 问题：权限不足

确保数据库用户有 TRUNCATE 权限：

```sql
GRANT TRUNCATE ON ALL TABLES IN SCHEMA public TO your_user;
```

### 问题：找不到模块

```bash
# 确保在 server 目录下
cd server

# 激活虚拟环境
source .venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

## 更多信息

详细文档请参考：[scripts/README.md](./README.md)
