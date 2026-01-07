import 'database_service.dart';

/// 应急金目标类型
enum EmergencyFundGoalType {
  /// 按月数（如3个月生活费）
  months,

  /// 按固定金额
  fixedAmount,

  /// 按年收入比例
  incomePercentage,
}

extension EmergencyFundGoalTypeExtension on EmergencyFundGoalType {
  String get displayName {
    switch (this) {
      case EmergencyFundGoalType.months:
        return '月生活费倍数';
      case EmergencyFundGoalType.fixedAmount:
        return '固定金额';
      case EmergencyFundGoalType.incomePercentage:
        return '年收入比例';
    }
  }
}

/// 应急金健康状态
enum EmergencyFundHealth {
  /// 危险（<1个月）
  danger,

  /// 警告（1-2个月）
  warning,

  /// 基础（3-4个月）
  basic,

  /// 良好（5-6个月）
  good,

  /// 优秀（>6个月）
  excellent,
}

extension EmergencyFundHealthExtension on EmergencyFundHealth {
  String get displayName {
    switch (this) {
      case EmergencyFundHealth.danger:
        return '危险';
      case EmergencyFundHealth.warning:
        return '需注意';
      case EmergencyFundHealth.basic:
        return '基础保障';
      case EmergencyFundHealth.good:
        return '良好';
      case EmergencyFundHealth.excellent:
        return '优秀';
    }
  }

  String get description {
    switch (this) {
      case EmergencyFundHealth.danger:
        return '应急储备严重不足，建议优先建立';
      case EmergencyFundHealth.warning:
        return '应急储备偏低，建议继续积累';
      case EmergencyFundHealth.basic:
        return '已有基础保障，可应对短期风险';
      case EmergencyFundHealth.good:
        return '应急储备良好，可应对中期风险';
      case EmergencyFundHealth.excellent:
        return '应急储备充足，财务安全感强';
    }
  }

  String get emoji {
    switch (this) {
      case EmergencyFundHealth.danger:
        return '🔴';
      case EmergencyFundHealth.warning:
        return '🟠';
      case EmergencyFundHealth.basic:
        return '🟡';
      case EmergencyFundHealth.good:
        return '🟢';
      case EmergencyFundHealth.excellent:
        return '💚';
    }
  }
}

/// 应急金目标
class EmergencyFundGoal {
  final String id;
  final EmergencyFundGoalType type;
  final double value; // 根据type：月数/金额/比例
  final double monthlyExpense; // 月均支出（用于计算）
  final double annualIncome; // 年收入（用于计算）
  final DateTime createdAt;
  final DateTime? updatedAt;

  const EmergencyFundGoal({
    required this.id,
    required this.type,
    required this.value,
    this.monthlyExpense = 0,
    this.annualIncome = 0,
    required this.createdAt,
    this.updatedAt,
  });

  /// 计算目标金额
  double get targetAmount {
    switch (type) {
      case EmergencyFundGoalType.months:
        return value * monthlyExpense;
      case EmergencyFundGoalType.fixedAmount:
        return value;
      case EmergencyFundGoalType.incomePercentage:
        return annualIncome * value;
    }
  }

