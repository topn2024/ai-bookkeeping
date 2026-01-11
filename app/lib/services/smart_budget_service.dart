import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart';

/// 预算建议
class BudgetSuggestion {
  final String categoryId;
  final String categoryName;
  final double suggestedAmount;
  final double historicalMedian;
  final double historicalP75;
  final double volatility;
  final String reason;
  final double confidence;
  final SuggestionSource source;

  const BudgetSuggestion({
    required this.categoryId,
    required this.categoryName,
    required this.suggestedAmount,
    required this.historicalMedian,
    required this.historicalP75,
    required this.volatility,
    required this.reason,
    required this.confidence,
    this.source = SuggestionSource.historical,
  });

  factory BudgetSuggestion.empty() {
    return const BudgetSuggestion(
      categoryId: '',
      categoryName: '',
      suggestedAmount: 0,
      historicalMedian: 0,
      historicalP75: 0,
      volatility: 0,
      reason: '',
      confidence: 0,
    );
  }

  bool get isEmpty => categoryId.isEmpty;

  double get amount => suggestedAmount;

  BudgetSuggestion copyWith({
    double? amount,
    double? confidence,
    String? reason,
  }) {
    return BudgetSuggestion(
      categoryId: categoryId,
      categoryName: categoryName,
      suggestedAmount: amount ?? suggestedAmount,
      historicalMedian: historicalMedian,
      historicalP75: historicalP75,
      volatility: volatility,
      reason: reason ?? this.reason,
      confidence: confidence ?? this.confidence,
      source: source,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'suggestedAmount': suggestedAmount,
      'historicalMedian': historicalMedian,
      'historicalP75': historicalP75,
      'volatility': volatility,
      'reason': reason,
      'confidence': confidence,
      'source': source.index,
    };
  }
}

/// 建议来源
enum SuggestionSource {
  /// 历史数据
  historical,

  /// 群体统计
  collaborative,

  /// 本地化推荐
  localized,

  /// 用户自定义
  custom,
}

/// 数据不足的分类信息
class InsufficientDataCategory {
  final String categoryId;
  final String categoryName;
  final int transactionCount;
  final int requiredCount;

  const InsufficientDataCategory({
    required this.categoryId,
    required this.categoryName,
    required this.transactionCount,
    required this.requiredCount,
  });

  String get message => '$categoryName需要至少$requiredCount笔交易才能生成建议（当前$transactionCount笔）';
}

/// 预算建议结果
class SmartBudgetResult {
  final List<BudgetSuggestion> suggestions;
  final List<InsufficientDataCategory> insufficientDataCategories;

  const SmartBudgetResult({
    required this.suggestions,
    required this.insufficientDataCategories,
  });

  bool get hasInsufficientData => insufficientDataCategories.isNotEmpty;

  String get summaryMessage {
    if (insufficientDataCategories.isEmpty) {
      return '已为${suggestions.length}个分类生成预算建议';
    }
    return '已为${suggestions.length}个分类生成预算建议，${insufficientDataCategories.length}个分类数据不足';
  }
}


/// 分类消费统计
class CategorySpendingStats {
  final String categoryId;
  final String categoryName;
  final List<double> amounts = [];
  final List<DateTime> dates = [];

  CategorySpendingStats({
    required this.categoryId,
    required this.categoryName,
  });

  double get totalAmount => amounts.fold(0.0, (a, b) => a + b);

  int get transactionCount => amounts.length;

  double get averageAmount =>
      amounts.isEmpty ? 0 : totalAmount / amounts.length;
}

/// 月度预算分析
class MonthlyBudgetAnalysis {
  final String month; // 如 "2024-01"
  final double totalIncome;
  final double totalExpense;
  final double savingsRate;
  final Map<String, double> categoryBreakdown;
  final List<String> insights;

  const MonthlyBudgetAnalysis({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.savingsRate,
    required this.categoryBreakdown,
    required this.insights,
  });
}

/// 智能预算建议服务
///
/// 基于历史消费数据生成预算建议，使用统计算法：
/// - 中位数分析
/// - 百分位数计算
/// - 波动率评估
/// - 季节性调整
class SmartBudgetService {
  final Database _db;

  // 缓存
  List<BudgetSuggestion>? _cachedSuggestions;
  DateTime? _cacheTime;
  static const _cacheValidityMinutes = 30;

  SmartBudgetService(this._db);

