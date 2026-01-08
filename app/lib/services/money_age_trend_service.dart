import 'dart:math';

import '../models/resource_pool.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import '../core/logger.dart';

/// 趋势方向
enum TrendDirection {
  /// 上升
  up,

  /// 下降
  down,

  /// 稳定
  stable,
}

extension TrendDirectionExtension on TrendDirection {
  String get displayName {
    switch (this) {
      case TrendDirection.up:
        return '上升';
      case TrendDirection.down:
        return '下降';
      case TrendDirection.stable:
        return '稳定';
    }
  }

  String get emoji {
    switch (this) {
      case TrendDirection.up:
        return '↑';
      case TrendDirection.down:
        return '↓';
      case TrendDirection.stable:
        return '→';
    }
  }
}

/// 趋势分析结果
class TrendAnalysis {
  /// 趋势方向
  final TrendDirection direction;

  /// 变化幅度（天数）
  final double changeAmount;

  /// 变化百分比
  final double changePercentage;

  /// 趋势强度（0-1，越大越明显）
  final double strength;

  /// 分析描述
  final String description;

  /// 预测的未来钱龄
  final int? predictedAge;

  /// 达到下一等级需要的天数
  final int? daysToNextLevel;

  const TrendAnalysis({
    required this.direction,
    required this.changeAmount,
    required this.changePercentage,
    required this.strength,
    required this.description,
    this.predictedAge,
    this.daysToNextLevel,
  });

  /// 是否为积极趋势
  bool get isPositive => direction == TrendDirection.up;

  /// 是否为消极趋势
  bool get isNegative => direction == TrendDirection.down;

  factory TrendAnalysis.empty() {
    return const TrendAnalysis(
      direction: TrendDirection.stable,
      changeAmount: 0,
      changePercentage: 0,
      strength: 0,
      description: '数据不足，无法分析趋势',
    );
  }
}

/// 预测结果
class MoneyAgePrediction {
  /// 预测日期
  final DateTime date;

  /// 预测的平均钱龄
  final int predictedAge;

  /// 预测的健康等级
  final MoneyAgeLevel predictedLevel;

  /// 置信度（0-1）
  final double confidence;

  /// 影响因素列表
  final List<PredictionFactor> factors;

  const MoneyAgePrediction({
    required this.date,
    required this.predictedAge,
    required this.predictedLevel,
    required this.confidence,
    this.factors = const [],
  });
}

/// 预测影响因素
class PredictionFactor {
  /// 因素名称
  final String name;

  /// 影响程度（正数为正向影响，负数为负向影响）
  final double impact;

  /// 描述
  final String description;

  const PredictionFactor({
    required this.name,
    required this.impact,
    required this.description,
  });

  bool get isPositive => impact > 0;
}

/// 季节性模式
class SeasonalPattern {
  /// 月份（1-12）
  final int month;

  /// 平均钱龄偏差
  final double averageDeviation;

  /// 典型原因
  final String typicalReason;

  const SeasonalPattern({
    required this.month,
    required this.averageDeviation,
    required this.typicalReason,
  });
}

/// 异常事件
class AnomalyEvent {
  /// 事件日期
  final DateTime date;

  /// 钱龄变化
  final double ageChange;

  /// 是否为异常高
  final bool isHigh;

  /// 可能的原因
  final String possibleCause;

  /// 相关交易ID列表
  final List<String> relatedTransactionIds;

  const AnomalyEvent({
    required this.date,
    required this.ageChange,
    required this.isHigh,
    required this.possibleCause,
    this.relatedTransactionIds = const [],
  });
}

/// 钱龄趋势分析与预测服务
///
/// 功能：
/// 1. 历史趋势分析（周、月、季度、年）
/// 2. 短期预测（未来7-30天）
/// 3. 季节性模式识别
/// 4. 异常检测
/// 5. 目标达成预测
class MoneyAgeTrendService {
  final DatabaseService _db;
  final Logger _logger = Logger();

  /// 趋势变化阈值（超过此值认为有变化）
  static const double trendChangeThreshold = 2.0;

  /// 异常检测标准差倍数
  static const double anomalyStdDevMultiplier = 2.0;

  MoneyAgeTrendService({DatabaseService? database})
      : _db = database ?? DatabaseService();

