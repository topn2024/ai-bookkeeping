import 'package:flutter/foundation.dart';

import '../../../services/collaborative_learning_service.dart';
import '../models/anomaly_result.dart';
import 'malicious_user_tracker.dart';
import 'rule_deviation_calculator.dart';

/// 异常规则检测器
///
/// 实现专利算法4：异常规则检测
/// 使用3σ原则检测异常规则，并追踪恶意用户
class AnomalyDetector {
  final RuleDeviationCalculator _deviationCalculator;
  final MaliciousUserTracker _userTracker;

  /// 异常检测配置
  final AnomalyDetectionConfig _config;

  AnomalyDetector({
    required MaliciousUserTracker userTracker,
    RuleDeviationCalculator? deviationCalculator,
    AnomalyDetectionConfig? config,
  })  : _userTracker = userTracker,
        _deviationCalculator =
            deviationCalculator ?? RuleDeviationCalculator(),
        _config = config ?? const AnomalyDetectionConfig();

  /// 用户追踪器
  MaliciousUserTracker get userTracker => _userTracker;

  /// 检测异常规则（算法4实现）
  ///
  /// [rules] 待检测的规则列表
  /// [userId] 可选的用户ID，用于追踪
  Future<AnomalyDetectionResult> detectAnomalies(
    List<LearnedRule> rules, {
    String? userId,
  }) async {
    if (rules.isEmpty) {
      return AnomalyDetectionResult(
        normalRules: [],
        anomalousRules: [],
        statistics: const AnomalyStatistics(
          median: 0,
          standardDeviation: 0,
          mean: 0,
          min: 0,
          max: 0,
          threshold3Sigma: 0,
        ),
        detectedAt: DateTime.now(),
      );
    }

    // 1. 计算置信度的统计信息
    final confidences = rules.map((r) => r.confidence).toList();
    final stats = _deviationCalculator.calculateStatistics(confidences);

    // 2. 检测异常规则
    final anomalous = <AnomalyRule>[];
    final normal = <LearnedRule>[];

    for (final rule in rules) {
      final deviation = _deviationCalculator.calculateDeviation(
        confidence: rule.confidence,
        statistics: stats,
      );

      // 3σ 异常判定
      if (deviation.deviationMultiple > _config.sigmaThreshold) {
        anomalous.add(AnomalyRule(
          rule: rule,
          deviation: deviation.deviationFromMedian,
          deviationMultiple: deviation.deviationMultiple,
          detectedAt: DateTime.now(),
        ));

        // 记录异常（如果有用户ID）
        if (userId != null) {
          await _userTracker.recordAnomaly(userId);
        }

        debugPrint(
          '检测到异常规则: ${rule.pattern.substring(0, rule.pattern.length.clamp(0, 20))}, '
          '置信度=${rule.confidence.toStringAsFixed(3)}, '
          '偏离度=${deviation.deviationMultiple.toStringAsFixed(2)}σ',
        );
      } else {
        normal.add(rule);

        // 记录正常贡献（如果有用户ID）
        if (userId != null) {
          await _userTracker.recordNormalContribution(userId);
        }
      }
    }

    return AnomalyDetectionResult(
      normalRules: normal,
      anomalousRules: anomalous,
      statistics: AnomalyStatistics(
        median: stats.median,
        standardDeviation: stats.standardDeviation,
        mean: stats.mean,
        min: stats.min,
        max: stats.max,
        threshold3Sigma: _config.sigmaThreshold * stats.standardDeviation,
      ),
      detectedAt: DateTime.now(),
    );
  }

