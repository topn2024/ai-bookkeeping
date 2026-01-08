import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart';
import 'vault_repository.dart';
import 'budget_money_age_integration.dart';
import 'wants_vs_needs_classifier.dart';

/// 拦截决策
enum InterceptionDecision {
  /// 允许（无风险）
  allow,

  /// 警告（低风险，提醒用户）
  warn,

  /// 建议延迟（中风险）
  suggestDelay,

  /// 强烈建议取消（高风险）
  stronglyDissuade,
}

extension InterceptionDecisionExtension on InterceptionDecision {
  String get displayName {
    switch (this) {
      case InterceptionDecision.allow:
        return '允许';
      case InterceptionDecision.warn:
        return '警告';
      case InterceptionDecision.suggestDelay:
        return '建议延迟';
      case InterceptionDecision.stronglyDissuade:
        return '强烈建议取消';
    }
  }

  bool get shouldIntercept =>
      this != InterceptionDecision.allow;
}

/// 拦截原因
class InterceptionReason {
  final String code;
  final String title;
  final String description;
  final double severity; // 0-1，严重程度

  const InterceptionReason({
    required this.code,
    required this.title,
    required this.description,
    required this.severity,
  });
}

/// 拦截结果
class InterceptionResult {
  final InterceptionDecision decision;
  final List<InterceptionReason> reasons;
  final List<String> suggestions;
  final double riskScore; // 0-100
  final WaitingSuggestion? waitingSuggestion;

  const InterceptionResult({
    required this.decision,
    required this.reasons,
    required this.suggestions,
    required this.riskScore,
    this.waitingSuggestion,
  });

  factory InterceptionResult.allow() {
    return const InterceptionResult(
      decision: InterceptionDecision.allow,
      reasons: [],
      suggestions: [],
      riskScore: 0,
    );
  }

  bool get shouldIntercept => decision.shouldIntercept;
  String get primaryReason =>
      reasons.isNotEmpty ? reasons.first.title : '';
}

/// 等待建议
class WaitingSuggestion {
  final Duration suggestedWait;
  final String reason;
  final double expectedSavingsRate; // 预期节省率（如24小时后20%的人会取消）

  const WaitingSuggestion({
    required this.suggestedWait,
    required this.reason,
    required this.expectedSavingsRate,
  });
}

/// 拦截配置
class InterceptionConfig {
  final bool enabled;
  final double lowBalanceThreshold; // 小金库余额警戒线（百分比）
  final double largeExpenseThreshold; // 大额消费阈值（金额）
  final double largeExpensePercentage; // 大额消费阈值（占月收入比例）
  final int cooldownMinutes; // 冷静期（分钟）
  final bool enableMoneyAgeWarning; // 是否启用钱龄警告
  final int moneyAgeDangerThreshold; // 钱龄危险阈值（天）
  final bool enableLateNightWarning; // 是否启用深夜消费警告
  final int lateNightStartHour; // 深夜开始时间
  final int lateNightEndHour; // 深夜结束时间
  final bool enableBudgetPortionWarning; // 是否启用预算占比警告
  final double budgetPortionThreshold; // 消费占剩余预算比例阈值
  final bool enableEarlyMonthWarning; // 是否启用月初大额消费警告
  final int earlyMonthDays; // 月初天数
  final double earlyMonthThreshold; // 月初大额消费占预算比例阈值
  final bool enableOptionalExpenseWarning; // 是否启用可选消费警告
  final double optionalExpenseThreshold; // 可选消费提醒金额阈值

