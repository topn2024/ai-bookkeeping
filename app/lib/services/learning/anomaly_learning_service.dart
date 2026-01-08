import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart'; // ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ==================== 异常学习数据模型 ====================

/// 异常学习数据
class AnomalyLearningData {
  final String transactionId;
  final double amount;
  final String category;
  final DateTime date;
  final AnomalyType anomalyType;
  final AnomalyFeedback? feedback;
  final Map<String, dynamic> transactionContext;

  const AnomalyLearningData({
    required this.transactionId,
    required this.amount,
    required this.category,
    required this.date,
    required this.anomalyType,
    this.feedback,
    this.transactionContext = const {},
  });

  Map<String, dynamic> toJson() => {
        'transaction_id': transactionId,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'anomaly_type': anomalyType.name,
        'feedback': feedback?.name,
        'context': transactionContext,
      };
}

/// 异常类型
enum AnomalyType {
  unusualAmount, // 异常金额
  unusualTime, // 异常时间
  unusualFrequency, // 异常频率
  unusualLocation, // 异常位置
  unusualCategory, // 异常分类
  potentialDuplicate, // 可能重复
  combined, // 组合异常
}

/// 用户反馈
enum AnomalyFeedback {
  confirmed, // 确认是异常
  dismissed, // 忽略（正常消费）
  corrected, // 修正（错误识别）
}

/// 规则来源
enum AnomalyRuleSource {
  userLearned, // 从用户行为学习
  systemDefault, // 系统默认规则
}

/// 预测来源
enum AnomalyPredictionSource {
  learnedRule, // 学习规则命中
  profileInference, // 画像推理
  fallback, // 兜底策略
}

/// 学习阶段
enum AnomalyLearningStage {
  coldStart, // 冷启动
  collecting, // 样本收集中
  active, // 正常运行
}

/// 异常规则
class AnomalyRule {
  final String ruleId;
  final String pattern;
  final double confidence;
  final AnomalyRuleSource source;
  final AnomalyType targetType;
  final Map<String, dynamic> thresholds;
  final double falsePositiveRate;
  final int sampleCount;

  AnomalyRule({
    required this.ruleId,
    required this.pattern,
    required this.confidence,
    required this.source,
    required this.targetType,
    required this.thresholds,
    this.falsePositiveRate = 0.0,
    this.sampleCount = 0,
  });

  bool matchesTransaction(double amount, String category, DateTime time) {
    switch (targetType) {
      case AnomalyType.unusualAmount:
        final threshold = thresholds['amount_threshold'] as double?;
        return threshold != null && amount > threshold;
      case AnomalyType.unusualTime:
        final startHour = thresholds['start_hour'] as int?;
        final endHour = thresholds['end_hour'] as int?;
        if (startHour != null && endHour != null) {
          final hour = time.hour;
          return hour >= startHour || hour < endHour;
        }
        return false;
      case AnomalyType.unusualCategory:
        final unusualCategories =
            thresholds['unusual_categories'] as List<String>?;
        return unusualCategories?.contains(category) ?? false;
      default:
        return false;
    }
  }

  AnomalyRule copyWith({
    double? confidence,
    double? falsePositiveRate,
    int? sampleCount,
  }) {
    return AnomalyRule(
      ruleId: ruleId,
      pattern: pattern,
      confidence: confidence ?? this.confidence,
      source: source,
      targetType: targetType,
      thresholds: thresholds,
      falsePositiveRate: falsePositiveRate ?? this.falsePositiveRate,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }
}

// ==================== 异常检测结果 ====================

/// 异常检测结果
class AnomalyDetectionResult {
  final String transactionId;
  final bool isAnomaly;
  final AnomalyType? anomalyType;
  final double confidence;
  final AnomalyPredictionSource source;
  final String? explanation;
  final List<String> matchedRuleIds;

  const AnomalyDetectionResult({
    required this.transactionId,
    required this.isAnomaly,
    this.anomalyType,
    required this.confidence,
    required this.source,
    this.explanation,
    this.matchedRuleIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'transaction_id': transactionId,
        'is_anomaly': isAnomaly,
        'anomaly_type': anomalyType?.name,
        'confidence': confidence,
        'source': source.name,
        'explanation': explanation,
        'matched_rule_ids': matchedRuleIds,
      };
}

// ==================== 用户异常模式 ====================

/// 用户异常模式
class UserAnomalyProfile {
  final String userId;
  final Map<String, AmountStatistics> categoryStats;
  final Map<int, double> hourlySpendingPattern;
  final Map<int, double> weekdaySpendingPattern;
  final double globalAmountMean;
  final double globalAmountStd;
  final DateTime lastUpdated;