  /// 批量检测多个用户的规则
  ///
  /// [rulesByUser] 按用户ID分组的规则
  Future<Map<String, AnomalyDetectionResult>> detectAnomaliesByUser(
    Map<String, List<LearnedRule>> rulesByUser,
  ) async {
    final results = <String, AnomalyDetectionResult>{};

    // 首先收集所有规则计算全局统计
    final allRules = rulesByUser.values.expand((rules) => rules).toList();
    if (allRules.isEmpty) {
      return results;
    }

    final confidences = allRules.map((r) => r.confidence).toList();
    final globalStats = _deviationCalculator.calculateStatistics(confidences);

    // 然后对每个用户的规则进行检测
    for (final entry in rulesByUser.entries) {
      final userId = entry.key;
      final userRules = entry.value;

      // 检查用户是否被隔离
      if (!_userTracker.canContribute(userId)) {
        debugPrint('跳过被隔离用户 $userId 的规则检测');
        results[userId] = AnomalyDetectionResult(
          normalRules: [],
          anomalousRules: userRules
              .map((r) => AnomalyRule(
                    rule: r,
                    deviation: 0,
                    deviationMultiple: 0,
                    detectedAt: DateTime.now(),
                  ))
              .toList(),
          statistics: AnomalyStatistics(
            median: globalStats.median,
            standardDeviation: globalStats.standardDeviation,
            mean: globalStats.mean,
            min: globalStats.min,
            max: globalStats.max,
            threshold3Sigma:
                _config.sigmaThreshold * globalStats.standardDeviation,
          ),
          detectedAt: DateTime.now(),
        );
        continue;
      }

      // 使用全局统计来检测该用户的规则
      final result =
          await _detectWithGlobalStats(userRules, globalStats, userId);
      results[userId] = result;
    }

    return results;
  }

  /// 使用全局统计检测规则
  Future<AnomalyDetectionResult> _detectWithGlobalStats(
    List<LearnedRule> rules,
    DeviationStatistics globalStats,
    String userId,
  ) async {
    final anomalous = <AnomalyRule>[];
    final normal = <LearnedRule>[];

    for (final rule in rules) {
      final deviation = _deviationCalculator.calculateDeviation(
        confidence: rule.confidence,
        statistics: globalStats,
      );

      if (deviation.deviationMultiple > _config.sigmaThreshold) {
        anomalous.add(AnomalyRule(
          rule: rule,
          deviation: deviation.deviationFromMedian,
          deviationMultiple: deviation.deviationMultiple,
          detectedAt: DateTime.now(),
        ));
        await _userTracker.recordAnomaly(userId);
      } else {
        normal.add(rule);
        await _userTracker.recordNormalContribution(userId);
      }
    }

    return AnomalyDetectionResult(
      normalRules: normal,
      anomalousRules: anomalous,
      statistics: AnomalyStatistics(
        median: globalStats.median,
        standardDeviation: globalStats.standardDeviation,
        mean: globalStats.mean,
        min: globalStats.min,
        max: globalStats.max,
        threshold3Sigma: _config.sigmaThreshold * globalStats.standardDeviation,
      ),
      detectedAt: DateTime.now(),
    );
  }

  /// 过滤异常规则，只返回正常规则
  Future<List<LearnedRule>> filterAnomalies(
    List<LearnedRule> rules, {
    String? userId,
  }) async {
    final result = await detectAnomalies(rules, userId: userId);
    return result.normalRules;
  }

  /// 检查单个规则是否异常
  Future<bool> isAnomaly(
    LearnedRule rule,
    List<LearnedRule> referenceRules,
  ) async {
    if (referenceRules.isEmpty) {
      return false;
    }

    final confidences = referenceRules.map((r) => r.confidence).toList();
    final stats = _deviationCalculator.calculateStatistics(confidences);

    final deviation = _deviationCalculator.calculateDeviation(
      confidence: rule.confidence,
      statistics: stats,
    );

    return deviation.deviationMultiple > _config.sigmaThreshold;
  }

  /// 获取异常检测统计
  AnomalyDetectorStatistics getStatistics() {
    final userStats = _userTracker.getStatistics();
    return AnomalyDetectorStatistics(
      userTrackingStats: userStats,
      config: _config,
    );
  }
}

/// 异常检测配置
class AnomalyDetectionConfig {
  /// sigma 阈值（默认3σ）
  final double sigmaThreshold;

  /// 最小样本量（样本太少时不进行检测）
  final int minSampleSize;

  /// 是否启用用户追踪
  final bool enableUserTracking;

  const AnomalyDetectionConfig({
    this.sigmaThreshold = 3.0,
    this.minSampleSize = 10,
    this.enableUserTracking = true,
  });
}

/// 异常检测器统计
class AnomalyDetectorStatistics {
  final UserTrackingStatistics userTrackingStats;
  final AnomalyDetectionConfig config;

  const AnomalyDetectorStatistics({
    required this.userTrackingStats,
    required this.config,
  });

  Map<String, dynamic> toJson() {
    return {
      'userTracking': userTrackingStats.toJson(),
      'config': {
        'sigmaThreshold': config.sigmaThreshold,
        'minSampleSize': config.minSampleSize,
        'enableUserTracking': config.enableUserTracking,
      },
    };
  }
}
