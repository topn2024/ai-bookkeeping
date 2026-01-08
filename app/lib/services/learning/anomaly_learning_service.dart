import 'dart:math' as math;

import 'package:collection/collection.dart';
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