  const InterceptionConfig({
    this.enabled = true,
    this.lowBalanceThreshold = 0.8, // 80%使用率
    this.largeExpenseThreshold = 500,
    this.largeExpensePercentage = 0.1, // 月收入的10%
    this.cooldownMinutes = 30,
    this.enableMoneyAgeWarning = true,
    this.moneyAgeDangerThreshold = 14,
    this.enableLateNightWarning = true,
    this.lateNightStartHour = 23,
    this.lateNightEndHour = 6,
    this.enableBudgetPortionWarning = true,
    this.budgetPortionThreshold = 0.5, // 占剩余预算50%
    this.enableEarlyMonthWarning = true,
    this.earlyMonthDays = 7,
    this.earlyMonthThreshold = 0.3, // 占月预算30%
    this.enableOptionalExpenseWarning = true,
    this.optionalExpenseThreshold = 200, // 200元以上的可选消费
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled ? 1 : 0,
      'lowBalanceThreshold': lowBalanceThreshold,
      'largeExpenseThreshold': largeExpenseThreshold,
      'largeExpensePercentage': largeExpensePercentage,
      'cooldownMinutes': cooldownMinutes,
      'enableMoneyAgeWarning': enableMoneyAgeWarning ? 1 : 0,
      'moneyAgeDangerThreshold': moneyAgeDangerThreshold,
      'enableLateNightWarning': enableLateNightWarning ? 1 : 0,
      'lateNightStartHour': lateNightStartHour,
      'lateNightEndHour': lateNightEndHour,
      'enableBudgetPortionWarning': enableBudgetPortionWarning ? 1 : 0,
      'budgetPortionThreshold': budgetPortionThreshold,
      'enableEarlyMonthWarning': enableEarlyMonthWarning ? 1 : 0,
      'earlyMonthDays': earlyMonthDays,
      'earlyMonthThreshold': earlyMonthThreshold,
      'enableOptionalExpenseWarning': enableOptionalExpenseWarning ? 1 : 0,
      'optionalExpenseThreshold': optionalExpenseThreshold,
    };
  }

  factory InterceptionConfig.fromMap(Map<String, dynamic> map) {
    return InterceptionConfig(
      enabled: map['enabled'] == 1,
      lowBalanceThreshold:
          (map['lowBalanceThreshold'] as num?)?.toDouble() ?? 0.8,
      largeExpenseThreshold:
          (map['largeExpenseThreshold'] as num?)?.toDouble() ?? 500,
      largeExpensePercentage:
          (map['largeExpensePercentage'] as num?)?.toDouble() ?? 0.1,
      cooldownMinutes: map['cooldownMinutes'] as int? ?? 30,
      enableMoneyAgeWarning: map['enableMoneyAgeWarning'] != 0,
      moneyAgeDangerThreshold: map['moneyAgeDangerThreshold'] as int? ?? 14,
      enableLateNightWarning: map['enableLateNightWarning'] != 0,
      lateNightStartHour: map['lateNightStartHour'] as int? ?? 23,
      lateNightEndHour: map['lateNightEndHour'] as int? ?? 6,
      enableBudgetPortionWarning: map['enableBudgetPortionWarning'] != 0,
      budgetPortionThreshold:
          (map['budgetPortionThreshold'] as num?)?.toDouble() ?? 0.5,
      enableEarlyMonthWarning: map['enableEarlyMonthWarning'] != 0,
      earlyMonthDays: map['earlyMonthDays'] as int? ?? 7,
      earlyMonthThreshold:
          (map['earlyMonthThreshold'] as num?)?.toDouble() ?? 0.3,
      enableOptionalExpenseWarning: map['enableOptionalExpenseWarning'] != 0,
      optionalExpenseThreshold:
          (map['optionalExpenseThreshold'] as num?)?.toDouble() ?? 200,
    );
  }
}

/// 冲动消费拦截服务
///
/// 在低余额、大额消费、异常时间等场景下
/// 触发冲动消费提醒，帮助用户理性消费
class ImpulseSpendingInterceptor {
  final VaultRepository _vaultRepository;
  final BudgetMoneyAgeIntegration _moneyAgeIntegration;
  final Database _db;

  InterceptionConfig _config = const InterceptionConfig();

  // 用户月收入（用于计算大额消费比例）
  double _monthlyIncome = 10000;

  // 最近拦截记录（用于分析）
  final List<InterceptionRecord> _recentInterceptions = [];

