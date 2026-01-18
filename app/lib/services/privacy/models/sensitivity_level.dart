/// 敏感度级别 - 对应专利设计的ε值分配
///
/// 不同敏感度级别对应不同的隐私保护强度：
/// - 高敏感数据需要更强的保护（更小的ε值）
/// - 低敏感数据可以使用较弱的保护（更大的ε值）
enum SensitivityLevel {
  /// 高敏感（金额、商户信息）：ε = 0.1
  /// 提供最强的隐私保护
  high,

  /// 中敏感（分类信息）：ε = 0.5
  /// 提供中等程度的隐私保护
  medium,

  /// 低敏感（统计信息）：ε = 1.0
  /// 提供基础的隐私保护
  low,
}

/// SensitivityLevel 扩展方法
extension SensitivityLevelExtension on SensitivityLevel {
  /// 获取对应的默认 epsilon 值
  double get defaultEpsilon {
    switch (this) {
      case SensitivityLevel.high:
        return 0.1;
      case SensitivityLevel.medium:
        return 0.5;
      case SensitivityLevel.low:
        return 1.0;
    }
  }

  /// 获取中文描述
  String get displayName {
    switch (this) {
      case SensitivityLevel.high:
        return '高敏感';
      case SensitivityLevel.medium:
        return '中敏感';
      case SensitivityLevel.low:
        return '低敏感';
    }
  }

  /// 获取详细描述
  String get description {
    switch (this) {
      case SensitivityLevel.high:
        return '金额、商户等核心财务信息，需要最强保护';
      case SensitivityLevel.medium:
        return '分类等辅助信息，需要中等保护';
      case SensitivityLevel.low:
        return '统计汇总信息，需要基础保护';
    }
  }
}
