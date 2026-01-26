# 预算系统架构重构提案

## 提案信息

- **提案编号**: refactor-budget-architecture
- **提案标题**: 统一预算系统架构，整合传统预算与零基预算
- **提案人**: Claude Code
- **创建日期**: 2026-01-25
- **状态**: 待审核

## 问题描述

### 当前问题

根据数据验证报告（DATA_VERIFICATION_REPORT.md）和代码分析，当前系统存在以下问题：

1. **双重预算系统并存**
   - `Budget` 模型：传统预算系统，支持按分类设置预算上限
   - `BudgetVault` 模型：零基预算系统（YNAB式），支持收入分配和小金库管理
   - 两个系统功能重叠但独立运行，造成用户困惑和维护困难

2. **数据库设计冗余**
   - `budgets` 表：存储传统预算
   - `budget_vaults` 表：存储小金库
   - 两个表都有 `targetAmount`、`ledgerId`、`categoryId` 等相似字段
   - 用户数据显示：0个活跃预算，0个活跃小金库（用户未使用任何预算功能）

3. **用户体验混乱**
   - 用户需要在"预算管理"和"小金库"两个入口之间切换
   - 不清楚应该使用哪种预算方式
   - 两种预算方式的数据无法互通

4. **代码维护成本高**
   - 两套独立的 Provider：`budgetProvider` 和 `budgetVaultProvider`
   - 两套独立的 Service：`smart_budget_service.dart` 和 `vault_repository.dart`
   - 大量重复的业务逻辑代码

### 影响范围

- **用户影响**: 预算功能使用率低，用户体验差
- **开发影响**: 维护成本高，新功能开发困难
- **数据影响**: 数据结构冗余，查询效率低

## 解决方案

### 设计目标

1. **统一预算模型**: 将 Budget 和 BudgetVault 合并为统一的预算系统
2. **保留两种模式**: 支持传统预算和零基预算两种模式，用户可自由切换
3. **简化用户体验**: 统一入口，清晰的模式切换
4. **向后兼容**: 保证现有数据不丢失（虽然当前用户数据为空）

### 核心设计

#### 1. 统一预算模型

```dart
/// 统一的预算模型
class UnifiedBudget {
  final String id;
  final String name;
  final String? description;
  final IconData icon;
  final Color color;

  // 基础属性
  final String ledgerId;
  final BudgetMode mode;              // 预算模式：traditional 或 zeroBased
  final BudgetPeriod period;          // 周期：daily, weekly, monthly, yearly
  final bool isEnabled;

  // 分类关联
  final String? categoryId;           // 单个分类（传统预算）
  final List<String>? categoryIds;    // 多个分类（零基预算）

  // 金额相关
  final double targetAmount;          // 目标金额/预算上限
  final double allocatedAmount;       // 已分配金额（零基预算）
  final double spentAmount;           // 已花费金额

  // 零基预算特有
  final VaultType? vaultType;         // 小金库类型：fixed, flexible, savings, debt
  final AllocationType? allocationType; // 分配类型：fixed, percentage, remainder, topUp
  final double? targetAllocation;     // 固定分配金额
  final double? targetPercentage;     // 分配百分比

  // 周期性
  final bool isRecurring;
  final RecurrenceRule? recurrence;
  final DateTime? dueDate;

  // 结转设置（传统预算）
  final bool enableCarryover;
  final bool carryoverSurplusOnly;

  // 元数据
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

#### 2. 预算模式枚举

```dart
/// 预算模式
enum BudgetMode {
  traditional,  // 传统预算：设置分类预算上限，监控支出
  zeroBased,    // 零基预算：收入分配到小金库，支出从小金库扣减
}
```

#### 3. 数据库迁移策略

**方案A：合并表（推荐）**
- 创建新表 `unified_budgets`
- 迁移 `budgets` 和 `budget_vaults` 数据到新表
- 保留旧表一段时间作为备份
- 优点：数据结构清晰，查询效率高
- 缺点：需要数据迁移

**方案B：保留双表**
- 保留 `budgets` 和 `budget_vaults` 表
- 在应用层统一处理
- 优点：无需数据迁移
- 缺点：维护成本高，查询复杂

**推荐方案A**，因为：
1. 当前用户数据为空（0个预算，0个小金库）
2. 无需担心数据迁移风险
3. 长期维护成本更低

#### 4. 统一的 Provider 架构

```dart
/// 统一预算 Provider
class UnifiedBudgetProvider extends StateNotifier<List<UnifiedBudget>> {
  final UnifiedBudgetRepository _repository;

