# 数据库设计审计技术分析

## 上下文

### 当前数据库概况
- **数据库引擎**：SQLite (via sqflite)
- **当前版本**：15
- **表数量**：30+
- **核心表**：transactions, accounts, categories, ledgers, budgets

### 版本演进历史
| 版本 | 变更内容 |
|------|---------|
| 1 | 基础表结构 |
| 2 | 添加交易拆分功能 |
| 3 | 添加信用卡管理 |
| 4 | 添加储蓄目标 |
| 5 | 添加账单提醒 |
| 6 | 添加投资账户 |
| 7 | 添加债务管理 |
| 9 | 储蓄目标增强 |
| 10 | 报销和标签功能 |
| 11 | 多成员协作 |
| 12 | 同步元数据 |
| 13 | AI识别源追踪 |
| 14 | 批量导入 |
| 15 | 钱龄系统+小金库 |

## 目标 / 非目标

### 目标
- 确保核心业务表（transactions, accounts, categories）长期稳定
- 提高数据完整性和一致性
- 优化查询性能
- 为未来扩展预留空间
- 保持向后兼容

### 非目标
- 完全重构数据库架构（风险太高）
- 更换数据库引擎
- 修改业务逻辑

## 详细问题分析

### 问题1：外键约束不一致

#### 现状分析
```
有外键的表                     无外键的引用
─────────────────────────     ─────────────────────────
transaction_splits             transactions.accountId
budget_carryovers              transactions.ledgerId
zero_based_allocations         transactions.vaultId
savings_deposits               budgets.ledgerId
debt_payments                  budgets.categoryId
resource_pools                 categories.parentId
resource_consumptions          savings_goals.linkedAccountId
vault_allocations              debts.linkedAccountId
vault_transfers                bill_reminders.linkedAccountId
                               ledger_members.ledgerId
                               member_budgets.ledgerId
                               expense_approvals.ledgerId
                               budget_vaults.ledgerId
```

#### SQLite外键限制
```dart
// SQLite默认不强制外键约束，需要显式启用
await db.execute('PRAGMA foreign_keys = ON');
```

#### 风险评估
- **孤儿记录**：删除 account 后，transactions 中的 accountId 指向不存在的记录
- **数据不一致**：无法保证引用完整性
- **级联删除失效**：只有显式声明的外键才能级联

### 问题2：冗余字段数据一致性

#### 受影响表分析
```sql
-- ledger_members 存储冗余用户信息
CREATE TABLE ledger_members (
  userId TEXT NOT NULL,      -- 用户ID（正确）
  userName TEXT NOT NULL,    -- 冗余：用户名可能变化
  userEmail TEXT,            -- 冗余：邮箱可能变化
  userAvatar TEXT,           -- 冗余：头像可能变化
  ...
);

-- member_invites 存储冗余邀请信息
CREATE TABLE member_invites (
  ledgerId TEXT NOT NULL,    -- 账本ID（正确）
  ledgerName TEXT NOT NULL,  -- 冗余：账本名可能改变
  inviterId TEXT NOT NULL,   -- 邀请者ID（正确）
  inviterName TEXT NOT NULL, -- 冗余：邀请者名可能变化
  ...
);
```

#### 设计考量
冗余存储的历史原因：
1. **性能考虑**：避免JOIN操作
2. **离线场景**：本地无法查询服务器用户数据
3. **历史快照**：保留创建时的状态

#### 建议方案
保留冗余但添加更新触发机制：
```dart
// 当用户信息更新时，同步更新相关表
Future<void> updateUserInfo(String userId, String newName) async {
  await db.transaction((txn) async {
    await txn.update('ledger_members',
      {'userName': newName},
      where: 'userId = ?', whereArgs: [userId]);
    // 其他表类似处理
  });
}
```

### 问题3：索引策略