  /// 生成预算建议（包含数据不足信息）
  Future<SmartBudgetResult> generateBudgetSuggestionsWithInfo({
    bool forceRefresh = false,
  }) async {
    final suggestions = <BudgetSuggestion>[];
    final insufficientDataCategories = <InsufficientDataCategory>[];

    // 获取最近3个月的消费数据
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final transactions = await _getExpensesSince(threeMonthsAgo);

    // 按分类聚合统计
    final categoryStats = <String, CategorySpendingStats>{};

    for (final tx in transactions) {
      final categoryId = tx['categoryId'] as String?;
      final categoryName = tx['categoryName'] as String? ?? '未分类';
      if (categoryId == null) continue;

      final stats = categoryStats.putIfAbsent(
        categoryId,
        () => CategorySpendingStats(
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      );
      stats.amounts.add((tx['amount'] as num).toDouble());
      stats.dates.add(DateTime.fromMillisecondsSinceEpoch(tx['date'] as int));
    }

    // 为每个分类生成建议
    for (final entry in categoryStats.entries) {
      final categoryId = entry.key;
      final stats = entry.value;

      if (stats.amounts.length < 3) {
        // 记录数据不足的分类
        insufficientDataCategories.add(InsufficientDataCategory(
          categoryId: categoryId,
          categoryName: stats.categoryName,
          transactionCount: stats.amounts.length,
          requiredCount: 3,
        ));
        continue;
      }

      // 计算统计指标
      final median = _calculateMedian(stats.amounts);
      final p75 = _calculatePercentile(stats.amounts, 75);
      final monthlyAverage = stats.totalAmount / 3;
      final volatility = _calculateVolatility(stats.amounts);

      // 检测季节性（如果是当前季节的消费高峰）
      final seasonalFactor = _detectSeasonality(stats.dates);

      // 计算建议预算
      double suggestedBudget;
      String reason;

      if (volatility < 0.2) {
        // 消费稳定：使用中位数 + 10%缓冲
        suggestedBudget = median * 1.1;
        reason = '您的${stats.categoryName}消费较稳定，建议预算略高于中位数';
      } else if (volatility < 0.5) {
        // 消费有波动：使用75分位数
        suggestedBudget = p75;
        reason = '${stats.categoryName}消费有一定波动，建议使用历史75%分位数';
      } else {
        // 消费波动大：使用月均值 + 20%缓冲
        suggestedBudget = monthlyAverage * 1.2;
        reason = '${stats.categoryName}消费波动较大，建议预留更多缓冲';
      }

      // 应用季节性调整
      suggestedBudget *= seasonalFactor;

      suggestions.add(BudgetSuggestion(
        categoryId: categoryId,
        categoryName: stats.categoryName,
        suggestedAmount: suggestedBudget.roundToDouble(),
        historicalMedian: median,
        historicalP75: p75,
        volatility: volatility,
        reason: reason,
        confidence: _calculateConfidence(stats.amounts.length, volatility),
      ));
    }

    // 按金额排序
    suggestions.sort((a, b) => b.suggestedAmount.compareTo(a.suggestedAmount));

    // 更新缓存
    _cachedSuggestions = suggestions;
    _cacheTime = DateTime.now();

    return SmartBudgetResult(
      suggestions: suggestions,
      insufficientDataCategories: insufficientDataCategories,
    );
  }

  /// 生成预算建议（向后兼容）
  Future<List<BudgetSuggestion>> generateBudgetSuggestions({
    bool forceRefresh = false,
  }) async {
    // 检查缓存
    if (!forceRefresh &&
        _cachedSuggestions != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < _cacheValidityMinutes) {
      return _cachedSuggestions!;
    }

    final result = await generateBudgetSuggestionsWithInfo(forceRefresh: forceRefresh);
    return result.suggestions;
  }

  /// 获取特定分类的预算建议
  Future<BudgetSuggestion?> getSuggestionForCategory(String categoryId) async {
    final suggestions = await generateBudgetSuggestions();
    try {
      return suggestions.firstWhere((s) => s.categoryId == categoryId);
    } catch (_) {
      return null;
    }
  }

  /// 分析月度预算执行情况
  Future<MonthlyBudgetAnalysis> analyzeMonthlyBudget({
    DateTime? month,
  }) async {
    final targetMonth = month ?? DateTime.now();
    final startOfMonth = DateTime(targetMonth.year, targetMonth.month, 1);
    final endOfMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0);

    // 获取收入
    final incomes = await _getIncomesBetween(startOfMonth, endOfMonth);
    final totalIncome =
        incomes.fold(0.0, (sum, i) => sum + (i['amount'] as num).toDouble());

    // 获取支出
    final expenses = await _getExpensesBetween(startOfMonth, endOfMonth);
    final totalExpense =
        expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());

