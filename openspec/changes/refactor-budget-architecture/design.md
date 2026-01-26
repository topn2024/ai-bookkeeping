# 预算系统架构设计文档

## 设计概述

本文档详细说明预算系统架构重构的技术设计方案，包括数据模型、架构模式、接口设计等。

---

## 1. 核心设计原则

### 1.1 统一性原则
- 统一的数据模型：`UnifiedBudget` 替代 `Budget` 和 `BudgetVault`
- 统一的接口：所有预算操作通过统一的 API
- 统一的用户体验：一个入口，清晰的模式切换

### 1.2 灵活性原则
- 支持两种预算模式：传统预算和零基预算
- 用户可自由选择和切换模式
- 保留各模式的特有功能

### 1.3 兼容性原则
- 向后兼容现有数据（虽然当前为空）
- 提供数据迁移方案
- 保留回滚能力

### 1.4 可维护性原则
- 清晰的代码结构
- 减少重复代码
- 完善的测试覆盖

---

## 2. 数据模型设计

### 2.1 统一预算模型

```dart
class UnifiedBudget {
  // 基础标识
  final String id;
  final String name;
  final String? description;
  final IconData icon;
  final Color color;

  // 账本关联
  final String ledgerId;

  // 预算模式（核心区分字段）
  final BudgetMode mode;  // traditional 或 zeroBased

  // 周期设置
  final BudgetPeriod period;  // daily, weekly, monthly, yearly
  final bool isRecurring;
  final RecurrenceRule? recurrence;
  final DateTime? dueDate;

  // 分类关联
  final String? categoryId;        // 单个分类（传统预算）
  final List<String>? categoryIds; // 多个分类（零基预算）

  // 金额字段
  final double targetAmount;      // 目标金额/预算上限
  final double allocatedAmount;   // 已分配金额（零基预算）
  final double spentAmount;       // 已花费金额

  // 零基预算特有字段
  final VaultType? vaultType;           // fixed, flexible, savings, debt
  final AllocationType? allocationType; // fixed, percentage, remainder, topUp
  final double? targetAllocation;       // 固定分配金额
  final double? targetPercentage;       // 分配百分比（0-1）

  // 传统预算特有字段
  final bool enableCarryover;        // 是否启用结转
  final bool carryoverSurplusOnly;   // 仅结转剩余

  // 状态和排序
  final bool isEnabled;
  final int sortOrder;

  // 时间戳
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### 2.2 预算模式枚举

```dart
enum BudgetMode {
  traditional,  // 传统预算：设置分类预算上限，监控支出
  zeroBased,    // 零基预算：收入分配到小金库，支出从小金库扣减
}

extension BudgetModeExtension on BudgetMode {
  String get displayName {
    switch (this) {
      case BudgetMode.traditional:
        return '传统预算';
      case BudgetMode.zeroBased:
        return '零基预算';
    }
  }

  String get description {
    switch (this) {
      case BudgetMode.traditional:
        return '为每个分类设置预算上限，监控支出情况';
      case BudgetMode.zeroBased:
        return '收入分配到小金库，每一分钱都有明确用途';
    }
  }
}
```

### 2.3 字段使用规则

| 字段 | 传统预算 | 零基预算 | 说明 |
|------|---------|---------|------|
| mode | required | required | 区分预算类型 |
| categoryId | optional | null | 传统预算关联单个分类 |
| categoryIds | null | optional | 零基预算可关联多个分类 |
| targetAmount | required | required | 传统：预算上限；零基：目标金额 |
| allocatedAmount | 0 | required | 零基预算的已分配金额 |
| spentAmount | required | required | 两种模式都需要 |
| vaultType | null | required | 零基预算的小金库类型 |
| allocationType | null | optional | 零基预算的分配类型 |
| targetAllocation | null | optional | 零基预算的固定分配金额 |
| targetPercentage | null | optional | 零基预算的分配百分比 |
| enableCarryover | optional | false | 传统预算的结转设置 |
| carryoverSurplusOnly | optional | false | 传统预算的结转模式 |

---

## 3. 数据库设计

### 3.1 表结构

```sql
CREATE TABLE unified_budgets (
  -- 基础字段
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  icon INTEGER NOT NULL,
  color INTEGER NOT NULL,

  -- 账本和模式
  ledgerId TEXT NOT NULL,
  mode TEXT NOT NULL CHECK(mode IN ('traditional', 'zeroBased')),

  -- 周期
  period INTEGER NOT NULL,
  isRecurring INTEGER NOT NULL DEFAULT 0,
  recurrenceJson TEXT,
  dueDate TEXT,

  -- 分类关联
  categoryId TEXT,
  categoryIds TEXT,  -- 逗号分隔的ID列表

  -- 金额
  targetAmount REAL NOT NULL,
  allocatedAmount REAL NOT NULL DEFAULT 0,
  spentAmount REAL NOT NULL DEFAULT 0,

  -- 零基预算字段
  vaultType TEXT CHECK(vaultType IN ('fixed', 'flexible', 'savings', 'debt')),
  allocationType TEXT CHECK(allocationType IN ('fixed', 'percentage', 'remainder', 'topUp')),
  targetAllocation REAL,
  targetPercentage REAL CHECK(targetPercentage >= 0 AND targetPercentage <= 1),

  -- 传统预算字段
  enableCarryover INTEGER NOT NULL DEFAULT 0,
  carryoverSurplusOnly INTEGER NOT NULL DEFAULT 1,

  -- 状态
  isEnabled INTEGER NOT NULL DEFAULT 1,
  sortOrder INTEGER NOT NULL DEFAULT 0,

  -- 时间戳
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,

  -- 外键约束
  FOREIGN KEY (ledgerId) REFERENCES ledgers(id) ON DELETE CASCADE,
  FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
);
```

### 3.2 索引设计

```sql
-- 账本索引（最常用的查询条件）
CREATE INDEX idx_unified_budgets_ledger
ON unified_budgets(ledgerId)
WHERE isEnabled = 1;