  /// 分析最近N天的趋势
  Future<TrendAnalysis> analyzeTrend({
    int days = 30,
    String? ledgerId,
  }) async {
    try {
      final dailyAges = await _getDailyMoneyAges(days: days, ledgerId: ledgerId);

      if (dailyAges.isEmpty) {
        return TrendAnalysis.empty();
      }

      if (dailyAges.length < 7) {
        return const TrendAnalysis(
          direction: TrendDirection.stable,
          changeAmount: 0,
          changePercentage: 0,
          strength: 0,
          description: '数据不足7天，需要更多数据进行准确分析',
        );
      }

      // 计算移动平均
      final recentAvg = _calculateMovingAverage(dailyAges.take(7).toList());
      final previousAvg = _calculateMovingAverage(
        dailyAges.skip(7).take(7).toList(),
      );

      final change = recentAvg - previousAvg;
      final changePercent = previousAvg > 0 ? (change / previousAvg) * 100 : 0;

      // 计算趋势强度（基于回归斜率）
      final slope = _calculateLinearRegressionSlope(dailyAges);
      final strength = (slope.abs() / 2).clamp(0.0, 1.0);

      // 确定趋势方向
      TrendDirection direction;
      if (change > trendChangeThreshold) {
        direction = TrendDirection.up;
      } else if (change < -trendChangeThreshold) {
        direction = TrendDirection.down;
      } else {
        direction = TrendDirection.stable;
      }

      // 生成描述
      final description = _generateTrendDescription(
        direction,
        change.abs(),
        recentAvg.round(),
      );

      // 预测7天后的钱龄
      final predictedAge = (recentAvg + slope * 7).round();

      // 计算达到下一等级需要的天数
      final currentLevel = _getLevelFromDays(recentAvg.round());
      final nextLevel = _getNextLevel(currentLevel);
      int? daysToNextLevel;
      if (nextLevel != null && slope > 0) {
        final daysNeeded = nextLevel.minDays - recentAvg.round();
        daysToNextLevel = (daysNeeded / slope).ceil();
      }

      return TrendAnalysis(
        direction: direction,
        changeAmount: change,
        changePercentage: changePercent,
        strength: strength,
        description: description,
        predictedAge: predictedAge,
        daysToNextLevel: daysToNextLevel,
      );
    } catch (e) {
      _logger.error('Trend analysis failed: $e', tag: 'MoneyAge');
      return TrendAnalysis.empty();
    }
  }

  /// 预测未来钱龄
  ///
  /// [daysAhead] 预测天数
  /// [includePredictedIncomes] 是否包含预期收入（如工资日）
  Future<List<MoneyAgePrediction>> predictFuture({
    int daysAhead = 30,
    String? ledgerId,
    List<({double amount, DateTime date})>? expectedIncomes,
    double? estimatedDailyExpense,
  }) async {
    try {
      // 获取历史数据用于预测
      final historicalData = await _getDailyMoneyAges(
        days: 90,
        ledgerId: ledgerId,
      );

      if (historicalData.isEmpty) {
        return [];
      }

      // 计算平均每日支出
      final dailyExpense = estimatedDailyExpense ??
          await _calculateAverageDailyExpense(ledgerId: ledgerId);

      // 计算趋势斜率
      final slope = _calculateLinearRegressionSlope(historicalData);

      // 获取当前钱龄
      final currentAge = historicalData.isNotEmpty
          ? historicalData.first.averageAge.toDouble()
          : 0.0;

      // 获取季节性模式
      final seasonalPatterns = await _analyzeSeasonalPatterns(ledgerId: ledgerId);

      final predictions = <MoneyAgePrediction>[];
      final today = DateTime.now();

      for (var i = 1; i <= daysAhead; i++) {
        final targetDate = today.add(Duration(days: i));

        // 基础预测（线性趋势）
        var predictedAge = currentAge + slope * i;

        // 应用季节性调整
        final seasonalAdjustment = _getSeasonalAdjustment(
          targetDate.month,
          seasonalPatterns,
        );
        predictedAge += seasonalAdjustment;

        // 考虑预期收入的影响
        if (expectedIncomes != null) {
          for (final income in expectedIncomes) {
            if (_isSameDay(income.date, targetDate)) {
              // 收入会提高钱龄
              final incomeImpact = (income.amount / dailyExpense).clamp(0, 30);
              predictedAge += incomeImpact;
            }
          }
        }

        // 确保预测值合理
        predictedAge = predictedAge.clamp(0, 365);

        // 计算置信度（距离越远置信度越低）
        final confidence = (1 - (i / daysAhead) * 0.5).clamp(0.3, 1.0);

        // 确定预测等级
        final predictedLevel = _getLevelFromDays(predictedAge.round());

        // 识别影响因素
        final factors = <PredictionFactor>[];
        if (slope > 0.5) {
          factors.add(PredictionFactor(
            name: '上升趋势',
            impact: slope,
            description: '历史数据显示钱龄呈上升趋势',
          ));
        } else if (slope < -0.5) {
          factors.add(PredictionFactor(
            name: '下降趋势',
            impact: slope,
            description: '历史数据显示钱龄呈下降趋势',
          ));
        }

        if (seasonalAdjustment.abs() > 1) {
          factors.add(PredictionFactor(
            name: '季节性因素',
            impact: seasonalAdjustment,
            description: '${targetDate.month}月通常有${seasonalAdjustment > 0 ? "较高" : "较低"}的钱龄',
          ));
        }

        predictions.add(MoneyAgePrediction(
          date: targetDate,
          predictedAge: predictedAge.round(),
          predictedLevel: predictedLevel,
          confidence: confidence,
          factors: factors,
        ));
      }

      return predictions;
    } catch (e) {
      _logger.error('Prediction failed: $e', tag: 'MoneyAge');
      return [];
    }
  }

