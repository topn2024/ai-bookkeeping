import 'database_service.dart';

/// 计划消费类型
enum PlannedExpenseType {
  /// 日常必需
  essential,

  /// 定期支出
  recurring,

  /// 大额购买
  largePurchase,

  /// 愿望清单
  wishList,

  /// 社交活动
  social,

  /// 其他
  other,
}

extension PlannedExpenseTypeExtension on PlannedExpenseType {
  String get displayName {
    switch (this) {
      case PlannedExpenseType.essential:
        return '日常必需';
      case PlannedExpenseType.recurring:
        return '定期支出';
      case PlannedExpenseType.largePurchase:
        return '大额购买';
      case PlannedExpenseType.wishList:
        return '愿望清单';
      case PlannedExpenseType.social:
        return '社交活动';
      case PlannedExpenseType.other:
        return '其他';
    }
  }
}

/// 计划消费状态
enum PlannedExpenseStatus {
  /// 待执行
  pending,

  /// 已执行
  executed,

  /// 已取消
  cancelled,

  /// 已延期
  postponed,
}

/// 计划消费项
class PlannedExpense {
  final String id;
  final String name;
  final double amount;
  final PlannedExpenseType type;
  final PlannedExpenseStatus status;
  final DateTime plannedDate;
  final DateTime? executedDate;
  final String? categoryId;
  final String? note;
  final int priority; // 1-5, 5最高
  final bool isFlexible; // 是否可调整

  const PlannedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    this.status = PlannedExpenseStatus.pending,
    required this.plannedDate,
    this.executedDate,
    this.categoryId,
    this.note,
    this.priority = 3,
    this.isFlexible = true,
  });

  bool get isPending => status == PlannedExpenseStatus.pending;
  bool get isOverdue => isPending && DateTime.now().isAfter(plannedDate);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'type': type.index,
    'status': status.index,
    'plannedDate': plannedDate.millisecondsSinceEpoch,
    'executedDate': executedDate?.millisecondsSinceEpoch,
    'categoryId': categoryId,
    'note': note,
    'priority': priority,
    'isFlexible': isFlexible ? 1 : 0,
  };

  factory PlannedExpense.fromMap(Map<String, dynamic> map) => PlannedExpense(
    id: map['id'] as String,
    name: map['name'] as String,
    amount: (map['amount'] as num).toDouble(),
    type: PlannedExpenseType.values[map['type'] as int],
    status: PlannedExpenseStatus.values[map['status'] as int? ?? 0],
    plannedDate: DateTime.fromMillisecondsSinceEpoch(map['plannedDate'] as int),
    executedDate: map['executedDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['executedDate'] as int)
        : null,
    categoryId: map['categoryId'] as String?,
    note: map['note'] as String?,
    priority: map['priority'] as int? ?? 3,
    isFlexible: (map['isFlexible'] as int?) != 0,
  );

  PlannedExpense copyWith({
    PlannedExpenseStatus? status,
    DateTime? executedDate,
    DateTime? plannedDate,
    String? note,
  }) {
    return PlannedExpense(
      id: id,
      name: name,
      amount: amount,
      type: type,
      status: status ?? this.status,
      plannedDate: plannedDate ?? this.plannedDate,
      executedDate: executedDate ?? this.executedDate,
      categoryId: categoryId,
      note: note ?? this.note,
      priority: priority,
      isFlexible: isFlexible,
    );
  }
}

/// 月度消费计划
class MonthlyPlan {
  final int year;
  final int month;
  final List<PlannedExpense> expenses;
  final double totalPlanned;
  final double totalExecuted;
  final double budgetLimit;

  const MonthlyPlan({
    required this.year,
    required this.month,
    required this.expenses,
    required this.totalPlanned,
    required this.totalExecuted,
    required this.budgetLimit,
  });

  double get remaining => budgetLimit - totalExecuted;
  double get pendingAmount => expenses
      .where((e) => e.isPending)
      .fold(0.0, (sum, e) => sum + e.amount);
  bool get isOverBudget => totalPlanned > budgetLimit;
  int get pendingCount => expenses.where((e) => e.isPending).length;
  int get executedCount => expenses.where((e) => e.status == PlannedExpenseStatus.executed).length;
}

