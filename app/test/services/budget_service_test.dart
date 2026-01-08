import 'package:flutter_test/flutter_test.dart';

/// 预算服务单元测试
///
/// 对应实施方案：轨道L 测试与质量保障模块

// ==================== Mock 预算模型 ====================

/// 预算模型
class Budget {
  final String id;
  final String categoryId;
  final double amount;
  final double spent;
  final String period; // monthly, weekly, yearly
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool rollover; // 是否结转

  Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    this.spent = 0,
    this.period = 'monthly',
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.rollover = false,
  });

  double get remaining => amount - spent;
  double get usagePercentage => amount > 0 ? (spent / amount * 100) : 0;
  bool get isOverBudget => spent > amount;

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    double? spent,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? rollover,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      spent: spent ?? this.spent,
      period: period ?? this.period,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      rollover: rollover ?? this.rollover,
    );
  }
}

/// 预算预警级别
enum BudgetAlertLevel {
  safe,      // < 50%
  warning,   // 50% - 80%
  danger,    // 80% - 100%
  exceeded,  // > 100%
}

/// 预算分析结果
class BudgetAnalysis {
  final Budget budget;
  final BudgetAlertLevel alertLevel;
  final double dailyAverage;
  final double suggestedDailyLimit;
  final int remainingDays;
  final String suggestion;

  BudgetAnalysis({
    required this.budget,
    required this.alertLevel,
    required this.dailyAverage,
    required this.suggestedDailyLimit,
    required this.remainingDays,
    required this.suggestion,
  });
}

// ==================== 预算服务 ====================

/// 预算服务
class BudgetService {
  final Map<String, Budget> _budgets = {};
  final Map<String, List<double>> _spendingHistory = {};

  /// 创建预算
  Budget createBudget({
    required String categoryId,
    required double amount,
    String period = 'monthly',
    DateTime? startDate,
    bool rollover = false,
  }) {
    final id = 'budget_${DateTime.now().millisecondsSinceEpoch}';
    final budget = Budget(
      id: id,
      categoryId: categoryId,
      amount: amount,
      period: period,
      startDate: startDate ?? DateTime.now(),
      rollover: rollover,
    );
    _budgets[id] = budget;
    return budget;
  }

  /// 获取预算
  Budget? getBudget(String id) => _budgets[id];

  /// 获取分类预算
  Budget? getBudgetByCategory(String categoryId) {
    return _budgets.values.cast<Budget?>().firstWhere(
      (b) => b!.categoryId == categoryId && b.isActive,
      orElse: () => null,
    );
  }

  /// 记录支出
  void recordSpending(String budgetId, double amount) {
    final budget = _budgets[budgetId];
    if (budget != null) {
      _budgets[budgetId] = budget.copyWith(spent: budget.spent + amount);
      _spendingHistory.putIfAbsent(budgetId, () => []);
      _spendingHistory[budgetId]!.add(amount);
    }
  }

  /// 获取预警级别
  BudgetAlertLevel getAlertLevel(Budget budget) {
    final usage = budget.usagePercentage;
    if (usage > 100) return BudgetAlertLevel.exceeded;
    if (usage >= 80) return BudgetAlertLevel.danger;
    if (usage >= 50) return BudgetAlertLevel.warning;
    return BudgetAlertLevel.safe;
  }

  /// 计算剩余天数
  int getRemainingDays(Budget budget) {
    final now = DateTime.now();
    DateTime endDate;

    switch (budget.period) {
      case 'weekly':
        final daysUntilEndOfWeek = 7 - now.weekday;
        endDate = now.add(Duration(days: daysUntilEndOfWeek));
        break;
      case 'yearly':
        endDate = DateTime(now.year + 1, 1, 1);
        break;
      case 'monthly':
      default:
        endDate = DateTime(now.year, now.month + 1, 1);
    }

    return endDate.difference(now).inDays;
  }