    // 按分类汇总
    final categoryBreakdown = <String, double>{};
    for (final expense in expenses) {
      final categoryName = expense['categoryName'] as String? ?? '未分类';
      categoryBreakdown[categoryName] =
          (categoryBreakdown[categoryName] ?? 0) + (expense['amount'] as num).toDouble();
    }

    // 计算储蓄率
    final savingsRate =
        totalIncome > 0 ? (totalIncome - totalExpense) / totalIncome : 0.0;

    // 生成洞察
    final insights = _generateInsights(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savingsRate: savingsRate,
      categoryBreakdown: categoryBreakdown,
    );

    return MonthlyBudgetAnalysis(
      month: '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}',
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      savingsRate: savingsRate,
      categoryBreakdown: categoryBreakdown,
      insights: insights,
    );
  }

  /// 预测下月预算需求
  Future<Map<String, double>> predictNextMonthBudget() async {
    final suggestions = await generateBudgetSuggestions();
    final predictions = <String, double>{};

    for (final suggestion in suggestions) {
      // 应用下月的季节性因子
      final nextMonth = DateTime.now().month + 1;
      final seasonalFactor = _getSeasonalFactor(nextMonth);
      predictions[suggestion.categoryId] =
          suggestion.suggestedAmount * seasonalFactor;
    }

    return predictions;
  }

  /// 获取消费趋势
  Future<List<SpendingTrend>> getSpendingTrends({
    int months = 6,
  }) async {
    final trends = <SpendingTrend>[];
    final now = DateTime.now();

    for (var i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final expenses = await _getExpensesBetween(month, endOfMonth);
      final total =
          expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());

      trends.add(SpendingTrend(
        month: '${month.year}-${month.month.toString().padLeft(2, '0')}',
        amount: total,
        transactionCount: expenses.length,
      ));
    }

    return trends;
  }

  /// 识别异常消费
  Future<List<AnomalyExpense>> detectAnomalies({
    int days = 30,
  }) async {
    final anomalies = <AnomalyExpense>[];
    final since = DateTime.now().subtract(Duration(days: days));
    final transactions = await _getExpensesSince(since);

    // 按分类分组
    final categoryGroups = <String, List<Map<String, dynamic>>>{};
    for (final tx in transactions) {
      final categoryId = tx['categoryId'] as String? ?? 'other';
      categoryGroups.putIfAbsent(categoryId, () => []).add(tx);
    }

    // 检测每个分类的异常值
    for (final entry in categoryGroups.entries) {
      final categoryId = entry.key;
      final txList = entry.value;

      if (txList.length < 5) continue; // 数据不足

      final amounts = txList.map((t) => (t['amount'] as num).toDouble()).toList();
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final stdDev = _calculateStdDev(amounts);

      // 找出超过2倍标准差的异常值
      for (final tx in txList) {
        final amount = (tx['amount'] as num).toDouble();
        if ((amount - mean).abs() > 2 * stdDev) {
          anomalies.add(AnomalyExpense(
            transactionId: tx['id'] as String,
            categoryId: categoryId,
            categoryName: tx['categoryName'] as String? ?? '未分类',
            amount: amount,
            expectedRange: AmountRange(
              min: max(0, mean - stdDev),
              max: mean + stdDev,
            ),
            deviationFactor: (amount - mean) / stdDev,
            date: DateTime.fromMillisecondsSinceEpoch(tx['date'] as int),
          ));
        }
      }
    }

    // 按偏离程度排序
    anomalies.sort((a, b) =>
        b.deviationFactor.abs().compareTo(a.deviationFactor.abs()));

    return anomalies;
  }

  // ==================== 私有方法 ====================

  /// 计算中位数
  double _calculateMedian(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// 计算分位数
  double _calculatePercentile(List<double> values, int percentile) {
    final sorted = List<double>.from(values)..sort();
    final index = (percentile / 100 * sorted.length).floor();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// 计算波动率（变异系数）
  double _calculateVolatility(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance) / mean;
  }

  /// 计算标准差
  double _calculateStdDev(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  /// 检测季节性因子
  double _detectSeasonality(List<DateTime> dates) {
    final currentMonth = DateTime.now().month;

    // 简单的季节性检测：查看历史同期数据
    final sameSeasonCount = dates.where((d) {
      final monthDiff = (d.month - currentMonth).abs();
      return monthDiff <= 1 || monthDiff >= 11; // 同季节
    }).length;

    if (sameSeasonCount > dates.length * 0.6) {
      return 1.0; // 数据主要来自同季节，不调整
    }

    return _getSeasonalFactor(currentMonth);
  }

  /// 获取季节性因子
  double _getSeasonalFactor(int month) {
    // 根据月份特征调整
    if (month == 12 || month == 1 || month == 2) {
      return 1.15; // 年末年初消费高峰
    } else if (month == 11) {
      return 1.2; // 双11购物节
    } else if (month == 6 || month == 7) {
      return 1.1; // 618购物节+暑期
    }
    return 1.0;
  }

  /// 计算置信度
  double _calculateConfidence(int sampleSize, double volatility) {
    // 样本量越大、波动越小，置信度越高
    final sizeFactor = min(1.0, sampleSize / 30);
    final volatilityFactor = max(0.3, 1 - volatility);
    return (sizeFactor * 0.6 + volatilityFactor * 0.4).clamp(0.3, 0.95);
  }

  /// 生成洞察
  List<String> _generateInsights({
    required double totalIncome,
    required double totalExpense,
    required double savingsRate,
    required Map<String, double> categoryBreakdown,
  }) {
    final insights = <String>[];

    // 储蓄率分析
    if (savingsRate < 0) {
      insights.add('本月支出超过收入，建议检查大额消费或增加收入来源');
    } else if (savingsRate < 0.1) {
      insights.add('储蓄率较低（${(savingsRate * 100).toStringAsFixed(1)}%），建议适当控制支出');
    } else if (savingsRate > 0.3) {
      insights.add('储蓄率优秀（${(savingsRate * 100).toStringAsFixed(1)}%），继续保持');
    }

    // 找出占比最高的分类
    if (categoryBreakdown.isNotEmpty) {
      final sorted = categoryBreakdown.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final top = sorted.first;
      final topPercentage = totalExpense > 0 ? top.value / totalExpense : 0;

      if (topPercentage > 0.4) {
        insights.add('${top.key}占消费的${(topPercentage * 100).toStringAsFixed(1)}%，占比较高');
      }
    }

    return insights;
  }

  /// 获取指定日期之后的支出
  Future<List<Map<String, dynamic>>> _getExpensesSince(DateTime since) async {
    return await _db.rawQuery('''
      SELECT t.*, c.name as categoryName
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      WHERE t.type = ? AND t.date >= ?
      ORDER BY t.date DESC
    ''', [TransactionType.expense.index, since.millisecondsSinceEpoch]);
  }

  /// 获取指定日期范围内的支出
  Future<List<Map<String, dynamic>>> _getExpensesBetween(
    DateTime start,
    DateTime end,
  ) async {
    return await _db.rawQuery('''
      SELECT t.*, c.name as categoryName
      FROM transactions t
      LEFT JOIN categories c ON t.categoryId = c.id
      WHERE t.type = ? AND t.date >= ? AND t.date <= ?
      ORDER BY t.date DESC
    ''', [
      TransactionType.expense.index,
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);
  }

  /// 获取指定日期范围内的收入
  Future<List<Map<String, dynamic>>> _getIncomesBetween(
    DateTime start,
    DateTime end,
  ) async {
    return await _db.rawQuery('''
      SELECT * FROM transactions
      WHERE type = ? AND date >= ? AND date <= ?
    ''', [
      TransactionType.income.index,
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    ]);
  }

  /// 清除缓存
  void clearCache() {
    _cachedSuggestions = null;
    _cacheTime = null;
  }
}

/// 消费趋势
class SpendingTrend {
  final String month;
  final double amount;
  final int transactionCount;

  const SpendingTrend({
    required this.month,
    required this.amount,
    required this.transactionCount,
  });
}

/// 异常消费
class AnomalyExpense {
  final String transactionId;
  final String categoryId;
  final String categoryName;
  final double amount;
  final AmountRange expectedRange;
  final double deviationFactor;
  final DateTime date;

  const AnomalyExpense({
    required this.transactionId,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.expectedRange,
    required this.deviationFactor,
    required this.date,
  });

  bool get isHighAnomaly => deviationFactor > 0;
  bool get isLowAnomaly => deviationFactor < 0;
}

/// 金额范围
class AmountRange {
  final double min;
  final double max;

  const AmountRange({required this.min, required this.max});
}