  ImpulseSpendingInterceptor(
    this._vaultRepository,
    this._moneyAgeIntegration,
    this._db,
  );

  /// 设置配置
  void setConfig(InterceptionConfig config) {
    _config = config;
  }

  /// 获取当前配置
  InterceptionConfig get config => _config;

  /// 设置月收入
  void setMonthlyIncome(double income) {
    _monthlyIncome = income;
  }

  /// 评估消费是否需要拦截
  Future<InterceptionResult> evaluate({
    required double amount,
    required String? categoryId,
    required String? vaultId,
    String? merchantName,
    DateTime? transactionTime,
  }) async {
    if (!_config.enabled) {
      return InterceptionResult.allow();
    }

    final reasons = <InterceptionReason>[];
    final suggestions = <String>[];
    final now = transactionTime ?? DateTime.now();

    // 1. 检查小金库余额
    if (vaultId != null) {
      final vaultReason = await _checkVaultBalance(vaultId, amount);
      if (vaultReason != null) {
        reasons.add(vaultReason);
        suggestions.add('考虑从其他小金库调拨资金');
      }
    }

    // 2. 检查大额消费
    final largeExpenseReason = _checkLargeExpense(amount);
    if (largeExpenseReason != null) {
      reasons.add(largeExpenseReason);
      suggestions.add('建议等待24小时后再决定');
    }

    // 3. 检查钱龄状态
    if (_config.enableMoneyAgeWarning) {
      final moneyAgeReason = _checkMoneyAge(amount);
      if (moneyAgeReason != null) {
        reasons.add(moneyAgeReason);
        suggestions.add('增加储蓄可以提升钱龄');
      }
    }

    // 4. 检查深夜消费
    if (_config.enableLateNightWarning) {
      final lateNightReason = _checkLateNight(now);
      if (lateNightReason != null) {
        reasons.add(lateNightReason);
        suggestions.add('深夜消费决策可能受疲劳影响');
      }
    }

    // 5. 检查消费频率
    final frequencyReason = await _checkSpendingFrequency(categoryId);
    if (frequencyReason != null) {
      reasons.add(frequencyReason);
      suggestions.add('本类目近期消费较频繁');
    }

    // 6. 检查消费占剩余预算比例
    final budgetPortionReason = await _checkBudgetPortion(vaultId, amount);
    if (budgetPortionReason != null) {
      reasons.add(budgetPortionReason);
      suggestions.add('这笔消费占剩余预算比例较高');
    }

    // 7. 检查月初大额消费
    double? monthlyBudget;
    if (vaultId != null) {
      final vault = await _vaultRepository.getById(vaultId);
      monthlyBudget = vault?.allocatedAmount;
    }
    final earlyMonthReason = _checkEarlyMonthLargeExpense(vaultId, amount, monthlyBudget);
    if (earlyMonthReason != null) {
      reasons.add(earlyMonthReason);
      suggestions.add('月初控制大额消费有助于预算管理');
    }

    // 8. 检查可选消费
    final optionalReason = _checkOptionalExpense(categoryId, amount);
    if (optionalReason != null) {
      reasons.add(optionalReason);
      suggestions.add('区分"想要"和"需要"，做出理性决策');
    }

    // 计算风险分数
    final riskScore = _calculateRiskScore(reasons);

    // 确定决策
    final decision = _determineDecision(riskScore, reasons);

    // 生成等待建议
    WaitingSuggestion? waitingSuggestion;
    if (decision == InterceptionDecision.suggestDelay ||
        decision == InterceptionDecision.stronglyDissuade) {
      waitingSuggestion = _generateWaitingSuggestion(riskScore, amount);
    }

    // 记录拦截
    if (decision.shouldIntercept) {
      _recordInterception(
        amount: amount,
        decision: decision,
        reasons: reasons,
      );
    }

    return InterceptionResult(
      decision: decision,
      reasons: reasons,
      suggestions: suggestions,
      riskScore: riskScore,
      waitingSuggestion: waitingSuggestion,
    );
  }

