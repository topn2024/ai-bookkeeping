import 'dart:async';
import 'dart:math';

/// 消费趋势预测服务
///
/// 功能：
/// 1. 月度消费预测（SMA + WMA + 季节性调整）
/// 2. 分类消费趋势分析
/// 3. 预算超支预警
/// 4. 消费习惯洞察
class TrendPredictionService {
  final TrendTransactionRepository _transactionRepo;
  final TrendBudgetRepository _budgetRepo;

  TrendPredictionService({
    required TrendTransactionRepository transactionRepo,
    TrendBudgetRepository? budgetRepo,
  })  : _transactionRepo = transactionRepo,
        _budgetRepo = budgetRepo ?? InMemoryBudgetRepository();

  /// 预测下月消费（使用简单移动平均 + 季节性调整）
  Future<MonthlyPrediction> predictNextMonth() async {
    // 获取过去12个月的月度消费
    final monthlyData = await _getMonthlySpending(months: 12);

    if (monthlyData.length < 3) {
      return MonthlyPrediction(
        predictedAmount: 0,
        confidence: 0,
        method: 'insufficient_data',
        message: '数据不足，需要至少3个月的记录',
      );
    }

    // 方法1: 简单移动平均（SMA）
    final sma3 = _calculateSMA(monthlyData, 3);

    // 方法2: 加权移动平均（WMA）- 最近的权重更高
    final wma3 = _calculateWMA(monthlyData, [0.5, 0.33, 0.17]);

    // 方法3: 季节性调整
    final nextMonth = (DateTime.now().month % 12) + 1;
    final seasonalFactor = _getSeasonalFactor(nextMonth);

    // 综合预测
    final predicted = (sma3 * 0.4 + wma3 * 0.6) * seasonalFactor;

    // 计算置信区间
    final stdDev = _calculateStdDev(monthlyData);
    final lowerBound = max(0.0, predicted - 1.96 * stdDev);
    final upperBound = predicted + 1.96 * stdDev;

    // 分类预测
    final categoryBreakdown = await _predictByCategory();

    return MonthlyPrediction(
      predictedAmount: predicted,
      lowerBound: lowerBound,
      upperBound: upperBound,
      confidence: _calculatePredictionConfidence(monthlyData),
      method: 'wma_seasonal',
      seasonalFactor: seasonalFactor,
      breakdown: categoryBreakdown,
      message: _generatePredictionMessage(predicted, seasonalFactor, nextMonth),
    );
  }

  /// 获取月度消费数据
  Future<List<double>> _getMonthlySpending({required int months}) async {
    final now = DateTime.now();
    final data = <double>[];

    for (int i = months - 1; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i, 1);
      final monthTotal = await _transactionRepo.getMonthlyTotal(
        year: targetMonth.year,
        month: targetMonth.month,
      );
      data.add(monthTotal);
    }

