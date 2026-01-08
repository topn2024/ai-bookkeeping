import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ==================== 预算学习数据模型 ====================

/// 预算学习样本
class BudgetLearningSample {
  final String id;
  final String userId;
  final BudgetInput input;
  final double suggestedAmount;
  final double? acceptedAmount;
  final BudgetAdjustType adjustType;
  final DateTime timestamp;
  final String? userFeedback;

  const BudgetLearningSample({
    required this.id,
    required this.userId,
    required this.input,
    required this.suggestedAmount,
    this.acceptedAmount,
    required this.adjustType,
    required this.timestamp,
    this.userFeedback,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'input': input.toJson(),
        'suggested_amount': suggestedAmount,
        'accepted_amount': acceptedAmount,
        'adjust_type': adjustType.name,
        'timestamp': timestamp.toIso8601String(),
        'user_feedback': userFeedback,
      };
}

/// 预算输入
class BudgetInput {
  final String categoryName;
  final double monthlyIncome;
  final int month;
  final String? region;
  final int? familySize;

  const BudgetInput({
    required this.categoryName,
    required this.monthlyIncome,
    required this.month,
    this.region,
    this.familySize,
  });

  Map<String, dynamic> toJson() => {
        'category_name': categoryName,
        'monthly_income': monthlyIncome,
        'month': month,
        'region': region,
        'family_size': familySize,
      };
}

/// 预算调整类型
enum BudgetAdjustType {
  accepted, // 接受建议
  increased, // 增加预算
  decreased, // 减少预算
  rejected, // 拒绝建议
  custom, // 自定义金额
}

// ==================== 脱敏数据模型 ====================

/// 脱敏后的预算模式
class SanitizedBudgetPattern {
  final String categoryName;
  final String incomeRange;
  final double? acceptanceRatio;
  final BudgetAdjustType adjustType;
  final String userHash;
  final int? month;
  final String? region;
  final DateTime timestamp;

