import 'package:flutter/foundation.dart';

// ==================== 家庭消费模式数据模型 ====================

/// 家庭消费模式
class FamilyConsumptionPattern {
  final String ledgerId;
  final WeeklyPattern weeklyPattern;
  final Map<String, double> memberContributionRatios;
  final Map<String, double> categoryPreferences;
  final double predictedMonthlyExpense;
  final int dataMonths;
  final double confidence;
  final DateTime analyzedAt;

  const FamilyConsumptionPattern({
    required this.ledgerId,
    required this.weeklyPattern,
    required this.memberContributionRatios,
    required this.categoryPreferences,
    required this.predictedMonthlyExpense,
    required this.dataMonths,
    required this.confidence,
    required this.analyzedAt,
  });

  Map<String, dynamic> toJson() => {
        'ledger_id': ledgerId,
        'weekly_pattern': weeklyPattern.toJson(),
        'member_contribution_ratios': memberContributionRatios,
        'category_preferences': categoryPreferences,
        'predicted_monthly_expense': predictedMonthlyExpense,
        'data_months': dataMonths,
        'confidence': confidence,
        'analyzed_at': analyzedAt.toIso8601String(),
      };
}

/// 周消费模式
class WeeklyPattern {
  final Map<int, double> dayOfWeekSpending;
  final double weekdayAverage;
  final double weekendAverage;
  final double weekendMultiplier;

  const WeeklyPattern({
    required this.dayOfWeekSpending,
    required this.weekdayAverage,
    required this.weekendAverage,
    required this.weekendMultiplier,
  });

  Map<String, dynamic> toJson() => {
        'day_of_week_spending': dayOfWeekSpending.map(
          (k, v) => MapEntry(k.toString(), v),
        ),
        'weekday_average': weekdayAverage,
        'weekend_average': weekendAverage,
        'weekend_multiplier': weekendMultiplier,
      };
}

/// 家庭预算建议
class FamilyBudgetSuggestion {
  final double totalBudget;
  final Map<String, double> memberAllocations;
  final Map<String, double> categoryAllocations;
  final double confidence;
  final String explanation;

  const FamilyBudgetSuggestion({
    required this.totalBudget,
    required this.memberAllocations,
    required this.categoryAllocations,
    required this.confidence,
    required this.explanation,
  });

  Map<String, dynamic> toJson() => {
        'total_budget': totalBudget,
        'member_allocations': memberAllocations,
        'category_allocations': categoryAllocations,
        'confidence': confidence,
        'explanation': explanation,
      };
}

/// 分摊偏好
class SplitPreference {
  final SplitMethod preferredMethod;
  final Map<String, double> defaultRatios;
  final List<String> frequentCategories;

  const SplitPreference({
    required this.preferredMethod,
    required this.defaultRatios,
    required this.frequentCategories,
  });
}

/// 分摊方式
enum SplitMethod {
  equal, // 平均分摊
  ratio, // 按比例分摊
  custom, // 自定义金额
  payerBased, // 按付款人
}

// ==================== 家庭交易数据 ====================

/// 家庭交易记录
class FamilyTransaction {
  final String id;
  final String ledgerId;
  final String memberId;
  final double amount;
  final String category;
  final DateTime date;
  final List<SplitDetail>? splits;

  const FamilyTransaction({
    required this.id,
    required this.ledgerId,
    required this.memberId,
    required this.amount,
    required this.category,
    required this.date,
    this.splits,
  });
}

/// 分摊详情
class SplitDetail {
  final String memberId;
  final double amount;
  final double ratio;

  const SplitDetail({
    required this.memberId,
    required this.amount,
    required this.ratio,
  });
}

/// 分摊历史统计
class SplitHistory {
  final SplitMethod mostUsedMethod;
  final Map<String, double> averageRatios;
  final List<String> frequentCategories;
  final int totalSplitCount;