-- 模式索引（按模式过滤）
CREATE INDEX idx_unified_budgets_mode
ON unified_budgets(mode, ledgerId);

-- 分类索引（查找分类的预算）
CREATE INDEX idx_unified_budgets_category
ON unified_budgets(categoryId)
WHERE categoryId IS NOT NULL;

-- 小金库类型索引（零基预算查询）
CREATE INDEX idx_unified_budgets_vault_type
ON unified_budgets(vaultType, ledgerId)
WHERE mode = 'zeroBased';

-- 排序索引
CREATE INDEX idx_unified_budgets_sort
ON unified_budgets(ledgerId, sortOrder);
```

### 3.3 数据迁移策略

**迁移步骤**：

1. 创建新表 `unified_budgets`
2. 从 `budgets` 表迁移传统预算数据
3. 从 `budget_vaults` 表迁移零基预算数据
4. 验证数据完整性
5. 重命名旧表为 `_backup` 后缀
6. 更新应用代码使用新表

**迁移脚本**：见 PROPOSAL.md 附录B

---

## 4. 架构设计

### 4.1 分层架构

```
┌─────────────────────────────────────┐
│         UI Layer (Pages)            │
│  - UnifiedBudgetCenterPage          │
│  - UnifiedBudgetDetailPage          │
│  - BudgetModeWizardPage             │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│      Provider Layer (State)         │
│  - UnifiedBudgetProvider            │
│  - UnifiedBudgetNotifier            │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│     Service Layer (Business)        │
│  - UnifiedBudgetService             │
│  - BudgetCalculationService         │
│  - BudgetAllocationService          │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│   Repository Layer (Data Access)    │
│  - UnifiedBudgetRepository          │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│      Database Layer (SQLite)        │
│  - unified_budgets table            │
└─────────────────────────────────────┘
```

### 4.2 核心类设计

#### 4.2.1 UnifiedBudgetRepository

```dart
abstract class UnifiedBudgetRepository {
  // 基础 CRUD
  Future<UnifiedBudget> create(UnifiedBudget budget);
  Future<UnifiedBudget> update(UnifiedBudget budget);
  Future<void> delete(String id);
  Future<UnifiedBudget?> getById(String id);
  Future<List<UnifiedBudget>> getAll();

  // 查询方法
  Future<List<UnifiedBudget>> getByLedger(String ledgerId);
  Future<List<UnifiedBudget>> getByMode(String ledgerId, BudgetMode mode);
  Future<List<UnifiedBudget>> getByCategory(String categoryId);
  Future<List<UnifiedBudget>> getByVaultType(String ledgerId, VaultType type);

  // 零基预算操作
  Future<void> allocate(String budgetId, double amount, {String? note});
  Future<void> spend(String budgetId, double amount);
  Future<void> transfer(String fromId, String toId, double amount, {String? note});