/// 消费规划服务
///
/// 帮助用户"先规划再消费"，将冲动消费转化为有计划的支出：
/// - 月度消费计划
/// - 大额消费提前规划
/// - 预算分配建议
/// - 计划执行追踪
class SpendingPlanningService {
  final DatabaseService _db;

  SpendingPlanningService(this._db);

  /// 创建计划消费
  Future<PlannedExpense> createPlan({
    required String name,
    required double amount,
    required PlannedExpenseType type,
    required DateTime plannedDate,
    String? categoryId,
    String? note,
    int priority = 3,
    bool isFlexible = true,
  }) async {
    final expense = PlannedExpense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      amount: amount,
      type: type,
      plannedDate: plannedDate,
      categoryId: categoryId,
      note: note,
      priority: priority,
      isFlexible: isFlexible,
    );

    await _db.rawInsert('''
      INSERT INTO planned_expenses
      (id, name, amount, type, status, plannedDate, categoryId, note, priority, isFlexible)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      expense.id,
      expense.name,
      expense.amount,
      expense.type.index,
      expense.status.index,
      expense.plannedDate.millisecondsSinceEpoch,
      expense.categoryId,
      expense.note,
      expense.priority,
      expense.isFlexible ? 1 : 0,
    ]);

    return expense;
  }

  /// 执行计划（标记为已消费）
  Future<void> executePlan(String planId, {String? transactionId}) async {
    await _db.rawUpdate('''
      UPDATE planned_expenses
      SET status = ?, executedDate = ?
      WHERE id = ?
    ''', [
      PlannedExpenseStatus.executed.index,
      DateTime.now().millisecondsSinceEpoch,
      planId,
    ]);

    // 关联到实际交易
    if (transactionId != null) {
      await _db.rawInsert('''
        INSERT INTO plan_transaction_links (planId, transactionId, linkedAt)
        VALUES (?, ?, ?)
      ''', [planId, transactionId, DateTime.now().millisecondsSinceEpoch]);
    }
  }

  /// 取消计划
  Future<void> cancelPlan(String planId, {String? reason}) async {
    await _db.rawUpdate('''
      UPDATE planned_expenses SET status = ?, note = ? WHERE id = ?
    ''', [PlannedExpenseStatus.cancelled.index, reason, planId]);
  }

  /// 延期计划
  Future<void> postponePlan(String planId, DateTime newDate) async {
    await _db.rawUpdate('''
      UPDATE planned_expenses SET status = ?, plannedDate = ? WHERE id = ?
    ''', [
      PlannedExpenseStatus.postponed.index,
      newDate.millisecondsSinceEpoch,
      planId,
    ]);
  }

  /// 获取月度计划
  Future<MonthlyPlan> getMonthlyPlan({
    required int year,
    required int month,
    double budgetLimit = 0,
  }) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    final results = await _db.rawQuery('''
      SELECT * FROM planned_expenses
      WHERE plannedDate >= ? AND plannedDate <= ?
      ORDER BY plannedDate ASC
    ''', [
      startOfMonth.millisecondsSinceEpoch,
      endOfMonth.millisecondsSinceEpoch,
    ]);

    final expenses = results.map((m) => PlannedExpense.fromMap(m)).toList();

    final totalPlanned = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalExecuted = expenses
        .where((e) => e.status == PlannedExpenseStatus.executed)
        .fold(0.0, (sum, e) => sum + e.amount);

    return MonthlyPlan(
      year: year,
      month: month,
      expenses: expenses,
      totalPlanned: totalPlanned,
      totalExecuted: totalExecuted,
      budgetLimit: budgetLimit,
    );
  }

  /// 获取待执行的计划
  Future<List<PlannedExpense>> getPendingPlans({int? daysAhead}) async {
    String query = '''
      SELECT * FROM planned_expenses WHERE status = ?
    ''';
    final params = <dynamic>[PlannedExpenseStatus.pending.index];

    if (daysAhead != null) {
      final deadline = DateTime.now()
          .add(Duration(days: daysAhead))
          .millisecondsSinceEpoch;
      query += ' AND plannedDate <= ?';
      params.add(deadline);
    }

    query += ' ORDER BY plannedDate ASC';

    final results = await _db.rawQuery(query, params);
    return results.map((m) => PlannedExpense.fromMap(m)).toList();
  }

  /// 获取过期未执行的计划
  Future<List<PlannedExpense>> getOverduePlans() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final results = await _db.rawQuery('''
      SELECT * FROM planned_expenses
      WHERE status = ? AND plannedDate < ?
      ORDER BY plannedDate ASC
    ''', [PlannedExpenseStatus.pending.index, now]);

    return results.map((m) => PlannedExpense.fromMap(m)).toList();
  }

  /// 获取今日计划
  Future<List<PlannedExpense>> getTodayPlans() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final results = await _db.rawQuery('''
      SELECT * FROM planned_expenses
      WHERE plannedDate >= ? AND plannedDate < ?
      ORDER BY priority DESC
    ''', [
      startOfDay.millisecondsSinceEpoch,
      endOfDay.millisecondsSinceEpoch,
    ]);

    return results.map((m) => PlannedExpense.fromMap(m)).toList();
  }

  /// 检查消费是否在计划内
  Future<PlannedExpense?> findMatchingPlan({
    required double amount,
    required String? categoryId,
    double tolerance = 0.1, // 10%容差
  }) async {
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    final weekLater = today.add(const Duration(days: 7));

    final results = await _db.rawQuery('''
      SELECT * FROM planned_expenses
      WHERE status = ? AND plannedDate >= ? AND plannedDate <= ?
      ORDER BY ABS(amount - ?) ASC
    ''', [
      PlannedExpenseStatus.pending.index,
      weekAgo.millisecondsSinceEpoch,
      weekLater.millisecondsSinceEpoch,
      amount,
    ]);

    for (final map in results) {
      final plan = PlannedExpense.fromMap(map);
      final amountDiff = (plan.amount - amount).abs() / plan.amount;

      if (amountDiff <= tolerance) {
        if (categoryId == null || plan.categoryId == categoryId) {
          return plan;
        }
      }
    }

    return null;
  }

  /// 获取计划执行统计
  Future<Map<String, dynamic>> getPlanStats({int days = 30}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    // 总计划数
    final totalResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM planned_expenses WHERE plannedDate >= ?
    ''', [since]);
    final total = (totalResult.first['count'] as int?) ?? 0;