  /// 计算建议日限额
  double getSuggestedDailyLimit(Budget budget) {
    final remainingDays = getRemainingDays(budget);
    if (remainingDays <= 0) return 0;
    return budget.remaining / remainingDays;
  }

  /// 分析预算
  BudgetAnalysis analyzeBudget(Budget budget) {
    final alertLevel = getAlertLevel(budget);
    final remainingDays = getRemainingDays(budget);
    final suggestedDaily = getSuggestedDailyLimit(budget);

    // 计算日均支出
    final history = _spendingHistory[budget.id] ?? [];
    final dailyAverage = history.isNotEmpty
        ? history.reduce((a, b) => a + b) / history.length
        : budget.spent / (DateTime.now().difference(budget.startDate).inDays + 1);

    String suggestion;
    switch (alertLevel) {
      case BudgetAlertLevel.safe:
        suggestion = '预算使用健康，继续保持！';
        break;
      case BudgetAlertLevel.warning:
        suggestion = '预算使用过半，建议控制支出。每日建议限额：¥${suggestedDaily.toStringAsFixed(2)}';
        break;
      case BudgetAlertLevel.danger:
        suggestion = '预算即将用尽，请严格控制支出！每日限额：¥${suggestedDaily.toStringAsFixed(2)}';
        break;
      case BudgetAlertLevel.exceeded:
        suggestion = '预算已超支 ¥${(-budget.remaining).toStringAsFixed(2)}，建议调整预算或减少支出';
        break;
    }

    return BudgetAnalysis(
      budget: budget,
      alertLevel: alertLevel,
      dailyAverage: dailyAverage,
      suggestedDailyLimit: suggestedDaily,
      remainingDays: remainingDays,
      suggestion: suggestion,
    );
  }

  /// 预算结转
  Budget? rolloverBudget(String budgetId) {
    final oldBudget = _budgets[budgetId];
    if (oldBudget == null || !oldBudget.rollover) return null;

    // 计算结转金额
    final rolloverAmount = oldBudget.remaining;

    // 创建新预算
    final newBudget = createBudget(
      categoryId: oldBudget.categoryId,
      amount: oldBudget.amount + (rolloverAmount > 0 ? rolloverAmount : 0),
      period: oldBudget.period,
      rollover: oldBudget.rollover,
    );

    // 标记旧预算为非活跃
    _budgets[budgetId] = oldBudget.copyWith(isActive: false);

    return newBudget;
  }

  /// 获取所有活跃预算
  List<Budget> getActiveBudgets() {
    return _budgets.values.where((b) => b.isActive).toList();
  }

  /// 获取预算概要
  Map<String, dynamic> getBudgetSummary() {
    final activeBudgets = getActiveBudgets();
    if (activeBudgets.isEmpty) {
      return {
        'totalBudget': 0.0,
        'totalSpent': 0.0,
        'totalRemaining': 0.0,
        'overallUsage': 0.0,
        'budgetCount': 0,
        'overBudgetCount': 0,
      };
    }

    final totalBudget = activeBudgets.fold<double>(0, (sum, b) => sum + b.amount);
    final totalSpent = activeBudgets.fold<double>(0, (sum, b) => sum + b.spent);
    final overBudgetCount = activeBudgets.where((b) => b.isOverBudget).length;

    return {
      'totalBudget': totalBudget,
      'totalSpent': totalSpent,
      'totalRemaining': totalBudget - totalSpent,
      'overallUsage': totalBudget > 0 ? totalSpent / totalBudget * 100 : 0,
      'budgetCount': activeBudgets.length,
      'overBudgetCount': overBudgetCount,
    };
  }

  /// 重置（测试用）
  void reset() {
    _budgets.clear();
    _spendingHistory.clear();
  }
}

// ==================== 测试用例 ====================