  const SplitHistory({
    required this.mostUsedMethod,
    required this.averageRatios,
    required this.frequentCategories,
    required this.totalSplitCount,
  });
}

// ==================== 自学习框架接口 ====================

/// 自学习框架接口
abstract class SelfLearningFramework {
  Future<void> learn({
    required String domain,
    required Map<String, dynamic> context,
    required List<String> features,
  });

  Future<FamilyConsumptionPattern> getPatterns({
    required String domain,
    required Map<String, dynamic> context,
  });
}

// ==================== 家庭消费模式学习服务 ====================

/// 家庭消费模式学习服务
class FamilyConsumptionLearningService {
  final FamilyTransactionStore _transactionStore;
  final Map<String, FamilyConsumptionPattern> _patterns = {};
  final Map<String, SplitHistory> _splitHistories = {};

  FamilyConsumptionLearningService({
    FamilyTransactionStore? transactionStore,
  }) : _transactionStore = transactionStore ?? InMemoryFamilyTransactionStore();

  /// 学习家庭消费模式
  Future<FamilyConsumptionPattern> learnFamilyPatterns(String ledgerId) async {
    final transactions = await _transactionStore.getLedgerTransactions(
      ledgerId,
      months: 6,
    );

    if (transactions.isEmpty) {
      return _getDefaultPattern(ledgerId);
    }

    // 1. 学习周消费模式（周末vs工作日）
    final weeklyPattern = _analyzeWeeklyPattern(transactions);

    // 2. 学习成员贡献比例
    final memberContribution = _analyzeMemberContribution(transactions);

    // 3. 学习家庭分类偏好
    final categoryPreference = _analyzeCategoryPreference(transactions);

    // 4. 预测月度支出
    final predictedMonthly = _predictMonthlyExpense(transactions);

    // 5. 计算数据月份数和置信度
    final dataMonths = _calculateDataMonths(transactions);
    final confidence = _calculateConfidence(transactions.length, dataMonths);

    final pattern = FamilyConsumptionPattern(
      ledgerId: ledgerId,
      weeklyPattern: weeklyPattern,
      memberContributionRatios: memberContribution,
      categoryPreferences: categoryPreference,
      predictedMonthlyExpense: predictedMonthly,
      dataMonths: dataMonths,
      confidence: confidence,
      analyzedAt: DateTime.now(),
    );

    _patterns[ledgerId] = pattern;
    debugPrint('Learned family patterns for ledger: $ledgerId');

    return pattern;
  }