  // 获取所有预算
  List<UnifiedBudget> get all => state;

  // 按模式过滤
  List<UnifiedBudget> get traditionalBudgets =>
    state.where((b) => b.mode == BudgetMode.traditional).toList();

  List<UnifiedBudget> get zeroBasedBudgets =>
    state.where((b) => b.mode == BudgetMode.zeroBased).toList();

  // 按类型过滤（零基预算）
  List<UnifiedBudget> getByVaultType(VaultType type) =>
    zeroBasedBudgets.where((b) => b.vaultType == type).toList();

  // 统一的CRUD操作
  Future<void> create(UnifiedBudget budget);
  Future<void> update(UnifiedBudget budget);
  Future<void> delete(String id);

  // 零基预算特有操作
  Future<void> allocate(String budgetId, double amount);
  Future<void> transfer(String fromId, String toId, double amount);
}
```

#### 5. 用户界面设计

**统一入口**
- 首页：显示当前预算模式的摘要
- 预算中心：统一的预算管理入口

**模式切换**
- 在预算中心顶部提供模式切换开关
- 传统模式：显示分类预算列表
- 零基模式：显示小金库列表（按类型分组）

**向导引导**
- 首次使用时，引导用户选择预算模式
- 提供两种模式的对比说明
- 支持后续切换（需要数据迁移提示）

### 实施计划

#### 阶段1：数据层重构（1-2天）

1. **创建统一模型**
   - [ ] 定义 `UnifiedBudget` 模型
   - [ ] 定义 `BudgetMode` 枚举
   - [ ] 实现 `toMap()` 和 `fromMap()` 方法

2. **数据库迁移**
   - [ ] 创建 `unified_budgets` 表
   - [ ] 编写迁移脚本（从 budgets 和 budget_vaults）
   - [ ] 创建索引（ledgerId, mode, categoryId）
   - [ ] 测试迁移脚本

3. **Repository 层**
   - [ ] 实现 `UnifiedBudgetRepository`
   - [ ] 实现 CRUD 操作
   - [ ] 实现零基预算特有操作（allocate, transfer）
   - [ ] 编写单元测试

#### 阶段2：业务层重构（2-3天）

1. **Provider 重构**
   - [ ] 实现 `UnifiedBudgetProvider`
   - [ ] 迁移 `budgetProvider` 逻辑
   - [ ] 迁移 `budgetVaultProvider` 逻辑
   - [ ] 编写单元测试

2. **Service 整合**
   - [ ] 整合 `smart_budget_service.dart`
   - [ ] 整合 `vault_repository.dart`
   - [ ] 整合 `adaptive_budget_service.dart`
   - [ ] 删除重复代码

3. **业务逻辑迁移**
   - [ ] 预算计算逻辑
   - [ ] 预算提醒逻辑
   - [ ] 预算结转逻辑
   - [ ] 零基预算分配逻辑

#### 阶段3：UI层重构（2-3天）

1. **预算中心页面**
   - [ ] 设计统一的预算中心界面
   - [ ] 实现模式切换功能
   - [ ] 实现传统预算视图
   - [ ] 实现零基预算视图

2. **预算详情页面**
   - [ ] 统一预算详情页面
   - [ ] 根据模式显示不同内容
   - [ ] 实现编辑功能

3. **首页集成**
   - [ ] 更新首页预算摘要
   - [ ] 根据模式显示不同指标
   - [ ] 更新预算状态栏

4. **引导流程**
   - [ ] 设计预算模式选择向导
   - [ ] 实现首次使用引导
   - [ ] 实现模式切换确认

#### 阶段4：测试与优化（1-2天）

1. **功能测试**
   - [ ] 传统预算功能测试
   - [ ] 零基预算功能测试
   - [ ] 模式切换测试
   - [ ] 数据迁移测试

2. **性能优化**
   - [ ] 查询性能优化
   - [ ] 缓存策略优化
   - [ ] 内存使用优化

3. **用户体验优化**
   - [ ] 交互流程优化
   - [ ] 错误提示优化
   - [ ] 加载状态优化

#### 阶段5：文档与发布（1天）

1. **文档更新**
   - [ ] 更新 API 文档
   - [ ] 更新用户指南
   - [ ] 编写迁移指南

2. **发布准备**
   - [ ] 编写 Release Notes
   - [ ] 准备回滚方案
   - [ ] 准备用户通知

### 风险评估

#### 高风险

1. **数据迁移风险**
   - **风险**: 数据迁移失败导致数据丢失
   - **缓解**: 当前用户数据为空，风险极低
   - **应对**: 完整的备份和回滚方案

2. **用户体验变化**
   - **风险**: 用户不适应新界面
   - **缓解**: 提供详细的引导和帮助
   - **应对**: 收集用户反馈，快速迭代

#### 中风险

1. **代码兼容性**
   - **风险**: 现有代码依赖旧模型
   - **缓解**: 分阶段迁移，保留适配层
   - **应对**: 充分的单元测试和集成测试

2. **性能影响**
   - **风险**: 统一模型导致查询变慢
   - **缓解**: 合理的索引设计
   - **应对**: 性能监控和优化

#### 低风险

1. **功能缺失**
   - **风险**: 迁移过程中遗漏功能
   - **缓解**: 详细的功能清单和测试用例
   - **应对**: 快速修复和补充

### 成功指标

1. **技术指标**
   - 代码行数减少 30%
   - 查询性能提升 20%
   - 单元测试覆盖率 > 80%

2. **用户指标**
   - 预算功能使用率提升 50%
   - 用户满意度 > 4.0/5.0
   - 预算相关问题反馈减少 40%

3. **维护指标**
   - 预算相关 Bug 减少 50%
   - 新功能开发时间减少 30%
   - 代码维护成本降低 40%

## 替代方案

### 方案1：保持现状

**优点**:
- 无需开发工作
- 无风险

**缺点**:
- 用户体验差
- 维护成本高
- 功能使用率低

**结论**: 不推荐

### 方案2：仅优化UI

**优点**:
- 开发工作量小
- 风险低

**缺点**:
- 无法解决根本问题
- 代码维护成本依然高

**结论**: 不推荐

### 方案3：完全移除一种预算方式

**优点**:
- 简化系统
- 开发工作量中等

**缺点**:
- 失去灵活性
- 无法满足不同用户需求

**结论**: 不推荐

## 依赖关系

### 前置依赖

- 无（当前用户数据为空，可以直接开始）

### 后续依赖

- 语音助手预算功能需要适配新模型
- 家庭账本预算功能需要适配新模型
- 报表系统需要适配新模型

## 参考资料

1. **YNAB (You Need A Budget)**: 零基预算的最佳实践
2. **Mint**: 传统预算的参考实现
3. **数据验证报告**: DATA_VERIFICATION_REPORT.md
4. **当前代码**:
   - `app/lib/models/budget.dart`
   - `app/lib/models/budget_vault.dart`
   - `app/lib/providers/budget_provider.dart`
   - `app/lib/providers/budget_vault_provider.dart`

## 审批流程

1. **技术审查**: 架构师审查设计方案
2. **产品审查**: 产品经理审查用户体验
3. **开发评估**: 开发团队评估工作量
4. **最终批准**: 项目负责人批准实施

## 附录

### A. 数据库表结构对比

#### 当前 budgets 表
```sql
CREATE TABLE budgets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  period INTEGER NOT NULL,
  categoryId TEXT,
  ledgerId TEXT NOT NULL,
  icon INTEGER NOT NULL,
  color INTEGER NOT NULL,
  isEnabled INTEGER NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt INTEGER,
  budgetType INTEGER,
  enableCarryover INTEGER,
  carryoverSurplusOnly INTEGER
);
```

#### 当前 budget_vaults 表
```sql
CREATE TABLE budget_vaults (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  iconCode INTEGER NOT NULL,
  colorValue INTEGER NOT NULL,
  type TEXT NOT NULL,
  targetAmount REAL NOT NULL,
  allocatedAmount REAL,
  spentAmount REAL,
  dueDate TEXT,
  isRecurring INTEGER,
  recurrenceJson TEXT,
  linkedCategoryId TEXT,
  linkedCategoryIds TEXT,
  ledgerId TEXT NOT NULL,
  isEnabled INTEGER,
  sortOrder INTEGER,
  createdAt TEXT NOT NULL,
  updatedAt TEXT,
  allocationType TEXT,
  targetAllocation REAL,
  targetPercentage REAL
);
```

#### 新 unified_budgets 表
```sql
CREATE TABLE unified_budgets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon INTEGER NOT NULL,
  color INTEGER NOT NULL,

  -- 基础属性
  ledgerId TEXT NOT NULL,
  mode TEXT NOT NULL,              -- 'traditional' or 'zeroBased'
  period INTEGER NOT NULL,
  isEnabled INTEGER NOT NULL DEFAULT 1,

  -- 分类关联
  categoryId TEXT,                 -- 单个分类
  categoryIds TEXT,                -- 多个分类（逗号分隔）

  -- 金额相关
  targetAmount REAL NOT NULL,
  allocatedAmount REAL DEFAULT 0,
  spentAmount REAL DEFAULT 0,

  -- 零基预算特有
  vaultType TEXT,                  -- 'fixed', 'flexible', 'savings', 'debt'
  allocationType TEXT,             -- 'fixed', 'percentage', 'remainder', 'topUp'
  targetAllocation REAL,
  targetPercentage REAL,

  -- 周期性
  isRecurring INTEGER DEFAULT 0,
  recurrenceJson TEXT,
  dueDate TEXT,

  -- 结转设置
  enableCarryover INTEGER DEFAULT 0,
  carryoverSurplusOnly INTEGER DEFAULT 1,

  -- 元数据
  sortOrder INTEGER DEFAULT 0,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,

  FOREIGN KEY (ledgerId) REFERENCES ledgers(id),
  FOREIGN KEY (categoryId) REFERENCES categories(id)
);