    // 已执行数
    final executedResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM planned_expenses
      WHERE status = ? AND plannedDate >= ?
    ''', [PlannedExpenseStatus.executed.index, since]);
    final executed = (executedResult.first['count'] as int?) ?? 0;

    // 已取消数
    final cancelledResult = await _db.rawQuery('''
      SELECT COUNT(*) as count FROM planned_expenses
      WHERE status = ? AND plannedDate >= ?
    ''', [PlannedExpenseStatus.cancelled.index, since]);
    final cancelled = (cancelledResult.first['count'] as int?) ?? 0;

    // 计划内消费金额
    final plannedAmountResult = await _db.rawQuery('''
      SELECT SUM(amount) as total FROM planned_expenses
      WHERE status = ? AND plannedDate >= ?
    ''', [PlannedExpenseStatus.executed.index, since]);
    final plannedAmount = (plannedAmountResult.first['total'] as num?)?.toDouble() ?? 0;

    return {
      'totalPlans': total,
      'executedPlans': executed,
      'cancelledPlans': cancelled,
      'executionRate': total > 0 ? executed / total : 0,
      'plannedAmount': plannedAmount,
    };
  }

  /// 生成下月计划建议（基于历史消费）
  Future<List<PlannedExpense>> generatePlanSuggestions({
    required int year,
    required int month,
  }) async {
    final suggestions = <PlannedExpense>[];

    // 获取上月的周期性消费
    final lastMonth = month == 1 ? 12 : month - 1;
    final lastYear = month == 1 ? year - 1 : year;

    final lastMonthPlan = await getMonthlyPlan(year: lastYear, month: lastMonth);

    // 复制上月的定期支出
    for (final expense in lastMonthPlan.expenses) {
      if (expense.type == PlannedExpenseType.recurring ||
          expense.type == PlannedExpenseType.essential) {
        final newDate = DateTime(year, month, expense.plannedDate.day);

        suggestions.add(PlannedExpense(
          id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}_${suggestions.length}',
          name: expense.name,
          amount: expense.amount,
          type: expense.type,
          plannedDate: newDate,
          categoryId: expense.categoryId,
          priority: expense.priority,
        ));
      }
    }

    return suggestions;
  }
}
