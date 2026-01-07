import 'dart:math' as math;
import 'database_service.dart';

/// 收入类型
enum IncomeType {
  /// 固定工资
  fixedSalary,

  /// 绩效奖金
  performanceBonus,

  /// 自由职业
  freelance,

  /// 兼职收入
  partTime,

  /// 投资收益
  investment,

  /// 其他收入
  other,
}

extension IncomeTypeExtension on IncomeType {
  String get displayName {
    switch (this) {
      case IncomeType.fixedSalary:
        return '固定工资';
      case IncomeType.performanceBonus:
        return '绩效奖金';
      case IncomeType.freelance:
        return '自由职业';
      case IncomeType.partTime:
        return '兼职收入';
      case IncomeType.investment:
        return '投资收益';
      case IncomeType.other:
        return '其他收入';
    }
  }

  /// 是否是可变收入
  bool get isVariable {
    switch (this) {
      case IncomeType.fixedSalary:
        return false;
      case IncomeType.performanceBonus:
      case IncomeType.freelance:
      case IncomeType.partTime:
      case IncomeType.investment:
      case IncomeType.other:
        return true;
    }
  }
}

/// 收入稳定性级别
enum IncomeStability {
  /// 高度稳定
  high,

  /// 中等稳定
  medium,

  /// 低稳定性
  low,

  /// 高度不稳定
  veryLow,
}

extension IncomeStabilityExtension on IncomeStability {
  String get displayName {
    switch (this) {
      case IncomeStability.high:
        return '高度稳定';
      case IncomeStability.medium:
        return '中等稳定';
      case IncomeStability.low:
        return '较不稳定';
      case IncomeStability.veryLow:
        return '高度不稳定';
    }
  }

  /// 建议的应急资金月数
  int get recommendedBufferMonths {
    switch (this) {
      case IncomeStability.high:
        return 3;
      case IncomeStability.medium:
        return 6;
      case IncomeStability.low:
        return 9;
      case IncomeStability.veryLow:
        return 12;
    }
  }

  /// 建议的预算保守系数
  double get budgetConservativeRatio {
    switch (this) {
      case IncomeStability.high:
        return 0.90; // 可使用收入的90%
      case IncomeStability.medium:
        return 0.80;
      case IncomeStability.low:
        return 0.70;
      case IncomeStability.veryLow:
        return 0.60;
    }
  }
}

/// 收入记录
class IncomeRecord {
  final String id;
  final double amount;
  final IncomeType type;
  final DateTime date;
  final String? source;
  final String? note;

  const IncomeRecord({
    required this.id,
    required this.amount,
    required this.type,
    required this.date,
    this.source,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'type': type.index,
        'date': date.millisecondsSinceEpoch,
        'source': source,
        'note': note,
      };

  factory IncomeRecord.fromMap(Map<String, dynamic> map) => IncomeRecord(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        type: IncomeType.values[map['type'] as int],
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        source: map['source'] as String?,
        note: map['note'] as String?,
      );
}

/// 收入分析结果
class IncomeAnalysis {
  final double averageMonthlyIncome;
  final double medianMonthlyIncome;
  final double minMonthlyIncome;
  final double maxMonthlyIncome;
  final double standardDeviation;
  final double coefficientOfVariation; // 变异系数
  final IncomeStability stability;
  final double fixedIncomeRatio; // 固定收入占比
  final double variableIncomeRatio; // 可变收入占比
  final List<MonthlyIncomeSummary> monthlyHistory;

  const IncomeAnalysis({
    required this.averageMonthlyIncome,
    required this.medianMonthlyIncome,
    required this.minMonthlyIncome,
    required this.maxMonthlyIncome,
    required this.standardDeviation,
    required this.coefficientOfVariation,
    required this.stability,
    required this.fixedIncomeRatio,
    required this.variableIncomeRatio,
    required this.monthlyHistory,
  });

  /// 建议的基准收入（用于预算规划）
  double get suggestedBaseIncome {
    // 使用较保守的估计：平均值和最小值的加权平均
    return averageMonthlyIncome * 0.6 + minMonthlyIncome * 0.4;
  }
}

/// 月度收入汇总
class MonthlyIncomeSummary {
  final int year;
  final int month;
  final double totalIncome;
  final double fixedIncome;
  final double variableIncome;
  final Map<IncomeType, double> byType;

  const MonthlyIncomeSummary({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.fixedIncome,
    required this.variableIncome,
    required this.byType,
  });
}

/// 自适应预算建议
class AdaptiveBudgetSuggestion {
  final double baseAmount; // 基准预算
  final double conservativeAmount; // 保守预算
  final double optimisticAmount; // 乐观预算
  final String strategy;
  final List<String> tips;