-- 索引
CREATE INDEX idx_unified_budgets_ledger ON unified_budgets(ledgerId);
CREATE INDEX idx_unified_budgets_mode ON unified_budgets(mode);
CREATE INDEX idx_unified_budgets_category ON unified_budgets(categoryId);
CREATE INDEX idx_unified_budgets_enabled ON unified_budgets(isEnabled);
```

### B. 迁移脚本示例

```dart
Future<void> migrateBudgetData() async {
  final db = await database;

  await db.transaction((txn) async {
    // 1. 创建新表
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS unified_budgets (
        -- 表结构见上
      )
    ''');

    // 2. 迁移传统预算
    await txn.execute('''
      INSERT INTO unified_budgets (
        id, name, description, icon, color,
        ledgerId, mode, period, isEnabled,
        categoryId, targetAmount, spentAmount,
        enableCarryover, carryoverSurplusOnly,
        sortOrder, createdAt, updatedAt
      )
      SELECT
        id, name, NULL, icon, color,
        ledgerId, 'traditional', period, isEnabled,
        categoryId, amount, 0,
        enableCarryover, carryoverSurplusOnly,
        0, createdAt, updatedAt
      FROM budgets
      WHERE isDeleted = 0
    ''');

    // 3. 迁移零基预算
    await txn.execute('''
      INSERT INTO unified_budgets (
        id, name, description, icon, color,
        ledgerId, mode, period, isEnabled,
        categoryId, categoryIds, targetAmount, allocatedAmount, spentAmount,
        vaultType, allocationType, targetAllocation, targetPercentage,
        isRecurring, recurrenceJson, dueDate,
        sortOrder, createdAt, updatedAt
      )
      SELECT
        id, name, description, iconCode, colorValue,
        ledgerId, 'zeroBased', 2, isEnabled,  -- period=2 表示 monthly
        linkedCategoryId, linkedCategoryIds, targetAmount, allocatedAmount, spentAmount,
        type, allocationType, targetAllocation, targetPercentage,
        isRecurring, recurrenceJson, dueDate,
        sortOrder, createdAt, updatedAt
      FROM budget_vaults
    ''');

    // 4. 重命名旧表（保留备份）
    await txn.execute('ALTER TABLE budgets RENAME TO budgets_backup');
    await txn.execute('ALTER TABLE budget_vaults RENAME TO budget_vaults_backup');
  });
}
```

---

**提案状态**: 待审核
**下一步**: 等待技术审查和产品审查