#### 当前索引分析
```sql
-- 已有索引（良好）
CREATE INDEX idx_transactions_external ON transactions(externalId, externalSource);
CREATE INDEX idx_transactions_import_batch ON transactions(importBatchId);
CREATE INDEX idx_transactions_dedup ON transactions(date, amount, type, category);
CREATE INDEX idx_sync_metadata_entity ON sync_metadata(entityType, localId);
CREATE INDEX idx_resource_pools_remaining ON resource_pools(remainingAmount);
CREATE INDEX idx_budget_vaults_ledger ON budget_vaults(ledgerId);

-- 缺失索引（需添加）
CREATE INDEX idx_transactions_date ON transactions(date);
CREATE INDEX idx_transactions_ledger ON transactions(ledgerId);
CREATE INDEX idx_transactions_account ON transactions(accountId);
CREATE INDEX idx_transactions_category ON transactions(category);
CREATE INDEX idx_budgets_ledger ON budgets(ledgerId);
CREATE INDEX idx_categories_parent ON categories(parentId);
CREATE INDEX idx_accounts_default ON accounts(isDefault);
```

#### 索引添加策略
```dart
if (oldVersion < 16) {
  // 批量创建索引，使用 IF NOT EXISTS 确保幂等
  await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_ledger ON transactions(ledgerId)');
  // ...
}
```

### 问题4：transactions 表膨胀

#### 字段分类
```
核心字段（必须保留）          扩展字段（可拆分）
────────────────────────    ────────────────────────
id                          sourceFileLocalPath
type                        sourceFileServerUrl
amount                      sourceFileType
category                    sourceFileSize
note                        recognitionRawData
date                        sourceFileExpiresAt
accountId                   externalId
toAccountId                 externalSource
ledgerId                    importBatchId
createdAt                   rawMerchant
                            locationJson
```

#### 拆分方案（2.0后考虑）
```sql
-- 核心交易表（精简）
CREATE TABLE transactions (
  id, type, amount, category, subcategory, note, date,
  accountId, toAccountId, ledgerId, isSplit,
  isReimbursable, isReimbursed, tags,
  createdAt, updatedAt
);

-- AI识别扩展表
CREATE TABLE transaction_ai_info (
  transactionId TEXT PRIMARY KEY,
  source INTEGER,
  aiConfidence REAL,
  sourceFileLocalPath TEXT,
  sourceFileServerUrl TEXT,
  sourceFileType TEXT,
  sourceFileSize INTEGER,
  recognitionRawData TEXT,
  sourceFileExpiresAt INTEGER,
  FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE
);

-- 导入信息扩展表
CREATE TABLE transaction_import_info (
  transactionId TEXT PRIMARY KEY,
  externalId TEXT,
  externalSource INTEGER,
  importBatchId TEXT,
  rawMerchant TEXT,
  FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE
);

-- 位置信息扩展表
CREATE TABLE transaction_location (
  transactionId TEXT PRIMARY KEY,
  latitude REAL,
  longitude REAL,
  address TEXT,
  placeName TEXT,
  FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE
);
```

### 问题5：软删除支持

#### 推荐模式
```sql
-- 添加软删除字段
ALTER TABLE transactions ADD COLUMN isDeleted INTEGER NOT NULL DEFAULT 0;
ALTER TABLE transactions ADD COLUMN deletedAt INTEGER;

-- 查询时默认过滤
SELECT * FROM transactions WHERE isDeleted = 0;

-- 真正删除（清理）
DELETE FROM transactions WHERE isDeleted = 1 AND deletedAt < ?;
```

#### 受影响的查询
需要更新所有 SELECT 查询添加 `WHERE isDeleted = 0` 条件，或创建视图：
```sql
CREATE VIEW active_transactions AS
SELECT * FROM transactions WHERE isDeleted = 0;
```

### 问题6：updatedAt 字段缺失

#### 受影响表
- accounts
- categories
- ledgers
- templates
- recurring_transactions
- credit_cards
- bill_reminders
- budgets

#### 实现建议
```dart
// 添加字段
await db.execute('ALTER TABLE accounts ADD COLUMN updatedAt INTEGER');
// 初始化为 createdAt
await db.execute('UPDATE accounts SET updatedAt = createdAt WHERE updatedAt IS NULL');

// 在 Model 的 toMap 中设置
Map<String, dynamic> toMap() {
  return {
    // ...
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  };
}
```

## 决策

### 采用的方案
1. **索引添加**：立即实施，低风险高收益
2. **updatedAt字段**：立即实施，向后兼容
3. **外键约束**：分阶段实施，需先处理孤儿数据
4. **软删除**：下一版本实施
5. **表拆分**：2.0后评估，风险较高

### 考虑的替代方案
| 方案 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| 完全重构 | 设计干净 | 风险极高 | 否决 |
| 保持现状 | 无风险 | 问题累积 | 否决 |
| 渐进改进 | 风险可控 | 时间较长 | **采用** |
| 迁移新库 | 彻底解决 | 数据迁移复杂 | 否决 |