  /// 分析周消费模式
  WeeklyPattern _analyzeWeeklyPattern(List<FamilyTransaction> transactions) {
    final daySpending = <int, List<double>>{};

    for (final tx in transactions) {
      final dayOfWeek = tx.date.weekday;
      daySpending.putIfAbsent(dayOfWeek, () => []).add(tx.amount);
    }

    // 计算每日平均
    final dayAverage = <int, double>{};
    for (final entry in daySpending.entries) {
      dayAverage[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    // 计算工作日和周末平均
    final weekdayAmounts = <double>[];
    final weekendAmounts = <double>[];

    for (final entry in dayAverage.entries) {
      if (entry.key >= 1 && entry.key <= 5) {
        weekdayAmounts.add(entry.value);
      } else {
        weekendAmounts.add(entry.value);
      }
    }

    final weekdayAvg = weekdayAmounts.isEmpty
        ? 0.0
        : weekdayAmounts.reduce((a, b) => a + b) / weekdayAmounts.length;
    final weekendAvg = weekendAmounts.isEmpty
        ? 0.0
        : weekendAmounts.reduce((a, b) => a + b) / weekendAmounts.length;

    return WeeklyPattern(
      dayOfWeekSpending: dayAverage,
      weekdayAverage: weekdayAvg,
      weekendAverage: weekendAvg,
      weekendMultiplier: weekdayAvg > 0 ? weekendAvg / weekdayAvg : 1.0,
    );
  }

  /// 分析成员贡献比例
  Map<String, double> _analyzeMemberContribution(
      List<FamilyTransaction> transactions) {
    final memberSpending = <String, double>{};
    double total = 0;

    for (final tx in transactions) {
      memberSpending[tx.memberId] =
          (memberSpending[tx.memberId] ?? 0) + tx.amount;
      total += tx.amount;
    }

    if (total == 0) return {};

    return memberSpending.map((k, v) => MapEntry(k, v / total));
  }

  /// 分析分类偏好
  Map<String, double> _analyzeCategoryPreference(
      List<FamilyTransaction> transactions) {
    final categorySpending = <String, double>{};
    double total = 0;

    for (final tx in transactions) {
      categorySpending[tx.category] =
          (categorySpending[tx.category] ?? 0) + tx.amount;
      total += tx.amount;
    }

    if (total == 0) return {};

    return categorySpending.map((k, v) => MapEntry(k, v / total));
  }

  /// 预测月度支出
  double _predictMonthlyExpense(List<FamilyTransaction> transactions) {
    if (transactions.isEmpty) return 0;

    // 按月分组计算平均
    final monthlySpending = <String, double>{};
    for (final tx in transactions) {
      final monthKey = '${tx.date.year}-${tx.date.month}';
      monthlySpending[monthKey] = (monthlySpending[monthKey] ?? 0) + tx.amount;
    }

    if (monthlySpending.isEmpty) return 0;

    return monthlySpending.values.reduce((a, b) => a + b) / monthlySpending.length;
  }

  int _calculateDataMonths(List<FamilyTransaction> transactions) {
    if (transactions.isEmpty) return 0;

    final months = transactions.map((tx) => '${tx.date.year}-${tx.date.month}').toSet();
    return months.length;
  }

  double _calculateConfidence(int sampleCount, int monthCount) {
    // 基于样本数和月份数计算置信度
    double confidence = 0.5;
    if (sampleCount >= 50) confidence += 0.2;
    if (sampleCount >= 100) confidence += 0.1;
    if (monthCount >= 3) confidence += 0.1;
    if (monthCount >= 6) confidence += 0.1;
    return confidence.clamp(0.0, 1.0);
  }

  FamilyConsumptionPattern _getDefaultPattern(String ledgerId) {
    return FamilyConsumptionPattern(
      ledgerId: ledgerId,
      weeklyPattern: const WeeklyPattern(
        dayOfWeekSpending: {},
        weekdayAverage: 0,
        weekendAverage: 0,
        weekendMultiplier: 1.0,
      ),
      memberContributionRatios: {},
      categoryPreferences: {},
      predictedMonthlyExpense: 0,
      dataMonths: 0,
      confidence: 0,
      analyzedAt: DateTime.now(),
    );
  }

  /// 获取家庭预算智能建议
  Future<FamilyBudgetSuggestion> suggestFamilyBudget({
    required String ledgerId,
    required String period,
  }) async {
    // 确保已学习模式
    var pattern = _patterns[ledgerId];
    pattern ??= await learnFamilyPatterns(ledgerId);

    final predictedExpense = pattern.predictedMonthlyExpense;
    final totalBudget = predictedExpense * 1.1; // 预留10%弹性

    return FamilyBudgetSuggestion(
      totalBudget: totalBudget,
      memberAllocations: pattern.memberContributionRatios.map(
        (k, v) => MapEntry(k, totalBudget * v),
      ),
      categoryAllocations: pattern.categoryPreferences.map(
        (k, v) => MapEntry(k, totalBudget * v),
      ),
      confidence: pattern.confidence,
      explanation: '基于过去${pattern.dataMonths}个月的家庭消费数据，'
          '预计本月支出${predictedExpense.toStringAsFixed(0)}元。',
    );
  }

  /// 学习成员分摊偏好
  Future<SplitPreference> learnSplitPreference(String ledgerId) async {
    final history = await _getSplitHistory(ledgerId);

    return SplitPreference(
      preferredMethod: history.mostUsedMethod,
      defaultRatios: history.averageRatios,
      frequentCategories: history.frequentCategories,
    );
  }

  Future<SplitHistory> _getSplitHistory(String ledgerId) async {
    if (_splitHistories.containsKey(ledgerId)) {
      return _splitHistories[ledgerId]!;
    }

    final transactions = await _transactionStore.getLedgerTransactions(
      ledgerId,
      months: 6,
    );

    // 分析分摊历史
    final methodCounts = <SplitMethod, int>{};
    final memberRatios = <String, List<double>>{};
    final splitCategories = <String, int>{};

    for (final tx in transactions) {
      if (tx.splits != null && tx.splits!.isNotEmpty) {
        // 识别分摊方式
        final method = _identifySplitMethod(tx.splits!);
        methodCounts[method] = (methodCounts[method] ?? 0) + 1;

        // 统计成员分摊比例
        for (final split in tx.splits!) {
          memberRatios.putIfAbsent(split.memberId, () => []).add(split.ratio);
        }

        // 统计分摊类目
        splitCategories[tx.category] = (splitCategories[tx.category] ?? 0) + 1;
      }
    }

    // 确定最常用方式
    final mostUsedMethod = methodCounts.isEmpty
        ? SplitMethod.equal
        : methodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // 计算平均比例
    final avgRatios = memberRatios.map((k, v) =>
        MapEntry(k, v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length));

    // 找出高频分摊类目
    final sortedCategories = splitCategories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final frequentCats = sortedCategories.take(5).map((e) => e.key).toList();

    final history = SplitHistory(
      mostUsedMethod: mostUsedMethod,
      averageRatios: avgRatios,
      frequentCategories: frequentCats,
      totalSplitCount: methodCounts.values.fold(0, (a, b) => a + b),
    );

    _splitHistories[ledgerId] = history;
    return history;
  }

  SplitMethod _identifySplitMethod(List<SplitDetail> splits) {
    if (splits.isEmpty) return SplitMethod.custom;

    // 检查是否平均分摊
    final firstRatio = splits.first.ratio;
    final isEqual = splits.every((s) => (s.ratio - firstRatio).abs() < 0.01);

    if (isEqual && (firstRatio - 1 / splits.length).abs() < 0.01) {
      return SplitMethod.equal;
    }

    return SplitMethod.ratio;
  }

  /// 记录新交易用于学习
  Future<void> recordTransaction(FamilyTransaction transaction) async {
    await _transactionStore.addTransaction(transaction);

    // 检查是否需要更新模式
    final pattern = _patterns[transaction.ledgerId];
    if (pattern != null) {
      final hoursSinceAnalysis =
          DateTime.now().difference(pattern.analyzedAt).inHours;
      if (hoursSinceAnalysis >= 24) {
        // 超过24小时重新学习
        await learnFamilyPatterns(transaction.ledgerId);
      }
    }
  }
}

// ==================== 交易存储 ====================

/// 家庭交易存储接口
abstract class FamilyTransactionStore {
  Future<List<FamilyTransaction>> getLedgerTransactions(
    String ledgerId, {
    int months = 6,
  });
  Future<void> addTransaction(FamilyTransaction transaction);
}

/// 内存家庭交易存储
class InMemoryFamilyTransactionStore implements FamilyTransactionStore {
  final List<FamilyTransaction> _transactions = [];

  @override
  Future<List<FamilyTransaction>> getLedgerTransactions(
    String ledgerId, {
    int months = 6,
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    return _transactions
        .where((tx) => tx.ledgerId == ledgerId && tx.date.isAfter(cutoff))
        .toList();
  }

  @override
  Future<void> addTransaction(FamilyTransaction transaction) async {
    _transactions.add(transaction);
  }

  void clear() => _transactions.clear();
}