  /// 分析季节性模式
  Future<List<SeasonalPattern>> _analyzeSeasonalPatterns({
    String? ledgerId,
  }) async {
    try {
      // 获取一年的历史数据
      final yearlyData = await _getDailyMoneyAges(days: 365, ledgerId: ledgerId);

      if (yearlyData.length < 60) {
        return []; // 数据不足，无法分析季节性
      }

      // 计算整体平均值
      final overallAvg =
          yearlyData.map((d) => d.averageAge).reduce((a, b) => a + b) /
              yearlyData.length;

      // 按月分组计算
      final monthlyData = <int, List<int>>{};
      for (final daily in yearlyData) {
        final month = daily.date.month;
        monthlyData.putIfAbsent(month, () => []);
        monthlyData[month]!.add(daily.averageAge);
      }

      final patterns = <SeasonalPattern>[];
      for (final entry in monthlyData.entries) {
        if (entry.value.isEmpty) continue;

        final monthAvg =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
        final deviation = monthAvg - overallAvg;

        String reason;
        if (entry.key == 1 || entry.key == 2) {
          reason = '春节期间支出增加';
        } else if (entry.key == 11) {
          reason = '双十一促销支出增加';
        } else if (entry.key == 12) {
          reason = '年终消费及年会支出';
        } else if (entry.key == 6 || entry.key == 7) {
          reason = '暑期消费及旅游支出';
        } else {
          reason = deviation > 0 ? '消费相对较少' : '消费相对较多';
        }

        patterns.add(SeasonalPattern(
          month: entry.key,
          averageDeviation: deviation,
          typicalReason: reason,
        ));
      }

      return patterns;
    } catch (e) {
      _logger.error('Seasonal pattern analysis failed: $e', tag: 'MoneyAge');
      return [];
    }
  }

  /// 检测异常事件
  Future<List<AnomalyEvent>> detectAnomalies({
    int days = 90,
    String? ledgerId,
  }) async {
    try {
      final dailyData = await _getDailyMoneyAges(days: days, ledgerId: ledgerId);

      if (dailyData.length < 14) {
        return [];
      }

      // 计算均值和标准差
      final ages = dailyData.map((d) => d.averageAge.toDouble()).toList();
      final mean = ages.reduce((a, b) => a + b) / ages.length;
      final variance =
          ages.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
              ages.length;
      final stdDev = sqrt(variance);

      final anomalies = <AnomalyEvent>[];

      for (var i = 1; i < dailyData.length; i++) {
        final current = dailyData[i];
        final previous = dailyData[i - 1];
        final change = (current.averageAge - previous.averageAge).toDouble();

        // 检测显著偏离均值的点
        final deviation = (current.averageAge - mean).abs();
        if (deviation > stdDev * anomalyStdDevMultiplier) {
          final isHigh = current.averageAge > mean;
          String cause;

          if (isHigh) {
            cause = '可能有大额收入或支出显著减少';
          } else {
            cause = '可能有大额支出或收入减少';
          }

          anomalies.add(AnomalyEvent(
            date: current.date,
            ageChange: change,
            isHigh: isHigh,
            possibleCause: cause,
          ));
        }
      }

      return anomalies;
    } catch (e) {
      _logger.error('Anomaly detection failed: $e', tag: 'MoneyAge');
      return [];
    }
  }