    return data;
  }

  /// 计算简单移动平均
  double _calculateSMA(List<double> data, int period) {
    if (data.length < period) return data.last;
    final recent = data.sublist(data.length - period);
    return recent.reduce((a, b) => a + b) / period;
  }

  /// 计算加权移动平均
  double _calculateWMA(List<double> data, List<double> weights) {
    final period = weights.length;
    if (data.length < period) return data.last;

    final recent = data.sublist(data.length - period);
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += recent[i] * weights[period - 1 - i];
    }
    return sum;
  }

  /// 季节性因子
  double _getSeasonalFactor(int month) {
    // 基于中国消费习惯的月度因子
    const factors = {
      1: 1.15, // 春节
      2: 1.10, // 春节
      3: 0.95,
      4: 0.95,
      5: 1.00,
      6: 1.10, // 618
      7: 1.05,
      8: 1.00,
      9: 0.95,
      10: 1.05, // 国庆
      11: 1.20, // 双11
      12: 1.10, // 年末
    };
    return factors[month] ?? 1.0;
  }

  /// 计算标准差
  double _calculateStdDev(List<double> values) {
    if (values.length < 2) return 0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;

    return sqrt(variance);
  }

  /// 计算预测置信度
  double _calculatePredictionConfidence(List<double> data) {
    if (data.length < 3) return 0.3;
    if (data.length < 6) return 0.5;
    if (data.length < 12) return 0.7;

    // 计算变异系数，变异系数越小，置信度越高
    final mean = data.reduce((a, b) => a + b) / data.length;
    final stdDev = _calculateStdDev(data);
    final cv = mean > 0 ? stdDev / mean : 0;

    // 变异系数转换为置信度
    return (1 - cv).clamp(0.5, 0.95).toDouble();
  }

  /// 按分类预测
  Future<List<CategoryPrediction>> _predictByCategory() async {
    final categories = await _transactionRepo.getTopCategories(limit: 5);
    final predictions = <CategoryPrediction>[];

    for (final category in categories) {
      final history = await _transactionRepo.getCategoryMonthlyTotals(
        categoryId: category.id,
        months: 6,
      );

      if (history.length < 2) continue;

      final predicted = _calculateWMA(history, [0.5, 0.3, 0.2]);
      final trend = _calculateTrend(history);

      predictions.add(CategoryPrediction(
        categoryId: category.id,
        categoryName: category.name,
        predictedAmount: predicted,
        trend: trend,
        trendPercentage: _calculateTrendPercentage(history),
      ));
    }

    return predictions;
  }

  /// 计算趋势方向
  TrendDirection _calculateTrend(List<double> data) {
    if (data.length < 2) return TrendDirection.stable;

    // 使用最近3个月的平均 vs 之前3个月的平均
    if (data.length >= 6) {
      final recent = data.sublist(data.length - 3);
      final previous = data.sublist(data.length - 6, data.length - 3);

      final recentAvg = recent.reduce((a, b) => a + b) / 3;
      final previousAvg = previous.reduce((a, b) => a + b) / 3;

      // 修复：添加除零检查，避免previousAvg为0时除零
      if (previousAvg == 0) {
        return recentAvg > 0 ? TrendDirection.increasing : TrendDirection.stable;
      }

      final changeRate = (recentAvg - previousAvg) / previousAvg;

      if (changeRate > 0.1) return TrendDirection.increasing;
      if (changeRate < -0.1) return TrendDirection.decreasing;
      return TrendDirection.stable;
    }

    // 数据较少时，比较最近两个月
    final last = data.last;
    final secondLast = data[data.length - 2];

    // 修复：添加除零检查，避免secondLast为0时除零
    if (secondLast == 0) {
      return last > 0 ? TrendDirection.increasing : TrendDirection.stable;
    }

    final changeRate = (last - secondLast) / secondLast;

    if (changeRate > 0.15) return TrendDirection.increasing;
    if (changeRate < -0.15) return TrendDirection.decreasing;
    return TrendDirection.stable;
  }

  /// 计算趋势百分比
  double _calculateTrendPercentage(List<double> data) {
    if (data.length < 2) return 0;

    final last = data.last;
    final secondLast = data[data.length - 2];

    if (secondLast == 0) return 0;
    return ((last - secondLast) / secondLast * 100);
  }

  /// 生成预测消息
  String _generatePredictionMessage(
    double predicted,
    double seasonalFactor,
    int month,
  ) {
    final buffer = StringBuffer();
    buffer.write('预计下月消费约¥${predicted.toStringAsFixed(0)}');

    if (seasonalFactor > 1.1) {
      buffer.write('，受${_getSeasonalEventName(month)}影响可能偏高');
    } else if (seasonalFactor < 0.95) {
      buffer.write('，消费淡季预计支出较少');
    }

    return buffer.toString();
  }

  /// 获取季节性事件名称
  String _getSeasonalEventName(int month) {
    switch (month) {
      case 1:
      case 2:
        return '春节';
      case 6:
        return '618购物节';
      case 10:
        return '国庆节';
      case 11:
        return '双11';
      case 12:
        return '年末';
      default:
        return '';
    }
  }

  /// 预测预算使用情况
  Future<BudgetPrediction> predictBudgetUsage({
    required String budgetId,
  }) async {
    final budget = await _budgetRepo.getById(budgetId);
    if (budget == null) {
      return BudgetPrediction(
        budgetId: budgetId,
        predictedUsage: 0,
        willExceed: false,
        confidence: 0,
        message: '未找到预算',
      );
    }

    // 获取本月已花费
    final now = DateTime.now();
    final spent = await _transactionRepo.getCategoryMonthlyTotal(
      categoryId: budget.categoryId,
      year: now.year,
      month: now.month,
    );

    // 预测本月剩余天数的消费
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = daysInMonth - now.day;
    final dailyAverage = spent / now.day;
    final predictedRemaining = dailyAverage * remainingDays;
    final predictedTotal = spent + predictedRemaining;

    final willExceed = predictedTotal > budget.amount;
    final usageRate = predictedTotal / budget.amount;

    String message;
    if (willExceed) {
      final exceededBy = predictedTotal - budget.amount;
      message = '按当前消费速度，预计超支¥${exceededBy.toStringAsFixed(0)}';
    } else {
      final remaining = budget.amount - predictedTotal;
      message = '预计可结余¥${remaining.toStringAsFixed(0)}';
    }

    return BudgetPrediction(
      budgetId: budgetId,
      budgetAmount: budget.amount,
      currentSpent: spent,
      predictedUsage: predictedTotal,
      willExceed: willExceed,
      usageRate: usageRate,
      confidence: _calculateBudgetPredictionConfidence(now.day, daysInMonth),
      exceededBy: willExceed ? predictedTotal - budget.amount : null,
      message: message,
      suggestedDailyLimit:
          willExceed ? (budget.amount - spent) / remainingDays : null,
    );
  }

  /// 计算预算预测置信度
  double _calculateBudgetPredictionConfidence(int currentDay, int totalDays) {
    // 月初预测置信度低，月末置信度高
    return (currentDay / totalDays * 0.7 + 0.3).clamp(0.3, 0.9);
  }

  /// 获取消费洞察
  Future<List<SpendingInsight>> getSpendingInsights() async {
    final insights = <SpendingInsight>[];

    // 洞察1: 消费趋势
    final prediction = await predictNextMonth();
    if (prediction.confidence > 0.5) {
      final monthlyData = await _getMonthlySpending(months: 3);
      final trend = _calculateTrend(monthlyData);

      if (trend == TrendDirection.increasing) {
        insights.add(SpendingInsight(
          type: InsightType.trend,
          title: '消费呈上升趋势',
          description: '近3个月消费逐月增加，建议关注支出',
          severity: InsightSeverity.warning,
          actionable: true,
          action: '设置预算提醒',
        ));
      }
    }

    // 洞察2: 拿铁因子
    final smallExpenses = await _transactionRepo.getSmallExpenses(
      threshold: 50,
      days: 30,
    );
    final smallTotal = smallExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
    final monthTotal = await _transactionRepo.getMonthlyTotal(
      year: DateTime.now().year,
      month: DateTime.now().month,
    );

    if (monthTotal > 0 && smallTotal / monthTotal > 0.3) {
      insights.add(SpendingInsight(
        type: InsightType.latteFactor,
        title: '小额消费占比较高',
        description:
            '本月50元以下的小额消费累计¥${smallTotal.toStringAsFixed(0)}，占总支出${(smallTotal / monthTotal * 100).toStringAsFixed(0)}%',
        severity: InsightSeverity.info,
        actionable: true,
        action: '查看小额消费明细',
        metadata: {
          'smallTotal': smallTotal,
          'ratio': smallTotal / monthTotal,
        },
      ));
    }

    // 洞察3: 周末消费
    final weekendSpending = await _transactionRepo.getWeekendSpending(days: 30);
    final weekdaySpending =
        await _transactionRepo.getWeekdaySpending(days: 30);

    if (weekdaySpending > 0) {
      final weekendRatio = weekendSpending / (weekendSpending + weekdaySpending);
      if (weekendRatio > 0.5) {
        insights.add(SpendingInsight(
          type: InsightType.pattern,
          title: '周末消费较多',
          description: '周末消费占比${(weekendRatio * 100).toStringAsFixed(0)}%，高于平均水平',
          severity: InsightSeverity.info,
          actionable: false,
        ));
      }
    }

    // 洞察4: 异常高额消费
    final largeExpenses = await _transactionRepo.getLargeExpenses(
      threshold: 1000,
      days: 30,
    );
    if (largeExpenses.isNotEmpty) {
      final largeTotal = largeExpenses.fold(0.0, (sum, tx) => sum + tx.amount);
      insights.add(SpendingInsight(
        type: InsightType.alert,
        title: '大额消费提醒',
        description: '本月有${largeExpenses.length}笔千元以上消费，共¥${largeTotal.toStringAsFixed(0)}',
        severity: InsightSeverity.info,
        actionable: true,
        action: '查看大额消费',
        metadata: {
          'count': largeExpenses.length,
          'total': largeTotal,
        },
      ));
    }

    return insights;
  }
}

