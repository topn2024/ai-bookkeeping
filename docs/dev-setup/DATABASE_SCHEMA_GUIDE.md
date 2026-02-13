# 数据库架构管理指南

**更新日期**: 2026-01-12
**管理方式**: 直接从模型定义创建表（无迁移脚本）

---

## 📋 总览

本项目采用**模型定义优先**的数据库管理方式：
- ✅ 所有表结构由 SQLAlchemy 模型定义
- ✅ 开发环境直接从模型创建/重建表
- ✅ 无需维护 Alembic 迁移脚本
- ✅ 简单、直观、不会出现模型与迁移不一致的问题

---

## 🗂️ 数据库模型清单

### 核心业务模型（8个）

| 模型 | 文件 | 表名 | 说明 |
|------|------|------|------|
| User | user.py | users | 用户账户 |
| Account | account.py | accounts | 资金账户 |
| Book | book.py | books | 账本 |
| Transaction | transaction.py | transactions | 交易记录 |
| Category | category.py | categories | 收支分类 |
| Budget | budget.py | budgets | 预算管理 |
| ExpenseTarget | expense_target.py | expense_targets | 支出目标 |
| Backup | backup.py | backups | 数据备份 |

### 协作功能模型（8个）

| 模型 | 文件 | 表名 | 说明 |
|------|------|------|------|
| BookMember | book.py | book_members | 账本成员 |
| BookInvitation | book.py | book_invitations | 账本邀请 ✅ |
| FamilyBudget | book.py | family_budgets | 家庭预算 ✅ |
| MemberBudget | book.py | member_budgets | 成员预算 |
| FamilySavingGoal | book.py | family_saving_goals | 储蓄目标 |
| GoalContribution | book.py | goal_contributions | 储蓄贡献 |
| TransactionSplit | book.py | transaction_splits | 分账记录 |
| SplitParticipant | book.py | split_participants | 分账参与者 |

### 智能功能模型（7个）

| 模型 | 文件 | 表名 | 说明 |
|------|------|------|------|
| GeoFence | location.py | geo_fences | 地理围栏 |
| FrequentLocation | location.py | frequent_locations | 常访位置 |
| UserHomeLocation | location.py | user_home_locations | 家/工作位置 |
| ResourcePool | money_age.py | resource_pools | 资金池（钱龄） |
| ConsumptionRecord | money_age.py | consumption_records | 消费记录 |
| MoneyAgeSnapshot | money_age.py | money_age_snapshots | 钱龄快照 |
| MoneyAgeConfig | money_age.py | money_age_configs | 钱龄配置 |

### 系统功能模型（8个）

| 模型 | 文件 | 表名 | 说明 |
|------|------|------|------|
| AppVersion | app_version.py | app_versions | 应用版本 |
| UpgradeAnalytics | upgrade_analytics.py | upgrade_analytics | 升级分析 |
| EmailBinding | email_binding.py | email_bindings | 邮箱绑定 |
| OAuthProvider | oauth_provider.py | oauth_providers | OAuth登录 |
| CompanionMessageLibrary | companion_message.py | companion_message_library | AI消息库 |
| CompanionMessageGenerationLog | companion_message.py | companion_message_generation_log | 消息生成日志 |
| CompanionMessageFeedback | companion_message.py | companion_message_feedback | 用户反馈 |
| DataQualityCheck | data_quality_check.py | data_quality_checks | 数据质量 |

### 管理后台模型（2个）

| 模型 | 文件 | 表名 | 说明 |
|------|------|------|------|
| AdminUser | admin.py | admin_users | 管理员账户 |
| AdminLog | admin.py | admin_logs | 管理日志 |

**总计**: 33 个表

---

## 🚀 数据库初始化

### 方式1：使用初始化脚本（推荐）

```bash
# 开发环境
cd server
python scripts/init_database.py

# 会提示确认删除所有数据，输入 YES 继续
# ⚠️ 此脚本仅在 DEBUG=true 时可运行
```

脚本功能：
1. ✅ 检查数据库连接
2. ✅ 删除所有现有表
3. ✅ 根据模型创建所有表
4. ✅ 验证表结构完整性
5. ✅ 显示详细报告

### 方式2：使用 Python 代码

```python
from app.core.database import engine, Base

# 导入所有模型
from app.models import *

# 创建所有表
Base.metadata.create_all(bind=engine)

# 删除所有表（谨慎使用）
# Base.metadata.drop_all(bind=engine)
```

### 方式3：生产环境部署