  /// 计算达到目标钱龄所需时间
  Future<int?> estimateDaysToTarget({
    required int targetAge,
    String? ledgerId,
  }) async {
    try {
      final analysis = await analyzeTrend(days: 30, ledgerId: ledgerId);

      if (analysis.direction != TrendDirection.up ||
          analysis.predictedAge == null) {
        return null; // 趋势不上升，无法估算
      }

      final dailyData = await _getDailyMoneyAges(days: 7, ledgerId: ledgerId);
      if (dailyData.isEmpty) return null;

      final currentAge = dailyData.first.averageAge;
      if (currentAge >= targetAge) return 0;

      final slope = _calculateLinearRegressionSlope(dailyData);
      if (slope <= 0) return null;

      final daysNeeded = ((targetAge - currentAge) / slope).ceil();
      return daysNeeded;
    } catch (e) {
      _logger.error('Target estimation failed: $e', tag: 'MoneyAge');
      return null;
    }
  }

  /// 生成钱龄洞察报告
  Future<MoneyAgeInsightReport> generateInsightReport({
    String? ledgerId,
  }) async {
    final trend = await analyzeTrend(days: 30, ledgerId: ledgerId);
    final predictions = await predictFuture(daysAhead: 7, ledgerId: ledgerId);
    final anomalies = await detectAnomalies(days: 30, ledgerId: ledgerId);
    final seasonalPatterns = await _analyzeSeasonalPatterns(ledgerId: ledgerId);

    // 生成洞察列表
    final insights = <String>[];

    // 趋势洞察
    if (trend.direction == TrendDirection.up) {
      insights.add('您的钱龄正在改善，${trend.description}');
    } else if (trend.direction == TrendDirection.down) {
      insights.add('注意：您的钱龄有下降趋势，${trend.description}');
    }

    // 预测洞察
    if (predictions.isNotEmpty) {
      final weekLater = predictions.length >= 7 ? predictions[6] : predictions.last;
      insights.add('预计一周后钱龄为 ${weekLater.predictedAge} 天');
    }

    // 异常洞察
    if (anomalies.isNotEmpty) {
      insights.add('过去30天发现 ${anomalies.length} 个异常波动');
    }

    // 季节性洞察
    final currentMonth = DateTime.now().month;
    final currentPattern = seasonalPatterns.firstWhere(
      (p) => p.month == currentMonth,
      orElse: () => const SeasonalPattern(month: 0, averageDeviation: 0, typicalReason: ''),
    );
    if (currentPattern.month > 0 && currentPattern.averageDeviation.abs() > 2) {
      insights.add('$currentMonth月通常${currentPattern.typicalReason}');
    }

    return MoneyAgeInsightReport(
      trend: trend,
      predictions: predictions,
      anomalies: anomalies,
      seasonalPatterns: seasonalPatterns,
      insights: insights,
      generatedAt: DateTime.now(),
    );
  }

  // ========== 私有辅助方法 ==========

  /// 获取每日钱龄数据
  Future<List<DailyMoneyAge>> _getDailyMoneyAges({
    required int days,
    String? ledgerId,
  }) async {
    try {
      final db = await _db.database;

      // 从daily_money_age缓存表获取，如果没有则计算
      final startDate = DateTime.now().subtract(Duration(days: days));

      var whereClause = 'date >= ?';
      final whereArgs = <dynamic>[startDate.millisecondsSinceEpoch];

      if (ledgerId != null) {
        whereClause += ' AND ledgerId = ?';
        whereArgs.add(ledgerId);
      }

      final results = await db.query(
        'daily_money_age',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'date DESC',
      );

      return results.map((row) => DailyMoneyAge.fromMap(row)).toList();
    } catch (e) {
      _logger.error('Failed to get daily money ages: $e', tag: 'MoneyAge');
      return [];
    }
  }