  /// 目标描述
  String get description {
    switch (type) {
      case EmergencyFundGoalType.months:
        return '${value.round()}个月生活费';
      case EmergencyFundGoalType.fixedAmount:
        return '¥${value.toStringAsFixed(0)}';
      case EmergencyFundGoalType.incomePercentage:
        return '年收入的${(value * 100).round()}%';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'value': value,
      'monthlyExpense': monthlyExpense,
      'annualIncome': annualIncome,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  factory EmergencyFundGoal.fromMap(Map<String, dynamic> map) {
    return EmergencyFundGoal(
      id: map['id'] as String,
      type: EmergencyFundGoalType.values[map['type'] as int],
      value: (map['value'] as num).toDouble(),
      monthlyExpense: (map['monthlyExpense'] as num?)?.toDouble() ?? 0,
      annualIncome: (map['annualIncome'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
          : null,
    );
  }

  EmergencyFundGoal copyWith({
    String? id,
    EmergencyFundGoalType? type,
    double? value,
    double? monthlyExpense,
    double? annualIncome,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyFundGoal(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      monthlyExpense: monthlyExpense ?? this.monthlyExpense,
      annualIncome: annualIncome ?? this.annualIncome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 应急金状态
class EmergencyFundStatus {
  final EmergencyFundGoal? goal;
  final double currentBalance;
  final double targetAmount;
  final double progress;
  final EmergencyFundHealth health;
  final double monthsCovered; // 可覆盖多少个月
  final double monthlyContribution; // 建议月供
  final int monthsToGoal; // 预计多少个月达成目标

  const EmergencyFundStatus({
    this.goal,
    required this.currentBalance,
    required this.targetAmount,
    required this.progress,
    required this.health,
    required this.monthsCovered,
    required this.monthlyContribution,
    required this.monthsToGoal,
  });

  double get remaining => (targetAmount - currentBalance).clamp(0, double.infinity);
  bool get isGoalReached => currentBalance >= targetAmount;
  int get progressPercent => (progress * 100).round();
}

/// 存款记录
class EmergencyFundDeposit {
  final String id;
  final double amount;
  final String? note;
  final DateTime depositedAt;

  const EmergencyFundDeposit({
    required this.id,
    required this.amount,
    this.note,
    required this.depositedAt,
  });
}

/// 财务缓冲服务（应急金管理）
///
/// 帮助用户建立和管理应急储备金，提供：
/// - 目标设定（按月数/固定金额/收入比例）
/// - 进度追踪
/// - 健康状态评估
/// - 存款计划建议
class FinancialBufferService {
  final DatabaseService _db;

  // 缓存
  EmergencyFundGoal? _cachedGoal;
  double _cachedBalance = 0;

  FinancialBufferService(this._db);

  /// 设置应急金目标
  Future<EmergencyFundGoal> setGoal({
    required EmergencyFundGoalType type,
    required double value,
    double? monthlyExpense,
    double? annualIncome,
  }) async {
    final now = DateTime.now();
    final existingGoal = await getGoal();

    final goal = EmergencyFundGoal(
      id: existingGoal?.id ?? '${now.millisecondsSinceEpoch}',
      type: type,
      value: value,
      monthlyExpense: monthlyExpense ?? existingGoal?.monthlyExpense ?? 0,
      annualIncome: annualIncome ?? existingGoal?.annualIncome ?? 0,
      createdAt: existingGoal?.createdAt ?? now,
      updatedAt: now,
    );

    if (existingGoal != null) {
      await _db.rawUpdate('''
        UPDATE emergency_fund_goals SET
          type = ?, value = ?, monthlyExpense = ?, annualIncome = ?, updatedAt = ?
        WHERE id = ?
      ''', [
        goal.type.index,
        goal.value,
        goal.monthlyExpense,
        goal.annualIncome,
        goal.updatedAt?.millisecondsSinceEpoch,
        goal.id,
      ]);
    } else {
      await _db.rawInsert('''
        INSERT INTO emergency_fund_goals
        (id, type, value, monthlyExpense, annualIncome, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        goal.id,
        goal.type.index,
        goal.value,
        goal.monthlyExpense,
        goal.annualIncome,
        goal.createdAt.millisecondsSinceEpoch,
        goal.updatedAt?.millisecondsSinceEpoch,
      ]);
    }

    _cachedGoal = goal;
    return goal;
  }

  /// 更新财务数据（月支出、年收入）
  Future<void> updateFinancialData({
    double? monthlyExpense,
    double? annualIncome,
  }) async {
    final goal = await getGoal();
    if (goal == null) return;

    final updated = goal.copyWith(
      monthlyExpense: monthlyExpense ?? goal.monthlyExpense,
      annualIncome: annualIncome ?? goal.annualIncome,
      updatedAt: DateTime.now(),
    );

    await _db.rawUpdate('''
      UPDATE emergency_fund_goals SET
        monthlyExpense = ?, annualIncome = ?, updatedAt = ?
      WHERE id = ?
    ''', [
      updated.monthlyExpense,
      updated.annualIncome,
      updated.updatedAt?.millisecondsSinceEpoch,
      updated.id,
    ]);

    _cachedGoal = updated;
  }

  /// 获取当前目标
  Future<EmergencyFundGoal?> getGoal() async {
    if (_cachedGoal != null) return _cachedGoal;

    final results = await _db.rawQuery('''
      SELECT * FROM emergency_fund_goals ORDER BY createdAt DESC LIMIT 1
    ''');

    if (results.isEmpty) return null;
    _cachedGoal = EmergencyFundGoal.fromMap(results.first);
    return _cachedGoal;
  }

  /// 存入应急金
  Future<void> deposit(double amount, {String? note}) async {
    if (amount <= 0) return;

    final now = DateTime.now();

    await _db.rawInsert('''
      INSERT INTO emergency_fund_deposits (id, amount, note, depositedAt)
      VALUES (?, ?, ?, ?)
    ''', [
      '${now.millisecondsSinceEpoch}',
      amount,
      note,
      now.millisecondsSinceEpoch,
    ]);

    _cachedBalance += amount;
  }

  /// 取出应急金（紧急使用）
  Future<void> withdraw(double amount, {String? reason}) async {
    if (amount <= 0) return;

    final now = DateTime.now();

    // 记录为负数存款
    await _db.rawInsert('''
      INSERT INTO emergency_fund_deposits (id, amount, note, depositedAt)
      VALUES (?, ?, ?, ?)
    ''', [
      '${now.millisecondsSinceEpoch}',
      -amount,
      reason ?? '紧急取出',
      now.millisecondsSinceEpoch,
    ]);

    _cachedBalance -= amount;
  }

  /// 获取当前余额
  Future<double> getBalance() async {
    final result = await _db.rawQuery('''
      SELECT SUM(amount) as total FROM emergency_fund_deposits
    ''');

    _cachedBalance = (result.first['total'] as num?)?.toDouble() ?? 0;
    return _cachedBalance;
  }

  /// 获取完整状态
  Future<EmergencyFundStatus> getStatus() async {
    final goal = await getGoal();
    final balance = await getBalance();

    if (goal == null) {
      return EmergencyFundStatus(
        goal: null,
        currentBalance: balance,
        targetAmount: 0,
        progress: 0,
        health: _calculateHealth(0, 0),
        monthsCovered: 0,
        monthlyContribution: 0,
        monthsToGoal: 0,
      );
    }

    final targetAmount = goal.targetAmount;
    final progress = targetAmount > 0 ? balance / targetAmount : 0;
    final monthsCovered = goal.monthlyExpense > 0
        ? balance / goal.monthlyExpense
        : 0;

    // 计算建议月供（假设12个月达成目标）
    final remaining = (targetAmount - balance).clamp(0, double.infinity);
    final monthlyContribution = remaining / 12;

    // 预计达成时间
    final monthsToGoal = monthlyContribution > 0
        ? (remaining / monthlyContribution).ceil()
        : 0;

    return EmergencyFundStatus(
      goal: goal,
      currentBalance: balance,
      targetAmount: targetAmount,
      progress: progress.clamp(0, 1),
      health: _calculateHealth(monthsCovered, goal.monthlyExpense),
      monthsCovered: monthsCovered,
      monthlyContribution: monthlyContribution,
      monthsToGoal: monthsToGoal,
    );
  }

  /// 获取存款历史
  Future<List<EmergencyFundDeposit>> getDepositHistory({int limit = 50}) async {
    final results = await _db.rawQuery('''
      SELECT * FROM emergency_fund_deposits
      ORDER BY depositedAt DESC
      LIMIT ?
    ''', [limit]);

    return results.map((m) => EmergencyFundDeposit(
      id: m['id'] as String,
      amount: (m['amount'] as num).toDouble(),
      note: m['note'] as String?,
      depositedAt: DateTime.fromMillisecondsSinceEpoch(m['depositedAt'] as int),
    )).toList();
  }

  /// 计算推荐目标
  Future<Map<String, double>> getRecommendedGoals({
    required double monthlyExpense,
    required double annualIncome,
  }) async {
    return {
      '基础保障（3个月）': monthlyExpense * 3,
      '标准目标（6个月）': monthlyExpense * 6,
      '充足保障（12个月）': monthlyExpense * 12,
      '年收入10%': annualIncome * 0.1,
      '年收入20%': annualIncome * 0.2,
    };
  }

  /// 生成存款计划
  Future<List<Map<String, dynamic>>> generateSavingPlan({
    required double targetAmount,
    required double currentBalance,
    required int targetMonths,
  }) async {
    final remaining = (targetAmount - currentBalance).clamp(0, double.infinity);
    final monthlyAmount = remaining / targetMonths;

    final plan = <Map<String, dynamic>>[];
    var accumulated = currentBalance;

    for (var i = 1; i <= targetMonths; i++) {
      accumulated += monthlyAmount;
      plan.add({
        'month': i,
        'deposit': monthlyAmount,
        'accumulated': accumulated,
        'progress': (accumulated / targetAmount * 100).round(),
      });
    }

    return plan;
  }

  EmergencyFundHealth _calculateHealth(double monthsCovered, double monthlyExpense) {
    if (monthlyExpense <= 0) {
      // 没有设置月支出，无法评估
      return EmergencyFundHealth.basic;
    }

    if (monthsCovered < 1) return EmergencyFundHealth.danger;
    if (monthsCovered < 3) return EmergencyFundHealth.warning;
    if (monthsCovered < 5) return EmergencyFundHealth.basic;
    if (monthsCovered < 7) return EmergencyFundHealth.good;
    return EmergencyFundHealth.excellent;
  }

  /// 清除缓存
  void clearCache() {
    _cachedGoal = null;
    _cachedBalance = 0;
  }
}