```bash
# 1. 在生产服务器上
ssh root@your-server

# 2. 准备数据库
sudo -u postgres psql
CREATE DATABASE ai_bookkeeping OWNER ai_bookkeeping;
\q

# 3. 初始化表结构
cd /home/ai-bookkeeping/app/server
source /home/ai-bookkeeping/venv/bin/activate

# 创建一个临时脚本
python -c "
from app.core.database import engine, Base
from app.models import *
Base.metadata.create_all(bind=engine)
print('✅ 数据库表创建完成')
"

# 4. 验证
psql -U ai_bookkeeping -d ai_bookkeeping -c "\dt"
```

---

## 🔑 关键字段说明

### BookInvitation（账本邀请）✅ 已修复

```python
class BookInvitation(Base):
    code: str              # 邀请码（20位字母数字）
    voice_code: str        # 语音码（6位数字，可选）✅ 新增
    status: int            # 状态：0=active, 1=expired, 2=revoked, 3=accepted ✅ 修复
    role: int              # 角色：0=viewer, 1=member, 2=admin, 3=owner
    max_uses: int          # 最大使用次数（NULL=无限制）✅ 修复
    expires_at: datetime   # 过期时间（必填）✅ 修复
```

**关键修复**：
- ✅ 字段名统一：`invite_code` → `code`
- ✅ 新增语音邀请功能：`voice_code` 字段
- ✅ 状态管理改进：`is_active` (Boolean) → `status` (Integer)

### FamilyBudget（家庭预算）✅ 已修复

```python
class FamilyBudget(Base):
    period: str            # 预算周期："YYYY-MM" 格式 ✅ 修复长度
    strategy: int          # 策略：0=unified, 1=per_member, 2=per_category, 3=hybrid
    total_budget: Decimal  # 总预算金额
```

**关键修复**：
- ✅ 字段长度修正：`String(20)` → `String(7)`
- ✅ 格式统一：使用 "YYYY-MM" 格式（如 "2026-01"）

### Transaction（交易记录）

```python
class Transaction(Base):
    # 基础字段
    amount: Decimal               # 金额（必填，> 0）
    transaction_type: int         # 类型：1=支出, 2=收入, 3=转账
    transaction_date: date        # 日期（必填）

    # 位置智能
    location_latitude: Decimal    # 纬度
    location_longitude: Decimal   # 经度
    location_place_name: str      # 地点名称
    geofence_region: str          # 围栏区域

    # 钱龄追踪
    money_age: int                # 资金年龄（天数）
    money_age_level: str          # 健康等级：health/warning/danger
    resource_pool_id: UUID        # 关联资金池
```

---

## ✅ 数据完整性保证

### 1. 字段约束

```python
# 所有模型都使用 Mapped 类型提示，确保类型安全
amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)

# CHECK 约束
sa.CheckConstraint('amount > 0', name='ck_transactions_amount_positive')
sa.CheckConstraint('transaction_type IN (1, 2, 3)', name='ck_transactions_type')
```

### 2. 外键关系

```python
# CASCADE DELETE：删除用户时自动删除其所有账本
book_id: Mapped[UUID] = mapped_column(ForeignKey("books.id", ondelete="CASCADE"))

# RESTRICT：防止删除正在使用的分类
category_id: Mapped[UUID] = mapped_column(ForeignKey("categories.id", ondelete="RESTRICT"))

# SET NULL：账户删除时保留交易记录
target_account_id: Mapped[Optional[UUID]] = mapped_column(ForeignKey("accounts.id", ondelete="SET NULL"))
```

### 3. 唯一约束

```python
# 用户手机号唯一
phone: Mapped[str] = mapped_column(String(20), unique=True)

# 邀请码唯一
code: Mapped[str] = mapped_column(String(20), unique=True)
```

### 4. 默认值

```python
# 服务器端默认值
created_at: Mapped[datetime] = mapped_column(DateTime, default=beijing_now_naive)

# 数据库端默认值
is_active: Mapped[bool] = mapped_column(Boolean, server_default='true')
```

---

## 🛡️ 防止兼容性问题的最佳实践

### ✅ DO（推荐做法）

1. **修改模型后立即测试**
   ```bash
   # 重建数据库测试
   python scripts/init_database.py

   # 运行测试
   pytest tests/
   ```

2. **使用类型提示**
   ```python
   # ✅ 好的做法
   name: Mapped[str] = mapped_column(String(100), nullable=False)

   # ❌ 避免
   name = Column(String(100))
   ```

