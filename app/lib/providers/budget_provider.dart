import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import 'base/crud_notifier.dart';
import 'transaction_provider.dart';
import 'ledger_provider.dart';

/// 预算管理 Notifier
///
/// 继承 SimpleCrudNotifier 基类，消除重复的 CRUD 代码
class BudgetNotifier extends SimpleCrudNotifier<Budget, String> {
  @override
  String get tableName => 'budgets';

  @override
  String getId(Budget entity) => entity.id;

  @override
  Future<List<Budget>> fetchAll() => db.getBudgets();

  @override
  Future<void> insertOne(Budget entity) => db.insertBudget(entity);

  @override
  Future<void> updateOne(Budget entity) => db.updateBudget(entity);

  @override
  Future<void> deleteOne(String id) => db.deleteBudget(id);

  // ==================== 业务特有方法（保留原有接口）====================

  /// 添加预算（保持原有方法名兼容）
  Future<void> addBudget(Budget budget) => add(budget);

  /// 更新预算（保持原有方法名兼容）
  Future<void> updateBudget(Budget budget) => update(budget);

  /// 删除预算（保持原有方法名兼容）
  Future<void> deleteBudget(String id) => delete(id);

  /// 切换预算启用状态
  Future<void> toggleBudget(String id) async {
    final budget = getById(id);
    if (budget == null) return;
    final updated = budget.copyWith(isEnabled: !budget.isEnabled);
    await update(updated);
  }

  /// 根据ID获取预算（使用基类方法）
  Budget? getBudgetById(String id) => getById(id);

  List<Budget> getBudgetsForLedger(String ledgerId) {
    return state.where((b) => b.ledgerId == ledgerId && b.isEnabled).toList();
  }

  List<Budget> getBudgetsForCategory(String categoryId) {
    return state.where((b) => b.categoryId == categoryId && b.isEnabled).toList();
  }

  /// 获取预算的结转记录
  Future<List<BudgetCarryover>> getCarryovers(String budgetId) async {
    return await db.getBudgetCarryovers(budgetId);
  }

  /// 获取指定月份的结转金额
  Future<double> getCarryoverAmountForMonth(String budgetId, int year, int month) async {
    final carryover = await db.getBudgetCarryoverForMonth(budgetId, year, month);
    return carryover?.carryoverAmount ?? 0;
  }

  /// 执行预算结转（通常在月末/周期结束时调用）
  Future<void> executeCarryover(String budgetId, double remainingAmount) async {
    final budget = getBudgetById(budgetId);
    if (budget == null || !budget.enableCarryover) return;

    // 计算结转金额
    double carryoverAmount;
    if (budget.carryoverSurplusOnly) {
      // 仅结转剩余（正数）
      carryoverAmount = remainingAmount > 0 ? remainingAmount : 0;
    } else {
      // 结转所有（包括超支的负数）
      carryoverAmount = remainingAmount;
    }

    if (carryoverAmount == 0) return;

    // 计算下一个周期的年月
    final now = DateTime.now();
    int nextYear = now.year;
    int nextMonth = now.month + 1;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    }

    // 创建结转记录
    final carryover = BudgetCarryover(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      budgetId: budgetId,
      year: nextYear,
      month: nextMonth,
      carryoverAmount: carryoverAmount,
      createdAt: DateTime.now(),
    );

    await db.insertBudgetCarryover(carryover);
  }
}

final budgetProvider =
    NotifierProvider<BudgetNotifier, List<Budget>>(BudgetNotifier.new);

// Calculate budget usage for a specific budget
class BudgetUsage {
  final Budget budget;
  final double spent;
  final double remaining;
  final double percentage;
  final double carryoverAmount;  // 本期结转金额（正数=剩余结转，负数=超支结转）
  final double effectiveBudget;  // 有效预算（基础预算+结转金额）

  BudgetUsage({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.percentage,
    this.carryoverAmount = 0,
    double? effectiveBudget,
  }) : effectiveBudget = effectiveBudget ?? budget.amount;

  bool get isOverBudget => spent > effectiveBudget;
  bool get isNearLimit => percentage >= 0.8 && !isOverBudget;
  bool get hasCarryover => carryoverAmount != 0;
}

