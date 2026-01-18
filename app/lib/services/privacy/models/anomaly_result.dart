import '../../../services/collaborative_learning_service.dart';

/// 异常规则
///
/// 表示被检测为异常的规则及其偏离度信息
class AnomalyRule {
  /// 原始规则
  final LearnedRule rule;

  /// 偏离度（与中位数的差异）
  final double deviation;

  /// 偏离倍数（相对于标准差）
  final double deviationMultiple;

  /// 检测时间
  final DateTime detectedAt;

  const AnomalyRule({
    required this.rule,
    required this.deviation,
    required this.deviationMultiple,
    required this.detectedAt,
  });

  /// 是否为严重异常（超过3σ）
  bool get isSevere => deviationMultiple > 3.0;

  /// 是否为中度异常（超过2σ但不超过3σ）
  bool get isModerate => deviationMultiple > 2.0 && deviationMultiple <= 3.0;

  Map<String, dynamic> toJson() {
    return {
      'ruleId': rule.id,
      'rulePattern': rule.pattern,
      'ruleConfidence': rule.confidence,
      'deviation': deviation,
      'deviationMultiple': deviationMultiple,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }
}

/// 异常检测结果
///
/// 包含正常规则和异常规则的分类结果
class AnomalyDetectionResult {
  /// 正常规则列表
  final List<LearnedRule> normalRules;

  /// 异常规则列表
  final List<AnomalyRule> anomalousRules;

  /// 统计信息
  final AnomalyStatistics statistics;

  /// 检测时间
  final DateTime detectedAt;

  const AnomalyDetectionResult({
    required this.normalRules,
    required this.anomalousRules,
    required this.statistics,
    required this.detectedAt,
  });

  /// 总规则数
  int get totalRules => normalRules.length + anomalousRules.length;

  /// 异常率
  double get anomalyRate =>
      totalRules > 0 ? anomalousRules.length / totalRules : 0.0;

  /// 是否有异常
  bool get hasAnomalies => anomalousRules.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'normalRulesCount': normalRules.length,
      'anomalousRulesCount': anomalousRules.length,
      'anomalousRules': anomalousRules.map((r) => r.toJson()).toList(),
      'statistics': statistics.toJson(),
      'detectedAt': detectedAt.toIso8601String(),
    };
  }
}

/// 异常统计信息
class AnomalyStatistics {
  /// 置信度中位数
  final double median;

  /// 置信度标准差
  final double standardDeviation;

  /// 置信度均值
  final double mean;

  /// 最小值
  final double min;

  /// 最大值
  final double max;

  /// 3σ阈值
  final double threshold3Sigma;

  const AnomalyStatistics({
    required this.median,
    required this.standardDeviation,
    required this.mean,
    required this.min,
    required this.max,
    required this.threshold3Sigma,
  });

  Map<String, dynamic> toJson() {
    return {
      'median': median,
      'standardDeviation': standardDeviation,
      'mean': mean,
      'min': min,
      'max': max,
      'threshold3Sigma': threshold3Sigma,
    };
  }
}

/// 用户异常汇总
class UserAnomalySummary {
  /// 用户ID（伪匿名化）
  final String pseudonymizedUserId;

  /// 异常规则数量
  final int anomalyCount;

  /// 平均偏离度
  final double averageDeviation;

  /// 最大偏离倍数
  final double maxDeviationMultiple;

  /// 首次检测时间
  final DateTime firstDetectedAt;

  /// 最近检测时间
  final DateTime lastDetectedAt;

  const UserAnomalySummary({
    required this.pseudonymizedUserId,
    required this.anomalyCount,
    required this.averageDeviation,
    required this.maxDeviationMultiple,
    required this.firstDetectedAt,
    required this.lastDetectedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'pseudonymizedUserId': pseudonymizedUserId,
      'anomalyCount': anomalyCount,
      'averageDeviation': averageDeviation,
      'maxDeviationMultiple': maxDeviationMultiple,
      'firstDetectedAt': firstDetectedAt.toIso8601String(),
      'lastDetectedAt': lastDetectedAt.toIso8601String(),
    };
  }
}
