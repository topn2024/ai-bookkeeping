/// 排行榜类型
enum LeaderboardType {
  /// 储蓄达人
  savings,
  /// 记账达人
  recording,
  /// 预算控制
  budgetControl,
  /// 目标贡献
  goalContribution,
}

extension LeaderboardTypeExtension on LeaderboardType {
  String get displayName {
    switch (this) {
      case LeaderboardType.savings:
        return '储蓄达人';
      case LeaderboardType.recording:
        return '记账达人';
      case LeaderboardType.budgetControl:
        return '预算控制';
      case LeaderboardType.goalContribution:
        return '目标贡献';
    }
  }

  String get emoji {
    switch (this) {
      case LeaderboardType.savings:
        return '💰';
      case LeaderboardType.recording:
        return '📝';
      case LeaderboardType.budgetControl:
        return '🎯';
      case LeaderboardType.goalContribution:
        return '🏆';
    }
  }
}

/// 排行榜周期
enum LeaderboardPeriod {
  weekly,
  monthly,
  yearly,
  allTime,
}

extension LeaderboardPeriodExtension on LeaderboardPeriod {
  String get displayName {
    switch (this) {
      case LeaderboardPeriod.weekly:
        return '本周';
      case LeaderboardPeriod.monthly:
        return '本月';
      case LeaderboardPeriod.yearly:
        return '本年';
      case LeaderboardPeriod.allTime:
        return '总榜';
    }
  }
}

/// 排行榜条目
class LeaderboardEntry {
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final int rank;
  final double score;
  final double previousScore;
  final int rankChange;
  final Map<String, dynamic>? details;

  const LeaderboardEntry({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.rank,
    required this.score,
    this.previousScore = 0,
    this.rankChange = 0,
    this.details,
  });

  /// 排名是否上升
  bool get isRankUp => rankChange > 0;

  /// 排名是否下降
  bool get isRankDown => rankChange < 0;

  /// 分数变化百分比
  double get scoreChangePercent {
    if (previousScore == 0) return 0;
    return (score - previousScore) / previousScore * 100;
  }
}

/// 家庭排行榜
class FamilyLeaderboard {
  final String ledgerId;
  final LeaderboardType type;
  final LeaderboardPeriod period;
  final List<LeaderboardEntry> entries;
  final DateTime generatedAt;

  const FamilyLeaderboard({
    required this.ledgerId,
    required this.type,
    required this.period,
    required this.entries,
    required this.generatedAt,
  });

  /// 获取冠军
  LeaderboardEntry? get champion => entries.isNotEmpty ? entries.first : null;

  /// 获取指定成员的排名
  LeaderboardEntry? getEntryByMember(String memberId) {
    return entries.where((e) => e.memberId == memberId).firstOrNull;
  }
}

/// 成就类型
enum AchievementType {
  /// 连续记账
  streak,
  /// 储蓄里程碑
  savingsMilestone,
  /// 预算达成
  budgetAchieved,
  /// 目标完成
  goalCompleted,
  /// 首次分摊
  firstSplit,
  /// 邀请成员
  inviteMember,
}

/// 成就
class Achievement {
  final String id;
  final AchievementType type;
  final String title;
  final String description;
  final String emoji;
  final DateTime unlockedAt;
  final String memberId;

  const Achievement({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    required this.unlockedAt,
    required this.memberId,
  });
}