final budgetUsageProvider = Provider.family<BudgetUsage?, String>((ref, budgetId) {
  final budgets = ref.watch(budgetProvider);
  final transactions = ref.watch(transactionProvider);

  final budget = budgets.where((b) => b.id == budgetId).firstOrNull;
  if (budget == null) return null;

  // Filter transactions within the budget period
  final periodTransactions = transactions.where((t) {
    if (t.type != TransactionType.expense) return false;
    if (t.date.isBefore(budget.periodStartDate)) return false;
    if (t.date.isAfter(budget.periodEndDate)) return false;

    // If budget is category-specific, filter by category
    if (budget.categoryId != null && t.category != budget.categoryId) {
      return false;
    }

    return true;
  }).toList();

  final spent = periodTransactions.fold<double>(0, (sum, t) => sum + t.amount);
  final remaining = budget.amount - spent;
  final percentage = budget.amount > 0 ? spent / budget.amount : 0.0;

  return BudgetUsage(
    budget: budget,
    spent: spent,
    remaining: remaining,
    percentage: percentage.toDouble(),
  );
});

// Get all budget usages for current ledger
final allBudgetUsagesProvider = Provider<List<BudgetUsage>>((ref) {
  final budgets = ref.watch(budgetProvider);
  final transactions = ref.watch(transactionProvider);
  final currentLedgerId = ref.watch(ledgerProvider.notifier).currentLedgerId;

  return budgets
      .where((b) => b.ledgerId == currentLedgerId && b.isEnabled)
      .map((budget) {
        final periodTransactions = transactions.where((t) {
          if (t.type != TransactionType.expense) return false;
          if (t.date.isBefore(budget.periodStartDate)) return false;
          if (t.date.isAfter(budget.periodEndDate)) return false;

          if (budget.categoryId != null && t.category != budget.categoryId) {
            return false;
          }

          return true;
        }).toList();

        final spent = periodTransactions.fold<double>(0, (sum, t) => sum + t.amount);
        final remaining = budget.amount - spent;
        final percentage = budget.amount > 0 ? spent / budget.amount : 0.0;

        return BudgetUsage(
          budget: budget,
          spent: spent,
          remaining: remaining,
          percentage: percentage.toDouble(),
        );
      })
      .toList();
});

// ============== 零基预算相关 Provider ==============

/// 零基预算分配管理器
class ZeroBasedBudgetNotifier extends Notifier<Map<String, ZeroBasedAllocation>> {
  DatabaseService get db => DatabaseService();

  @override
  Map<String, ZeroBasedAllocation> build() {
    return {};
  }

  /// 获取指定预算当月的分配金额
  Future<double> getAllocationForMonth(String budgetId, int year, int month) async {
    final key = '$budgetId-$year-$month';
    if (state.containsKey(key)) {
      return state[key]!.allocatedAmount;
    }
    final allocation = await db.getZeroBasedAllocationForMonth(budgetId, year, month);
    if (allocation != null) {
      state = {...state, key: allocation};
      return allocation.allocatedAmount;
    }
    return 0;
  }

  /// 设置预算分配金额
  Future<void> setAllocation(String budgetId, double amount) async {
    final now = DateTime.now();
    final key = '$budgetId-${now.year}-${now.month}';

    // 检查是否已有分配记录
    final existing = await db.getZeroBasedAllocationForMonth(budgetId, now.year, now.month);

    if (existing != null) {
      // 更新现有记录
      final updated = ZeroBasedAllocation(
        id: existing.id,
        budgetId: budgetId,
        allocatedAmount: amount,
        year: now.year,
        month: now.month,
        createdAt: existing.createdAt,
      );
      await db.updateZeroBasedAllocation(updated);
      state = {...state, key: updated};
    } else {
      // 创建新记录
      final allocation = ZeroBasedAllocation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        budgetId: budgetId,
        allocatedAmount: amount,
        year: now.year,
        month: now.month,
        createdAt: DateTime.now(),
      );
      await db.insertZeroBasedAllocation(allocation);
      state = {...state, key: allocation};
    }
  }

  /// 从一个预算转移金额到另一个预算（Cover功能）
  Future<void> transferBetweenBudgets(
    String fromBudgetId,
    String toBudgetId,
    double amount,
  ) async {
    final now = DateTime.now();

    // 减少来源预算的分配
    final fromAllocation = await getAllocationForMonth(fromBudgetId, now.year, now.month);
    await setAllocation(fromBudgetId, fromAllocation - amount);

    // 增加目标预算的分配
    final toAllocation = await getAllocationForMonth(toBudgetId, now.year, now.month);
    await setAllocation(toBudgetId, toAllocation + amount);
  }
}

final zeroBasedBudgetProvider =
    NotifierProvider<ZeroBasedBudgetNotifier, Map<String, ZeroBasedAllocation>>(
        ZeroBasedBudgetNotifier.new);

/// 月度预算总额Provider
final monthlyBudgetProvider = Provider<double>((ref) {
  final budgets = ref.watch(budgetProvider);
  final now = DateTime.now();
  return budgets
      .where((b) => b.period == BudgetPeriod.monthly)
      .fold(0.0, (sum, b) => sum + b.amount);
});

