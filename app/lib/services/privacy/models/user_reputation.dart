/// 用户信誉等级
enum ReputationLevel {
  /// 可信用户 - 可完全参与协同学习
  trusted,

  /// 观察中 - 规则被额外审查
  underReview,

  /// 隔离状态 - 规则不参与协同学习
  isolated,
}

/// 用户信誉等级扩展
extension ReputationLevelExtension on ReputationLevel {
  /// 是否可以贡献规则
  bool get canContribute {
    switch (this) {
      case ReputationLevel.trusted:
        return true;
      case ReputationLevel.underReview:
        return true; // 可以贡献但会被额外审查
      case ReputationLevel.isolated:
        return false;
    }
  }

  /// 是否需要额外审查
  bool get requiresReview {
    switch (this) {
      case ReputationLevel.trusted:
        return false;
      case ReputationLevel.underReview:
        return true;
      case ReputationLevel.isolated:
        return true;
    }
  }

  /// 获取中文描述
  String get displayName {
    switch (this) {
      case ReputationLevel.trusted:
        return '可信用户';
      case ReputationLevel.underReview:
        return '观察中';
      case ReputationLevel.isolated:
        return '已隔离';
    }
  }
}

/// 用户信誉模型
///
/// 跟踪用户在协同学习中的信誉状态
class UserReputation {
  /// 用户ID（伪匿名化）
  final String pseudonymizedUserId;

  /// 信誉分数（0-100）
  final double score;

  /// 信誉等级
  final ReputationLevel level;

  /// 总贡献规则数
  final int totalContributions;

  /// 异常规则数
  final int anomalyCount;

  /// 连续正常次数（用于恢复信誉）
  final int consecutiveNormalCount;

  /// 隔离开始时间（如果被隔离）
  final DateTime? isolatedAt;

  /// 上次更新时间
  final DateTime lastUpdated;

  /// 创建时间
  final DateTime createdAt;

  const UserReputation({
    required this.pseudonymizedUserId,
    this.score = 100.0,
    this.level = ReputationLevel.trusted,
    this.totalContributions = 0,
    this.anomalyCount = 0,
    this.consecutiveNormalCount = 0,
    this.isolatedAt,
    required this.lastUpdated,
    required this.createdAt,
  });

  /// 新用户的初始信誉
  factory UserReputation.newUser(String pseudonymizedUserId) {
    final now = DateTime.now();
    return UserReputation(
      pseudonymizedUserId: pseudonymizedUserId,
      lastUpdated: now,
      createdAt: now,
    );
  }

  /// 异常率
  double get anomalyRate =>
      totalContributions > 0 ? anomalyCount / totalContributions : 0.0;

  /// 是否处于隔离状态
  bool get isIsolated => level == ReputationLevel.isolated;

  /// 是否需要审查
  bool get needsReview => level.requiresReview;

  /// 复制并更新
  UserReputation copyWith({
    double? score,
    ReputationLevel? level,
    int? totalContributions,
    int? anomalyCount,
    int? consecutiveNormalCount,
    DateTime? isolatedAt,
    DateTime? lastUpdated,
  }) {
    return UserReputation(
      pseudonymizedUserId: pseudonymizedUserId,
      score: score ?? this.score,
      level: level ?? this.level,
      totalContributions: totalContributions ?? this.totalContributions,
      anomalyCount: anomalyCount ?? this.anomalyCount,
      consecutiveNormalCount:
          consecutiveNormalCount ?? this.consecutiveNormalCount,
      isolatedAt: isolatedAt ?? this.isolatedAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pseudonymizedUserId': pseudonymizedUserId,
      'score': score,
      'level': level.name,
      'totalContributions': totalContributions,
      'anomalyCount': anomalyCount,
      'consecutiveNormalCount': consecutiveNormalCount,
      'isolatedAt': isolatedAt?.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserReputation.fromJson(Map<String, dynamic> json) {
    return UserReputation(
      pseudonymizedUserId: json['pseudonymizedUserId'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 100.0,
      level: ReputationLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => ReputationLevel.trusted,
      ),
      totalContributions: json['totalContributions'] as int? ?? 0,
      anomalyCount: json['anomalyCount'] as int? ?? 0,
      consecutiveNormalCount: json['consecutiveNormalCount'] as int? ?? 0,
      isolatedAt: json['isolatedAt'] != null
          ? DateTime.parse(json['isolatedAt'] as String)
          : null,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

/// 信誉配置
class ReputationConfig {
  /// 降为观察状态的异常阈值
  final int reviewThreshold;

  /// 降为隔离状态的异常阈值
  final int isolationThreshold;

  /// 恢复到观察状态所需的连续正常次数
  final int recoveryToReviewCount;

  /// 恢复到可信状态所需的连续正常次数
  final int recoveryToTrustedCount;

  /// 每次异常扣除的分数
  final double anomalyPenalty;

  /// 每次正常贡献恢复的分数
  final double normalReward;

  /// 最低分数（达到后隔离）
  final double minScore;

  const ReputationConfig({
    this.reviewThreshold = 3,
    this.isolationThreshold = 5,
    this.recoveryToReviewCount = 5,
    this.recoveryToTrustedCount = 10,
    this.anomalyPenalty = 10.0,
    this.normalReward = 2.0,
    this.minScore = 30.0,
  });

  static const defaultConfig = ReputationConfig();
}