  const AdaptiveBudgetSuggestion({
    required this.baseAmount,
    required this.conservativeAmount,
    required this.optimisticAmount,
    required this.strategy,
    required this.tips,
  });
}

/// 收入预测
class IncomeForecast {
  final int year;
  final int month;
  final double predictedAmount;
  final double lowerBound; // 95%置信区间下限
  final double upperBound; // 95%置信区间上限
  final double confidence;

  const IncomeForecast({
    required this.year,
    required this.month,
    required this.predictedAmount,
    required this.lowerBound,
    required this.upperBound,
    required this.confidence,
  });
}

/// 收入不稳定适配器
///
/// 帮助收入不稳定的用户（自由职业者、兼职者等）更好地管理财务：
/// - 分析收入稳定性
/// - 自适应预算建议
/// - 收入平滑策略
/// - 应急资金规划
class VariableIncomeAdapter {
  final DatabaseService _db;

  VariableIncomeAdapter(this._db);

  /// 记录收入
  Future<IncomeRecord> recordIncome({
    required double amount,
    required IncomeType type,
    DateTime? date,
    String? source,
    String? note,
  }) async {
    final record = IncomeRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: type,
      date: date ?? DateTime.now(),
      source: source,
      note: note,
    );

    await _db.rawInsert('''
      INSERT INTO income_records (id, amount, type, date, source, note)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      record.id,
      record.amount,
      record.type.index,
      record.date.millisecondsSinceEpoch,
      record.source,
      record.note,
    ]);

    return record;
  }

  /// 分析收入稳定性
  Future<IncomeAnalysis> analyzeIncome({int months = 12}) async {
    final since = DateTime.now()
        .subtract(Duration(days: months * 30))
        .millisecondsSinceEpoch;

    // 获取收入记录
    final results = await _db.rawQuery('''
      SELECT * FROM income_records WHERE date >= ? ORDER BY date ASC
    ''', [since]);

    if (results.isEmpty) {
      return const IncomeAnalysis(
        averageMonthlyIncome: 0,
        medianMonthlyIncome: 0,
        minMonthlyIncome: 0,
        maxMonthlyIncome: 0,
        standardDeviation: 0,
        coefficientOfVariation: 0,
        stability: IncomeStability.veryLow,
        fixedIncomeRatio: 0,
        variableIncomeRatio: 0,
        monthlyHistory: [],
      );
    }

    final records = results.map((m) => IncomeRecord.fromMap(m)).toList();

    // 按月汇总
    final monthlyData = <String, MonthlyIncomeSummary>{};
    double totalFixed = 0;
    double totalVariable = 0;

    for (final record in records) {
      final key = '${record.date.year}-${record.date.month}';
      final isFixed = !record.type.isVariable;

      if (isFixed) {
        totalFixed += record.amount;
      } else {
        totalVariable += record.amount;
      }

      if (!monthlyData.containsKey(key)) {
        monthlyData[key] = MonthlyIncomeSummary(
          year: record.date.year,
          month: record.date.month,
          totalIncome: 0,
          fixedIncome: 0,
          variableIncome: 0,
          byType: {},
        );
      }

      final existing = monthlyData[key]!;
      final byType = Map<IncomeType, double>.from(existing.byType);
      byType[record.type] = (byType[record.type] ?? 0) + record.amount;

      monthlyData[key] = MonthlyIncomeSummary(
        year: existing.year,
        month: existing.month,
        totalIncome: existing.totalIncome + record.amount,
        fixedIncome: existing.fixedIncome + (isFixed ? record.amount : 0),
        variableIncome: existing.variableIncome + (isFixed ? 0 : record.amount),
        byType: byType,
      );
    }

    final monthlyHistory = monthlyData.values.toList()
      ..sort((a, b) {
        final aKey = a.year * 100 + a.month;
        final bKey = b.year * 100 + b.month;
        return aKey.compareTo(bKey);
      });

    // 计算统计数据
    final monthlyIncomes = monthlyHistory.map((m) => m.totalIncome).toList();

    if (monthlyIncomes.isEmpty) {
      return const IncomeAnalysis(
        averageMonthlyIncome: 0,
        medianMonthlyIncome: 0,
        minMonthlyIncome: 0,
        maxMonthlyIncome: 0,
        standardDeviation: 0,
        coefficientOfVariation: 0,
        stability: IncomeStability.veryLow,
        fixedIncomeRatio: 0,
        variableIncomeRatio: 0,
        monthlyHistory: [],
      );
    }

    final average = monthlyIncomes.reduce((a, b) => a + b) / monthlyIncomes.length;
    final sorted = List<double>.from(monthlyIncomes)..sort();
    final median = sorted[sorted.length ~/ 2];
    final min = sorted.first;
    final max = sorted.last;

    // 标准差
    final variance = monthlyIncomes
            .map((x) => math.pow(x - average, 2))
            .reduce((a, b) => a + b) /
        monthlyIncomes.length;
    final stdDev = math.sqrt(variance);

    // 变异系数
    final cv = average > 0 ? stdDev / average : 0.0;

    // 确定稳定性级别
    IncomeStability stability;
    if (cv < 0.1) {
      stability = IncomeStability.high;
    } else if (cv < 0.25) {
      stability = IncomeStability.medium;
    } else if (cv < 0.5) {
      stability = IncomeStability.low;
    } else {
      stability = IncomeStability.veryLow;
    }

    final total = totalFixed + totalVariable;
    final fixedRatio = total > 0 ? totalFixed / total : 0.0;
    final variableRatio = total > 0 ? totalVariable / total : 0.0;

    return IncomeAnalysis(
      averageMonthlyIncome: average,
      medianMonthlyIncome: median,
      minMonthlyIncome: min,
      maxMonthlyIncome: max,
      standardDeviation: stdDev,
      coefficientOfVariation: cv,
      stability: stability,
      fixedIncomeRatio: fixedRatio,
      variableIncomeRatio: variableRatio,
      monthlyHistory: monthlyHistory,
    );
  }

  /// 获取自适应预算建议
  Future<AdaptiveBudgetSuggestion> getAdaptiveBudgetSuggestion({
    String? categoryId,
  }) async {
    final analysis = await analyzeIncome();

    final baseIncome = analysis.suggestedBaseIncome;
    final conservativeRatio = analysis.stability.budgetConservativeRatio;

    // 基准预算：使用建议基准收入
    final baseAmount = baseIncome * conservativeRatio;

    // 保守预算：使用最低收入
    final conservativeAmount = analysis.minMonthlyIncome * 0.8;

    // 乐观预算：使用平均收入
    final optimisticAmount = analysis.averageMonthlyIncome * 0.85;

    // 生成策略建议
    String strategy;
    final tips = <String>[];

    switch (analysis.stability) {
      case IncomeStability.high:
        strategy = '您的收入稳定，可以使用常规预算方式';
        tips.add('建议将收入的20%用于储蓄');
        tips.add('可以考虑固定的投资计划');
        break;
      case IncomeStability.medium:
        strategy = '收入有一定波动，建议使用保守预算';
        tips.add('建议建立3-6个月的应急资金');
        tips.add('预算基于较低收入估计');
        tips.add('高收入月份多存储，低收入月份使用储蓄');
        break;
      case IncomeStability.low:
        strategy = '收入波动较大，建议采用收入平滑策略';
        tips.add('建议建立6-9个月的应急资金');
        tips.add('使用"工资制"：每月给自己固定的"工资"');
        tips.add('超出"工资"的部分存入缓冲账户');
        tips.add('先存后花，控制消费冲动');
        break;
      case IncomeStability.veryLow:
        strategy = '收入高度不稳定，需要特别的财务策略';
        tips.add('建议建立9-12个月的应急资金');
        tips.add('严格执行最低预算');
        tips.add('建立多元收入来源');
        tips.add('考虑寻找部分固定收入');
        tips.add('有钱时多存，没钱时省着花');
        break;
    }

    return AdaptiveBudgetSuggestion(
      baseAmount: baseAmount,
      conservativeAmount: conservativeAmount,
      optimisticAmount: optimisticAmount,
      strategy: strategy,
      tips: tips,
    );
  }

  /// 预测未来收入
  Future<List<IncomeForecast>> forecastIncome({int months = 3}) async {
    final analysis = await analyzeIncome();
    final forecasts = <IncomeForecast>[];

    final now = DateTime.now();

    for (int i = 1; i <= months; i++) {
      final targetDate = DateTime(now.year, now.month + i, 1);

      // 简单预测：使用历史平均值
      final predicted = analysis.averageMonthlyIncome;

      // 置信区间基于标准差
      final margin = analysis.standardDeviation * 1.96; // 95%置信区间
      final lowerBound = math.max(0, predicted - margin);
      final upperBound = predicted + margin;

      // 置信度基于稳定性
      double confidence;
      switch (analysis.stability) {
        case IncomeStability.high:
          confidence = 0.85;
          break;
        case IncomeStability.medium:
          confidence = 0.70;
          break;
        case IncomeStability.low:
          confidence = 0.55;
          break;
        case IncomeStability.veryLow:
          confidence = 0.40;
          break;
      }

      // 距离越远，置信度越低
      confidence *= math.pow(0.95, i - 1);

      forecasts.add(IncomeForecast(
        year: targetDate.year,
        month: targetDate.month,
        predictedAmount: predicted,
        lowerBound: lowerBound,
        upperBound: upperBound,
        confidence: confidence,
      ));
    }

    return forecasts;
  }

  /// 计算收入平滑建议
  Future<Map<String, dynamic>> calculateIncomeSmoothing() async {
    final analysis = await analyzeIncome();

    // 建议的"月薪"：使用保守估计
    final suggestedMonthlySalary = analysis.suggestedBaseIncome *
        analysis.stability.budgetConservativeRatio;

    // 需要的缓冲资金
    final bufferMonths = analysis.stability.recommendedBufferMonths;
    final requiredBuffer = suggestedMonthlySalary * bufferMonths;

    // 检查当前缓冲状态
    final currentBuffer = await _getCurrentBufferBalance();
    final bufferStatus = currentBuffer >= requiredBuffer
        ? '充足'
        : currentBuffer >= requiredBuffer * 0.5
            ? '不足'
            : '严重不足';

    return {
      'suggestedMonthlySalary': suggestedMonthlySalary,
      'bufferMonths': bufferMonths,
      'requiredBuffer': requiredBuffer,
      'currentBuffer': currentBuffer,
      'bufferStatus': bufferStatus,
      'bufferProgress': currentBuffer / requiredBuffer,
      'stability': analysis.stability.displayName,
      'strategy': _getSmoothingStrategy(analysis.stability),
    };
  }

  /// 获取收入来源统计
  Future<Map<IncomeType, double>> getIncomeSourceStats({int months = 6}) async {
    final since = DateTime.now()
        .subtract(Duration(days: months * 30))
        .millisecondsSinceEpoch;

    final results = await _db.rawQuery('''
      SELECT type, SUM(amount) as total
      FROM income_records
      WHERE date >= ?
      GROUP BY type
    ''', [since]);

    final stats = <IncomeType, double>{};
    for (final row in results) {
      final type = IncomeType.values[row['type'] as int];
      stats[type] = (row['total'] as num).toDouble();
    }

    return stats;
  }

  /// 获取收入趋势
  Future<List<Map<String, dynamic>>> getIncomeTrend({int months = 12}) async {
    final analysis = await analyzeIncome(months: months);

    return analysis.monthlyHistory.map((m) => {
      'year': m.year,
      'month': m.month,
      'total': m.totalIncome,
      'fixed': m.fixedIncome,
      'variable': m.variableIncome,
    }).toList();
  }

  /// 检查是否需要提醒
  Future<Map<String, dynamic>> checkIncomeAlerts() async {
    final analysis = await analyzeIncome(months: 3);
    final alerts = <String>[];

    // 检查本月收入是否低于预期
    final currentMonth = DateTime.now();
    final currentMonthIncome = analysis.monthlyHistory
        .where((m) => m.year == currentMonth.year && m.month == currentMonth.month)
        .fold(0.0, (sum, m) => sum + m.totalIncome);

    final expectedIncome = analysis.averageMonthlyIncome;
    final dayOfMonth = currentMonth.day;
    final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final expectedSoFar = expectedIncome * dayOfMonth / daysInMonth;

    if (currentMonthIncome < expectedSoFar * 0.7) {
      alerts.add('本月收入进度低于预期，可能需要调整预算');
    }

    // 检查收入多样性
    final sourceStats = await getIncomeSourceStats(months: 3);
    if (sourceStats.length == 1) {
      alerts.add('收入来源单一，建议考虑多元化收入');
    }

    // 检查可变收入占比
    if (analysis.variableIncomeRatio > 0.7) {
      alerts.add('可变收入占比过高，建议增加稳定收入来源');
    }

    return {
      'alerts': alerts,
      'hasAlerts': alerts.isNotEmpty,
      'currentMonthIncome': currentMonthIncome,
      'expectedIncome': expectedIncome,
      'progress': currentMonthIncome / expectedSoFar,
    };
  }

  // 私有方法

  Future<double> _getCurrentBufferBalance() async {
    // 从应急资金账户获取余额
    final results = await _db.rawQuery('''
      SELECT balance FROM emergency_fund_goals
      ORDER BY updatedAt DESC
      LIMIT 1
    ''');

    if (results.isEmpty) return 0;
    return (results.first['balance'] as num?)?.toDouble() ?? 0;
  }

  String _getSmoothingStrategy(IncomeStability stability) {
    switch (stability) {
      case IncomeStability.high:
        return '标准预算：按月收入的80-90%制定预算';
      case IncomeStability.medium:
        return '保守预算：按平均收入的70-80%制定预算，多余收入存入缓冲';
      case IncomeStability.low:
        return '收入平滑：给自己发固定"工资"，其余存入缓冲账户';
      case IncomeStability.veryLow:
        return '最低保障：按最低收入制定预算，建立大额缓冲';
    }
  }
}