/// 获取当月可分配资金（收入 - 已分配）
final availableToAssignProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionProvider);
  final budgets = ref.watch(budgetProvider);
  final allocations = ref.watch(zeroBasedBudgetProvider);

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // 计算本月收入
  final monthlyIncome = transactions
      .where((t) =>
          t.type == TransactionType.income &&
          t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
          t.date.isBefore(monthEnd.add(const Duration(days: 1))))
      .fold<double>(0, (sum, t) => sum + t.amount);

  // 计算已分配金额（所有零基预算的当月分配）
  double totalAllocated = 0;
  for (final budget in budgets.where((b) => b.budgetType == BudgetType.zeroBased && b.isEnabled)) {
    final key = '${budget.id}-${now.year}-${now.month}';
    if (allocations.containsKey(key)) {
      totalAllocated += allocations[key]!.allocatedAmount;
    }
  }

  return monthlyIncome - totalAllocated;
});

// ============== 钱龄相关 Provider ==============

/// 钱龄计算 Provider
/// 钱龄 = 当前余额可以支撑的天数（基于平均日支出）
final moneyAgeProvider = Provider<MoneyAge>((ref) {
  final transactions = ref.watch(transactionProvider);

  final now = DateTime.now();

  // 计算总余额（所有收入 - 所有支出）
  double totalIncome = 0;
  double totalExpense = 0;

  for (final t in transactions) {
    if (t.type == TransactionType.income) {
      totalIncome += t.amount;
    } else if (t.type == TransactionType.expense) {
      totalExpense += t.amount;
    }
  }

  final totalBalance = totalIncome - totalExpense;

  // 计算最近30天的平均日支出
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));
  final recentExpenses = transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          t.date.isAfter(thirtyDaysAgo))
      .fold<double>(0, (sum, t) => sum + t.amount);

  final avgDailyExpense = recentExpenses / 30;

  // 钱龄 = 当前余额 / 平均日支出
  int moneyAgeDays = 0;
  if (avgDailyExpense > 0 && totalBalance > 0) {
    moneyAgeDays = (totalBalance / avgDailyExpense).round();
  }

  // 计算趋势（对比上月钱龄）
  String? trend;
  final sixtyDaysAgo = now.subtract(const Duration(days: 60));
  final previousPeriodExpenses = transactions
      .where((t) =>
          t.type == TransactionType.expense &&
          t.date.isAfter(sixtyDaysAgo) &&
          t.date.isBefore(thirtyDaysAgo))
      .fold<double>(0, (sum, t) => sum + t.amount);

  if (previousPeriodExpenses > 0) {
    final previousAvgDaily = previousPeriodExpenses / 30;
    if (avgDailyExpense < previousAvgDaily * 0.9) {
      trend = 'up'; // 支出减少，钱龄上升
    } else if (avgDailyExpense > previousAvgDaily * 1.1) {
      trend = 'down'; // 支出增加，钱龄下降
    } else {
      trend = 'stable';
    }
  }

  return MoneyAge(
    days: moneyAgeDays,
    calculatedAt: now,
    totalBalance: totalBalance,
    trend: trend,
  );
});

/// 钱龄历史记录（用于显示趋势图表）
final moneyAgeHistoryProvider = Provider<List<MapEntry<DateTime, int>>>((ref) {
  final transactions = ref.watch(transactionProvider);

  if (transactions.isEmpty) return [];

  final now = DateTime.now();
  final history = <MapEntry<DateTime, int>>[];

  // 计算最近12个月的钱龄
  for (int i = 0; i < 12; i++) {
    final monthEnd = DateTime(now.year, now.month - i + 1, 0);
    final monthStart = DateTime(now.year, now.month - i, 1);

    // 计算到该月末的总余额
    double balance = 0;
    for (final t in transactions.where((t) => t.date.isBefore(monthEnd.add(const Duration(days: 1))))) {
      if (t.type == TransactionType.income) {
        balance += t.amount;
      } else if (t.type == TransactionType.expense) {
        balance -= t.amount;
      }
    }

    // 计算该月的平均日支出
    final monthExpenses = transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            t.date.isBefore(monthEnd.add(const Duration(days: 1))))
        .fold<double>(0, (sum, t) => sum + t.amount);

    final daysInMonth = monthEnd.day;
    final avgDailyExpense = monthExpenses / daysInMonth;

    int moneyAge = 0;
    if (avgDailyExpense > 0 && balance > 0) {
      moneyAge = (balance / avgDailyExpense).round();
    }

    history.add(MapEntry(monthEnd, moneyAge));
  }

  return history.reversed.toList();
});