  /// 计算移动平均
  double _calculateMovingAverage(List<DailyMoneyAge> data) {
    if (data.isEmpty) return 0;
    final sum = data.map((d) => d.averageAge).reduce((a, b) => a + b);
    return sum / data.length;
  }

  /// 计算线性回归斜率
  double _calculateLinearRegressionSlope(List<DailyMoneyAge> data) {
    if (data.length < 2) return 0;

    final n = data.length;
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumX2 = 0.0;

    for (var i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = data[n - 1 - i].averageAge.toDouble(); // 从旧到新
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) return 0;

    return (n * sumXY - sumX * sumY) / denominator;
  }

  /// 生成趋势描述
  String _generateTrendDescription(
    TrendDirection direction,
    double changeAmount,
    int currentAge,
  ) {
    final changeText = changeAmount.toStringAsFixed(1);

    switch (direction) {
      case TrendDirection.up:
        return '近期钱龄上升了约 $changeText 天，当前平均钱龄 $currentAge 天，继续保持！';
      case TrendDirection.down:
        return '近期钱龄下降了约 $changeText 天，当前平均钱龄 $currentAge 天，建议控制支出。';
      case TrendDirection.stable:
        return '近期钱龄保持稳定在 $currentAge 天左右。';
    }
  }

  /// 根据天数获取等级
  MoneyAgeLevel _getLevelFromDays(int days) {
    if (days < 7) return MoneyAgeLevel.danger;
    if (days < 14) return MoneyAgeLevel.warning;
    if (days < 30) return MoneyAgeLevel.normal;
    if (days < 60) return MoneyAgeLevel.good;
    if (days < 90) return MoneyAgeLevel.excellent;
    return MoneyAgeLevel.ideal;
  }

  /// 获取下一个等级
  MoneyAgeLevel? _getNextLevel(MoneyAgeLevel current) {
    final index = MoneyAgeLevel.values.indexOf(current);
    if (index < MoneyAgeLevel.values.length - 1) {
      return MoneyAgeLevel.values[index + 1];
    }
    return null;
  }

  /// 获取季节性调整值
  double _getSeasonalAdjustment(int month, List<SeasonalPattern> patterns) {
    final pattern = patterns.firstWhere(
      (p) => p.month == month,
      orElse: () => const SeasonalPattern(month: 0, averageDeviation: 0, typicalReason: ''),
    );
    return pattern.averageDeviation;
  }

  /// 计算平均每日支出
  Future<double> _calculateAverageDailyExpense({String? ledgerId}) async {
    try {
      final db = await _db.database;
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      var whereClause = 'type = ? AND date >= ?';
      final whereArgs = <dynamic>[
        TransactionType.expense.index,
        thirtyDaysAgo.millisecondsSinceEpoch,
      ];

      if (ledgerId != null) {
        whereClause += ' AND ledgerId = ?';
        whereArgs.add(ledgerId);
      }

      final result = await db.rawQuery(
        'SELECT SUM(amount) as total FROM transactions WHERE $whereClause',
        whereArgs,
      );

      final total = (result.first['total'] as num?)?.toDouble() ?? 0;
      return total / 30;
    } catch (e) {
      return 100; // 默认值
    }
  }

  /// 判断两个日期是否是同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

/// 钱龄洞察报告
class MoneyAgeInsightReport {
  final TrendAnalysis trend;
  final List<MoneyAgePrediction> predictions;
  final List<AnomalyEvent> anomalies;
  final List<SeasonalPattern> seasonalPatterns;
  final List<String> insights;
  final DateTime generatedAt;

  const MoneyAgeInsightReport({
    required this.trend,
    required this.predictions,
    required this.anomalies,
    required this.seasonalPatterns,
    required this.insights,
    required this.generatedAt,
  });

  /// 获取主要洞察
  String get primaryInsight => insights.isNotEmpty ? insights.first : '暂无洞察';

  /// 是否有警告
  bool get hasWarnings => trend.isNegative || anomalies.isNotEmpty;
}