  UserAnomalyProfile({
    required this.userId,
    required this.categoryStats,
    required this.hourlySpendingPattern,
    required this.weekdaySpendingPattern,
    required this.globalAmountMean,
    required this.globalAmountStd,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// 计算金额异常分数（基于Z-score）
  double calculateAmountZScore(double amount, String category) {
    final stats = categoryStats[category];
    if (stats == null || stats.std == 0) {
      if (globalAmountStd == 0) return 0;
      return (amount - globalAmountMean) / globalAmountStd;
    }
    return (amount - stats.mean) / stats.std;
  }

  /// 计算时间异常分数
  double calculateTimeAnomalyScore(DateTime time) {
    final hourPattern = hourlySpendingPattern[time.hour] ?? 0;
    final weekdayPattern = weekdaySpendingPattern[time.weekday] ?? 0;

    if (hourPattern == 0 && weekdayPattern == 0) {
      return 1.0;
    }

    return 1.0 - (hourPattern * 0.6 + weekdayPattern * 0.4);
  }
}

/// 金额统计
class AmountStatistics {
  final double mean;
  final double std;
  final double min;
  final double max;
  final int count;

  const AmountStatistics({
    required this.mean,
    required this.std,
    required this.min,
    required this.max,
    required this.count,
  });
}

// ==================== 异常学习服务 ====================

/// 异常学习服务
class AnomalyLearningService {
  final AnomalyDataStore _dataStore;
  final Map<String, UserAnomalyProfile> _profileCache = {};
  final List<AnomalyRule> _learnedRules = [];

  // 配置
  static const int _minSamplesForLearning = 20;
  static const double _zScoreThreshold = 2.5;
  // ignore: unused_field
  static const double _confidenceThreshold = 0.7;

  String get moduleId => 'anomaly_learning';
  AnomalyLearningStage stage = AnomalyLearningStage.coldStart;
  double accuracy = 0.0;

  AnomalyLearningService({
    AnomalyDataStore? dataStore,
  }) : _dataStore = dataStore ?? InMemoryAnomalyDataStore();

  /// 学习异常数据
  Future<void> learn(AnomalyLearningData data) async {
    await _dataStore.saveData(data);

    // 更新用户画像
    await _updateUserProfile(data);

    // 检查学习阶段
    final sampleCount =
        await _dataStore.getDataCount(userId: _extractUserId(data.transactionId));
    if (sampleCount >= _minSamplesForLearning &&
        stage == AnomalyLearningStage.coldStart) {
      stage = AnomalyLearningStage.collecting;
    }

    if (sampleCount >= _minSamplesForLearning * 2) {
      await _triggerRuleLearning(_extractUserId(data.transactionId));
      stage = AnomalyLearningStage.active;
    }
  }

  String _extractUserId(String transactionId) {
    final parts = transactionId.split('_');
    return parts.isNotEmpty ? parts.first : 'default';
  }

  /// 更新用户画像
  Future<void> _updateUserProfile(AnomalyLearningData data) async {
    final userId = _extractUserId(data.transactionId);
    final allData = await _dataStore.getUserData(userId, months: 6);

    if (allData.isEmpty) return;

    // 计算分类统计
    final categoryStats = <String, AmountStatistics>{};
    final byCategory = groupBy(allData, (d) => d.category);

    for (final entry in byCategory.entries) {
      final amounts = entry.value.map((d) => d.amount).toList();
      categoryStats[entry.key] = _calculateStats(amounts);
    }

    // 计算时间模式
    final hourlyPattern = <int, double>{};
    final weekdayPattern = <int, double>{};

    for (final d in allData) {
      hourlyPattern[d.date.hour] = (hourlyPattern[d.date.hour] ?? 0) + 1;
      weekdayPattern[d.date.weekday] = (weekdayPattern[d.date.weekday] ?? 0) + 1;
    }

    // 归一化
    final hourTotal = hourlyPattern.values.fold(0.0, (a, b) => a + b);
    final weekdayTotal = weekdayPattern.values.fold(0.0, (a, b) => a + b);

    if (hourTotal > 0) {
      for (final key in hourlyPattern.keys) {
        hourlyPattern[key] = hourlyPattern[key]! / hourTotal;
      }
    }
    if (weekdayTotal > 0) {
      for (final key in weekdayPattern.keys) {
        weekdayPattern[key] = weekdayPattern[key]! / weekdayTotal;
      }
    }

    // 计算全局统计
    final allAmounts = allData.map((d) => d.amount).toList();
    final globalStats = _calculateStats(allAmounts);

    _profileCache[userId] = UserAnomalyProfile(
      userId: userId,
      categoryStats: categoryStats,
      hourlySpendingPattern: hourlyPattern,
      weekdaySpendingPattern: weekdayPattern,
      globalAmountMean: globalStats.mean,
      globalAmountStd: globalStats.std,
    );
  }

  AmountStatistics _calculateStats(List<double> values) {
    if (values.isEmpty) {
      return const AmountStatistics(mean: 0, std: 0, min: 0, max: 0, count: 0);
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;
    final std = math.sqrt(variance);

    return AmountStatistics(
      mean: mean,
      std: std,
      min: values.reduce(math.min),
      max: values.reduce(math.max),
      count: values.length,
    );
  }

  /// 触发规则学习
  Future<void> _triggerRuleLearning(String userId) async {
    final allData = await _dataStore.getUserData(userId, months: 6);
    final confirmedAnomalies =
        allData.where((d) => d.feedback == AnomalyFeedback.confirmed).toList();
    final dismissedAnomalies =
        allData.where((d) => d.feedback == AnomalyFeedback.dismissed).toList();

    if (confirmedAnomalies.isEmpty) return;

    // 分析确认的异常，提取模式
    await _learnAmountRules(confirmedAnomalies, dismissedAnomalies);
    await _learnTimeRules(confirmedAnomalies, dismissedAnomalies);
    await _learnCategoryRules(confirmedAnomalies, dismissedAnomalies);

    debugPrint('Learned ${_learnedRules.length} anomaly rules for user: $userId');
  }

  Future<void> _learnAmountRules(
    List<AnomalyLearningData> confirmed,
    List<AnomalyLearningData> dismissed,
  ) async {
    final amountAnomalies =
        confirmed.where((d) => d.anomalyType == AnomalyType.unusualAmount).toList();

    if (amountAnomalies.isEmpty) return;

    final amounts = amountAnomalies.map((d) => d.amount).toList();
    final threshold = amounts.reduce(math.min) * 0.9;

    final falsePositives =
        dismissed.where((d) => d.amount >= threshold).length;
    final falsePositiveRate =
        dismissed.isEmpty ? 0.0 : falsePositives / dismissed.length;

    final rule = AnomalyRule(
      ruleId: 'amount_${DateTime.now().millisecondsSinceEpoch}',
      pattern: 'amount > $threshold',
      confidence: 1.0 - falsePositiveRate,
      source: AnomalyRuleSource.userLearned,
      targetType: AnomalyType.unusualAmount,
      thresholds: {'amount_threshold': threshold},
      falsePositiveRate: falsePositiveRate,
      sampleCount: amountAnomalies.length,
    );

    _learnedRules.add(rule);
  }

  Future<void> _learnTimeRules(
    List<AnomalyLearningData> confirmed,
    List<AnomalyLearningData> dismissed,
  ) async {
    final timeAnomalies =
        confirmed.where((d) => d.anomalyType == AnomalyType.unusualTime).toList();

    if (timeAnomalies.isEmpty) return;

    final hours = timeAnomalies.map((d) => d.date.hour).toList();
    final hourCounts = <int, int>{};
    for (final h in hours) {
      hourCounts[h] = (hourCounts[h] ?? 0) + 1;
    }

    final sortedHours = hourCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedHours.isNotEmpty) {
      final peakHour = sortedHours.first.key;

      final rule = AnomalyRule(
        ruleId: 'time_${DateTime.now().millisecondsSinceEpoch}',
        pattern: 'hour around $peakHour',
        confidence: 0.8,
        source: AnomalyRuleSource.userLearned,
        targetType: AnomalyType.unusualTime,
        thresholds: {
          'start_hour': (peakHour - 1 + 24) % 24,
          'end_hour': (peakHour + 2) % 24,
        },
        sampleCount: timeAnomalies.length,
      );

      _learnedRules.add(rule);
    }
  }

  Future<void> _learnCategoryRules(
    List<AnomalyLearningData> confirmed,
    List<AnomalyLearningData> dismissed,
  ) async {
    final categoryAnomalies = confirmed
        .where((d) => d.anomalyType == AnomalyType.unusualCategory)
        .toList();

    if (categoryAnomalies.isEmpty) return;

    final categoryCounts = <String, int>{};
    for (final d in categoryAnomalies) {
      categoryCounts[d.category] = (categoryCounts[d.category] ?? 0) + 1;
    }

    final unusualCategories = categoryCounts.entries
        .where((e) => e.value >= 2)
        .map((e) => e.key)
        .toList();

    if (unusualCategories.isNotEmpty) {
      final rule = AnomalyRule(
        ruleId: 'category_${DateTime.now().millisecondsSinceEpoch}',
        pattern: 'category in $unusualCategories',
        confidence: 0.75,
        source: AnomalyRuleSource.userLearned,
        targetType: AnomalyType.unusualCategory,
        thresholds: {'unusual_categories': unusualCategories},
        sampleCount: categoryAnomalies.length,
      );

      _learnedRules.add(rule);
    }
  }

  /// 检测异常
  Future<AnomalyDetectionResult> detectAnomaly({
    required String transactionId,
    required double amount,
    required String category,
    required DateTime time,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _extractUserId(transactionId);

    // 1. 尝试用学习的规则匹配
    for (final rule in _learnedRules) {
      if (rule.matchesTransaction(amount, category, time)) {
        return AnomalyDetectionResult(
          transactionId: transactionId,
          isAnomaly: true,
          anomalyType: rule.targetType,
          confidence: rule.confidence,
          source: AnomalyPredictionSource.learnedRule,
          explanation: _generateExplanation(rule),
          matchedRuleIds: [rule.ruleId],
        );
      }
    }

    // 2. 用用户画像检测
    final profile = _profileCache[effectiveUserId];
    if (profile != null) {
      final zScore = profile.calculateAmountZScore(amount, category);
      final timeScore = profile.calculateTimeAnomalyScore(time);

      if (zScore.abs() > _zScoreThreshold) {
        return AnomalyDetectionResult(
          transactionId: transactionId,
          isAnomaly: true,
          anomalyType: AnomalyType.unusualAmount,
          confidence: _zScoreToConfidence(zScore),
          source: AnomalyPredictionSource.profileInference,
          explanation: '金额显著高于您的日常消费',
        );
      }

      if (timeScore > 0.8) {
        return AnomalyDetectionResult(
          transactionId: transactionId,
          isAnomaly: true,
          anomalyType: AnomalyType.unusualTime,
          confidence: timeScore,
          source: AnomalyPredictionSource.profileInference,
          explanation: '在您不常消费的时段发生',
        );
      }
    }

    // 3. 无异常
    return AnomalyDetectionResult(
      transactionId: transactionId,
      isAnomaly: false,
      confidence: 0.9,
      source: AnomalyPredictionSource.fallback,
    );
  }

  double _zScoreToConfidence(double zScore) {
    final absZ = zScore.abs();
    if (absZ > 4) return 0.99;
    if (absZ > 3) return 0.95;
    if (absZ > 2.5) return 0.85;
    return 0.7;
  }

  String _generateExplanation(AnomalyRule rule) {
    switch (rule.targetType) {
      case AnomalyType.unusualAmount:
        return '金额显著高于您的日常消费';
      case AnomalyType.unusualTime:
        return '在您不常消费的时段发生';
      case AnomalyType.unusualCategory:
        return '该分类消费对您来说不常见';
      case AnomalyType.unusualFrequency:
        return '消费频率异常';
      default:
        return '检测到异常消费模式';
    }
  }

  /// 用户反馈
  Future<void> feedback(AnomalyLearningData data, bool positive) async {
    final updatedData = AnomalyLearningData(
      transactionId: data.transactionId,
      amount: data.amount,
      category: data.category,
      date: data.date,
      anomalyType: data.anomalyType,
      feedback: positive ? AnomalyFeedback.confirmed : AnomalyFeedback.dismissed,
      transactionContext: data.transactionContext,
    );

    await _dataStore.saveData(updatedData);

    // 更新规则置信度
    if (!positive) {
      for (int i = 0; i < _learnedRules.length; i++) {
        if (_learnedRules[i].targetType == data.anomalyType) {
          _learnedRules[i] = _learnedRules[i].copyWith(
            confidence: _learnedRules[i].confidence * 0.95,
            falsePositiveRate: _learnedRules[i].falsePositiveRate + 0.01,
          );
        }
      }
    }

    await _updateAccuracy();
  }

  Future<void> _updateAccuracy() async {
    final recentData = await _dataStore.getRecentData(limit: 100);
    final withFeedback = recentData.where((d) => d.feedback != null).toList();

    if (withFeedback.isEmpty) return;

    final correct = withFeedback.where((d) {
      final wasAnomaly = d.anomalyType != AnomalyType.combined;
      final userConfirmed = d.feedback == AnomalyFeedback.confirmed;
      return wasAnomaly == userConfirmed;
    }).length;

    accuracy = correct / withFeedback.length;
  }

  /// 导出规则
  Future<List<AnomalyRule>> exportRules() async {
    return List.unmodifiable(_learnedRules);
  }

  /// 获取统计信息
  Future<AnomalyLearningStats> getStats() async {
    return AnomalyLearningStats(
      moduleId: moduleId,
      stage: stage,
      accuracy: accuracy,
      rulesCount: _learnedRules.length,
      profilesCached: _profileCache.length,
    );
  }

  /// 获取用户画像
  Future<UserAnomalyProfile?> getUserProfile(String userId) async {
    return _profileCache[userId];
  }
}

/// 异常学习统计
class AnomalyLearningStats {
  final String moduleId;
  final AnomalyLearningStage stage;
  final double accuracy;
  final int rulesCount;
  final int profilesCached;

  const AnomalyLearningStats({
    required this.moduleId,
    required this.stage,
    required this.accuracy,
    required this.rulesCount,
    required this.profilesCached,
  });
}

// ==================== 数据存储 ====================

/// 异常数据存储接口
abstract class AnomalyDataStore {
  Future<void> saveData(AnomalyLearningData data);
  Future<List<AnomalyLearningData>> getUserData(String userId, {int? months});
  Future<List<AnomalyLearningData>> getRecentData({int limit = 100});
  Future<int> getDataCount({String? userId});
}

/// 内存异常数据存储
class InMemoryAnomalyDataStore implements AnomalyDataStore {
  final List<AnomalyLearningData> _data = [];

  @override
  Future<void> saveData(AnomalyLearningData data) async {
    final index = _data.indexWhere((d) => d.transactionId == data.transactionId);
    if (index >= 0) {
      _data[index] = data;
    } else {
      _data.add(data);
    }
  }

  @override
  Future<List<AnomalyLearningData>> getUserData(
    String userId, {
    int? months,
  }) async {
    var result = _data.where((d) => d.transactionId.startsWith(userId));

    if (months != null) {
      final cutoff = DateTime.now().subtract(Duration(days: months * 30));
      result = result.where((d) => d.date.isAfter(cutoff));
    }

    return result.toList();
  }

  @override
  Future<List<AnomalyLearningData>> getRecentData({int limit = 100}) async {
    final sorted = _data.toList()..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  @override
  Future<int> getDataCount({String? userId}) async {
    if (userId == null) return _data.length;
    return _data.where((d) => d.transactionId.startsWith(userId)).length;
  }

  void clear() => _data.clear();
}

// ==================== 脱敏数据模型（协同学习） ====================

/// 脱敏后的异常模式
class SanitizedAnomalyPattern {
  /// 异常类型
  final AnomalyType anomalyType;

  /// 金额区间
  final String amountRange;

  /// 分类（脱敏后）
  final String categoryGroup;

  /// 时段
  final int? hour;

  /// 星期几
  final int? dayOfWeek;

  /// 用户反馈
  final AnomalyFeedback? feedback;

  /// 异常分数区间
  final String anomalyScoreRange;

  /// 用户哈希
  final String userHash;

  /// 时间戳
  final DateTime timestamp;

  const SanitizedAnomalyPattern({
    required this.anomalyType,
    required this.amountRange,
    required this.categoryGroup,
    this.hour,
    this.dayOfWeek,
    this.feedback,
    required this.anomalyScoreRange,
    required this.userHash,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'anomaly_type': anomalyType.name,
        'amount_range': amountRange,
        'category_group': categoryGroup,
        'hour': hour,
        'day_of_week': dayOfWeek,
        'feedback': feedback?.name,
        'anomaly_score_range': anomalyScoreRange,
        'user_hash': userHash,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SanitizedAnomalyPattern.fromJson(Map<String, dynamic> json) {
    return SanitizedAnomalyPattern(
      anomalyType: AnomalyType.values.firstWhere(
        (t) => t.name == json['anomaly_type'],
        orElse: () => AnomalyType.unusualAmount,
      ),
      amountRange: json['amount_range'] as String,
      categoryGroup: json['category_group'] as String,
      hour: json['hour'] as int?,
      dayOfWeek: json['day_of_week'] as int?,
      feedback: json['feedback'] != null
          ? AnomalyFeedback.values.firstWhere(
              (f) => f.name == json['feedback'],
              orElse: () => AnomalyFeedback.dismissed,
            )
          : null,
      anomalyScoreRange: json['anomaly_score_range'] as String,
      userHash: json['user_hash'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

// ==================== 全局异常洞察 ====================

/// 全局异常洞察
class GlobalAnomalyInsights {
  /// 各异常类型分布
  final Map<AnomalyType, double> typeDistribution;

  /// 各金额区间的异常率
  final Map<String, double> amountRangeAnomalyRate;

  /// 各时段的异常率
  final Map<int, double> hourlyAnomalyRate;

  /// 各分类组的异常阈值参考
  final Map<String, CategoryAnomalyThreshold> categoryThresholds;

  /// 全局误报率
  final double globalFalsePositiveRate;

  /// 热门异常模式
  final List<PopularAnomalyPattern> popularPatterns;

  /// 新型异常警告
  final List<EmergingAnomalyAlert> emergingAlerts;

  /// 生成时间
  final DateTime generatedAt;

  const GlobalAnomalyInsights({
    required this.typeDistribution,
    required this.amountRangeAnomalyRate,
    required this.hourlyAnomalyRate,
    required this.categoryThresholds,
    required this.globalFalsePositiveRate,
    required this.popularPatterns,
    required this.emergingAlerts,
    required this.generatedAt,
  });
}

/// 分类异常阈值
class CategoryAnomalyThreshold {
  final String categoryGroup;
  final double avgThreshold;
  final double p90Threshold;
  final double p99Threshold;
  final int sampleCount;

  const CategoryAnomalyThreshold({
    required this.categoryGroup,
    required this.avgThreshold,
    required this.p90Threshold,
    required this.p99Threshold,
    required this.sampleCount,
  });
}

/// 热门异常模式
class PopularAnomalyPattern {
  final AnomalyType type;
  final String description;
  final double frequency;
  final double confirmRate;

  const PopularAnomalyPattern({
    required this.type,
    required this.description,
    required this.frequency,
    required this.confirmRate,
  });
}

/// 新型异常警告
class EmergingAnomalyAlert {
  final String alertId;
  final String title;
  final String description;
  final AnomalyType relatedType;
  final double riskLevel;
  final DateTime detectedAt;

  const EmergingAnomalyAlert({
    required this.alertId,
    required this.title,
    required this.description,
    required this.relatedType,
    required this.riskLevel,
    required this.detectedAt,
  });
}

// ==================== 异常协同学习服务 ====================

/// 异常协同学习服务
class AnomalyCollaborativeLearningService {
  final GlobalAnomalyInsightsAggregator _aggregator;
  final AnomalyPatternReporter _reporter;
  final String _currentUserId;

  // 本地缓存
  GlobalAnomalyInsights? _insightsCache;
  DateTime? _lastInsightsUpdate;

  // 配置
  static const Duration _cacheExpiry = Duration(hours: 12);
  // ignore: unused_field
  static const double _privacyEpsilon = 0.1;

  AnomalyCollaborativeLearningService({
    GlobalAnomalyInsightsAggregator? aggregator,
    AnomalyPatternReporter? reporter,
    String? currentUserId,
  })  : _aggregator = aggregator ?? GlobalAnomalyInsightsAggregator(),
        _reporter = reporter ?? InMemoryAnomalyPatternReporter(),
        _currentUserId = currentUserId ?? 'anonymous';

  /// 上报异常模式（隐私保护）
  Future<void> reportAnomalyPattern(AnomalyLearningData data) async {
    final pattern = SanitizedAnomalyPattern(
      anomalyType: data.anomalyType,
      amountRange: _getAmountRange(data.amount),
      categoryGroup: _getCategoryGroup(data.category),
      hour: data.date.hour,
      dayOfWeek: data.date.weekday,
      feedback: data.feedback,
      anomalyScoreRange: _getAnomalyScoreRange(data.amount),
      userHash: _hashValue(_currentUserId),
      timestamp: DateTime.now(),
    );

    await _reporter.report(pattern);
    debugPrint('Reported anomaly pattern: ${pattern.anomalyType.name}');
  }

  /// 金额区间化（保护隐私）
  String _getAmountRange(double amount) {
    if (amount < 50) return '0-50';
    if (amount < 100) return '50-100';
    if (amount < 200) return '100-200';
    if (amount < 500) return '200-500';
    if (amount < 1000) return '500-1000';
    if (amount < 2000) return '1000-2000';
    if (amount < 5000) return '2000-5000';
    return '5000+';
  }

  /// 分类组化（保护隐私）
  String _getCategoryGroup(String category) {
    // 将具体分类映射到大类
    final categoryMapping = {
      '餐饮': 'daily_expense',
      '交通': 'daily_expense',
      '购物': 'shopping',
      '娱乐': 'entertainment',
      '医疗': 'healthcare',
      '教育': 'education',
      '转账': 'transfer',
      '理财': 'investment',
    };
    return categoryMapping[category] ?? 'other';
  }

  /// 异常分数区间化
  String _getAnomalyScoreRange(double amount) {
    // 简化实现：基于金额估算异常分数区间
    if (amount < 100) return 'low';
    if (amount < 500) return 'medium';
    if (amount < 2000) return 'high';
    return 'very_high';
  }

  String _hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// 获取全局异常洞察
  Future<GlobalAnomalyInsights> getGlobalInsights({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _insightsCache != null &&
        _lastInsightsUpdate != null &&
        DateTime.now().difference(_lastInsightsUpdate!) < _cacheExpiry) {
      return _insightsCache!;
    }

    _insightsCache = await _aggregator.aggregate();
    _lastInsightsUpdate = DateTime.now();
    return _insightsCache!;
  }

  /// 获取分类的全局异常阈值
  Future<CategoryAnomalyThreshold?> getCategoryThreshold(String category) async {
    final insights = await getGlobalInsights();
    final categoryGroup = _getCategoryGroup(category);
    return insights.categoryThresholds[categoryGroup];
  }

  /// 检查是否为新型异常模式
  Future<EmergingAnomalyAlert?> checkEmergingAnomaly(AnomalyLearningData data) async {
    final insights = await getGlobalInsights();

    // 检查是否匹配任何新型异常警告
    for (final alert in insights.emergingAlerts) {
      if (alert.relatedType == data.anomalyType && alert.riskLevel > 0.7) {
        return alert;
      }
    }

    return null;
  }

  /// 获取同类用户的异常率对比
  Future<AnomalyComparison> compareToPopulation(
    String categoryGroup,
    double userAnomalyRate,
  ) async {
    final insights = await getGlobalInsights();

    // 计算该分类组的全局平均异常率
    double globalRate = 0.1; // 默认值
    final threshold = insights.categoryThresholds[categoryGroup];
    if (threshold != null) {
      globalRate = threshold.avgThreshold > 0 ? 0.1 : 0.05;
    }

    // 计算百分位
    int percentile;
    String recommendation;

    if (userAnomalyRate < globalRate * 0.5) {
      percentile = 90;
      recommendation = '您的异常率低于90%的用户，消费非常规律';
    } else if (userAnomalyRate < globalRate) {
      percentile = 70;
      recommendation = '您的异常率处于正常水平';
    } else if (userAnomalyRate < globalRate * 1.5) {
      percentile = 40;
      recommendation = '您的异常率略高于平均，建议关注消费规律';
    } else {
      percentile = 20;
      recommendation = '您的异常率较高，建议仔细审查近期消费';
    }

    return AnomalyComparison(
      categoryGroup: categoryGroup,
      userAnomalyRate: userAnomalyRate,
      globalAnomalyRate: globalRate,
      percentile: percentile,
      recommendation: recommendation,
    );
  }

  /// 批量上报
  Future<void> reportBatch(List<AnomalyLearningData> dataList) async {
    for (final data in dataList) {
      await reportAnomalyPattern(data);
    }
  }

  /// 获取热门异常模式
  Future<List<PopularAnomalyPattern>> getPopularPatterns() async {
    final insights = await getGlobalInsights();
    return insights.popularPatterns;
  }

  /// 获取新型异常警告
  Future<List<EmergingAnomalyAlert>> getEmergingAlerts() async {
    final insights = await getGlobalInsights();
    return insights.emergingAlerts;
  }
}

/// 异常对比结果
class AnomalyComparison {
  final String categoryGroup;
  final double userAnomalyRate;
  final double globalAnomalyRate;
  final int percentile;
  final String recommendation;

  const AnomalyComparison({
    required this.categoryGroup,
    required this.userAnomalyRate,
    required this.globalAnomalyRate,
    required this.percentile,
    required this.recommendation,
  });
}

// ==================== 模式上报器 ====================

/// 异常模式上报器接口
abstract class AnomalyPatternReporter {
  Future<void> report(SanitizedAnomalyPattern pattern);
  Future<List<SanitizedAnomalyPattern>> getAllPatterns();
}

/// 内存异常模式上报器
class InMemoryAnomalyPatternReporter implements AnomalyPatternReporter {
  final List<SanitizedAnomalyPattern> _patterns = [];

  @override
  Future<void> report(SanitizedAnomalyPattern pattern) async {
    _patterns.add(pattern);
  }

  @override
  Future<List<SanitizedAnomalyPattern>> getAllPatterns() async {
    return List.unmodifiable(_patterns);
  }

  void clear() => _patterns.clear();
}

// ==================== 全局异常洞察聚合 ====================

/// 全局异常洞察聚合器
class GlobalAnomalyInsightsAggregator {
  final AnomalyPatternReporter _db;

  GlobalAnomalyInsightsAggregator({AnomalyPatternReporter? db})
      : _db = db ?? InMemoryAnomalyPatternReporter();

  Future<GlobalAnomalyInsights> aggregate() async {
    final patterns = await _db.getAllPatterns();

    return GlobalAnomalyInsights(
      typeDistribution: _aggregateTypeDistribution(patterns),
      amountRangeAnomalyRate: _aggregateAmountRangeAnomalyRate(patterns),
      hourlyAnomalyRate: _aggregateHourlyAnomalyRate(patterns),
      categoryThresholds: _aggregateCategoryThresholds(patterns),
      globalFalsePositiveRate: _calculateGlobalFalsePositiveRate(patterns),
      popularPatterns: _aggregatePopularPatterns(patterns),
      emergingAlerts: _detectEmergingAlerts(patterns),
      generatedAt: DateTime.now(),
    );
  }

  Map<AnomalyType, double> _aggregateTypeDistribution(
    List<SanitizedAnomalyPattern> patterns,
  ) {
    if (patterns.isEmpty) return _getDefaultTypeDistribution();

    final counts = <AnomalyType, int>{};
    for (final p in patterns) {
      counts[p.anomalyType] = (counts[p.anomalyType] ?? 0) + 1;
    }

    final total = patterns.length;
    return counts.map((k, v) => MapEntry(k, v / total));
  }

  Map<AnomalyType, double> _getDefaultTypeDistribution() {
    return {
      AnomalyType.unusualAmount: 0.45,
      AnomalyType.unusualTime: 0.20,
      AnomalyType.unusualFrequency: 0.15,
      AnomalyType.unusualCategory: 0.10,
      AnomalyType.potentialDuplicate: 0.08,
      AnomalyType.unusualLocation: 0.02,
    };
  }

  Map<String, double> _aggregateAmountRangeAnomalyRate(
    List<SanitizedAnomalyPattern> patterns,
  ) {
    if (patterns.isEmpty) {
      return {
        '0-50': 0.02,
        '50-100': 0.03,
        '100-200': 0.05,
        '200-500': 0.08,
        '500-1000': 0.12,
        '1000-2000': 0.18,
        '2000-5000': 0.25,
        '5000+': 0.35,
      };
    }

    final rangeCounts = <String, int>{};
    final rangeConfirmed = <String, int>{};

    for (final p in patterns) {
      rangeCounts[p.amountRange] = (rangeCounts[p.amountRange] ?? 0) + 1;
      if (p.feedback == AnomalyFeedback.confirmed) {
        rangeConfirmed[p.amountRange] = (rangeConfirmed[p.amountRange] ?? 0) + 1;
      }
    }

    final result = <String, double>{};
    for (final entry in rangeCounts.entries) {
      final confirmed = rangeConfirmed[entry.key] ?? 0;
      result[entry.key] = confirmed / entry.value;
    }

    return result;
  }

  Map<int, double> _aggregateHourlyAnomalyRate(
    List<SanitizedAnomalyPattern> patterns,
  ) {
    if (patterns.isEmpty) {
      // 默认：深夜和凌晨异常率较高
      return {
        0: 0.25, 1: 0.30, 2: 0.35, 3: 0.35, 4: 0.30, 5: 0.20,
        6: 0.10, 7: 0.05, 8: 0.05, 9: 0.05, 10: 0.05, 11: 0.05,
        12: 0.08, 13: 0.05, 14: 0.05, 15: 0.05, 16: 0.05, 17: 0.05,
        18: 0.08, 19: 0.08, 20: 0.10, 21: 0.12, 22: 0.15, 23: 0.20,
      };
    }

    final hourCounts = <int, int>{};
    final hourConfirmed = <int, int>{};

    for (final p in patterns) {
      if (p.hour != null) {
        hourCounts[p.hour!] = (hourCounts[p.hour!] ?? 0) + 1;
        if (p.feedback == AnomalyFeedback.confirmed) {
          hourConfirmed[p.hour!] = (hourConfirmed[p.hour!] ?? 0) + 1;
        }
      }
    }

    final result = <int, double>{};
    for (int h = 0; h < 24; h++) {
      final total = hourCounts[h] ?? 1;
      final confirmed = hourConfirmed[h] ?? 0;
      result[h] = confirmed / total;
    }

    return result;
  }

  Map<String, CategoryAnomalyThreshold> _aggregateCategoryThresholds(
    List<SanitizedAnomalyPattern> patterns,
  ) {
    final thresholds = <String, CategoryAnomalyThreshold>{};

    final byCategory = groupBy(patterns, (p) => p.categoryGroup);

    for (final entry in byCategory.entries) {
      if (entry.value.length >= 5) {
        // 根据金额区间估算阈值
        final amountEstimates = entry.value.map((p) {
          switch (p.amountRange) {
            case '0-50': return 25.0;
            case '50-100': return 75.0;
            case '100-200': return 150.0;
            case '200-500': return 350.0;
            case '500-1000': return 750.0;
            case '1000-2000': return 1500.0;
            case '2000-5000': return 3500.0;
            default: return 7500.0;
          }
        }).toList()..sort();

        final avgThreshold = amountEstimates.reduce((a, b) => a + b) / amountEstimates.length;
        final p90Index = (amountEstimates.length * 0.9).floor();
        final p99Index = (amountEstimates.length * 0.99).floor();

        thresholds[entry.key] = CategoryAnomalyThreshold(
          categoryGroup: entry.key,
          avgThreshold: avgThreshold,
          p90Threshold: amountEstimates[p90Index.clamp(0, amountEstimates.length - 1)],
          p99Threshold: amountEstimates[p99Index.clamp(0, amountEstimates.length - 1)],
          sampleCount: entry.value.length,
        );
      }
    }

    // 添加默认阈值
    _addDefaultCategoryThresholds(thresholds);

    return thresholds;
  }

  void _addDefaultCategoryThresholds(Map<String, CategoryAnomalyThreshold> thresholds) {
    final defaults = {
      'daily_expense': const CategoryAnomalyThreshold(
        categoryGroup: 'daily_expense',
        avgThreshold: 200,
        p90Threshold: 500,
        p99Threshold: 1000,
        sampleCount: 100,
      ),
      'shopping': const CategoryAnomalyThreshold(
        categoryGroup: 'shopping',
        avgThreshold: 500,
        p90Threshold: 2000,
        p99Threshold: 5000,
        sampleCount: 100,
      ),
      'entertainment': const CategoryAnomalyThreshold(
        categoryGroup: 'entertainment',
        avgThreshold: 300,
        p90Threshold: 1000,
        p99Threshold: 3000,
        sampleCount: 100,
      ),
      'transfer': const CategoryAnomalyThreshold(
        categoryGroup: 'transfer',
        avgThreshold: 1000,
        p90Threshold: 5000,
        p99Threshold: 20000,
        sampleCount: 100,
      ),
    };

    for (final entry in defaults.entries) {
      thresholds.putIfAbsent(entry.key, () => entry.value);
    }
  }

  double _calculateGlobalFalsePositiveRate(List<SanitizedAnomalyPattern> patterns) {
    if (patterns.isEmpty) return 0.15;

    final withFeedback = patterns.where((p) => p.feedback != null).toList();
    if (withFeedback.isEmpty) return 0.15;

    final dismissed = withFeedback.where((p) => p.feedback == AnomalyFeedback.dismissed).length;
    return dismissed / withFeedback.length;
  }

  List<PopularAnomalyPattern> _aggregatePopularPatterns(
    List<SanitizedAnomalyPattern> patterns,
  ) {
    if (patterns.isEmpty) {
      return [
        const PopularAnomalyPattern(
          type: AnomalyType.unusualAmount,
          description: '大额消费异常',
          frequency: 0.45,
          confirmRate: 0.70,
        ),
        const PopularAnomalyPattern(
          type: AnomalyType.unusualTime,
          description: '深夜消费',
          frequency: 0.20,
          confirmRate: 0.50,
        ),
        const PopularAnomalyPattern(
          type: AnomalyType.potentialDuplicate,
          description: '疑似重复交易',
          frequency: 0.15,
          confirmRate: 0.85,
        ),
      ];
    }

    final byType = groupBy(patterns, (p) => p.anomalyType);
    final total = patterns.length;

    final popularPatterns = byType.entries.map((entry) {
      final confirmedCount = entry.value
          .where((p) => p.feedback == AnomalyFeedback.confirmed)
          .length;
      final withFeedbackCount = entry.value.where((p) => p.feedback != null).length;

      return PopularAnomalyPattern(
        type: entry.key,
        description: _getTypeDescription(entry.key),
        frequency: entry.value.length / total,
        confirmRate: withFeedbackCount > 0 ? confirmedCount / withFeedbackCount : 0.5,
      );
    }).toList();

    popularPatterns.sort((a, b) => b.frequency.compareTo(a.frequency));
    return popularPatterns.take(5).toList();
  }

  String _getTypeDescription(AnomalyType type) {
    switch (type) {
      case AnomalyType.unusualAmount:
        return '大额消费异常';
      case AnomalyType.unusualTime:
        return '异常时段消费';
      case AnomalyType.unusualFrequency:
        return '异常消费频率';
      case AnomalyType.unusualLocation:
        return '异常消费地点';
      case AnomalyType.unusualCategory:
        return '异常消费分类';
      case AnomalyType.potentialDuplicate:
        return '疑似重复交易';
      case AnomalyType.combined:
        return '多因素异常';
    }
  }

  List<EmergingAnomalyAlert> _detectEmergingAlerts(
    List<SanitizedAnomalyPattern> patterns,
  ) {
    final alerts = <EmergingAnomalyAlert>[];

    if (patterns.isEmpty) return alerts;

    // 检测最近7天的异常模式变化
    final recentPatterns = patterns
        .where((p) => p.timestamp.isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .toList();

    if (recentPatterns.isEmpty) return alerts;

    // 检测异常激增
    final recentByType = groupBy(recentPatterns, (p) => p.anomalyType);
    final olderPatterns = patterns
        .where((p) => p.timestamp.isBefore(DateTime.now().subtract(const Duration(days: 7))))
        .toList();
    final olderByType = groupBy(olderPatterns, (p) => p.anomalyType);

    for (final entry in recentByType.entries) {
      final recentRate = entry.value.length / math.max(1, recentPatterns.length);
      final olderCount = olderByType[entry.key]?.length ?? 0;
      final olderRate = olderCount / math.max(1, olderPatterns.length);

      // 如果某类型异常率增加了50%以上
      if (olderRate > 0 && recentRate > olderRate * 1.5) {
        alerts.add(EmergingAnomalyAlert(
          alertId: 'emerging_${entry.key.name}_${DateTime.now().millisecondsSinceEpoch}',
          title: '${_getTypeDescription(entry.key)}激增',
          description: '近7天该类型异常增加${((recentRate / olderRate - 1) * 100).toStringAsFixed(0)}%',
          relatedType: entry.key,
          riskLevel: math.min(1.0, (recentRate / olderRate - 1)),
          detectedAt: DateTime.now(),
        ));
      }
    }

    return alerts;
  }
}

// ==================== 异常学习整合服务 ====================

/// 异常学习整合服务（整合本地学习与协同学习）
class AnomalyLearningIntegrationService {
  final AnomalyLearningService _localService;
  final AnomalyCollaborativeLearningService _collaborativeService;

  AnomalyLearningIntegrationService({
    AnomalyLearningService? localService,
    AnomalyCollaborativeLearningService? collaborativeService,
  })  : _localService = localService ?? AnomalyLearningService(),
        _collaborativeService =
            collaborativeService ?? AnomalyCollaborativeLearningService();

  /// 检测异常（整合本地与协同学习）
  Future<EnhancedAnomalyDetectionResult> detectAnomaly({
    required String transactionId,
    required double amount,
    required String category,
    required DateTime time,
    String? userId,
  }) async {
    // 1. 本地检测
    final localResult = await _localService.detectAnomaly(
      transactionId: transactionId,
      amount: amount,
      category: category,
      time: time,
      userId: userId,
    );

    // 2. 获取全局阈值参考
    final globalThreshold = await _collaborativeService.getCategoryThreshold(category);

    // 3. 检查是否为新型异常
    EmergingAnomalyAlert? emergingAlert;
    if (localResult.isAnomaly) {
      emergingAlert = await _collaborativeService.checkEmergingAnomaly(
        AnomalyLearningData(
          transactionId: transactionId,
          amount: amount,
          category: category,
          date: time,
          anomalyType: localResult.anomalyType ?? AnomalyType.unusualAmount,
        ),
      );
    }

    // 4. 调整置信度（结合全局数据）
    double adjustedConfidence = localResult.confidence;
    if (globalThreshold != null && amount > globalThreshold.p90Threshold) {
      adjustedConfidence = math.min(1.0, adjustedConfidence * 1.2);
    }

    return EnhancedAnomalyDetectionResult(
      localResult: localResult,
      globalThreshold: globalThreshold,
      emergingAlert: emergingAlert,
      adjustedConfidence: adjustedConfidence,
      globalContext: await _getGlobalContext(category),
    );
  }

  Future<String> _getGlobalContext(String category) async {
    final insights = await _collaborativeService.getGlobalInsights();
    final categoryGroup = _getCategoryGroup(category);
    final threshold = insights.categoryThresholds[categoryGroup];

    if (threshold != null) {
      return '该分类全局P90阈值: ¥${threshold.p90Threshold.toStringAsFixed(0)}';
    }
    return '';
  }

  String _getCategoryGroup(String category) {
    final mapping = {
      '餐饮': 'daily_expense',
      '交通': 'daily_expense',
      '购物': 'shopping',
      '娱乐': 'entertainment',
      '转账': 'transfer',
    };
    return mapping[category] ?? 'other';
  }

  /// 记录异常数据
  Future<void> recordAnomaly(AnomalyLearningData data) async {
    // 本地学习
    await _localService.learn(data);

    // 上报协同学习
    await _collaborativeService.reportAnomalyPattern(data);
  }

  /// 用户反馈
  Future<void> feedback(AnomalyLearningData data, bool confirmed) async {
    await _localService.feedback(data, confirmed);

    // 更新后重新上报
    final updatedData = AnomalyLearningData(
      transactionId: data.transactionId,
      amount: data.amount,
      category: data.category,
      date: data.date,
      anomalyType: data.anomalyType,
      feedback: confirmed ? AnomalyFeedback.confirmed : AnomalyFeedback.dismissed,
      transactionContext: data.transactionContext,
    );
    await _collaborativeService.reportAnomalyPattern(updatedData);
  }

  /// 获取统计信息
  Future<AnomalyLearningStats> getStats() async {
    return _localService.getStats();
  }

  /// 获取全局洞察
  Future<GlobalAnomalyInsights> getGlobalInsights() async {
    return _collaborativeService.getGlobalInsights();
  }

  /// 获取热门异常模式
  Future<List<PopularAnomalyPattern>> getPopularPatterns() async {
    return _collaborativeService.getPopularPatterns();
  }

  /// 获取新型异常警告
  Future<List<EmergingAnomalyAlert>> getEmergingAlerts() async {
    return _collaborativeService.getEmergingAlerts();
  }
}

/// 增强的异常检测结果
class EnhancedAnomalyDetectionResult {
  final AnomalyDetectionResult localResult;
  final CategoryAnomalyThreshold? globalThreshold;
  final EmergingAnomalyAlert? emergingAlert;
  final double adjustedConfidence;
  final String globalContext;

  const EnhancedAnomalyDetectionResult({
    required this.localResult,
    this.globalThreshold,
    this.emergingAlert,
    required this.adjustedConfidence,
    required this.globalContext,
  });

  bool get isAnomaly => localResult.isAnomaly;
  AnomalyType? get anomalyType => localResult.anomalyType;
  String? get explanation => localResult.explanation;

  /// 是否为新型异常
  bool get isEmergingAnomaly => emergingAlert != null;

  /// 获取综合说明
  String getComprehensiveExplanation() {
    final buffer = StringBuffer();

    if (localResult.explanation != null) {
      buffer.writeln(localResult.explanation);
    }

    if (globalContext.isNotEmpty) {
      buffer.writeln(globalContext);
    }

    if (emergingAlert != null) {
      buffer.writeln('⚠️ ${emergingAlert!.title}: ${emergingAlert!.description}');
    }

    return buffer.toString().trim();
  }
}
