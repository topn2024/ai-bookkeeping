# 数据库重置脚本 - 更新说明

## 主要变更

### ✅ 支持表结构重建

脚本现在会**删除所有表并重新创建**，而不是仅仅清空数据。这意味着：

1. **支持表结构变更**：当数据库模型发生变化时（添加字段、修改类型、添加约束等），可以直接使用此脚本重建数据库
2. **完全重置**：确保数据库结构与代码模型完全一致
3. **避免迁移问题**：不需要手动处理复杂的数据库迁移

### 🔧 实现方式

使用 PostgreSQL 的 CASCADE 删除来处理循环外键依赖：

```python
# 删除整个 public schema（包含所有表）
await conn.execute(text("DROP SCHEMA public CASCADE"))

# 重新创建 schema
await conn.execute(text("CREATE SCHEMA public"))

# 恢复默认权限
await conn.execute(text("GRANT ALL ON SCHEMA public TO PUBLIC"))

# 使用 SQLAlchemy 创建所有表
await conn.run_sync(Base.metadata.create_all)
```

### 🐛 解决的问题

**循环外键依赖**：`transactions` 和 `resource_pools` 表之间存在循环依赖：
- `transactions.resource_pool_id` → `resource_pools.id`
- `resource_pools.income_transaction_id` → `transactions.id`

使用 `DROP SCHEMA CASCADE` 可以一次性删除所有表，避免外键约束冲突。

### 📋 三种模式

1. **clean** - 仅重建表结构
   - 删除所有表
   - 重新创建所有表
   - 不初始化任何数据

2. **init** - 重建表并初始化系统数据（推荐）
   - 删除并重建所有表
   - 初始化系统分类（23个预设分类）
   - 初始化管理员角色和权限（5个角色，40+权限）
   - 创建默认管理员账号（admin/admin123）

3. **full** - 完整重置（含测试数据）
   - 执行 init 模式的所有操作
   - 创建测试用户（13800138000/test123）
   - 创建示例账本、账户、交易、预算

## 使用场景

### 场景 1：表结构更新

当你修改了数据库模型（例如在 `app/models/` 中添加了新字段），运行：

```bash
python3 scripts/reset_database.py --mode init
```

这会删除旧表，创建新表，并初始化系统数据。

### 场景 2：开发环境初始化

首次设置开发环境或需要测试数据时：

```bash
python3 scripts/reset_database.py --mode full
```

### 场景 3：测试环境重置

在测试前重置环境：

```bash
python3 scripts/reset_database.py --mode init
```

## 安全提示

⚠️ **极其重要：**

1. **仅用于测试环境** - 此脚本会永久删除所有数据
2. **不可恢复** - 表删除后无法回滚
3. **确认数据库** - 执行前务必确认 DATABASE_URL
4. **生产环境禁用** - 切勿在生产环境使用

## 与 Alembic 的关系

- **Alembic**：用于生产环境的渐进式数据库迁移
- **reset_database.py**：用于测试环境的快速重建

在开发过程中：
1. 修改模型后，使用 `reset_database.py` 快速重建测试数据库
2. 准备发布时，使用 Alembic 创建迁移脚本用于生产环境

## 文件清单

- `scripts/reset_database.py` - 主脚本
- `scripts/reset_db.sh` - 交互式快捷脚本
- `scripts/verify_database.py` - 验证脚本
- `scripts/README.md` - 详细文档
- `scripts/QUICKSTART.md` - 快速开始指南

## 验证

重置后可以运行验证脚本：

```bash
python3 scripts/verify_database.py
```

这会检查：
- 系统分类是否正确创建
- 管理员角色和权限是否正确
- 默认管理员账号是否存在
- 测试数据是否正确（如果使用 full 模式）

## 示例输出

```
🔧 AI记账 - 数据库重置工具
============================================================

⚠️  警告：数据库重置操作
============================================================
模式: init
数据库: postgresql://...

此操作将：
  ❌ 删除所有数据库表
  ❌ 删除所有用户数据
  ❌ 删除所有交易记录
  ✅ 重新创建所有表结构
  ✅ 初始化系统分类
  ✅ 初始化管理员角色和权限
  ✅ 创建默认管理员账号

============================================================
确认执行此操作？(输入 'YES' 继续): YES

🔨 重建数据库表结构...
  🗑️  删除所有表...
  ✓ 所有表已删除
  🏗️  创建所有表...
  ✓ 所有表已创建
✅ 表结构重建完成

📁 初始化系统分类...
  ✓ 创建支出分类: 餐饮
  ✓ 创建支出分类: 购物
  ...
✅ 系统分类初始化完成

👥 初始化管理员角色和权限...
  ✓ 创建权限: dashboard:view - 查看仪表盘
  ...
✅ 管理员角色和权限初始化完成

👤 创建默认超级管理员...
  ✓ 用户名: admin
  ✓ 密码: admin123
  ✓ 邮箱: admin@example.com
✅ 默认管理员创建完成

============================================================
✅ 数据库重置完成！
============================================================
```
