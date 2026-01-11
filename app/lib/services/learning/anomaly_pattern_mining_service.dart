import 'dart:convert';
import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

// ==================== 异常模式类型 ====================

/// 异常模式类型
enum AnomalyPatternType {
  amount, // 金额异常
  time, // 时间异常
  frequency, // 频率异常
  combined, // 组合异常
  merchant, // 商家异常
  location, // 位置异常
}

// ==================== 异常模式 ====================

/// 异常模式
class AnomalyPattern {
  final String patternId;
  final AnomalyPatternType type;
  final String? category;
  final String condition;
  final double confidence;
  final double? relativeThreshold;
  final int sampleCount;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  AnomalyPattern({
    required this.patternId,
    required this.type,
    this.category,
    required this.condition,
    required this.confidence,
    this.relativeThreshold,
    this.sampleCount = 0,
    DateTime? createdAt,
    this.metadata = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'pattern_id': patternId,
        'type': type.name,
        'category': category,
        'condition': condition,
        'confidence': confidence,
        'relative_threshold': relativeThreshold,
        'sample_count': sampleCount,
        'created_at': createdAt.toIso8601String(),
        'metadata': metadata,
      };

  factory AnomalyPattern.fromJson(Map<String, dynamic> json) {
    return AnomalyPattern(
      patternId: json['pattern_id'] as String,
      type: AnomalyPatternType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => AnomalyPatternType.amount,
      ),
      category: json['category'] as String?,
      condition: json['condition'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      relativeThreshold: (json['relative_threshold'] as num?)?.toDouble(),
      sampleCount: json['sample_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

// ==================== 异常学习样本 ====================

/// 异常学习样本（用于模式挖掘）
class AnomalyLearningSample {
  final String id;
  final AnomalyInput input;
  final bool isConfirmedAnomaly;
  final DateTime timestamp;
  final String userId;
  final String? userFeedback;

  const AnomalyLearningSample({
    required this.id,
    required this.input,
    required this.isConfirmedAnomaly,
    required this.timestamp,
    required this.userId,
    this.userFeedback,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'input': input.toJson(),
        'is_confirmed_anomaly': isConfirmedAnomaly,
        'timestamp': timestamp.toIso8601String(),
        'user_id': userId,
        'user_feedback': userFeedback,
      };
}

/// 异常检测输入
class AnomalyInput {
  final double amount;
  final String category;
  final String? merchant;
  final DateTime timestamp;
  final int? hour;
  final int? dayOfWeek;
  final String? location;

  AnomalyInput({
    required this.amount,
    required this.category,
    this.merchant,
    required this.timestamp,
    int? hour,
    int? dayOfWeek,
    this.location,
  })  : hour = hour ?? timestamp.hour,
        dayOfWeek = dayOfWeek ?? timestamp.weekday;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'category': category,
        'merchant': merchant,
        'timestamp': timestamp.toIso8601String(),
        'hour': hour,
        'day_of_week': dayOfWeek,
        'location': location,
      };
}

// ==================== 异常模式挖掘服务 ====================

/// 异常模式挖掘服务
class AnomalyPatternMiningService {
  final AnomalySampleStore _sampleStore;

  // 配置
  static const int _minSamplesForPattern = 5;
  // ignore: unused_field
  static const double __minConfidence = 0.7;

  AnomalyPatternMiningService({AnomalySampleStore? sampleStore})
      : _sampleStore = sampleStore ?? InMemoryAnomalySampleStore();

  /// 从确认的异常中学习模式
  Future<List<AnomalyPattern>> minePatterns() async {
    final confirmedAnomalies = await _sampleStore.getConfirmedAnomalies();

    if (confirmedAnomalies.isEmpty) {
      return [];
    }

    final patterns = <AnomalyPattern>[];

    // 1. 金额异常模式
    patterns.addAll(_mineAmountPatterns(confirmedAnomalies));

    // 2. 时间异常模式（如凌晨消费）
    patterns.addAll(_mineTimePatterns(confirmedAnomalies));

    // 3. 频率异常模式（如同一商家连续消费）
    patterns.addAll(_mineFrequencyPatterns(confirmedAnomalies));

    // 4. 组合异常模式
    patterns.addAll(_mineCombinedPatterns(confirmedAnomalies));

    debugPrint('Mined ${patterns.length} anomaly patterns');
    return patterns;
  }

  /// 挖掘金额异常模式
  List<AnomalyPattern> _mineAmountPatterns(List<AnomalyLearningSample> samples) {
    final patterns = <AnomalyPattern>[];

    // 按分类分组，找出各分类的异常金额特征
    final byCategory = _groupByCategory(samples);

    for (final entry in byCategory.entries) {
      final amounts = entry.value.map((s) => s.input.amount).toList();
      if (amounts.length >= _minSamplesForPattern) {
        final percentile90 = _calculatePercentile(amounts, 0.9);
        final mean = amounts.reduce((a, b) => a + b) / amounts.length;
        final relativeThreshold = percentile90 / mean;

        patterns.add(AnomalyPattern(
          patternId: 'amount_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
          type: AnomalyPatternType.amount,
          category: entry.key,
          condition: 'amount > $percentile90',
          confidence: 0.8,
          relativeThreshold: relativeThreshold,
          sampleCount: amounts.length,
          metadata: {
            'percentile_90': percentile90,
            'mean': mean,
          },
        ));
      }
    }

    return patterns;
  }

  /// 挖掘时间异常模式
  List<AnomalyPattern> _mineTimePatterns(List<AnomalyLearningSample> samples) {
    final patterns = <AnomalyPattern>[];

    // 按小时分组
    final byHour = <int, List<AnomalyLearningSample>>{};
    for (final sample in samples) {
      final hour = sample.input.hour ?? sample.input.timestamp.hour;
      byHour.putIfAbsent(hour, () => []).add(sample);
    }

    // 找出异常高发时段
    final totalSamples = samples.length;
    for (final entry in byHour.entries) {
      final hourSamples = entry.value.length;
      final ratio = hourSamples / totalSamples;

      // 如果某时段异常占比超过15%，认为是异常高发时段
      if (hourSamples >= 3 && ratio > 0.15) {
        String timeDescription;
        final hour = entry.key;
        if (hour >= 0 && hour < 6) {
          timeDescription = '凌晨($hour点)';
        } else if (hour >= 22 || hour < 0) {
          timeDescription = '深夜($hour点)';
        } else {
          timeDescription = '$hour点';
        }

        patterns.add(AnomalyPattern(
          patternId: 'time_hour_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
          type: AnomalyPatternType.time,
          condition: 'hour == ${entry.key}',
          confidence: math.min(0.9, 0.5 + ratio),
          sampleCount: hourSamples,
          metadata: {
            'hour': entry.key,
            'description': timeDescription,
            'ratio': ratio,
          },
        ));
      }
    }

    // 凌晨时段特殊检测 (2-5点)
    final lateNightSamples = samples.where((s) {
      final hour = s.input.hour ?? s.input.timestamp.hour;
      return hour >= 2 && hour < 5;
    }).toList();

    if (lateNightSamples.length >= 3) {
      patterns.add(AnomalyPattern(
        patternId: 'time_late_night_${DateTime.now().millisecondsSinceEpoch}',
        type: AnomalyPatternType.time,
        condition: 'hour >= 2 && hour < 5',
        confidence: 0.85,
        sampleCount: lateNightSamples.length,
        metadata: {
          'description': '凌晨2-5点消费',
          'sample_count': lateNightSamples.length,
        },
      ));
    }

    return patterns;
  }

  /// 挖掘频率异常模式
  List<AnomalyPattern> _mineFrequencyPatterns(
      List<AnomalyLearningSample> samples) {
    final patterns = <AnomalyPattern>[];

    // 按商家分组
    final byMerchant = <String, List<AnomalyLearningSample>>{};
    for (final sample in samples) {
      if (sample.input.merchant != null) {
        byMerchant
            .putIfAbsent(sample.input.merchant!, () => [])
            .add(sample);
      }
    }

    // 找出频繁出现异常的商家
    for (final entry in byMerchant.entries) {
      if (entry.value.length >= 3) {
        // 检查是否有短时间内多次消费
        final sorted = entry.value.toList()
          ..sort((a, b) => a.input.timestamp.compareTo(b.input.timestamp));

        int consecutiveCount = 0;
        for (int i = 1; i < sorted.length; i++) {
          final diff = sorted[i].input.timestamp.difference(sorted[i - 1].input.timestamp);
          if (diff.inHours < 1) {
            consecutiveCount++;
          }
        }

        if (consecutiveCount >= 2) {
          patterns.add(AnomalyPattern(
            patternId:
                'freq_merchant_${entry.key.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            type: AnomalyPatternType.frequency,
            condition: 'merchant == "${entry.key}" && consecutive_in_1h >= 3',
            confidence: 0.8,
            sampleCount: entry.value.length,
            metadata: {
              'merchant': entry.key,
              'consecutive_count': consecutiveCount,
              'description': '同一商家1小时内多次消费',
            },
          ));
        }
      }
    }

    return patterns;
  }

  /// 挖掘组合异常模式
  List<AnomalyPattern> _mineCombinedPatterns(
      List<AnomalyLearningSample> samples) {
    final patterns = <AnomalyPattern>[];

    // 按分类+时段组合分组
    final byCategoryAndTime = <String, List<AnomalyLearningSample>>{};
    for (final sample in samples) {
      final hour = sample.input.hour ?? sample.input.timestamp.hour;
      final timeSlot = _getTimeSlot(hour);
      final key = '${sample.input.category}_$timeSlot';
      byCategoryAndTime.putIfAbsent(key, () => []).add(sample);
    }

    for (final entry in byCategoryAndTime.entries) {
      if (entry.value.length >= _minSamplesForPattern) {
        final parts = entry.key.split('_');
        final category = parts[0];
        final timeSlot = parts[1];

        patterns.add(AnomalyPattern(
          patternId: 'combined_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
          type: AnomalyPatternType.combined,
          category: category,
          condition: 'category == "$category" && time_slot == "$timeSlot"',
          confidence: 0.75,
          sampleCount: entry.value.length,
          metadata: {
            'category': category,
            'time_slot': timeSlot,
            'description': '$category类目在$timeSlot的异常消费',
          },
        ));
      }
    }

    return patterns;
  }

  Map<String, List<AnomalyLearningSample>> _groupByCategory(
      List<AnomalyLearningSample> samples) {
    return groupBy(samples, (s) => s.input.category);
  }

  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0;
    final sorted = values.toList()..sort();
    final index = ((sorted.length - 1) * percentile).floor();
    return sorted[index];
  }

  String _getTimeSlot(int hour) {
    if (hour >= 6 && hour < 12) return '上午';
    if (hour >= 12 && hour < 14) return '午间';
    if (hour >= 14 && hour < 18) return '下午';
    if (hour >= 18 && hour < 22) return '晚间';
    return '深夜';
  }

  /// 匹配异常模式
  Future<List<AnomalyPattern>> matchPatterns(AnomalyInput input) async {
    final allPatterns = await minePatterns();
    final matched = <AnomalyPattern>[];

    for (final pattern in allPatterns) {
      if (_matchesPattern(input, pattern)) {
        matched.add(pattern);
      }
    }

    return matched;
  }

  bool _matchesPattern(AnomalyInput input, AnomalyPattern pattern) {
    switch (pattern.type) {
      case AnomalyPatternType.amount:
        if (pattern.category != null && pattern.category != input.category) {
          return false;
        }
        if (pattern.relativeThreshold != null) {
          // 需要知道类目平均值才能判断，这里简化处理
          return false;
        }
        return true;

      case AnomalyPatternType.time:
        final hour = input.hour ?? input.timestamp.hour;
        if (pattern.condition.contains('hour ==')) {
          final targetHour = int.tryParse(
              pattern.condition.replaceAll(RegExp(r'[^0-9]'), ''));
          return targetHour == hour;
        }
        if (pattern.condition.contains('hour >= 2 && hour < 5')) {
          return hour >= 2 && hour < 5;
        }
        return false;

      case AnomalyPatternType.frequency:
        // 频率异常需要历史数据，这里简化处理
        return false;

      case AnomalyPatternType.combined:
        if (pattern.category != null && pattern.category != input.category) {
          return false;
        }
        final hour = input.hour ?? input.timestamp.hour;
        final timeSlot = _getTimeSlot(hour);
        return pattern.metadata['time_slot'] == timeSlot;

      default:
        return false;
    }
  }
}

// ==================== 样本存储接口 ====================

/// 异常样本存储接口
abstract class AnomalySampleStore {
  Future<List<AnomalyLearningSample>> getConfirmedAnomalies();
  Future<void> addSample(AnomalyLearningSample sample);
  Future<void> clear();
}

/// 内存异常样本存储
class InMemoryAnomalySampleStore implements AnomalySampleStore {
  final List<AnomalyLearningSample> _samples = [];

  @override
  Future<List<AnomalyLearningSample>> getConfirmedAnomalies() async {
    return _samples.where((s) => s.isConfirmedAnomaly).toList();
  }

  @override
  Future<void> addSample(AnomalyLearningSample sample) async {
    _samples.add(sample);
  }

  @override
  Future<void> clear() async {
    _samples.clear();
  }

  List<AnomalyLearningSample> get allSamples => List.unmodifiable(_samples);
}

// ==================== 异常检测协同学习服务 ====================

/// 异常检测协同学习服务
class AnomalyCollaborativeLearningService {
  // ignore: unused_field
  final AnomalyPatternMiningService __miningService;
  final GlobalAnomalyPatternAggregator _aggregator;
  final String _currentUserId;

  AnomalyCollaborativeLearningService({
    required AnomalyPatternMiningService miningService,
    GlobalAnomalyPatternAggregator? aggregator,
    String? currentUserId,
  })  : __miningService = miningService,
        _aggregator = aggregator ?? GlobalAnomalyPatternAggregator(),
        _currentUserId = currentUserId ?? 'anonymous';

  /// 上报异常模式（隐私保护）
  Future<void> reportAnomalyPattern(AnomalyPattern pattern) async {
    // 只上报高置信度模式
    if (pattern.confidence < 0.8) return;

    // 只上报模式特征，不上报具体金额
    final sanitizedPattern = SanitizedAnomalyPattern(
      type: pattern.type,
      category: pattern.category,
      // 相对阈值而非绝对值
      relativeThreshold: pattern.relativeThreshold,
      userHash: _hashUserId(_currentUserId),
      timestamp: DateTime.now(),
      confidence: pattern.confidence,
    );

    await _aggregator.reportPattern(sanitizedPattern);
    debugPrint('Reported anomaly pattern: ${sanitizedPattern.toJson()}');
  }

  /// 下载全局异常模式
  Future<List<GlobalAnomalyPattern>> downloadGlobalPatterns() async {
    return _aggregator.discoverGlobalPatterns();
  }

  /// 检查欺诈预警
  Future<List<FraudAlert>> checkFraudAlerts() async {
    return _aggregator.detectEmergingFraudPatterns();
  }

  String _hashUserId(String userId) {
    final bytes = utf8.encode(userId);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}

/// 脱敏后的异常模式
class SanitizedAnomalyPattern {
  final AnomalyPatternType type;
  final String? category;
  final double? relativeThreshold;
  final String userHash;
  final DateTime timestamp;
  final double confidence;

  const SanitizedAnomalyPattern({
    required this.type,
    this.category,
    this.relativeThreshold,
    required this.userHash,
    required this.timestamp,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'category': category,
        'relative_threshold': relativeThreshold,
        'user_hash': userHash,
        'timestamp': timestamp.toIso8601String(),
        'confidence': confidence,
      };
}

// ==================== 全局异常模式聚合 ====================

/// 全局异常模式
class GlobalAnomalyPattern {
  final AnomalyPatternType type;
  final String? category;
  final String condition;
  final double confidence;
  final int userCount;
  final DateTime firstDetected;
  final DateTime lastUpdated;

  const GlobalAnomalyPattern({
    required this.type,
    this.category,
    required this.condition,
    required this.confidence,
    required this.userCount,
    required this.firstDetected,
    required this.lastUpdated,
  });
}

/// 欺诈预警
class FraudAlert {
  final AnomalyPattern pattern;
  final int affectedUsers;
  final double confidence;
  final DateTime firstDetected;
  final String description;
  final AlertSeverity severity;

  const FraudAlert({
    required this.pattern,
    required this.affectedUsers,
    required this.confidence,
    required this.firstDetected,
    required this.description,
    required this.severity,
  });
}

/// 预警严重程度
enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

/// 全局异常模式聚合器
class GlobalAnomalyPatternAggregator {
  // 存储上报的模式
  final List<SanitizedAnomalyPattern> _reportedPatterns = [];

  /// 上报模式
  Future<void> reportPattern(SanitizedAnomalyPattern pattern) async {
    _reportedPatterns.add(pattern);
    debugPrint('Pattern reported to aggregator: ${pattern.type.name}');
  }

  /// 发现群体级异常模式
  Future<List<GlobalAnomalyPattern>> discoverGlobalPatterns() async {
    final patterns = <GlobalAnomalyPattern>[];

    // 按类型分组
    final byType = groupBy(_reportedPatterns, (p) => p.type);

    for (final entry in byType.entries) {
      // 计算用户数
      final userHashes = entry.value.map((p) => p.userHash).toSet();
      if (userHashes.length >= 3) {
        // 至少3个用户报告才认为是全局模式
        final sorted = entry.value.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        patterns.add(GlobalAnomalyPattern(
          type: entry.key,
          category: entry.value.first.category,
          condition: _generateCondition(entry.key, entry.value),
          confidence: _calculateGlobalConfidence(entry.value),
          userCount: userHashes.length,
          firstDetected: sorted.first.timestamp,
          lastUpdated: sorted.last.timestamp,
        ));
      }
    }

    // 示例全局模式
    // 如：大多数用户认为餐饮单笔超过月均5倍是异常
    // 如：凌晨2-5点的消费普遍被标记为异常
    // 如：同一商家1小时内3次以上消费被标记为异常

    return patterns;
  }

  String _generateCondition(
      AnomalyPatternType type, List<SanitizedAnomalyPattern> patterns) {
    switch (type) {
      case AnomalyPatternType.amount:
        final avgThreshold = patterns
            .where((p) => p.relativeThreshold != null)
            .map((p) => p.relativeThreshold!)
            .fold(0.0, (a, b) => a + b);
        final count =
            patterns.where((p) => p.relativeThreshold != null).length;
        if (count > 0) {
          return 'amount > mean * ${(avgThreshold / count).toStringAsFixed(1)}';
        }
        return 'amount > threshold';
      case AnomalyPatternType.time:
        return 'hour >= 2 && hour < 5';
      case AnomalyPatternType.frequency:
        return 'consecutive_transactions >= 3 within 1 hour';
      default:
        return 'custom_condition';
    }
  }

  double _calculateGlobalConfidence(List<SanitizedAnomalyPattern> patterns) {
    if (patterns.isEmpty) return 0;
    return patterns.map((p) => p.confidence).reduce((a, b) => a + b) /
        patterns.length;
  }

  /// 新型诈骗/盗刷模式预警
  Future<List<FraudAlert>> detectEmergingFraudPatterns() async {
    final alerts = <FraudAlert>[];

    // 当多个用户在短时间内报告相似的异常模式时
    // 可能是新型诈骗手段，需要全局预警
    final recentPatterns = _reportedPatterns
        .where((p) =>
            p.timestamp.isAfter(DateTime.now().subtract(const Duration(hours: 24))))
        .toList();

    if (recentPatterns.isEmpty) return alerts;

    final clusters = _clusterSimilarPatterns(recentPatterns);

    for (final cluster in clusters) {
      if (cluster.userCount >= 10 && cluster.similarity >= 0.8) {
        alerts.add(FraudAlert(
          pattern: AnomalyPattern(
            patternId: 'fraud_${DateTime.now().millisecondsSinceEpoch}',
            type: cluster.representativeType,
            condition: cluster.condition,
            confidence: cluster.similarity,
            sampleCount: cluster.userCount,
          ),
          affectedUsers: cluster.userCount,
          confidence: cluster.similarity,
          firstDetected: cluster.earliestTimestamp,
          description: _generateAlertDescription(cluster),
          severity: _calculateSeverity(cluster),
        ));
      }
    }

    return alerts;
  }

  List<_PatternCluster> _clusterSimilarPatterns(
      List<SanitizedAnomalyPattern> patterns) {
    final clusters = <_PatternCluster>[];

    // 按类型和分类简单聚类
    final grouped = <String, List<SanitizedAnomalyPattern>>{};
    for (final pattern in patterns) {
      final key = '${pattern.type.name}_${pattern.category ?? "unknown"}';
      grouped.putIfAbsent(key, () => []).add(pattern);
    }

    for (final entry in grouped.entries) {
      final userHashes = entry.value.map((p) => p.userHash).toSet();
      if (userHashes.length >= 2) {
        final sorted = entry.value.toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        clusters.add(_PatternCluster(
          representativeType: entry.value.first.type,
          category: entry.value.first.category,
          condition: 'type == ${entry.value.first.type.name}',
          userCount: userHashes.length,
          similarity: 0.9,
          earliestTimestamp: sorted.first.timestamp,
        ));
      }
    }

    return clusters;
  }

  String _generateAlertDescription(_PatternCluster cluster) {
    return '检测到${cluster.userCount}个用户在过去24小时内报告相似的'
        '${cluster.representativeType.name}类型异常，'
        '可能存在新型欺诈风险';
  }

  AlertSeverity _calculateSeverity(_PatternCluster cluster) {
    if (cluster.userCount >= 50) return AlertSeverity.critical;
    if (cluster.userCount >= 20) return AlertSeverity.high;
    if (cluster.userCount >= 10) return AlertSeverity.medium;
    return AlertSeverity.low;
  }
}

class _PatternCluster {
  final AnomalyPatternType representativeType;
  final String? category;
  final String condition;
  final int userCount;
  final double similarity;
  final DateTime earliestTimestamp;

  _PatternCluster({
    required this.representativeType,
    this.category,
    required this.condition,
    required this.userCount,
    required this.similarity,
    required this.earliestTimestamp,
  });
}
