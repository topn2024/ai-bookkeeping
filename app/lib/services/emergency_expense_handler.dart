import 'dart:math' as math;
import 'database_service.dart';

/// 突发支出类型
enum EmergencyType {
  /// 医疗急症
  medical,

  /// 车辆维修
  carRepair,

  /// 家电损坏
  applianceBreakdown,

  /// 房屋维修
  homeRepair,

  /// 工作相关
  workRelated,

  /// 家庭紧急事务
  familyEmergency,

  /// 意外损失
  accidentalLoss,

  /// 其他突发
  other,
}

extension EmergencyTypeExtension on EmergencyType {
  String get displayName {
    switch (this) {
      case EmergencyType.medical:
        return '医疗急症';
      case EmergencyType.carRepair:
        return '车辆维修';
      case EmergencyType.applianceBreakdown:
        return '家电损坏';
      case EmergencyType.homeRepair:
        return '房屋维修';
      case EmergencyType.workRelated:
        return '工作相关';
      case EmergencyType.familyEmergency:
        return '家庭紧急';
      case EmergencyType.accidentalLoss:
        return '意外损失';
      case EmergencyType.other:
        return '其他突发';
    }
  }

  String get icon {
    switch (this) {
      case EmergencyType.medical:
        return '🏥';
      case EmergencyType.carRepair:
        return '🚗';
      case EmergencyType.applianceBreakdown:
        return '📺';
      case EmergencyType.homeRepair:
        return '🏠';
      case EmergencyType.workRelated:
        return '💼';
      case EmergencyType.familyEmergency:
        return '👨‍👩‍👧';
      case EmergencyType.accidentalLoss:
        return '⚠️';
      case EmergencyType.other:
        return '📋';
    }
  }
}

/// 资金来源优先级
enum FundingSource {
  /// 应急金
  emergencyFund,

  /// 小金库调配
  vaultReallocation,

  /// 本月预算压缩
  budgetCompression,

  /// 分期付款
  installment,

  /// 临时借款
  temporaryLoan,
}

extension FundingSourceExtension on FundingSource {
  String get displayName {
    switch (this) {
      case FundingSource.emergencyFund:
        return '应急金';
      case FundingSource.vaultReallocation:
        return '小金库调配';
      case FundingSource.budgetCompression:
        return '预算压缩';
      case FundingSource.installment:
        return '分期付款';
      case FundingSource.temporaryLoan:
        return '临时借款';
    }
  }

  int get priority {
    switch (this) {
      case FundingSource.emergencyFund:
        return 1;
      case FundingSource.vaultReallocation:
        return 2;
      case FundingSource.budgetCompression:
        return 3;
      case FundingSource.installment:
        return 4;
      case FundingSource.temporaryLoan:
        return 5;
    }
  }
}

/// 突发支出记录
class EmergencyExpense {
  final String id;
  final EmergencyType type;
  final double amount;
  final String description;
  final DateTime occurredAt;
  final List<FundingAllocation> fundingPlan;
  final bool isResolved;
  final DateTime? resolvedAt;

  const EmergencyExpense({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.occurredAt,
    required this.fundingPlan,
    this.isResolved = false,
    this.resolvedAt,
  });

  double get fundedAmount =>
      fundingPlan.fold(0.0, (sum, f) => sum + f.amount);
  double get remainingAmount => amount - fundedAmount;
  bool get isFullyFunded => remainingAmount <= 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.index,
        'amount': amount,
        'description': description,
        'occurredAt': occurredAt.millisecondsSinceEpoch,
        'isResolved': isResolved ? 1 : 0,
        'resolvedAt': resolvedAt?.millisecondsSinceEpoch,
      };

  factory EmergencyExpense.fromMap(Map<String, dynamic> map,
      [List<FundingAllocation>? funding]) => EmergencyExpense(
        id: map['id'] as String,
        type: EmergencyType.values[map['type'] as int],
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(map['occurredAt'] as int),
        fundingPlan: funding ?? [],
        isResolved: (map['isResolved'] as int?) != 0,
        resolvedAt: map['resolvedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['resolvedAt'] as int)
            : null,
      );
}