void main() {
  late BudgetService budgetService;

  setUp(() {
    budgetService = BudgetService();
  });

  tearDown(() {
    budgetService.reset();
  });

  group('预算创建测试', () {
    test('创建月度预算', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 3000,
        period: 'monthly',
      );

      expect(budget.categoryId, 'cat_food');
      expect(budget.amount, 3000);
      expect(budget.spent, 0);
      expect(budget.period, 'monthly');
      expect(budget.isActive, true);
      expect(budget.remaining, 3000);
      expect(budget.usagePercentage, 0);
    });

    test('创建周度预算', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_transport',
        amount: 500,
        period: 'weekly',
      );

      expect(budget.period, 'weekly');
      expect(budget.amount, 500);
    });

    test('创建带结转的预算', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_entertainment',
        amount: 1000,
        rollover: true,
      );

      expect(budget.rollover, true);
    });
  });

  group('支出记录测试', () {
    test('记录支出更新已花费金额', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 3000,
      );

      budgetService.recordSpending(budget.id, 100);
      final updated = budgetService.getBudget(budget.id)!;

      expect(updated.spent, 100);
      expect(updated.remaining, 2900);
    });

    test('多次支出累计', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 3000,
      );

      budgetService.recordSpending(budget.id, 100);
      budgetService.recordSpending(budget.id, 200);
      budgetService.recordSpending(budget.id, 300);

      final updated = budgetService.getBudget(budget.id)!;
      expect(updated.spent, 600);
      expect(updated.remaining, 2400);
    });

    test('支出超过预算', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 1000,
      );

      budgetService.recordSpending(budget.id, 1200);
      final updated = budgetService.getBudget(budget.id)!;

      expect(updated.spent, 1200);
      expect(updated.remaining, -200);
      expect(updated.isOverBudget, true);
    });
  });

  group('预警级别测试', () {
    test('安全级别 - 使用率低于50%', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 400,
        startDate: DateTime.now(),
      );

      expect(budgetService.getAlertLevel(budget), BudgetAlertLevel.safe);
    });

    test('警告级别 - 使用率50%-80%', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 600,
        startDate: DateTime.now(),
      );

      expect(budgetService.getAlertLevel(budget), BudgetAlertLevel.warning);
    });

    test('危险级别 - 使用率80%-100%', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 850,
        startDate: DateTime.now(),
      );

      expect(budgetService.getAlertLevel(budget), BudgetAlertLevel.danger);
    });

    test('超支级别 - 使用率超过100%', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 1200,
        startDate: DateTime.now(),
      );

      expect(budgetService.getAlertLevel(budget), BudgetAlertLevel.exceeded);
    });

    test('边界值 - 恰好50%', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 500,
        startDate: DateTime.now(),
      );

      expect(budgetService.getAlertLevel(budget), BudgetAlertLevel.warning);
    });

    test('边界值 - 恰好80%', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 800,
        startDate: DateTime.now(),
      );

      expect(budgetService.getAlertLevel(budget), BudgetAlertLevel.danger);
    });

    test('边界值 - 恰好100%', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 1000,
        startDate: DateTime.now(),
      );

      expect(budgetService.getAlertLevel(budget), BudgetAlertLevel.danger);
    });
  });

  group('预算分析测试', () {
    test('安全状态分析', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 3000,
      );
      budgetService.recordSpending(budget.id, 500);

      final analysis = budgetService.analyzeBudget(
        budgetService.getBudget(budget.id)!,
      );

      expect(analysis.alertLevel, BudgetAlertLevel.safe);
      expect(analysis.suggestion.contains('健康'), true);
    });

    test('超支状态分析', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 1000,
      );
      budgetService.recordSpending(budget.id, 1500);

      final analysis = budgetService.analyzeBudget(
        budgetService.getBudget(budget.id)!,
      );

      expect(analysis.alertLevel, BudgetAlertLevel.exceeded);
      expect(analysis.suggestion.contains('超支'), true);
    });

    test('建议日限额计算', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 3000,
        spent: 1000,
        startDate: DateTime.now().subtract(const Duration(days: 10)),
      );

      final suggestedDaily = budgetService.getSuggestedDailyLimit(budget);

      // 剩余金额 / 剩余天数
      expect(suggestedDaily, greaterThan(0));
    });
  });

  group('预算结转测试', () {
    test('结转剩余预算', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 3000,
        rollover: true,
      );
      budgetService.recordSpending(budget.id, 2500);

      final newBudget = budgetService.rolloverBudget(budget.id);

      expect(newBudget, isNotNull);
      expect(newBudget!.amount, 3500); // 3000 + 500 结转
      expect(newBudget.rollover, true);

      // 旧预算应该被标记为非活跃
      final oldBudget = budgetService.getBudget(budget.id);
      expect(oldBudget!.isActive, false);
    });

    test('超支不结转负值', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 1000,
        rollover: true,
      );
      budgetService.recordSpending(budget.id, 1200);

      final newBudget = budgetService.rolloverBudget(budget.id);

      expect(newBudget, isNotNull);
      expect(newBudget!.amount, 1000); // 不结转负值
    });

    test('不允许结转的预算返回null', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 3000,
        rollover: false,
      );

      final newBudget = budgetService.rolloverBudget(budget.id);
      expect(newBudget, isNull);
    });
  });

  group('预算概要测试', () {
    test('空预算概要', () {
      final summary = budgetService.getBudgetSummary();

      expect(summary['totalBudget'], 0);
      expect(summary['totalSpent'], 0);
      expect(summary['budgetCount'], 0);
    });

    test('多预算概要统计', () {
      budgetService.createBudget(categoryId: 'cat_food', amount: 3000);
      budgetService.createBudget(categoryId: 'cat_transport', amount: 1000);
      budgetService.createBudget(categoryId: 'cat_entertainment', amount: 500);

      final summary = budgetService.getBudgetSummary();

      expect(summary['totalBudget'], 4500);
      expect(summary['budgetCount'], 3);
    });

    test('超支预算计数', () {
      final budget1 = budgetService.createBudget(categoryId: 'cat_food', amount: 1000);
      final budget2 = budgetService.createBudget(categoryId: 'cat_transport', amount: 500);

      budgetService.recordSpending(budget1.id, 1200); // 超支
      budgetService.recordSpending(budget2.id, 600);  // 超支

      final summary = budgetService.getBudgetSummary();

      expect(summary['overBudgetCount'], 2);
    });
  });

  group('按分类获取预算测试', () {
    test('获取分类预算', () {
      budgetService.createBudget(categoryId: 'cat_food', amount: 3000);

      final budget = budgetService.getBudgetByCategory('cat_food');
      expect(budget, isNotNull);
      expect(budget!.categoryId, 'cat_food');
    });

    test('获取不存在的分类预算', () {
      final budget = budgetService.getBudgetByCategory('cat_nonexistent');
      expect(budget, isNull);
    });

    test('只获取活跃预算', () {
      final budget = budgetService.createBudget(
        categoryId: 'cat_food',
        amount: 3000,
        rollover: true,
      );
      budgetService.rolloverBudget(budget.id);

      final activeBudgets = budgetService.getActiveBudgets();
      expect(activeBudgets.length, 1);
      expect(activeBudgets.first.id, isNot(budget.id));
    });
  });

  group('使用率计算测试', () {
    test('使用率计算正确', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 250,
        startDate: DateTime.now(),
      );

      expect(budget.usagePercentage, 25);
    });

    test('零预算使用率为0', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 0,
        spent: 100,
        startDate: DateTime.now(),
      );

      expect(budget.usagePercentage, 0);
    });

    test('超支使用率大于100', () {
      final budget = Budget(
        id: 'test',
        categoryId: 'cat_food',
        amount: 1000,
        spent: 1500,
        startDate: DateTime.now(),
      );

      expect(budget.usagePercentage, 150);
    });
  });
}
