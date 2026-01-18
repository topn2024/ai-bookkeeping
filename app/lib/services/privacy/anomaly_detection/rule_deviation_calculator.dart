import 'dart:math';

import '../../../services/collaborative_learning_service.dart';

/// 规则偏离度计算器
///
/// 计算规则置信度相对于整体分布的偏离程度。
/// 用于异常检测中判定规则是否异常。
class RuleDeviationCalculator {
  /// 计算一组置信度值的统计信息
  DeviationStatistics calculateStatistics(List<double> confidences) {
    if (confidences.isEmpty) {
      return const DeviationStatistics(
        median: 0,
        mean: 0,
        standardDeviation: 0,
        min: 0,
        max: 0,
        count: 0,
      );
    }

    final sorted = List<double>.from(confidences)..sort();
    final count = sorted.length;

    // 计算中位数
    final median = count.isOdd
        ? sorted[count ~/ 2]
        : (sorted[count ~/ 2 - 1] + sorted[count ~/ 2]) / 2;

    // 计算均值
    final mean = sorted.reduce((a, b) => a + b) / count;

    // 计算标准差
    final variance =
        sorted.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) / count;
    final standardDeviation = sqrt(variance);

    return DeviationStatistics(
      median: median,
      mean: mean,
      standardDeviation: standardDeviation,
      min: sorted.first,
      max: sorted.last,
      count: count,
    );
  }

  /// 计算单个规则的偏离度
  ///
  /// [confidence] 规则的置信度
  /// [statistics] 整体统计信息
  ///
  /// 返回偏离信息
  DeviationInfo calculateDeviation({
    required double confidence,
    required DeviationStatistics statistics,
  }) {
    // 与中位数的绝对偏差
    final deviationFromMedian = (confidence - statistics.median).abs();

    // 与均值的绝对偏差
    final deviationFromMean = (confidence - statistics.mean).abs();

    // 计算偏离倍数（相对于标准差）
    final deviationMultiple = statistics.standardDeviation > 0
        ? deviationFromMedian / statistics.standardDeviation
        : 0.0;

    // Z-score
    final zScore = statistics.standardDeviation > 0
        ? (confidence - statistics.mean) / statistics.standardDeviation
        : 0.0;

    return DeviationInfo(
      deviationFromMedian: deviationFromMedian,
      deviationFromMean: deviationFromMean,
      deviationMultiple: deviationMultiple,
      zScore: zScore,
    );
  }

  /// 批量计算规则偏离度
  List<RuleDeviationResult> calculateRuleDeviations(List<LearnedRule> rules) {
    if (rules.isEmpty) {
      return [];
    }

    final confidences = rules.map((r) => r.confidence).toList();
    final statistics = calculateStatistics(confidences);

    return rules.map((rule) {
      final deviation = calculateDeviation(
        confidence: rule.confidence,
        statistics: statistics,
      );
      return RuleDeviationResult(
        rule: rule,
        deviation: deviation,
        statistics: statistics,
      );
    }).toList();
  }

  /// 计算四分位数范围 (IQR)
  IQRStatistics calculateIQR(List<double> values) {
    if (values.isEmpty) {
      return const IQRStatistics(
        q1: 0,
        q2: 0,
        q3: 0,
        iqr: 0,
        lowerBound: 0,
        upperBound: 0,
      );
    }

    final sorted = List<double>.from(values)..sort();
    final n = sorted.length;

    // Q1: 第25百分位
    final q1Index = (n * 0.25).floor();
    final q1 = sorted[q1Index.clamp(0, n - 1)];

    // Q2: 中位数（第50百分位）
    final q2 = n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;

    // Q3: 第75百分位
    final q3Index = (n * 0.75).floor();
    final q3 = sorted[q3Index.clamp(0, n - 1)];

    // IQR
    final iqr = q3 - q1;

    // 异常值边界（1.5 * IQR）
    final lowerBound = q1 - 1.5 * iqr;
    final upperBound = q3 + 1.5 * iqr;

    return IQRStatistics(
      q1: q1,
      q2: q2,
      q3: q3,
      iqr: iqr,
      lowerBound: lowerBound,
      upperBound: upperBound,
    );
  }

  /// 使用 IQR 方法检测异常值
  List<LearnedRule> detectOutliersUsingIQR(List<LearnedRule> rules) {
    if (rules.isEmpty) return [];

    final confidences = rules.map((r) => r.confidence).toList();
    final iqrStats = calculateIQR(confidences);

    return rules.where((rule) {
      return rule.confidence < iqrStats.lowerBound ||
          rule.confidence > iqrStats.upperBound;
    }).toList();
  }
}

