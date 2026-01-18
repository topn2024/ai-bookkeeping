import '../models/sensitivity_level.dart';

/// 敏感度计算器
///
/// 计算各类查询和数据的敏感度（Δf），用于确定差分隐私中的噪声量。
/// 敏感度定义为：当单个记录改变时，查询结果的最大变化量。
class SensitivityCalculator {
  /// 计算数值敏感度
  ///
  /// 对于范围在 [minValue, maxValue] 的数值，敏感度为范围大小
  static double forNumericValue({
    required double minValue,
    required double maxValue,
  }) {
    return (maxValue - minValue).abs();
  }

  /// 计算置信度敏感度
  ///
  /// 置信度范围通常是 [0, 1]，敏感度为 1
  static double forConfidence() {
    return 1.0;
  }

  /// 计算均值查询的敏感度
  ///
  /// 均值查询敏感度 = (max - min) / n
  /// 其中 n 是记录数量
  static double forMean({
    required double minValue,
    required double maxValue,
    required int recordCount,
  }) {
    if (recordCount <= 0) {
      throw ArgumentError('recordCount must be positive');
    }
    return (maxValue - minValue).abs() / recordCount;
  }

  /// 计算求和查询的敏感度
  ///
  /// 求和查询敏感度 = max(|max|, |min|)
  /// 即单个记录可能贡献的最大值
  static double forSum({
    required double minValue,
    required double maxValue,
  }) {
    return [minValue.abs(), maxValue.abs()].reduce((a, b) => a > b ? a : b);
  }

  /// 计算计数查询的敏感度
  ///
  /// 计数查询的敏感度总是 1（单个记录的存在/不存在）
  static double forCount() {
    return 1.0;
  }

  /// 计算直方图查询的敏感度
  ///
  /// 直方图的敏感度为 1（每条记录只属于一个桶）
  static double forHistogram() {
    return 1.0;
  }

  /// 计算比例/百分比的敏感度
  ///
  /// 比例的敏感度 = 1 / n
  static double forRatio({required int recordCount}) {
    if (recordCount <= 0) {
      throw ArgumentError('recordCount must be positive');
    }
    return 1.0 / recordCount;
  }

  /// 根据数据类型确定敏感度级别
  static SensitivityLevel classifyDataType(String dataType) {
    switch (dataType.toLowerCase()) {
      // 高敏感数据
      case 'amount':
      case 'balance':
      case 'income':
      case 'expense':
      case 'merchant':
      case 'merchant_name':
      case 'account':
      case 'card_number':
        return SensitivityLevel.high;

      // 中敏感数据
      case 'category':
      case 'subcategory':
      case 'confidence':
      case 'pattern':
        return SensitivityLevel.medium;

      // 低敏感数据
      case 'count':
      case 'statistics':
      case 'aggregated':
      case 'day_of_week':
      case 'time_slot':
        return SensitivityLevel.low;

      default:
        // 默认为中敏感
        return SensitivityLevel.medium;
    }
  }

  /// 计算学习规则的敏感度信息
  static RuleSensitivityInfo forLearnedRule() {
    return const RuleSensitivityInfo(
      confidenceSensitivity: 1.0, // 置信度范围 [0, 1]
      hitCountSensitivityPerRecord: 1.0, // 每条记录最多贡献1次命中
      confidenceSensitivityLevel: SensitivityLevel.medium,
    );
  }

  /// 计算组合查询的敏感度（串行组合）
  ///
  /// 串行组合的敏感度为各查询敏感度之和
  static double forSequentialComposition(List<double> sensitivities) {
    return sensitivities.fold(0.0, (sum, s) => sum + s);
  }

  /// 计算组合查询的敏感度（并行组合）
  ///
  /// 并行组合（在不相交数据集上）的敏感度为最大敏感度
  static double forParallelComposition(List<double> sensitivities) {
    if (sensitivities.isEmpty) return 0.0;
    return sensitivities.reduce((a, b) => a > b ? a : b);
  }
}

/// 规则敏感度信息
class RuleSensitivityInfo {
  /// 置信度的敏感度
  final double confidenceSensitivity;

  /// 每条记录对命中次数的敏感度
  final double hitCountSensitivityPerRecord;

  /// 置信度的敏感度级别
  final SensitivityLevel confidenceSensitivityLevel;

  const RuleSensitivityInfo({
    required this.confidenceSensitivity,
    required this.hitCountSensitivityPerRecord,
    required this.confidenceSensitivityLevel,
  });
}
