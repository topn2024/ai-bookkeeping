# 技术说明：循环外键依赖处理

## 问题描述

在执行数据库表删除时，遇到了循环外键依赖错误：

```
Can't sort tables for DROP; an unresolvable foreign key dependency exists
between tables: resource_pools, transactions.
```

## 根本原因

数据库模型中存在循环外键依赖：

### 依赖关系

1. **transactions → resource_pools**
   ```python
   # app/models/transaction.py
   class Transaction(Base):
       resource_pool_id: Mapped[Optional[uuid.UUID]] = mapped_column(
           UUID(as_uuid=True),
           ForeignKey("resource_pools.id"),
           nullable=True
       )
   ```

2. **resource_pools → transactions**
   ```python
   # app/models/money_age.py
   class ResourcePool(Base):
       income_transaction_id: Mapped[uuid.UUID] = mapped_column(
           UUID(as_uuid=True),
           ForeignKey("transactions.id"),
           nullable=False
       )
   ```

3. **consumption_records → transactions**
   ```python
   # app/models/money_age.py
   class ConsumptionRecord(Base):
       expense_transaction_id: Mapped[uuid.UUID] = mapped_column(
           UUID(as_uuid=True),
           ForeignKey("transactions.id"),
           nullable=False
       )
   ```

### 循环依赖图

```
transactions ←→ resource_pools
     ↑
     |
consumption_records
```

这种循环依赖导致 SQLAlchemy 无法确定删除表的正确顺序。

## 解决方案

### 方案一：DROP SCHEMA CASCADE（已采用）

使用 PostgreSQL 的 `DROP SCHEMA CASCADE` 命令，一次性删除整个 schema 及其所有对象。

```python
async def drop_and_create_tables():
    async with engine.begin() as conn:
        # 删除整个 public schema（包含所有表、视图、序列等）
        await conn.execute(text("DROP SCHEMA public CASCADE"))

        # 重新创建 schema
        await conn.execute(text("CREATE SCHEMA public"))

        # 恢复默认权限
        await conn.execute(text("GRANT ALL ON SCHEMA public TO PUBLIC"))

        # 使用 SQLAlchemy 创建所有表
        await conn.run_sync(Base.metadata.create_all)
```

**优点：**
- ✅ 简单可靠
- ✅ 自动处理所有外键约束
- ✅ 删除所有数据库对象（表、视图、序列等）
- ✅ 适用于测试环境的完全重置

**缺点：**
- ⚠️ 会删除 schema 中的所有对象（包括非 SQLAlchemy 管理的对象）
- ⚠️ 需要足够的数据库权限

### 方案二：禁用外键约束（备选）

临时禁用外键约束检查，删除表后重新启用。

```python
async def drop_and_create_tables():
    async with engine.begin() as conn:
        # 禁用外键约束
        await conn.execute(text("SET session_replication_role = 'replica'"))

        # 删除所有表
        await conn.run_sync(Base.metadata.drop_all)

        # 重新启用外键约束
        await conn.execute(text("SET session_replication_role = 'origin'"))

        # 创建所有表
        await conn.run_sync(Base.metadata.create_all)
```

**优点：**
- ✅ 保留其他数据库对象
- ✅ 更精确的控制

**缺点：**
- ⚠️ 需要超级用户权限或特定角色
- ⚠️ 可能在某些 PostgreSQL 配置下不可用

### 方案三：手动删除表（不推荐）

按照依赖关系手动指定删除顺序。

```python
tables_to_drop = [
    "consumption_records",
    "resource_pools",
    "transactions",
    # ... 其他表
]

for table in tables_to_drop:
    await conn.execute(text(f"DROP TABLE IF EXISTS {table} CASCADE"))
```

**缺点：**
- ❌ 需要手动维护删除顺序
- ❌ 容易出错
- ❌ 不适合动态模型变更

## 为什么会有循环依赖？

这是 Money Age 功能的设计需求：

1. **收入交易创建资源池**：当用户记录收入时，创建一个 `ResourcePool` 来追踪这笔钱
2. **支出交易消耗资源池**：当用户记录支出时，从 `ResourcePool` 中扣除（FIFO 策略）
3. **交易记录资源池信息**：`Transaction` 需要记录它关联的 `ResourcePool`（用于显示金钱年龄）

这种双向关联是业务逻辑的必然结果。

## 最佳实践

### 开发环境

使用 `DROP SCHEMA CASCADE` 方案，因为：
- 简单快速
- 完全重置环境
- 不需要担心遗留对象

### 生产环境

**不要使用此脚本！** 应该使用 Alembic 进行渐进式迁移：

```bash
# 创建迁移
alembic revision --autogenerate -m "description"

# 应用迁移
alembic upgrade head
```

## 相关资源

- [PostgreSQL DROP SCHEMA 文档](https://www.postgresql.org/docs/current/sql-dropschema.html)
- [SQLAlchemy 循环依赖处理](https://docs.sqlalchemy.org/en/20/core/constraints.html#configuring-constraint-naming-conventions)
- [Money Age 功能设计文档](../docs/money_age.md)

## 总结

循环外键依赖是复杂业务逻辑的正常现象。在测试环境中，使用 `DROP SCHEMA CASCADE` 是最简单可靠的解决方案。在生产环境中，应该使用 Alembic 进行受控的数据库迁移。