/// 偏离统计信息
class DeviationStatistics {
  /// 中位数
  final double median;

  /// 均值
  final double mean;

  /// 标准差
  final double standardDeviation;

  /// 最小值
  final double min;

  /// 最大值
  final double max;

  /// 样本数量
  final int count;

  const DeviationStatistics({
    required this.median,
    required this.mean,
    required this.standardDeviation,
    required this.min,
    required this.max,
    required this.count,
  });

  /// 3σ 上界
  double get upperBound3Sigma => mean + 3 * standardDeviation;

  /// 3σ 下界
  double get lowerBound3Sigma => mean - 3 * standardDeviation;

  /// 2σ 上界
  double get upperBound2Sigma => mean + 2 * standardDeviation;

  /// 2σ 下界
  double get lowerBound2Sigma => mean - 2 * standardDeviation;

  Map<String, dynamic> toJson() {
    return {
      'median': median,
      'mean': mean,
      'standardDeviation': standardDeviation,
      'min': min,
      'max': max,
      'count': count,
    };
  }
}

/// 单个值的偏离信息
class DeviationInfo {
  /// 与中位数的绝对偏差
  final double deviationFromMedian;

  /// 与均值的绝对偏差
  final double deviationFromMean;

  /// 偏离倍数（相对于标准差）
  final double deviationMultiple;

  /// Z-score
  final double zScore;

  const DeviationInfo({
    required this.deviationFromMedian,
    required this.deviationFromMean,
    required this.deviationMultiple,
    required this.zScore,
  });

  /// 是否为 3σ 异常
  bool get is3SigmaAnomaly => deviationMultiple > 3.0;

  /// 是否为 2σ 异常
  bool get is2SigmaAnomaly => deviationMultiple > 2.0;

  Map<String, dynamic> toJson() {
    return {
      'deviationFromMedian': deviationFromMedian,
      'deviationFromMean': deviationFromMean,
      'deviationMultiple': deviationMultiple,
      'zScore': zScore,
    };
  }
}

/// 规则偏离度结果
class RuleDeviationResult {
  /// 原始规则
  final LearnedRule rule;

  /// 偏离信息
  final DeviationInfo deviation;

  /// 统计信息
  final DeviationStatistics statistics;

  const RuleDeviationResult({
    required this.rule,
    required this.deviation,
    required this.statistics,
  });

  /// 是否为异常规则
  bool get isAnomaly => deviation.is3SigmaAnomaly;
}

/// IQR 统计信息
class IQRStatistics {
  /// 第一四分位数
  final double q1;

  /// 中位数
  final double q2;

  /// 第三四分位数
  final double q3;

  /// 四分位距
  final double iqr;

  /// 异常下界
  final double lowerBound;

  /// 异常上界
  final double upperBound;

  const IQRStatistics({
    required this.q1,
    required this.q2,
    required this.q3,
    required this.iqr,
    required this.lowerBound,
    required this.upperBound,
  });

  Map<String, dynamic> toJson() {
    return {
      'q1': q1,
      'q2': q2,
      'q3': q3,
      'iqr': iqr,
      'lowerBound': lowerBound,
      'upperBound': upperBound,
    };
  }
}