/// 资金分配
class FundingAllocation {
  final String id;
  final String emergencyId;
  final FundingSource source;
  final String? sourceId; // 小金库ID等
  final double amount;
  final DateTime allocatedAt;

  const FundingAllocation({
    required this.id,
    required this.emergencyId,
    required this.source,
    this.sourceId,
    required this.amount,
    required this.allocatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'emergencyId': emergencyId,
        'source': source.index,
        'sourceId': sourceId,
        'amount': amount,
        'allocatedAt': allocatedAt.millisecondsSinceEpoch,
      };

  factory FundingAllocation.fromMap(Map<String, dynamic> map) =>
      FundingAllocation(
        id: map['id'] as String,
        emergencyId: map['emergencyId'] as String,
        source: FundingSource.values[map['source'] as int],
        sourceId: map['sourceId'] as String?,
        amount: (map['amount'] as num).toDouble(),
        allocatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['allocatedAt'] as int),
      );
}

/// 资金解决方案
class FundingSolution {
  final FundingSource source;
  final String sourceName;
  final double availableAmount;
  final double suggestedAmount;
  final String? sourceId;
  final String description;
  final int priority;

  const FundingSolution({
    required this.source,
    required this.sourceName,
    required this.availableAmount,
    required this.suggestedAmount,
    this.sourceId,
    required this.description,
    required this.priority,
  });
}

/// 预算恢复计划
class BudgetRecoveryPlan {
  final double totalToRecover;
  final int recoveryMonths;
  final double monthlyRecoveryAmount;
  final List<Map<String, dynamic>> monthlyPlan;
  final String suggestion;

  const BudgetRecoveryPlan({
    required this.totalToRecover,
    required this.recoveryMonths,
    required this.monthlyRecoveryAmount,
    required this.monthlyPlan,
    required this.suggestion,
  });
}

/// 突发支出处理服务
///
/// 帮助用户应对突发支出：
/// - 智能资金来源建议
/// - 自动调配小金库
/// - 预算恢复计划
/// - 应急金补充建议
class EmergencyExpenseHandler {
  final DatabaseService _db;

  EmergencyExpenseHandler(this._db);

  /// 创建突发支出记录
  Future<EmergencyExpense> createEmergencyExpense({
    required EmergencyType type,
    required double amount,
    required String description,
  }) async {
    final expense = EmergencyExpense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      amount: amount,
      description: description,
      occurredAt: DateTime.now(),
      fundingPlan: [],
    );