  // 统计方法
  Future<double> getTotalAllocated(String ledgerId);
  Future<double> getTotalSpent(String ledgerId);
  Future<BudgetSummary> getSummary(String ledgerId);
}
```

#### 4.2.2 UnifiedBudgetProvider

```dart
class UnifiedBudgetProvider extends StateNotifier<AsyncValue<List<UnifiedBudget>>> {
  final UnifiedBudgetRepository _repository;
  final String _ledgerId;

  UnifiedBudgetProvider(this._repository, this._ledgerId) : super(const AsyncValue.loading()) {
    _loadBudgets();
  }

  // 数据加载
  Future<void> _loadBudgets() async {
    state = const AsyncValue.loading();
    try {
      final budgets = await _repository.getByLedger(_ledgerId);
      state = AsyncValue.data(budgets);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // CRUD 操作
  Future<void> create(UnifiedBudget budget) async {
    await _repository.create(budget);
    await _loadBudgets();
  }

  Future<void> update(UnifiedBudget budget) async {
    await _repository.update(budget);
    await _loadBudgets();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await _loadBudgets();
  }

  // 过滤方法
  List<UnifiedBudget> get traditionalBudgets {
    return state.value?.where((b) => b.mode == BudgetMode.traditional).toList() ?? [];
  }

  List<UnifiedBudget> get zeroBasedBudgets {
    return state.value?.where((b) => b.mode == BudgetMode.zeroBased).toList() ?? [];
  }

  List<UnifiedBudget> getByVaultType(VaultType type) {
    return zeroBasedBudgets.where((b) => b.vaultType == type).toList();
  }

  // 零基预算操作
  Future<void> allocate(String budgetId, double amount, {String? note}) async {
    await _repository.allocate(budgetId, amount, note: note);
    await _loadBudgets();
  }

  Future<void> transfer(String fromId, String toId, double amount, {String? note}) async {
    await _repository.transfer(fromId, toId, amount, note: note);
    await _loadBudgets();
  }

  // 统计计算
  double get totalAllocated {
    return zeroBasedBudgets.fold(0.0, (sum, b) => sum + b.allocatedAmount);
  }

  double get totalSpent {
    return state.value?.fold(0.0, (sum, b) => sum + b.spentAmount) ?? 0.0;
  }

  double get totalAvailable {
    return totalAllocated - totalSpent;
  }
}
```

#### 4.2.3 UnifiedBudgetService

```dart
class UnifiedBudgetService {
  final UnifiedBudgetRepository _repository;

  // 预算计算
  Future<double> calculateRemaining(String budgetId) async {
    final budget = await _repository.getById(budgetId);
    if (budget == null) return 0;

    if (budget.mode == BudgetMode.traditional) {
      return budget.targetAmount - budget.spentAmount;
    } else {
      return budget.allocatedAmount - budget.spentAmount;
    }
  }

  // 预算状态判断
  BudgetStatus getBudgetStatus(UnifiedBudget budget) {
    final remaining = budget.mode == BudgetMode.traditional
        ? budget.targetAmount - budget.spentAmount
        : budget.allocatedAmount - budget.spentAmount;

    if (remaining < 0) return BudgetStatus.overSpent;
    if (remaining / budget.targetAmount < 0.1) return BudgetStatus.almostEmpty;
    return BudgetStatus.healthy;
  }

  // 零基预算自动分配
  Future<Map<String, double>> calculateAutoAllocation(
    String ledgerId,
    double incomeAmount,
  ) async {
    final budgets = await _repository.getByMode(ledgerId, BudgetMode.zeroBased);
    final allocation = <String, double>{};

    // 按优先级排序
    budgets.sort((a, b) =>
      (a.vaultType?.allocationPriority ?? 999)
        .compareTo(b.vaultType?.allocationPriority ?? 999)
    );

    var remaining = incomeAmount;

    for (final budget in budgets) {
      if (!budget.isEnabled) continue;

      double amount = 0;

      switch (budget.allocationType) {
        case AllocationType.fixed:
          amount = budget.targetAllocation ?? 0;
          break;
        case AllocationType.percentage:
          amount = incomeAmount * (budget.targetPercentage ?? 0);
          break;
        case AllocationType.topUp:
          final needed = budget.targetAmount - budget.allocatedAmount;
          amount = needed > 0 ? needed.clamp(0, remaining) : 0;
          break;
        case AllocationType.remainder:
          // 最后处理
          continue;
        default:
          break;
      }

      amount = amount.clamp(0, remaining);
      allocation[budget.id] = amount;
      remaining -= amount;
    }

    // 处理 remainder 类型
    final remainderBudgets = budgets.where(
      (b) => b.allocationType == AllocationType.remainder && b.isEnabled
    ).toList();

    if (remainderBudgets.isNotEmpty && remaining > 0) {
      final perBudget = remaining / remainderBudgets.length;
      for (final budget in remainderBudgets) {
        allocation[budget.id] = perBudget;
      }
    }

    return allocation;
  }
}
```

---

## 5. 用户界面设计

### 5.1 预算中心页面

**布局结构**：

```
┌─────────────────────────────────────┐
│  [返回]  预算中心  [设置]            │
├─────────────────────────────────────┤
│  [传统预算] [零基预算]  ← 模式切换   │
├─────────────────────────────────────┤
│  ┌───────────────────────────────┐  │
│  │  预算摘要卡片                  │  │
│  │  总预算: ¥5000                │  │
│  │  已使用: ¥3200 (64%)          │  │
│  │  剩余: ¥1800                  │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  预算列表                            │
│  ┌───────────────────────────────┐  │
│  │ [图标] 餐饮                    │  │
│  │        ¥800 / ¥1000 (80%)     │  │
│  │        [进度条]                │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │ [图标] 交通                    │  │
│  │        ¥500 / ¥800 (62.5%)    │  │
│  │        [进度条]                │  │
│  └───────────────────────────────┘  │
├─────────────────────────────────────┤
│  [+ 创建预算]                        │
└─────────────────────────────────────┘
```

### 5.2 预算详情页面

**传统预算详情**：
- 预算基本信息
- 使用情况图表（饼图/柱状图）
- 本期交易列表
- 历史趋势图

**零基预算详情**：
- 小金库基本信息
- 分配和使用情况
- 分配历史记录
- 支出记录列表
- 转账记录

### 5.3 预算模式选择向导

**步骤1：欢迎页**
- 介绍预算功能
- 说明两种模式的区别

**步骤2：模式对比**
- 并排对比两种模式
- 优缺点说明
- 适用场景

**步骤3：模式选择**
- 选择预算模式
- 确认并开始使用

---

## 6. 技术决策

### 6.1 为什么选择统一模型？

**优点**：
- 减少代码重复
- 简化数据查询
- 统一用户体验
- 降低维护成本

**缺点**：
- 模型字段较多
- 部分字段仅特定模式使用

**结论**：优点大于缺点，统一模型是最佳选择

### 6.2 为什么选择合并表？

**优点**：
- 查询效率高
- 数据结构清晰
- 易于维护

**缺点**：
- 需要数据迁移

**结论**：当前用户数据为空，迁移风险低，选择合并表

### 6.3 为什么保留两种模式？

**优点**：
- 满足不同用户需求
- 保留现有功能
- 提供灵活性

**缺点**：
- 增加复杂度

**结论**：两种模式各有优势，都应保留

---

## 7. 性能考虑

### 7.1 查询优化

- 使用索引加速常用查询
- 实现查询结果缓存
- 避免 N+1 查询问题

### 7.2 内存优化

- 使用分页加载大量数据
- 及时释放不用的对象
- 避免内存泄漏

### 7.3 UI渲染优化

- 使用 ListView.builder 懒加载
- 实现列表项复用
- 减少不必要的重建

---

## 8. 安全考虑

### 8.1 数据验证

- 金额字段必须 >= 0
- 百分比字段必须在 0-1 之间
- 必填字段不能为空

### 8.2 权限控制

- 用户只能访问自己账本的预算
- 家庭账本需要权限检查

### 8.3 数据备份

- 迁移前自动备份
- 提供手动备份功能
- 支持数据恢复

---

## 9. 测试策略

### 9.1 单元测试

- 模型序列化/反序列化
- Repository CRUD 操作
- Service 业务逻辑
- Provider 状态管理

### 9.2 集成测试

- 数据库迁移
- 端到端用户流程
- 跨模块交互

### 9.3 UI测试

- 页面渲染
- 用户交互
- 边界条件

---

## 10. 发布计划

### 10.1 灰度发布

- 先发布给内部测试用户
- 收集反馈并修复问题
- 逐步扩大用户范围

### 10.2 监控指标

- 崩溃率
- 性能指标
- 用户使用率
- 用户反馈

### 10.3 回滚方案

- 保留旧表备份
- 提供回滚脚本
- 快速回滚流程

---

**文档版本**: v1.0
**最后更新**: 2026-01-25
**作者**: Claude Code
