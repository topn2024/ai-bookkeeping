import 'dart:math';

import 'database_service.dart';

/// 债务类型
enum DebtType {
  /// 信用卡
  creditCard,

  /// 消费贷款
  consumerLoan,

  /// 房贷
  mortgage,

  /// 车贷
  carLoan,

  /// 学生贷款
  studentLoan,

  /// 其他
  other,
}

extension DebtTypeExtension on DebtType {
  String get displayName {
    switch (this) {
      case DebtType.creditCard:
        return '信用卡';
      case DebtType.consumerLoan:
        return '消费贷款';
      case DebtType.mortgage:
        return '房贷';
      case DebtType.carLoan:
        return '车贷';
      case DebtType.studentLoan:
        return '学生贷款';
      case DebtType.other:
        return '其他';
    }
  }

  /// 是否为"好"债务（资产类）
  bool get isGoodDebt =>
      this == DebtType.mortgage || this == DebtType.studentLoan;

  /// 是否为高息债务
  bool get isHighInterest =>
      this == DebtType.creditCard || this == DebtType.consumerLoan;
}

/// 债务健康等级
enum DebtHealthLevel {
  /// 无债务或健康
  healthy,

  /// 轻度负债
  mild,

  /// 中度负债
  moderate,

  /// 重度负债
  severe,

  /// 危险
  critical,
}

extension DebtHealthLevelExtension on DebtHealthLevel {
  String get displayName {
    switch (this) {
      case DebtHealthLevel.healthy:
        return '健康';
      case DebtHealthLevel.mild:
        return '轻度';
      case DebtHealthLevel.moderate:
        return '中度';
      case DebtHealthLevel.severe:
        return '重度';
      case DebtHealthLevel.critical:
        return '危险';
    }
  }

  String get description {
    switch (this) {
      case DebtHealthLevel.healthy:
        return '债务管理良好，继续保持！';
      case DebtHealthLevel.mild:
        return '债务水平可控，建议按时还款';
      case DebtHealthLevel.moderate:
        return '债务压力适中，需要制定还款计划';
      case DebtHealthLevel.severe:
        return '债务压力较大，建议优先偿还高息债务';
      case DebtHealthLevel.critical:
        return '债务状况严重，请立即采取行动';
    }
  }

  String get emoji {
    switch (this) {
      case DebtHealthLevel.healthy:
        return '💚';
      case DebtHealthLevel.mild:
        return '🟢';
      case DebtHealthLevel.moderate:
        return '🟡';
      case DebtHealthLevel.severe:
        return '🟠';
      case DebtHealthLevel.critical:
        return '🔴';
    }
  }
}

/// 债务项目
class DebtItem {
  final String id;
  final String name;
  final DebtType type;
  final double totalAmount; // 总欠款
  final double remainingAmount; // 剩余欠款
  final double interestRate; // 年利率
  final double minimumPayment; // 最低还款额
  final DateTime? dueDate; // 下次还款日
  final DateTime createdAt;
  final bool isActive;

  const DebtItem({
    required this.id,
    required this.name,
    required this.type,
    required this.totalAmount,
    required this.remainingAmount,
    required this.interestRate,
    this.minimumPayment = 0,
    this.dueDate,
    required this.createdAt,
    this.isActive = true,
  });

  /// 已还款比例
  double get paidPercentage {
    if (totalAmount <= 0) return 0;
    return ((totalAmount - remainingAmount) / totalAmount).clamp(0, 1);
  }

  /// 月利息
  double get monthlyInterest => remainingAmount * interestRate / 12;