3. **明确指定约束**
   ```python
   # ✅ 好的做法
   amount: Mapped[Decimal] = mapped_column(
       Numeric(15, 2),
       nullable=False,
       server_default='0'
   )
   ```

4. **字段添加时提供默认值**
   ```python
   # ✅ 好的做法 - 新字段可空或有默认值
   voice_code: Mapped[Optional[str]] = mapped_column(String(6), nullable=True)
   is_active: Mapped[bool] = mapped_column(Boolean, default=True)
   ```

### ❌ DON'T（避免做法）

1. **不要直接修改数据库**
   ```sql
   -- ❌ 避免直接在数据库执行
   ALTER TABLE users ADD COLUMN new_field VARCHAR(50);
   ```

2. **不要省略 nullable 声明**
   ```python
   # ❌ 避免 - 不清楚是否可空
   name = mapped_column(String(100))

   # ✅ 明确声明
   name: Mapped[str] = mapped_column(String(100), nullable=False)
   ```

3. **不要使用硬编码的魔法数字**
   ```python
   # ❌ 避免
   if transaction.type == 1:  # 什么类型？

   # ✅ 使用枚举或常量
   class TransactionType:
       EXPENSE = 1
       INCOME = 2
       TRANSFER = 3

   if transaction.type == TransactionType.EXPENSE:
   ```

---

## 🔧 常见问题处理

### Q1: 添加新字段后应用启动失败

**原因**: 数据库表中没有新字段

**解决**:
```bash
# 开发环境：重建数据库
python scripts/init_database.py

# 生产环境：使用 ALTER TABLE（需要手动操作）
psql -U ai_bookkeeping -d ai_bookkeeping
ALTER TABLE table_name ADD COLUMN new_field VARCHAR(100);
```

### Q2: 字段类型不匹配

**原因**: 模型定义与数据库实际类型不同

**解决**:
```bash
# 检查数据库表结构
psql -U ai_bookkeeping -d ai_bookkeeping
\d table_name

# 删除并重建表（⚠️ 会丢失数据）
python scripts/init_database.py
```

### Q3: 外键约束错误

**原因**: 试图删除被引用的记录

**解决**:
```python
# 检查外键关系
from sqlalchemy import inspect
inspector = inspect(engine)
fk_info = inspector.get_foreign_keys('table_name')

# 修改 ondelete 行为
# CASCADE：级联删除
# RESTRICT：禁止删除
# SET NULL：设置为 NULL
```

---

## 📊 表结构验证清单

部署前检查：

- [ ] 所有模型文件已导入到 `app/models/__init__.py`
- [ ] 所有字段都有明确的类型提示 `Mapped[Type]`
- [ ] 所有字段都明确声明了 `nullable=True/False`
- [ ] 外键关系的 `ondelete` 行为正确设置
- [ ] 运行 `python scripts/init_database.py` 成功
- [ ] 所有 33 个表都创建成功
- [ ] 关键字段验证通过（users, books, transactions, book_invitations, family_budgets）
- [ ] 应用启动成功，无模型相关错误

---

## 🚦 部署流程

### 开发环境

```bash
# 1. 配置数据库连接
cp server/.env.example server/.env
vi server/.env  # 修改 DATABASE_URL

# 2. 初始化数据库
cd server
python scripts/init_database.py

# 3. 启动应用
uvicorn app.main:app --reload
```

### 生产环境

```bash
# 1. 数据库准备
sudo -u postgres createdb -O ai_bookkeeping ai_bookkeeping

# 2. 初始化表结构
cd /home/ai-bookkeeping/app/server
source /home/ai-bookkeeping/venv/bin/activate
python -c "from app.core.database import engine, Base; from app.models import *; Base.metadata.create_all(bind=engine)"

# 3. 验证
psql -U ai_bookkeeping -d ai_bookkeeping -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';"

# 4. 启动服务
systemctl start ai-bookkeeping-api@8000
```

---

## 📝 更新日志

### 2026-01-12
- 🔴 **重大变更**: 移除所有 Alembic 迁移脚本
- ✅ 修复 BookInvitation 字段不匹配问题（code, voice_code, status）
- ✅ 修复 FamilyBudget.period 长度和格式问题
- ✅ 修复 Budget.name 约束问题
- ✅ 创建数据库初始化脚本 `scripts/init_database.py`
- ✅ 简化部署流程，直接从模型创建表

---

**维护者**: 开发团队
**最后更新**: 2026-01-12