    await _db.rawInsert('''
      INSERT INTO emergency_expenses
      (id, type, amount, description, occurredAt, isResolved)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      expense.id,
      expense.type.index,
      expense.amount,
      expense.description,
      expense.occurredAt.millisecondsSinceEpoch,
      0,
    ]);

    return expense;
  }

  /// 获取资金解决方案
  Future<List<FundingSolution>> getFundingSolutions(double amount) async {
    final solutions = <FundingSolution>[];
    double remaining = amount;

    // 1. 检查应急金
    final emergencyFund = await _getEmergencyFundBalance();
    if (emergencyFund > 0) {
      final useAmount = math.min(emergencyFund, remaining);
      solutions.add(FundingSolution(
        source: FundingSource.emergencyFund,
        sourceName: '应急金账户',
        availableAmount: emergencyFund,
        suggestedAmount: useAmount,
        description: '从应急金账户支出，这是应急金的正确用途',
        priority: 1,
      ));
      remaining -= useAmount;
    }

    // 2. 检查可调配的小金库
    if (remaining > 0) {
      final vaults = await _getReallocationCandidates();
      for (final vault in vaults) {
        if (remaining <= 0) break;

        final vaultId = vault['id'] as String;
        final vaultName = vault['name'] as String;
        final available = (vault['available'] as num).toDouble();

        if (available > 0) {
          final useAmount = math.min(available * 0.5, remaining); // 最多调配50%
          solutions.add(FundingSolution(
            source: FundingSource.vaultReallocation,
            sourceName: vaultName,
            availableAmount: available,
            suggestedAmount: useAmount,
            sourceId: vaultId,
            description: '从"$vaultName"临时调配，后续可补充',
            priority: 2,
          ));
          remaining -= useAmount;
        }
      }
    }

    // 3. 预算压缩建议
    if (remaining > 0) {
      final compressible = await _getCompressibleBudget();
      if (compressible > 0) {
        final useAmount = math.min(compressible * 0.3, remaining);
        solutions.add(FundingSolution(
          source: FundingSource.budgetCompression,
          sourceName: '本月可压缩预算',
          availableAmount: compressible,
          suggestedAmount: useAmount,
          description: '压缩本月非必要支出，暂时节省开支',
          priority: 3,
        ));
        remaining -= useAmount;
      }
    }

    // 4. 分期建议（大额支出）
    if (remaining > 0 && amount > 1000) {
      solutions.add(FundingSolution(
        source: FundingSource.installment,
        sourceName: '分期付款',
        availableAmount: remaining,
        suggestedAmount: remaining,
        description: '如商家支持，可考虑0利息分期',
        priority: 4,
      ));
    }

    // 5. 临时借款（最后手段）
    if (remaining > 0) {
      solutions.add(FundingSolution(
        source: FundingSource.temporaryLoan,
        sourceName: '临时借款',
        availableAmount: remaining,
        suggestedAmount: remaining,
        description: '向亲友借款或信用卡临时周转',
        priority: 5,
      ));
    }

    return solutions;
  }

  /// 执行资金分配
  Future<FundingAllocation> allocateFunding({
    required String emergencyId,
    required FundingSource source,
    required double amount,
    String? sourceId,
  }) async {
    final allocation = FundingAllocation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      emergencyId: emergencyId,
      source: source,
      sourceId: sourceId,
      amount: amount,
      allocatedAt: DateTime.now(),
    );

    await _db.rawInsert('''
      INSERT INTO funding_allocations
      (id, emergencyId, source, sourceId, amount, allocatedAt)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      allocation.id,
      allocation.emergencyId,
      allocation.source.index,
      allocation.sourceId,
      allocation.amount,
      allocation.allocatedAt.millisecondsSinceEpoch,
    ]);

    // 如果是从应急金或小金库扣除，需要更新余额
    if (source == FundingSource.emergencyFund) {
      await _deductFromEmergencyFund(amount);
    } else if (source == FundingSource.vaultReallocation && sourceId != null) {
      await _deductFromVault(sourceId, amount);
    }

    return allocation;
  }

  /// 标记突发支出已解决
  Future<void> resolveEmergency(String emergencyId) async {
    await _db.rawUpdate('''
      UPDATE emergency_expenses
      SET isResolved = 1, resolvedAt = ?
      WHERE id = ?
    ''', [DateTime.now().millisecondsSinceEpoch, emergencyId]);
  }

  /// 获取突发支出详情（含资金分配）
  Future<EmergencyExpense?> getEmergencyExpense(String id) async {
    final expenseResults = await _db.rawQuery('''
      SELECT * FROM emergency_expenses WHERE id = ?
    ''', [id]);

    if (expenseResults.isEmpty) return null;

    final fundingResults = await _db.rawQuery('''
      SELECT * FROM funding_allocations WHERE emergencyId = ?
    ''', [id]);

    final funding =
        fundingResults.map((m) => FundingAllocation.fromMap(m)).toList();

    return EmergencyExpense.fromMap(expenseResults.first, funding);
  }

  /// 获取未解决的突发支出
  Future<List<EmergencyExpense>> getPendingEmergencies() async {
    final results = await _db.rawQuery('''
      SELECT * FROM emergency_expenses WHERE isResolved = 0
      ORDER BY occurredAt DESC
    ''');

    final emergencies = <EmergencyExpense>[];
    for (final row in results) {
      final id = row['id'] as String;
      final fundingResults = await _db.rawQuery('''
        SELECT * FROM funding_allocations WHERE emergencyId = ?
      ''', [id]);

      final funding =
          fundingResults.map((m) => FundingAllocation.fromMap(m)).toList();
      emergencies.add(EmergencyExpense.fromMap(row, funding));
    }

    return emergencies;
  }

  /// 生成预算恢复计划
  Future<BudgetRecoveryPlan> generateRecoveryPlan(double amount) async {
    // 获取月均收入
    final avgIncome = await _getAverageMonthlyIncome();
    final avgExpense = await _getAverageMonthlyExpense();
    final monthlySurplus = avgIncome - avgExpense;

    // 计算恢复时间
    int recoveryMonths;
    double monthlyRecovery;

    if (monthlySurplus <= 0) {
      // 收支紧张，建议更长的恢复期
      recoveryMonths = 12;
      monthlyRecovery = amount / recoveryMonths;
    } else {
      // 使用盈余的50%进行恢复
      monthlyRecovery = monthlySurplus * 0.5;
      recoveryMonths = (amount / monthlyRecovery).ceil();
      recoveryMonths = recoveryMonths.clamp(3, 24);
      monthlyRecovery = amount / recoveryMonths;
    }

    // 生成月度计划
    final monthlyPlan = <Map<String, dynamic>>[];
    final now = DateTime.now();
    double remaining = amount;

    for (int i = 0; i < recoveryMonths; i++) {
      final month = DateTime(now.year, now.month + i + 1, 1);
      final payment = math.min(monthlyRecovery, remaining);
      remaining -= payment;

      monthlyPlan.add({
        'month': '${month.year}年${month.month}月',
        'amount': payment,
        'remaining': remaining,
      });

      if (remaining <= 0) break;
    }

    // 生成建议
    String suggestion;
    if (recoveryMonths <= 3) {
      suggestion = '突发支出金额适中，$recoveryMonths个月内可以恢复正常';
    } else if (recoveryMonths <= 6) {
      suggestion = '建议在$recoveryMonths个月内逐步恢复，同时考虑增加应急金储备';
    } else {
      suggestion = '恢复期较长，建议同时开源节流，加快恢复进度';
    }

    return BudgetRecoveryPlan(
      totalToRecover: amount,
      recoveryMonths: recoveryMonths,
      monthlyRecoveryAmount: monthlyRecovery,
      monthlyPlan: monthlyPlan,
      suggestion: suggestion,
    );
  }

  /// 获取应急金补充建议
  Future<Map<String, dynamic>> getEmergencyFundAdvice() async {
    final currentBalance = await _getEmergencyFundBalance();
    final monthlyExpense = await _getAverageMonthlyExpense();

    // 建议应急金为3-6个月支出
    final recommendedMin = monthlyExpense * 3;
    final recommendedMax = monthlyExpense * 6;

    String status;
    String advice;

    if (currentBalance >= recommendedMax) {
      status = 'excellent';
      advice = '应急金储备充足，可以考虑将多余部分用于投资';
    } else if (currentBalance >= recommendedMin) {
      status = 'good';
      advice = '应急金储备良好，继续保持';
    } else if (currentBalance > 0) {
      status = 'insufficient';
      advice = '建议继续增加应急金储备至${recommendedMin.toStringAsFixed(0)}元';
    } else {
      status = 'none';
      advice = '建议立即开始建立应急金，目标${recommendedMin.toStringAsFixed(0)}元';
    }

    return {
      'currentBalance': currentBalance,
      'recommendedMin': recommendedMin,
      'recommendedMax': recommendedMax,
      'status': status,
      'advice': advice,
      'monthsOfExpense': currentBalance / monthlyExpense,
    };
  }

  /// 获取突发支出统计
  Future<Map<String, dynamic>> getEmergencyStats({int months = 12}) async {
    final since = DateTime.now()
        .subtract(Duration(days: months * 30))
        .millisecondsSinceEpoch;

    // 总突发支出
    final totalResult = await _db.rawQuery('''
      SELECT COUNT(*) as count, SUM(amount) as total
      FROM emergency_expenses
      WHERE occurredAt >= ?
    ''', [since]);

    final count = (totalResult.first['count'] as int?) ?? 0;
    final total = (totalResult.first['total'] as num?)?.toDouble() ?? 0;

    // 按类型统计
    final byTypeResult = await _db.rawQuery('''
      SELECT type, COUNT(*) as count, SUM(amount) as total
      FROM emergency_expenses
      WHERE occurredAt >= ?
      GROUP BY type
    ''', [since]);

    final byType = <EmergencyType, Map<String, dynamic>>{};
    for (final row in byTypeResult) {
      final type = EmergencyType.values[row['type'] as int];
      byType[type] = {
        'count': row['count'] as int,
        'total': (row['total'] as num).toDouble(),
      };
    }

    return {
      'totalCount': count,
      'totalAmount': total,
      'avgAmount': count > 0 ? total / count : 0,
      'byType': byType,
      'monthsCovered': months,
    };
  }

  // 私有方法

  Future<double> _getEmergencyFundBalance() async {
    final result = await _db.rawQuery('''
      SELECT balance FROM emergency_fund_goals
      ORDER BY updatedAt DESC
      LIMIT 1
    ''');

    return (result.isNotEmpty)
        ? (result.first['balance'] as num?)?.toDouble() ?? 0
        : 0;
  }

  Future<List<Map<String, dynamic>>> _getReallocationCandidates() async {
    // 获取有余额且非必要的小金库
    return await _db.rawQuery('''
      SELECT id, name, (amount - COALESCE(spent, 0)) as available
      FROM budget_vaults v
      LEFT JOIN (
        SELECT vaultId, SUM(amount) as spent
        FROM transactions
        WHERE date >= ? AND type = 'expense'
        GROUP BY vaultId
      ) t ON v.id = t.vaultId
      WHERE v.isActive = 1 AND v.isEssential = 0
      HAVING available > 0
      ORDER BY available DESC
    ''', [
      DateTime(DateTime.now().year, DateTime.now().month, 1)
          .millisecondsSinceEpoch,
    ]);
  }

  Future<double> _getCompressibleBudget() async {
    // 获取非必要类别的剩余预算
    final result = await _db.rawQuery('''
      SELECT SUM(amount - COALESCE(spent, 0)) as compressible
      FROM budget_vaults v
      LEFT JOIN (
        SELECT vaultId, SUM(amount) as spent
        FROM transactions
        WHERE date >= ? AND type = 'expense'
        GROUP BY vaultId
      ) t ON v.id = t.vaultId
      WHERE v.isActive = 1 AND v.isEssential = 0
    ''', [
      DateTime(DateTime.now().year, DateTime.now().month, 1)
          .millisecondsSinceEpoch,
    ]);

    return (result.first['compressible'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _getAverageMonthlyIncome() async {
    final result = await _db.rawQuery('''
      SELECT AVG(monthly) as avg FROM (
        SELECT strftime('%Y-%m', date/1000, 'unixepoch') as month,
               SUM(amount) as monthly
        FROM transactions
        WHERE type = 'income' AND date >= ?
        GROUP BY month
      )
    ''', [
      DateTime.now()
          .subtract(const Duration(days: 180))
          .millisecondsSinceEpoch,
    ]);

    return (result.first['avg'] as num?)?.toDouble() ?? 0;
  }

  Future<double> _getAverageMonthlyExpense() async {
    final result = await _db.rawQuery('''
      SELECT AVG(monthly) as avg FROM (
        SELECT strftime('%Y-%m', date/1000, 'unixepoch') as month,
               SUM(amount) as monthly
        FROM transactions
        WHERE type = 'expense' AND date >= ?
        GROUP BY month
      )
    ''', [
      DateTime.now()
          .subtract(const Duration(days: 180))
          .millisecondsSinceEpoch,
    ]);

    return (result.first['avg'] as num?)?.toDouble() ?? 0;
  }

  Future<void> _deductFromEmergencyFund(double amount) async {
    await _db.rawUpdate('''
      UPDATE emergency_fund_goals
      SET balance = balance - ?
      WHERE id = (SELECT id FROM emergency_fund_goals ORDER BY updatedAt DESC LIMIT 1)
    ''', [amount]);
  }

  Future<void> _deductFromVault(String vaultId, double amount) async {
    // 记录一笔内部转账或调整
    await _db.rawInsert('''
      INSERT INTO transactions
      (id, amount, type, categoryId, vaultId, date, description)
      VALUES (?, ?, 'transfer_out', 'emergency', ?, ?, ?)
    ''', [
      DateTime.now().millisecondsSinceEpoch.toString(),
      amount,
      vaultId,
      DateTime.now().millisecondsSinceEpoch,
      '突发支出调配',
    ]);
  }
}