/// 趋势方向
enum TrendDirection {
  increasing, // 上升
  stable, // 稳定
  decreasing, // 下降
}

extension TrendDirectionExtension on TrendDirection {
  String get label {
    switch (this) {
      case TrendDirection.increasing:
        return '上升';
      case TrendDirection.stable:
        return '稳定';
      case TrendDirection.decreasing:
        return '下降';
    }
  }

  String get emoji {
    switch (this) {
      case TrendDirection.increasing:
        return '📈';
      case TrendDirection.stable:
        return '➡️';
      case TrendDirection.decreasing:
        return '📉';
    }
  }
}

/// 月度预测结果
class MonthlyPrediction {
  final double predictedAmount;
  final double? lowerBound;
  final double? upperBound;
  final double confidence;
  final String method;
  final double? seasonalFactor;
  final List<CategoryPrediction>? breakdown;
  final String? message;

  const MonthlyPrediction({
    required this.predictedAmount,
    this.lowerBound,
    this.upperBound,
    required this.confidence,
    required this.method,
    this.seasonalFactor,
    this.breakdown,
    this.message,
  });

  String get confidenceLevel {
    if (confidence > 0.8) return '高';
    if (confidence > 0.5) return '中';
    return '低';
  }
}

/// 分类预测结果
class CategoryPrediction {
  final String categoryId;
  final String categoryName;
  final double predictedAmount;
  final TrendDirection trend;
  final double trendPercentage;