  /// 检查小金库余额
  Future<InterceptionReason?> _checkVaultBalance(
    String vaultId,
    double amount,
  ) async {
    final vault = await _vaultRepository.getById(vaultId);
    if (vault == null) return null;

    // 消费后使用率
    final newSpent = vault.spentAmount + amount;
    final newUsageRate = vault.allocatedAmount > 0
        ? newSpent / vault.allocatedAmount
        : 1.0;

    // 消费后是否超支
    if (newUsageRate > 1.0) {
      return InterceptionReason(
        code: 'VAULT_OVERSPENT',
        title: '${vault.name}将超支',
        description: '这笔消费将导致超支 ¥${(newSpent - vault.allocatedAmount).toStringAsFixed(2)}',
        severity: 0.9,
      );
    }

    // 消费后余额不足
    if (newUsageRate >= _config.lowBalanceThreshold) {
      return InterceptionReason(
        code: 'VAULT_LOW_BALANCE',
        title: '${vault.name}余额不足',
        description: '消费后剩余 ¥${(vault.allocatedAmount - newSpent).toStringAsFixed(2)}，'
            '使用率${(newUsageRate * 100).toStringAsFixed(0)}%',
        severity: 0.7,
      );
    }

    return null;
  }

  /// 检查大额消费
  InterceptionReason? _checkLargeExpense(double amount) {
    // 绝对金额阈值
    if (amount >= _config.largeExpenseThreshold) {
      return InterceptionReason(
        code: 'LARGE_EXPENSE_ABSOLUTE',
        title: '大额消费',
        description: '这笔消费 ¥${amount.toStringAsFixed(2)} 超过设定阈值 ¥${_config.largeExpenseThreshold.toStringAsFixed(0)}',
        severity: 0.6,
      );
    }

    // 相对收入比例阈值
    final percentage = amount / _monthlyIncome;
    if (percentage >= _config.largeExpensePercentage) {
      return InterceptionReason(
        code: 'LARGE_EXPENSE_RELATIVE',
        title: '消费占收入比例较高',
        description: '这笔消费占月收入的${(percentage * 100).toStringAsFixed(1)}%',
        severity: 0.5,
      );
    }

    return null;
  }

  /// 检查钱龄状态
  InterceptionReason? _checkMoneyAge(double amount) {
    final moneyAge = _moneyAgeIntegration.getCurrentMoneyAge();

    if (moneyAge.days < _config.moneyAgeDangerThreshold) {
      // 钱龄处于危险水平
      final impact = _moneyAgeIntegration.predictExpenseImpact(amount);

      return InterceptionReason(
        code: 'MONEY_AGE_DANGER',
        title: '钱龄较低',
        description: '当前钱龄${moneyAge.days}天，这笔消费可能使钱龄降至${impact.projectedAge}天',
        severity: 0.8,
      );
    }

    return null;
  }

  /// 检查深夜消费
  InterceptionReason? _checkLateNight(DateTime time) {
    final hour = time.hour;

    final isLateNight = hour >= _config.lateNightStartHour ||
        hour < _config.lateNightEndHour;

    if (isLateNight) {
      return const InterceptionReason(
        code: 'LATE_NIGHT',
        title: '深夜消费',
        description: '现在是深夜时段，消费决策可能受疲劳影响',
        severity: 0.4,
      );
    }

    return null;
  }