## 风险 / 权衡

### 风险1：外键约束导致写入失败
- **场景**：存在孤儿记录时，启用外键约束会导致写入失败
- **缓解**：迁移前清理孤儿数据，添加约束前验证数据完整性

### 风险2：索引影响写入性能
- **场景**：大量索引会减慢INSERT/UPDATE操作
- **缓解**：仅添加必要索引，监控写入性能

### 风险3：软删除增加查询复杂度
- **场景**：所有查询需要添加过滤条件
- **缓解**：使用视图封装，统一查询接口

## 迁移计划

### 版本16迁移脚本
```dart
if (oldVersion < 16) {
  // 1. 添加索引（幂等操作）
  await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_ledger ON transactions(ledgerId)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(accountId)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_ledger ON budgets(ledgerId)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parentId)');

  // 2. 添加 updatedAt 字段
  final tablesNeedingUpdatedAt = ['accounts', 'categories', 'ledgers', 'templates',
    'recurring_transactions', 'credit_cards', 'bill_reminders', 'budgets'];
  for (final table in tablesNeedingUpdatedAt) {
    await db.execute('ALTER TABLE $table ADD COLUMN updatedAt INTEGER');
    await db.execute('UPDATE $table SET updatedAt = createdAt WHERE updatedAt IS NULL');
  }
}
```

### 回滚策略
1. 索引可以安全删除：`DROP INDEX IF EXISTS idx_name`
2. 新字段可以保持为NULL：不影响旧版本读取
3. 数据备份：迁移前自动备份（已有机制）

## 待决问题（已决策）

### 1. 外键约束何时启用？
**已解决**（版本18）：
- 启用 `PRAGMA foreign_keys = ON`
- 现有外键约束（transaction_splits, budget_carryovers等）现在强制执行
- 主表（transactions, budgets等）暂不添加外键约束，因SQLite需要重建表
- 通过孤儿数据检测和清理机制保证数据完整性

### 2. 软删除适用范围？
**已解决**（版本17）：
- 适用于5个核心业务表：transactions, accounts, categories, ledgers, budgets
- 保留期：30天后可清理（通过 `purgeDeletedRecords` 方法）
- 已创建 `active_*` 视图简化查询

### 3. transactions表是否拆分？
**评估结论**：暂不实施，原因如下：
- **查询模式分析**：大部分查询只需核心字段，AI/导入信息访问频率较低
- **收益有限**：SQLite单表性能足够，拆分主要影响是代码复杂度增加
- **代码变更成本高**：需要修改所有Transaction相关的Model和Service代码
- **建议**：保持现状，如果未来性能成为问题再考虑拆分
- 如需实施，应作为独立提案进行

### 4. 冗余字段更新策略？
**评估结论**：保持现状，原因如下：
- **设计意图**：冗余是有意为之，用于离线场景和历史快照
- **更新频率低**：用户名/头像等字段变化不频繁
- **触发器复杂**：SQLite触发器难以维护且有性能影响
- **建议**：在用户信息更新时，由应用层同步更新相关表

### 5. JSON vs 关系存储？
**评估结论**：当前混合方案是合理的：
- `locationJson`：位置信息结构化程度低，JSON适合
- `tags`：标签是简单列表，JSON适合
- `recognitionRawData`：AI原始数据，JSON适合保存完整结构
- 其他字段使用关系存储，适合频繁查询和索引
- **建议**：保持现状，不做改变

## 版本演进历史（更新）

| 版本 | 变更内容 |
|------|---------|
| 1 | 基础表结构 |
| 2 | 添加交易拆分功能 |
| 3 | 添加信用卡管理 |
| 4 | 添加储蓄目标 |
| 5 | 添加账单提醒 |
| 6 | 添加投资账户 |
| 7 | 添加债务管理 |
| 9 | 储蓄目标增强 |
| 10 | 报销和标签功能 |
| 11 | 多成员协作 |
| 12 | 同步元数据 |
| 13 | AI识别源追踪 |
| 14 | 批量导入 |
| 15 | 钱龄系统+小金库 |
| 16 | 索引优化+updatedAt字段 |
| 17 | 软删除支持 |
| 18 | 活动记录视图+外键启用 |