  /// 是否高息债务
  bool get isHighInterest => interestRate > 0.12; // >12%年息

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'interestRate': interestRate,
      'minimumPayment': minimumPayment,
      'dueDate': dueDate?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory DebtItem.fromMap(Map<String, dynamic> map) {
    return DebtItem(
      id: map['id'] as String,
      name: map['name'] as String,
      type: DebtType.values[map['type'] as int],
      totalAmount: (map['totalAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      minimumPayment: (map['minimumPayment'] as num?)?.toDouble() ?? 0,
      dueDate: map['dueDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      isActive: (map['isActive'] as int?) != 0,
    );
  }

  DebtItem copyWith({
    String? id,
    String? name,
    DebtType? type,
    double? totalAmount,
    double? remainingAmount,
    double? interestRate,
    double? minimumPayment,
    DateTime? dueDate,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return DebtItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      interestRate: interestRate ?? this.interestRate,
      minimumPayment: minimumPayment ?? this.minimumPayment,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 还款计划项
class PaymentPlanItem {
  final String debtId;
  final String debtName;
  final double paymentAmount;
  final int priority;
  final String reason;

  const PaymentPlanItem({
    required this.debtId,
    required this.debtName,
    required this.paymentAmount,
    required this.priority,
    required this.reason,
  });
}

/// 债务健康报告
class DebtHealthReport {
  final DebtHealthLevel level;
  final double totalDebt;
  final double totalMonthlyPayment;
  final double debtToIncomeRatio; // 债务收入比
  final double monthlyInterestCost; // 月利息成本
  final List<DebtItem> highPriorityDebts;
  final List<String> recommendations;

  const DebtHealthReport({
    required this.level,
    required this.totalDebt,
    required this.totalMonthlyPayment,
    required this.debtToIncomeRatio,
    required this.monthlyInterestCost,
    required this.highPriorityDebts,
    required this.recommendations,
  });
}

/// 雪球还款计划
class SnowballPlan {
  final List<PaymentPlanItem> monthlyPayments;
  final int totalMonths;
  final double totalInterestSaved;
  final DateTime estimatedPayoffDate;

  const SnowballPlan({
    required this.monthlyPayments,
    required this.totalMonths,
    required this.totalInterestSaved,
    required this.estimatedPayoffDate,
  });
}

/// 债务健康管理服务
///
/// 提供债务追踪、健康评估、还款计划等功能：
/// - 债务收入比计算
/// - 雪球/雪崩还款策略
/// - 债务健康评分
/// - 还款优先级建议
class DebtHealthService {
  final DatabaseService _db;

  // 用户月收入（用于计算债务收入比）
  double _monthlyIncome = 0;

  DebtHealthService(this._db);

  /// 设置月收入
  void setMonthlyIncome(double income) {
    _monthlyIncome = income;
  }

  /// 添加债务
  Future<DebtItem> addDebt({
    required String name,
    required DebtType type,
    required double totalAmount,
    required double remainingAmount,
    required double interestRate,
    double? minimumPayment,
    DateTime? dueDate,
  }) async {
    final now = DateTime.now();
    final debt = DebtItem(
      id: '${now.millisecondsSinceEpoch}',
      name: name,
      type: type,
      totalAmount: totalAmount,
      remainingAmount: remainingAmount,
      interestRate: interestRate,
      minimumPayment: minimumPayment ?? remainingAmount * 0.1,
      dueDate: dueDate,
      createdAt: now,
    );

    await _db.rawInsert('''
      INSERT INTO debts
      (id, name, type, totalAmount, remainingAmount, interestRate,
       minimumPayment, dueDate, createdAt, isActive)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      debt.id,
      debt.name,
      debt.type.index,
      debt.totalAmount,
      debt.remainingAmount,
      debt.interestRate,
      debt.minimumPayment,
      debt.dueDate?.millisecondsSinceEpoch,
      debt.createdAt.millisecondsSinceEpoch,
      1,
    ]);

    return debt;
  }

  /// 更新债务
  Future<void> updateDebt(DebtItem debt) async {
    await _db.rawUpdate('''
      UPDATE debts SET
        name = ?, type = ?, totalAmount = ?, remainingAmount = ?,
        interestRate = ?, minimumPayment = ?, dueDate = ?, isActive = ?
      WHERE id = ?
    ''', [
      debt.name,
      debt.type.index,
      debt.totalAmount,
      debt.remainingAmount,
      debt.interestRate,
      debt.minimumPayment,
      debt.dueDate?.millisecondsSinceEpoch,
      debt.isActive ? 1 : 0,
      debt.id,
    ]);
  }

  /// 记录还款
  Future<void> recordPayment(String debtId, double amount) async {
    final debt = await getDebt(debtId);
    if (debt == null) return;

    final newRemaining = max(0, debt.remainingAmount - amount);
    final isFullyPaid = newRemaining <= 0;

    await _db.rawUpdate('''
      UPDATE debts SET remainingAmount = ?, isActive = ? WHERE id = ?
    ''', [newRemaining, isFullyPaid ? 0 : 1, debtId]);

    // 记录还款历史
    await _db.rawInsert('''
      INSERT INTO debt_payments (id, debtId, amount, paidAt)
      VALUES (?, ?, ?, ?)
    ''', [
      DateTime.now().millisecondsSinceEpoch.toString(),
      debtId,
      amount,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  /// 获取单个债务
  Future<DebtItem?> getDebt(String debtId) async {
    final results = await _db.rawQuery(
      'SELECT * FROM debts WHERE id = ?',
      [debtId],
    );
    if (results.isEmpty) return null;
    return DebtItem.fromMap(results.first);
  }

  /// 获取所有活跃债务
  Future<List<DebtItem>> getActiveDebts() async {
    final results = await _db.rawQuery('''
      SELECT * FROM debts WHERE isActive = 1 ORDER BY interestRate DESC
    ''');
    return results.map((m) => DebtItem.fromMap(m)).toList();
  }

  /// 获取债务健康报告
  Future<DebtHealthReport> getHealthReport() async {
    final debts = await getActiveDebts();

    final totalDebt = debts.fold(0.0, (sum, d) => sum + d.remainingAmount);
    final totalMonthlyPayment =
        debts.fold(0.0, (sum, d) => sum + d.minimumPayment);
    final monthlyInterest = debts.fold(0.0, (sum, d) => sum + d.monthlyInterest);

    final debtToIncomeRatio =
        _monthlyIncome > 0 ? totalMonthlyPayment / _monthlyIncome : 0.0;

    final level = _calculateHealthLevel(debtToIncomeRatio, debts);

    final highPriorityDebts = debts
        .where((d) => d.isHighInterest || d.dueDate != null &&
            d.dueDate!.difference(DateTime.now()).inDays <= 7)
        .toList();

    final recommendations = _generateRecommendations(level, debts);

    return DebtHealthReport(
      level: level,
      totalDebt: totalDebt,
      totalMonthlyPayment: totalMonthlyPayment,
      debtToIncomeRatio: debtToIncomeRatio,
      monthlyInterestCost: monthlyInterest,
      highPriorityDebts: highPriorityDebts,
      recommendations: recommendations,
    );
  }

  /// 生成雪球还款计划（优先还小额债务）
  Future<SnowballPlan> generateSnowballPlan({
    required double monthlyBudget,
  }) async {
    final debts = await getActiveDebts();

    // 雪球法：按剩余金额从小到大排序
    final sortedDebts = List<DebtItem>.from(debts)
      ..sort((a, b) => a.remainingAmount.compareTo(b.remainingAmount));

    return _generatePaymentPlan(sortedDebts, monthlyBudget, '金额最小');
  }

  /// 生成雪崩还款计划（优先还高息债务）
  Future<SnowballPlan> generateAvalanchePlan({
    required double monthlyBudget,
  }) async {
    final debts = await getActiveDebts();

    // 雪崩法：按利率从高到低排序
    final sortedDebts = List<DebtItem>.from(debts)
      ..sort((a, b) => b.interestRate.compareTo(a.interestRate));

    return _generatePaymentPlan(sortedDebts, monthlyBudget, '利率最高');
  }

  /// 获取本月还款建议
  Future<List<PaymentPlanItem>> getMonthlyPaymentPlan({
    required double availableBudget,
  }) async {
    final debts = await getActiveDebts();
    final plan = <PaymentPlanItem>[];

    var remaining = availableBudget;

    // 1. 先还最低还款额
    for (final debt in debts) {
      final payment = min(debt.minimumPayment, remaining);
      if (payment > 0) {
        plan.add(PaymentPlanItem(
          debtId: debt.id,
          debtName: debt.name,
          paymentAmount: payment,
          priority: debt.isHighInterest ? 1 : 2,
          reason: '最低还款额',
        ));
        remaining -= payment;
      }
    }

    // 2. 剩余资金优先还高息债务
    if (remaining > 0) {
      final highInterestDebts = debts.where((d) => d.isHighInterest).toList();
      for (final debt in highInterestDebts) {
        final extraPayment = min(
          debt.remainingAmount - debt.minimumPayment,
          remaining,
        );
        if (extraPayment > 0) {
          // 找到已有的计划项并增加金额
          final existingIndex = plan.indexWhere((p) => p.debtId == debt.id);
          if (existingIndex >= 0) {
            final existing = plan[existingIndex];
            plan[existingIndex] = PaymentPlanItem(
              debtId: debt.id,
              debtName: debt.name,
              paymentAmount: existing.paymentAmount + extraPayment,
              priority: 1,
              reason: '优先偿还高息债务',
            );
          }
          remaining -= extraPayment;
        }
      }
    }

    plan.sort((a, b) => a.priority.compareTo(b.priority));
    return plan;
  }

  SnowballPlan _generatePaymentPlan(
    List<DebtItem> sortedDebts,
    double monthlyBudget,
    String priorityReason,
  ) {
    final payments = <PaymentPlanItem>[];
    var totalMonths = 0;
    double totalInterestSaved = 0;

    var priority = 1;
    for (final debt in sortedDebts) {
      payments.add(PaymentPlanItem(
        debtId: debt.id,
        debtName: debt.name,
        paymentAmount: debt.minimumPayment,
        priority: priority++,
        reason: priorityReason,
      ));
    }

    // 简化计算：假设持续还款
    final totalDebt = sortedDebts.fold(0.0, (sum, d) => sum + d.remainingAmount);
    totalMonths = (totalDebt / monthlyBudget).ceil();

    return SnowballPlan(
      monthlyPayments: payments,
      totalMonths: totalMonths,
      totalInterestSaved: totalInterestSaved,
      estimatedPayoffDate: DateTime.now().add(Duration(days: totalMonths * 30)),
    );
  }

  DebtHealthLevel _calculateHealthLevel(
    double debtToIncomeRatio,
    List<DebtItem> debts,
  ) {
    if (debts.isEmpty) return DebtHealthLevel.healthy;

    // 基于债务收入比判断
    if (debtToIncomeRatio <= 0.2) return DebtHealthLevel.healthy;
    if (debtToIncomeRatio <= 0.3) return DebtHealthLevel.mild;
    if (debtToIncomeRatio <= 0.4) return DebtHealthLevel.moderate;
    if (debtToIncomeRatio <= 0.5) return DebtHealthLevel.severe;
    return DebtHealthLevel.critical;
  }

  List<String> _generateRecommendations(
    DebtHealthLevel level,
    List<DebtItem> debts,
  ) {
    final recommendations = <String>[];

    // 高息债务警告
    final highInterestDebts = debts.where((d) => d.isHighInterest).toList();
    if (highInterestDebts.isNotEmpty) {
      recommendations.add(
        '您有${highInterestDebts.length}笔高息债务，建议优先偿还以减少利息支出',
      );
    }

    // 即将到期提醒
    final upcomingDue = debts.where((d) =>
        d.dueDate != null &&
        d.dueDate!.difference(DateTime.now()).inDays <= 7).toList();
    if (upcomingDue.isNotEmpty) {
      recommendations.add('有${upcomingDue.length}笔债务即将到期，请确保按时还款');
    }

    // 根据健康等级给出建议
    switch (level) {
      case DebtHealthLevel.healthy:
        recommendations.add('您的债务管理良好，继续保持！');
        break;
      case DebtHealthLevel.mild:
        recommendations.add('建议制定还款计划，避免债务累积');
        break;
      case DebtHealthLevel.moderate:
        recommendations.add('建议减少非必要支出，增加还款额度');
        break;
      case DebtHealthLevel.severe:
        recommendations.add('建议考虑债务整合或与债权人协商还款计划');
        break;
      case DebtHealthLevel.critical:
        recommendations.add('建议寻求专业财务顾问帮助');
        break;
    }

    return recommendations;
  }
}