  const CategoryPrediction({
    required this.categoryId,
    required this.categoryName,
    required this.predictedAmount,
    required this.trend,
    required this.trendPercentage,
  });
}

/// 预算预测结果
class BudgetPrediction {
  final String budgetId;
  final double? budgetAmount;
  final double? currentSpent;
  final double predictedUsage;
  final bool willExceed;
  final double? usageRate;
  final double confidence;
  final double? exceededBy;
  final String message;
  final double? suggestedDailyLimit;

  const BudgetPrediction({
    required this.budgetId,
    this.budgetAmount,
    this.currentSpent,
    required this.predictedUsage,
    required this.willExceed,
    this.usageRate,
    required this.confidence,
    this.exceededBy,
    required this.message,
    this.suggestedDailyLimit,
  });
}

/// 消费洞察类型
enum InsightType {
  trend, // 趋势
  latteFactor, // 拿铁因子
  pattern, // 消费模式
  alert, // 提醒
  saving, // 省钱建议
}

/// 洞察严重程度
enum InsightSeverity {
  info, // 信息
  warning, // 警告
  critical, // 严重
}

/// 消费洞察
class SpendingInsight {
  final InsightType type;
  final String title;
  final String description;
  final InsightSeverity severity;
  final bool actionable;
  final String? action;
  final Map<String, dynamic>? metadata;

  const SpendingInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.actionable,
    this.action,
    this.metadata,
  });
}

/// 简单交易数据
class SimpleTrendTransaction {
  final String id;
  final double amount;
  final DateTime date;
  final String? categoryId;

  const SimpleTrendTransaction({
    required this.id,
    required this.amount,
    required this.date,
    this.categoryId,
  });
}

/// 简单分类数据
class SimpleCategory {
  final String id;
  final String name;

  const SimpleCategory({required this.id, required this.name});
}

/// 简单预算数据
class SimpleBudget {
  final String id;
  final String categoryId;
  final double amount;
  final int year;
  final int month;

  const SimpleBudget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.year,
    required this.month,
  });
}

/// 交易仓库接口
abstract class TrendTransactionRepository {
  Future<double> getMonthlyTotal({required int year, required int month});
  Future<double> getCategoryMonthlyTotal({
    required String categoryId,
    required int year,
    required int month,
  });
  Future<List<double>> getCategoryMonthlyTotals({
    required String categoryId,
    required int months,
  });
  Future<List<SimpleCategory>> getTopCategories({required int limit});
  Future<List<SimpleTrendTransaction>> getSmallExpenses({
    required double threshold,
    required int days,
  });
  Future<List<SimpleTrendTransaction>> getLargeExpenses({
    required double threshold,
    required int days,
  });
  Future<double> getWeekendSpending({required int days});
  Future<double> getWeekdaySpending({required int days});
}

/// 预算仓库接口
abstract class TrendBudgetRepository {
  Future<SimpleBudget?> getById(String id);
}

/// 内存预算仓库实现
class InMemoryBudgetRepository implements TrendBudgetRepository {
  final Map<String, SimpleBudget> _budgets = {};

  @override
  Future<SimpleBudget?> getById(String id) async {
    return _budgets[id];
  }
}
