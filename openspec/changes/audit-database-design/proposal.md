# 变更：数据库设计审计与改进

## 为什么

当前数据库包含30+表，经过多次迭代升级（版本1→15），存在设计一致性问题。需要系统性审计以确保核心业务数据的稳定性、可扩展性和数据完整性。

## 审计发现摘要

### 1. 外键约束不一致

**有外键约束的表（7个）：**
- transaction_splits → transactions
- budget_carryovers → budgets
- zero_based_allocations → budgets
- savings_deposits → savings_goals
- debt_payments → debts
- resource_pools → transactions
- resource_consumptions → resource_pools, transactions
- vault_allocations → budget_vaults
- vault_transfers → budget_vaults

**缺少外键约束的引用关系（15+）：**
- transactions.accountId → accounts.id ❌
- transactions.ledgerId → ledgers.id ❌
- transactions.vaultId → budget_vaults.id ❌
- transactions.resourcePoolId → resource_pools.id ❌
- budgets.ledgerId → ledgers.id ❌
- budgets.categoryId → categories.id ❌
- categories.parentId → categories.id ❌
- savings_goals.linkedAccountId → accounts.id ❌
- debts.linkedAccountId → accounts.id ❌
- bill_reminders.linkedAccountId → accounts.id ❌
- ledger_members.ledgerId → ledgers.id ❌
- member_budgets.ledgerId → ledgers.id ❌
- expense_approvals.ledgerId → ledgers.id ❌
- expense_approvals.transactionId → transactions.id ❌
- budget_vaults.ledgerId → ledgers.id ❌

### 2. 数据冗余与反范式问题

**表中存储冗余的名称字段：**
- ledger_members: userName, userEmail, userAvatar（应关联用户表）
- member_invites: ledgerName, inviterName
- member_budgets: memberName
- expense_approvals: requesterName, approverName

**风险**：当源数据更新时，冗余字段可能导致数据不一致。

### 3. 索引缺失

**高频查询字段缺少索引：**
- transactions.date（按日期筛选是最常见操作）
- transactions.ledgerId（多账本查询）
- transactions.accountId（按账户筛选）
- transactions.category（分类统计）
- budgets.ledgerId
- categories.parentId

### 4. 核心表字段膨胀

transactions 表已有 30+ 字段，通过多次 ALTER TABLE 添加：
- 基础字段：id, type, amount, category, note, date, accountId, toAccountId, ledgerId
- 拆分字段：isSplit
- 报销字段：isReimbursable, isReimbursed, tags
- AI识别字段：source, aiConfidence, sourceFile*, recognitionRawData
- 导入字段：externalId, externalSource, importBatchId, rawMerchant
- 2.0新增：vaultId, moneyAge, moneyAgeLevel, resourcePoolId, visibility, locationJson

**建议**：考虑将非核心字段拆分到扩展表。

### 5. 字段存储模式不一致

**使用JSON字符串存储的字段：**
- transactions.tags（TEXT）
- transactions.locationJson（TEXT）
- budget_vaults.recurrenceJson（TEXT）
- budget_vaults.linkedCategoryIds（TEXT）

**使用独立表的类似数据：**
- transaction_splits（独立表）
- vault_allocations（独立表）

### 6. 软删除支持缺失

仅 sync_metadata 表有 isDeleted 字段，其他表缺少软删除支持，导致：
- 无法追踪删除历史
- 难以实现数据恢复
- 同步时无法区分"删除"和"从未存在"

### 7. 时间戳字段不完整

**缺少 updatedAt 的表：**
- accounts
- categories
- ledgers
- templates
- recurring_transactions
- credit_cards
- bill_reminders
- ledger_members（仅有 joinedAt）
- member_invites
- budgets

## 变更内容

### Phase 1：低风险修复（不影响现有数据）
- 添加缺失的索引
- 添加缺失的 updatedAt 字段

### Phase 2：中风险改进（需要数据迁移）
- 为关键引用添加外键约束（需启用 FOREIGN KEY 并处理孤儿数据）
- 添加软删除支持（isDeleted + deletedAt）

### Phase 3：高风险重构（可选，2.0后考虑）
- 拆分 transactions 扩展字段到独立表
- 规范化冗余名称字段
- 统一 JSON vs 关联表的存储模式

## 影响

- 受影响规范：database, transactions, sync
- 受影响代码：
  - app/lib/services/database_service.dart
  - app/lib/services/database_migration_service.dart
  - app/lib/models/*.dart
  - 所有使用 DatabaseService 的服务层代码