  /// 检查消费频率
  Future<InterceptionReason?> _checkSpendingFrequency(String? categoryId) async {
    if (categoryId == null) return null;

    // 查询最近7天该类目的消费次数
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));

    final count = Sqflite.firstIntValue(await _db.rawQuery('''
      SELECT COUNT(*) FROM transactions
      WHERE categoryId = ? AND type = ? AND date >= ?
    ''', [
      categoryId,
      TransactionType.expense.index,
      weekAgo.millisecondsSinceEpoch,
    ])) ?? 0;

    // 如果一周内消费超过10次
    if (count >= 10) {
      return InterceptionReason(
        code: 'HIGH_FREQUENCY',
        title: '消费频繁',
        description: '本周该类目已消费$count次',
        severity: 0.3,
      );
    }

    return null;
  }

  /// 检查消费占剩余预算比例
  Future<InterceptionReason?> _checkBudgetPortion(
    String? vaultId,
    double amount,
  ) async {
    if (!_config.enableBudgetPortionWarning || vaultId == null) return null;

    final vault = await _vaultRepository.getById(vaultId);
    if (vault == null) return null;

    final remaining = vault.allocatedAmount - vault.spentAmount;
    if (remaining <= 0 || remaining <= 100) return null; // 余额太少则跳过

    final portion = amount / remaining;

    if (portion > _config.budgetPortionThreshold) {
      return InterceptionReason(
        code: 'LARGE_BUDGET_PORTION',
        title: '消费占比较高',
        description: '这笔消费将用掉${vault.name}剩余预算的${(portion * 100).toStringAsFixed(0)}%',
        severity: 0.5,
      );
    }

    return null;
  }

  /// 检查月初大额消费
  InterceptionReason? _checkEarlyMonthLargeExpense(
    String? vaultId,
    double amount,
    double? monthlyBudget,
  ) {
    if (!_config.enableEarlyMonthWarning) return null;

    final dayOfMonth = DateTime.now().day;
    if (dayOfMonth > _config.earlyMonthDays) return null;

    // 如果有月预算，检查占比；否则检查绝对金额
    final budget = monthlyBudget ?? _monthlyIncome;
    final portion = amount / budget;

    if (portion > _config.earlyMonthThreshold) {
      return InterceptionReason(
        code: 'EARLY_MONTH_LARGE',
        title: '月初大额消费',
        description: '月初大额消费可能影响本月预算控制（占预算${(portion * 100).toStringAsFixed(0)}%）',
        severity: 0.5,
      );
    }

    return null;
  }

  /// 检查可选消费
  InterceptionReason? _checkOptionalExpense(
    String? categoryId,
    double amount,
  ) {
    if (!_config.enableOptionalExpenseWarning) return null;
    if (amount < _config.optionalExpenseThreshold) return null;

    // 使用 WantsVsNeedsClassifier 判断消费必要性
    final necessity = WantsVsNeedsClassifier.classifyByCategory(categoryId ?? '');

    if (necessity == SpendingNecessity.want ||
        necessity == SpendingNecessity.waste) {
      return InterceptionReason(
        code: 'OPTIONAL_EXPENSE',
        title: '可选消费',
        description: '这是一笔${necessity == SpendingNecessity.waste ? "非必要" : "可选"}消费，考虑是否真的需要？',
        severity: necessity == SpendingNecessity.waste ? 0.6 : 0.3,
      );
    }

    return null;
  }

  /// 计算风险分数
  double _calculateRiskScore(List<InterceptionReason> reasons) {
    if (reasons.isEmpty) return 0;

    // 加权平均
    double totalSeverity = 0;
    for (final reason in reasons) {
      totalSeverity += reason.severity;
    }

    // 多个风险因素叠加时，风险更高
    final multiplier = 1 + (reasons.length - 1) * 0.2;

    return (totalSeverity / reasons.length * 100 * multiplier)
        .clamp(0, 100);
  }

  /// 确定拦截决策
  InterceptionDecision _determineDecision(
    double riskScore,
    List<InterceptionReason> reasons,
  ) {
    // 有超支风险直接强烈建议取消
    if (reasons.any((r) => r.code == 'VAULT_OVERSPENT')) {
      return InterceptionDecision.stronglyDissuade;
    }

    if (riskScore >= 70) {
      return InterceptionDecision.stronglyDissuade;
    } else if (riskScore >= 50) {
      return InterceptionDecision.suggestDelay;
    } else if (riskScore >= 30) {
      return InterceptionDecision.warn;
    } else {
      return InterceptionDecision.allow;
    }
  }

  /// 生成等待建议
  WaitingSuggestion _generateWaitingSuggestion(
    double riskScore,
    double amount,
  ) {
    Duration suggestedWait;
    double expectedSavingsRate;
    String reason;

    if (riskScore >= 70) {
      suggestedWait = const Duration(hours: 48);
      expectedSavingsRate = 0.4; // 40%的人会取消
      reason = '强烈建议等待48小时后再决定';
    } else if (amount >= 1000) {
      suggestedWait = const Duration(hours: 24);
      expectedSavingsRate = 0.3;
      reason = '大额消费建议等待24小时';
    } else {
      suggestedWait = Duration(minutes: _config.cooldownMinutes);
      expectedSavingsRate = 0.2;
      reason = '建议冷静${_config.cooldownMinutes}分钟后再决定';
    }

    return WaitingSuggestion(
      suggestedWait: suggestedWait,
      reason: reason,
      expectedSavingsRate: expectedSavingsRate,
    );
  }

  /// 记录拦截
  void _recordInterception({
    required double amount,
    required InterceptionDecision decision,
    required List<InterceptionReason> reasons,
  }) {
    _recentInterceptions.add(InterceptionRecord(
      timestamp: DateTime.now(),
      amount: amount,
      decision: decision,
      reasonCodes: reasons.map((r) => r.code).toList(),
    ));

    // 只保留最近100条记录
    if (_recentInterceptions.length > 100) {
      _recentInterceptions.removeAt(0);
    }
  }

  /// 用户确认继续消费
  Future<void> confirmProceed({
    required String transactionId,
    required InterceptionDecision originalDecision,
  }) async {
    // 记录用户忽略了警告
    await _db.insert('interception_overrides', {
      'id': '${DateTime.now().millisecondsSinceEpoch}_$transactionId',
      'transactionId': transactionId,
      'decision': originalDecision.index,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 用户接受建议取消消费
  Future<void> confirmCancel({
    required double amount,
    required InterceptionDecision decision,
  }) async {
    // 记录节省的金额
    await _db.insert('savings_from_interception', {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': amount,
      'decision': decision.index,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// 获取拦截统计
  Future<InterceptionStats> getStats({int days = 30}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    // 拦截次数
    final totalInterceptions = _recentInterceptions.length;

    // 用户忽略警告的次数
    final overrides = Sqflite.firstIntValue(await _db.rawQuery('''
      SELECT COUNT(*) FROM interception_overrides WHERE timestamp >= ?
    ''', [since])) ?? 0;

    // 因拦截节省的金额
    final savingsResult = await _db.rawQuery('''
      SELECT SUM(amount) as total FROM savings_from_interception
      WHERE timestamp >= ?
    ''', [since]);
    final totalSavings =
        (savingsResult.first['total'] as num?)?.toDouble() ?? 0;

    return InterceptionStats(
      totalInterceptions: totalInterceptions,
      overrideCount: overrides,
      acceptCount: totalInterceptions - overrides,
      totalSavings: totalSavings,
      acceptanceRate: totalInterceptions > 0
          ? (totalInterceptions - overrides) / totalInterceptions
          : 0,
    );
  }

  /// 获取最近拦截记录
  List<InterceptionRecord> getRecentInterceptions({int limit = 10}) {
    final sorted = List<InterceptionRecord>.from(_recentInterceptions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return sorted.take(limit).toList();
  }
}

/// 拦截记录
class InterceptionRecord {
  final DateTime timestamp;
  final double amount;
  final InterceptionDecision decision;
  final List<String> reasonCodes;

  const InterceptionRecord({
    required this.timestamp,
    required this.amount,
    required this.decision,
    required this.reasonCodes,
  });
}

/// 拦截统计
class InterceptionStats {
  final int totalInterceptions;
  final int overrideCount;
  final int acceptCount;
  final double totalSavings;
  final double acceptanceRate;

  const InterceptionStats({
    required this.totalInterceptions,
    required this.overrideCount,
    required this.acceptCount,
    required this.totalSavings,
    required this.acceptanceRate,
  });
}
