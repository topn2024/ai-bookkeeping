import 'sensitivity_level.dart';

/// 隐私预算配置
///
/// 定义各敏感度级别的epsilon值和总预算限制
class PrivacyBudgetConfig {
  /// 高敏感数据的epsilon值
  final double highSensitivityEpsilon;

  /// 中敏感数据的epsilon值
  final double mediumSensitivityEpsilon;

  /// 低敏感数据的epsilon值
  final double lowSensitivityEpsilon;

  /// 总预算上限
  final double totalBudgetLimit;

  /// 预算重置周期（小时）
  final int resetPeriodHours;

  const PrivacyBudgetConfig({
    this.highSensitivityEpsilon = 0.1,
    this.mediumSensitivityEpsilon = 0.5,
    this.lowSensitivityEpsilon = 1.0,
    this.totalBudgetLimit = 10.0,
    this.resetPeriodHours = 24,
  });

  /// 默认配置
  static const defaultConfig = PrivacyBudgetConfig();

  /// 获取指定敏感度级别的epsilon值
  double getEpsilon(SensitivityLevel level) {
    switch (level) {
      case SensitivityLevel.high:
        return highSensitivityEpsilon;
      case SensitivityLevel.medium:
        return mediumSensitivityEpsilon;
      case SensitivityLevel.low:
        return lowSensitivityEpsilon;
    }
  }

  PrivacyBudgetConfig copyWith({
    double? highSensitivityEpsilon,
    double? mediumSensitivityEpsilon,
    double? lowSensitivityEpsilon,
    double? totalBudgetLimit,
    int? resetPeriodHours,
  }) {
    return PrivacyBudgetConfig(
      highSensitivityEpsilon:
          highSensitivityEpsilon ?? this.highSensitivityEpsilon,
      mediumSensitivityEpsilon:
          mediumSensitivityEpsilon ?? this.mediumSensitivityEpsilon,
      lowSensitivityEpsilon:
          lowSensitivityEpsilon ?? this.lowSensitivityEpsilon,
      totalBudgetLimit: totalBudgetLimit ?? this.totalBudgetLimit,
      resetPeriodHours: resetPeriodHours ?? this.resetPeriodHours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'highSensitivityEpsilon': highSensitivityEpsilon,
      'mediumSensitivityEpsilon': mediumSensitivityEpsilon,
      'lowSensitivityEpsilon': lowSensitivityEpsilon,
      'totalBudgetLimit': totalBudgetLimit,
      'resetPeriodHours': resetPeriodHours,
    };
  }

  factory PrivacyBudgetConfig.fromJson(Map<String, dynamic> json) {
    return PrivacyBudgetConfig(
      highSensitivityEpsilon:
          (json['highSensitivityEpsilon'] as num?)?.toDouble() ?? 0.1,
      mediumSensitivityEpsilon:
          (json['mediumSensitivityEpsilon'] as num?)?.toDouble() ?? 0.5,
      lowSensitivityEpsilon:
          (json['lowSensitivityEpsilon'] as num?)?.toDouble() ?? 1.0,
      totalBudgetLimit:
          (json['totalBudgetLimit'] as num?)?.toDouble() ?? 10.0,
      resetPeriodHours: json['resetPeriodHours'] as int? ?? 24,
    );
  }
}

/// 隐私预算状态
///
/// 跟踪各敏感度级别的预算消耗情况
class PrivacyBudgetState {
  /// 高敏感数据已消耗的预算
  final double highSensitivityConsumed;

  /// 中敏感数据已消耗的预算
  final double mediumSensitivityConsumed;

  /// 低敏感数据已消耗的预算
  final double lowSensitivityConsumed;

  /// 上次重置时间
  final DateTime lastResetTime;

  /// 预算是否已耗尽
  final bool isExhausted;

  const PrivacyBudgetState({
    this.highSensitivityConsumed = 0.0,
    this.mediumSensitivityConsumed = 0.0,
    this.lowSensitivityConsumed = 0.0,
    required this.lastResetTime,
    this.isExhausted = false,
  });

  /// 初始状态
  factory PrivacyBudgetState.initial() {
    return PrivacyBudgetState(
      lastResetTime: DateTime.now(),
    );
  }

  /// 获取总消耗量
  double get totalConsumed =>
      highSensitivityConsumed +
      mediumSensitivityConsumed +
      lowSensitivityConsumed;

  /// 获取指定级别的消耗量
  double getConsumed(SensitivityLevel level) {
    switch (level) {
      case SensitivityLevel.high:
        return highSensitivityConsumed;
      case SensitivityLevel.medium:
        return mediumSensitivityConsumed;
      case SensitivityLevel.low:
        return lowSensitivityConsumed;
    }
  }

  PrivacyBudgetState copyWith({
    double? highSensitivityConsumed,
    double? mediumSensitivityConsumed,
    double? lowSensitivityConsumed,
    DateTime? lastResetTime,
    bool? isExhausted,
  }) {
    return PrivacyBudgetState(
      highSensitivityConsumed:
          highSensitivityConsumed ?? this.highSensitivityConsumed,
      mediumSensitivityConsumed:
          mediumSensitivityConsumed ?? this.mediumSensitivityConsumed,
      lowSensitivityConsumed:
          lowSensitivityConsumed ?? this.lowSensitivityConsumed,
      lastResetTime: lastResetTime ?? this.lastResetTime,
      isExhausted: isExhausted ?? this.isExhausted,
    );
  }

  /// 重置预算状态
  PrivacyBudgetState reset() {
    return PrivacyBudgetState(
      highSensitivityConsumed: 0.0,
      mediumSensitivityConsumed: 0.0,
      lowSensitivityConsumed: 0.0,
      lastResetTime: DateTime.now(),
      isExhausted: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'highSensitivityConsumed': highSensitivityConsumed,
      'mediumSensitivityConsumed': mediumSensitivityConsumed,
      'lowSensitivityConsumed': lowSensitivityConsumed,
      'lastResetTime': lastResetTime.toIso8601String(),
      'isExhausted': isExhausted,
    };
  }

  factory PrivacyBudgetState.fromJson(Map<String, dynamic> json) {
    return PrivacyBudgetState(
      highSensitivityConsumed:
          (json['highSensitivityConsumed'] as num?)?.toDouble() ?? 0.0,
      mediumSensitivityConsumed:
          (json['mediumSensitivityConsumed'] as num?)?.toDouble() ?? 0.0,
      lowSensitivityConsumed:
          (json['lowSensitivityConsumed'] as num?)?.toDouble() ?? 0.0,
      lastResetTime: json['lastResetTime'] != null
          ? DateTime.parse(json['lastResetTime'] as String)
          : DateTime.now(),
      isExhausted: json['isExhausted'] as bool? ?? false,
    );
  }
}

/// 预算消耗记录
class BudgetConsumptionRecord {
  /// 记录ID
  final String id;

  /// 消耗的epsilon值
  final double epsilon;

  /// 敏感度级别
  final SensitivityLevel level;

  /// 操作类型
  final String operation;

  /// 时间戳
  final DateTime timestamp;

  const BudgetConsumptionRecord({
    required this.id,
    required this.epsilon,
    required this.level,
    required this.operation,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'epsilon': epsilon,
      'level': level.name,
      'operation': operation,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BudgetConsumptionRecord.fromJson(Map<String, dynamic> json) {
    return BudgetConsumptionRecord(
      id: json['id'] as String,
      epsilon: (json['epsilon'] as num).toDouble(),
      level: SensitivityLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => SensitivityLevel.medium,
      ),
      operation: json['operation'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