  const SanitizedBudgetPattern({
    required this.categoryName,
    required this.incomeRange,
    this.acceptanceRatio,
    required this.adjustType,
    required this.userHash,
    this.month,
    this.region,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'category_name': categoryName,
        'income_range': incomeRange,
        'acceptance_ratio': acceptanceRatio,
        'adjust_type': adjustType.name,
        'user_hash': userHash,
        'month': month,
        'region': region,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ==================== 全局预算洞察 ====================

/// 全局预算洞察
class GlobalBudgetInsights {
  final Map<String, Map<String, double>> incomeRangeBudgetRatios;
  final Map<String, CategoryAdjustmentTrend> categoryAdjustmentTrends;
  final Map<int, SeasonalTrend> seasonalTrends;
  final DateTime generatedAt;

  const GlobalBudgetInsights({
    required this.incomeRangeBudgetRatios,
    required this.categoryAdjustmentTrends,
    required this.seasonalTrends,
    required this.generatedAt,
  });
}

/// 分类调整趋势
class CategoryAdjustmentTrend {
  final String categoryName;
  final double averageAdjustment;
  final BudgetAdjustType mostCommonAdjust;
  final int sampleCount;

  const CategoryAdjustmentTrend({
    required this.categoryName,
    required this.averageAdjustment,
    required this.mostCommonAdjust,
    required this.sampleCount,
  });
}

/// 季节性趋势
class SeasonalTrend {
  final int month;
  final double adjustmentMultiplier;
  final List<String> highSpendingCategories;

  const SeasonalTrend({
    required this.month,
    required this.adjustmentMultiplier,
    required this.highSpendingCategories,
  });
}

// ==================== 预算协同学习服务 ====================

/// 预算协同学习服务
class BudgetCollaborativeLearningService {
  final GlobalBudgetInsightsAggregator _aggregator;
  final BudgetPatternReporter _reporter;
  final String _currentUserId;

  BudgetCollaborativeLearningService({
    GlobalBudgetInsightsAggregator? aggregator,
    BudgetPatternReporter? reporter,
    String? currentUserId,
  })  : _aggregator = aggregator ?? GlobalBudgetInsightsAggregator(),
        _reporter = reporter ?? InMemoryBudgetPatternReporter(),
        _currentUserId = currentUserId ?? 'anonymous';

  /// 上报预算模式（隐私保护）
  Future<void> reportBudgetPattern(BudgetLearningSample sample) async {
    // 只上报相对比例，不上报绝对金额
    final pattern = SanitizedBudgetPattern(
      // 分类
      categoryName: sample.input.categoryName,
      // 收入区间（脱敏）
      incomeRange: _getIncomeRange(sample.input.monthlyIncome),
      // 建议/实际比例
      acceptanceRatio: sample.acceptedAmount != null
          ? sample.acceptedAmount! / sample.suggestedAmount
          : null,
      // 调整类型
      adjustType: sample.adjustType,
      // 用户哈希
      userHash: _hashUserId(sample.userId),
      // 月份（用于季节性分析）
      month: sample.input.month,
      // 地区（可选）
      region: sample.input.region,
      timestamp: DateTime.now(),
    );

    await _reporter.report(pattern);
    debugPrint('Reported budget pattern: ${pattern.toJson()}');
  }

  /// 收入区间脱敏
  String _getIncomeRange(double income) {
    if (income < 5000) return '0-5k';
    if (income < 10000) return '5k-10k';
    if (income < 20000) return '10k-20k';
    if (income < 50000) return '20k-50k';
    return '50k+';
  }

  String _hashUserId(String userId) {
    final bytes = utf8.encode(userId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 获取全局预算洞察
  Future<GlobalBudgetInsights> getGlobalInsights() async {
    return _aggregator.aggregate();
  }

  /// 为新用户提供参考预算
  Future<Map<String, double>> getReferenceBudget({
    required double monthlyIncome,
    String? region,
  }) async {
    final incomeRange = _getIncomeRange(monthlyIncome);
    final insights = await _aggregator.aggregate();

    final ratios = insights.incomeRangeBudgetRatios[incomeRange] ?? {};

    // 将比例转换为实际金额
    final budget = <String, double>{};
    for (final entry in ratios.entries) {
      budget[entry.key] = monthlyIncome * entry.value;
    }

    return budget;
  }

  /// 获取分类调整建议
  Future<double?> getCategoryAdjustmentSuggestion(
    String category,
    double currentBudget,
    int month,
  ) async {
    final insights = await _aggregator.aggregate();

    // 检查季节性调整
    final seasonalTrend = insights.seasonalTrends[month];
    double multiplier = 1.0;
    if (seasonalTrend != null) {
      multiplier = seasonalTrend.adjustmentMultiplier;
      if (seasonalTrend.highSpendingCategories.contains(category)) {
        multiplier *= 1.2; // 高消费月份额外增加
      }
    }

    // 检查分类调整趋势
    final categoryTrend = insights.categoryAdjustmentTrends[category];
    if (categoryTrend != null) {
      multiplier *= (1 + categoryTrend.averageAdjustment);
    }

    if ((multiplier - 1.0).abs() > 0.05) {
      return currentBudget * multiplier;
    }

    return null;
  }

  /// 批量上报样本
  Future<void> reportBatch(List<BudgetLearningSample> samples) async {
    for (final sample in samples) {
      await reportBudgetPattern(sample);
    }
  }
}

// ==================== 模式上报器 ====================

/// 预算模式上报器接口
abstract class BudgetPatternReporter {
  Future<void> report(SanitizedBudgetPattern pattern);
  Future<List<SanitizedBudgetPattern>> getAllPatterns();
}

/// 内存预算模式上报器
class InMemoryBudgetPatternReporter implements BudgetPatternReporter {
  final List<SanitizedBudgetPattern> _patterns = [];

  @override
  Future<void> report(SanitizedBudgetPattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<List<SanitizedBudgetPattern>> getAllPatterns() async {
    return List.unmodifiable(_patterns);
  }

  void clear() => _patterns.clear();
}

// ==================== 全局预算洞察聚合 ====================

/// 全局预算洞察聚合器
class GlobalBudgetInsightsAggregator {
  final BudgetPatternReporter _db;

  GlobalBudgetInsightsAggregator({BudgetPatternReporter? db})
      : _db = db ?? InMemoryBudgetPatternReporter();

  /// 聚合群体预算偏好
  Future<GlobalBudgetInsights> aggregate() async {
    final patterns = await _db.getAllPatterns();

    return GlobalBudgetInsights(
      // 各收入区间的平均预算分配比例
      incomeRangeBudgetRatios: _aggregateByIncomeRange(patterns),
      // 各分类的群体平均调整幅度
      categoryAdjustmentTrends: _aggregateByCategoryTrends(patterns),
      // 季节性预算变化趋势
      seasonalTrends: _aggregateSeasonalTrends(patterns),
      generatedAt: DateTime.now(),
    );
  }

  Map<String, Map<String, double>> _aggregateByIncomeRange(
    List<SanitizedBudgetPattern> patterns,
  ) {
    final result = <String, Map<String, double>>{};

    // 按收入区间分组
    final byIncome = groupBy(patterns, (p) => p.incomeRange);

    for (final incomeEntry in byIncome.entries) {
      final categoryRatios = <String, List<double>>{};

      for (final pattern in incomeEntry.value) {
        if (pattern.acceptanceRatio != null) {
          categoryRatios
              .putIfAbsent(pattern.categoryName, () => [])
              .add(pattern.acceptanceRatio!);
        }
      }

      // 计算每个分类的平均比例
      final averages = <String, double>{};
      for (final catEntry in categoryRatios.entries) {
        if (catEntry.value.isNotEmpty) {
          averages[catEntry.key] =
              catEntry.value.reduce((a, b) => a + b) / catEntry.value.length;
        }
      }

      result[incomeEntry.key] = averages;
    }

    // 添加默认预算比例建议
    _addDefaultRatios(result);

    return result;
  }

  void _addDefaultRatios(Map<String, Map<String, double>> result) {
    final defaultRatios = <String, double>{
      '餐饮': 0.15,
      '交通': 0.08,
      '购物': 0.10,
      '娱乐': 0.05,
      '居住': 0.25,
      '教育': 0.05,
      '医疗': 0.03,
      '其他': 0.05,
    };

    for (final incomeRange in ['0-5k', '5k-10k', '10k-20k', '20k-50k', '50k+']) {
      result.putIfAbsent(incomeRange, () => defaultRatios);
    }
  }

  Map<String, CategoryAdjustmentTrend> _aggregateByCategoryTrends(
    List<SanitizedBudgetPattern> patterns,
  ) {
    final result = <String, CategoryAdjustmentTrend>{};

    // 按分类分组
    final byCategory = groupBy(patterns, (p) => p.categoryName);

    for (final entry in byCategory.entries) {
      final adjustments = <double>[];
      final adjustTypes = <BudgetAdjustType, int>{};

      for (final pattern in entry.value) {
        if (pattern.acceptanceRatio != null) {
          adjustments.add(pattern.acceptanceRatio! - 1.0);
        }
        adjustTypes[pattern.adjustType] =
            (adjustTypes[pattern.adjustType] ?? 0) + 1;
      }

      if (adjustments.isNotEmpty) {
        final avgAdjustment =
            adjustments.reduce((a, b) => a + b) / adjustments.length;
        final mostCommon = adjustTypes.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

        result[entry.key] = CategoryAdjustmentTrend(
          categoryName: entry.key,
          averageAdjustment: avgAdjustment,
          mostCommonAdjust: mostCommon,
          sampleCount: entry.value.length,
        );
      }
    }

    return result;
  }

  Map<int, SeasonalTrend> _aggregateSeasonalTrends(
    List<SanitizedBudgetPattern> patterns,
  ) {
    final result = <int, SeasonalTrend>{};

    // 按月份分组
    final byMonth = groupBy(
      patterns.where((p) => p.month != null),
      (p) => p.month!,
    );

    for (final entry in byMonth.entries) {
      final adjustments = <double>[];
      final categorySpending = <String, int>{};

      for (final pattern in entry.value) {
        if (pattern.acceptanceRatio != null) {
          adjustments.add(pattern.acceptanceRatio!);
        }
        categorySpending[pattern.categoryName] =
            (categorySpending[pattern.categoryName] ?? 0) + 1;
      }

      if (adjustments.isNotEmpty) {
        final avgMultiplier =
            adjustments.reduce((a, b) => a + b) / adjustments.length;

        // 找出高消费分类（出现频率高的）
        final sortedCategories = categorySpending.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final highSpendingCategories =
            sortedCategories.take(3).map((e) => e.key).toList();

        result[entry.key] = SeasonalTrend(
          month: entry.key,
          adjustmentMultiplier: avgMultiplier,
          highSpendingCategories: highSpendingCategories,
        );
      }
    }

    // 添加默认季节性调整
    _addDefaultSeasonalTrends(result);

    return result;
  }

  void _addDefaultSeasonalTrends(Map<int, SeasonalTrend> result) {
    // 春节月份（1-2月）消费增加
    result.putIfAbsent(
      1,
      () => const SeasonalTrend(
        month: 1,
        adjustmentMultiplier: 1.3,
        highSpendingCategories: ['餐饮', '购物', '交通'],
      ),
    );
    result.putIfAbsent(
      2,
      () => const SeasonalTrend(
        month: 2,
        adjustmentMultiplier: 1.4,
        highSpendingCategories: ['餐饮', '购物', '娱乐'],
      ),
    );

    // 双11/双12（11-12月）购物增加
    result.putIfAbsent(
      11,
      () => const SeasonalTrend(
        month: 11,
        adjustmentMultiplier: 1.2,
        highSpendingCategories: ['购物', '餐饮'],
      ),
    );
    result.putIfAbsent(
      12,
      () => const SeasonalTrend(
        month: 12,
        adjustmentMultiplier: 1.25,
        highSpendingCategories: ['购物', '餐饮', '娱乐'],
      ),
    );

    // 开学季（9月）教育支出增加
    result.putIfAbsent(
      9,
      () => const SeasonalTrend(
        month: 9,
        adjustmentMultiplier: 1.1,
        highSpendingCategories: ['教育', '购物'],
      ),
    );
  }

  /// 为新用户提供参考预算
  Future<Map<String, double>> getReferenceBudget({
    required double monthlyIncome,
    required String region,
  }) async {
    final incomeRange = _getIncomeRange(monthlyIncome);
    final insights = await aggregate();

    final ratios = insights.incomeRangeBudgetRatios[incomeRange] ?? {};

    // 将比例转换为实际金额
    final budget = <String, double>{};
    for (final entry in ratios.entries) {
      budget[entry.key] = monthlyIncome * entry.value;
    }

    return budget;
  }

  String _getIncomeRange(double income) {
    if (income < 5000) return '0-5k';
    if (income < 10000) return '5k-10k';
    if (income < 20000) return '10k-20k';
    if (income < 50000) return '20k-50k';
    return '50k+';
  }
}

// ==================== 预算建议服务 ====================

/// 预算建议服务（整合协同学习）
class BudgetSuggestionService {
  final BudgetCollaborativeLearningService _collaborativeService;
  final List<BudgetLearningSample> _localSamples = [];

  BudgetSuggestionService({
    BudgetCollaborativeLearningService? collaborativeService,
  }) : _collaborativeService =
            collaborativeService ?? BudgetCollaborativeLearningService();

  /// 生成预算建议
  Future<BudgetSuggestion> suggestBudget({
    required String category,
    required double monthlyIncome,
    double? historicalAverage,
    int? month,
  }) async {
    // 1. 获取全局参考预算
    final referenceBudget = await _collaborativeService.getReferenceBudget(
      monthlyIncome: monthlyIncome,
    );
    final globalSuggestion = referenceBudget[category] ?? monthlyIncome * 0.1;

    // 2. 考虑历史平均
    double baseSuggestion = globalSuggestion;
    if (historicalAverage != null) {
      baseSuggestion = (globalSuggestion + historicalAverage) / 2;
    }

    // 3. 考虑季节性调整
    double seasonalMultiplier = 1.0;
    if (month != null) {
      final adjustedBudget =
          await _collaborativeService.getCategoryAdjustmentSuggestion(
        category,
        baseSuggestion,
        month,
      );
      if (adjustedBudget != null) {
        seasonalMultiplier = adjustedBudget / baseSuggestion;
      }
    }

    final finalSuggestion = baseSuggestion * seasonalMultiplier;

    return BudgetSuggestion(
      category: category,
      suggestedAmount: finalSuggestion,
      globalReference: globalSuggestion,
      seasonalMultiplier: seasonalMultiplier,
      confidence: _calculateConfidence(historicalAverage != null, month != null),
      reasoning: _generateReasoning(
        category,
        globalSuggestion,
        historicalAverage,
        seasonalMultiplier,
      ),
    );
  }

  double _calculateConfidence(bool hasHistory, bool hasSeasonal) {
    double confidence = 0.6;
    if (hasHistory) confidence += 0.2;
    if (hasSeasonal) confidence += 0.1;
    return confidence.clamp(0.0, 1.0);
  }

  String _generateReasoning(
    String category,
    double globalRef,
    double? history,
    double seasonalMult,
  ) {
    final parts = <String>[];

    parts.add('基于群体数据，$category类目建议预算为${globalRef.toStringAsFixed(0)}元');

    if (history != null) {
      parts.add('结合您的历史消费(${history.toStringAsFixed(0)}元)');
    }

    if ((seasonalMult - 1.0).abs() > 0.05) {
      if (seasonalMult > 1.0) {
        parts.add('当前月份消费偏高，建议适当增加预算');
      } else {
        parts.add('当前月份消费较低，建议适当减少预算');
      }
    }

    return '${parts.join('，')}。';
  }

  /// 记录用户对建议的反馈
  Future<void> recordFeedback(
    BudgetSuggestion suggestion,
    double? acceptedAmount,
    BudgetAdjustType adjustType,
  ) async {
    final sample = BudgetLearningSample(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'current_user', // 实际应从用户服务获取
      input: BudgetInput(
        categoryName: suggestion.category,
        monthlyIncome: suggestion.globalReference / 0.1, // 估算
        month: DateTime.now().month,
      ),
      suggestedAmount: suggestion.suggestedAmount,
      acceptedAmount: acceptedAmount,
      adjustType: adjustType,
      timestamp: DateTime.now(),
    );

    _localSamples.add(sample);

    // 上报到协同学习服务
    await _collaborativeService.reportBudgetPattern(sample);
  }
}

/// 预算建议
class BudgetSuggestion {
  final String category;
  final double suggestedAmount;
  final double globalReference;
  final double seasonalMultiplier;
  final double confidence;
  final String reasoning;

  const BudgetSuggestion({
    required this.category,
    required this.suggestedAmount,
    required this.globalReference,
    required this.seasonalMultiplier,
    required this.confidence,
    required this.reasoning,
  });

  Map<String, dynamic> toJson() => {
        'category': category,
        'suggested_amount': suggestedAmount,
        'global_reference': globalReference,
        'seasonal_multiplier': seasonalMultiplier,
        'confidence': confidence,
        'reasoning': reasoning,
      };
}
