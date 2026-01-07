import 'package:flutter/material.dart';

/// 成就分类
enum AchievementCategory {
  /// 记账相关成就
  bookkeeping,

  /// 储蓄相关成就
  savings,

  /// 预算相关成就
  budget,

  /// 钱龄相关成就
  moneyAge,

  /// 连续打卡成就
  streak,

  /// 里程碑成就
  milestone,

  /// 特殊成就
  special,
}

extension AchievementCategoryExtension on AchievementCategory {
  String get displayName {
    switch (this) {
      case AchievementCategory.bookkeeping:
        return '记账达人';
      case AchievementCategory.savings:
        return '储蓄能手';
      case AchievementCategory.budget:
        return '预算专家';
      case AchievementCategory.moneyAge:
        return '钱龄大师';
      case AchievementCategory.streak:
        return '坚持不懈';
      case AchievementCategory.milestone:
        return '重要里程碑';
      case AchievementCategory.special:
        return '特殊成就';
    }
  }

  IconData get icon {
    switch (this) {
      case AchievementCategory.bookkeeping:
        return Icons.edit_note;
      case AchievementCategory.savings:
        return Icons.savings;
      case AchievementCategory.budget:
        return Icons.account_balance_wallet;
      case AchievementCategory.moneyAge:
        return Icons.access_time_filled;
      case AchievementCategory.streak:
        return Icons.local_fire_department;
      case AchievementCategory.milestone:
        return Icons.flag;
      case AchievementCategory.special:
        return Icons.star;
    }
  }

  Color get color {
    switch (this) {
      case AchievementCategory.bookkeeping:
        return Colors.blue;
      case AchievementCategory.savings:
        return Colors.green;
      case AchievementCategory.budget:
        return Colors.purple;
      case AchievementCategory.moneyAge:
        return Colors.teal;
      case AchievementCategory.streak:
        return Colors.orange;
      case AchievementCategory.milestone:
        return Colors.amber;
      case AchievementCategory.special:
        return Colors.pink;
    }
  }
}

/// 成就稀有度
enum AchievementRarity {
  /// 普通
  common,

  /// 稀有
  rare,

  /// 史诗
  epic,

  /// 传奇
  legendary,
}

extension AchievementRarityExtension on AchievementRarity {
  String get displayName {
    switch (this) {
      case AchievementRarity.common:
        return '普通';
      case AchievementRarity.rare:
        return '稀有';
      case AchievementRarity.epic:
        return '史诗';
      case AchievementRarity.legendary:
        return '传奇';
    }
  }

  Color get color {
    switch (this) {
      case AchievementRarity.common:
        return Colors.grey;
      case AchievementRarity.rare:
        return Colors.blue;
      case AchievementRarity.epic:
        return Colors.purple;
      case AchievementRarity.legendary:
        return Colors.amber;
    }
  }

  /// 稀有度对应的奖励倍数
  double get rewardMultiplier {
    switch (this) {
      case AchievementRarity.common:
        return 1.0;
      case AchievementRarity.rare:
        return 1.5;
      case AchievementRarity.epic:
        return 2.0;
      case AchievementRarity.legendary:
        return 3.0;
    }
  }
}

/// 成就定义
///
/// 定义成就的基本信息和解锁条件
class Achievement {
  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final IconData icon;
  final int targetValue;              // 目标值
  final int rewardPoints;             // 奖励积分
  final String? badgeImagePath;       // 徽章图片路径
  final bool isHidden;                // 是否隐藏成就（达成前不显示）
  final String? unlockHint;           // 解锁提示
  final List<String>? prerequisiteIds; // 前置成就ID列表

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.icon,
    required this.targetValue,
    required this.rewardPoints,
    this.badgeImagePath,
    this.isHidden = false,
    this.unlockHint,
    this.prerequisiteIds,
  });

  /// 是否有前置成就要求
  bool get hasPrerequisites =>
      prerequisiteIds != null && prerequisiteIds!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.index,
      'rarity': rarity.index,
      'iconCode': icon.codePoint,
      'targetValue': targetValue,
      'rewardPoints': rewardPoints,
      'badgeImagePath': badgeImagePath,
      'isHidden': isHidden ? 1 : 0,
      'unlockHint': unlockHint,
      'prerequisiteIds': prerequisiteIds?.join(','),
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      category: AchievementCategory.values[map['category'] as int],
      rarity: AchievementRarity.values[map['rarity'] as int],
      icon: IconData(map['iconCode'] as int, fontFamily: 'MaterialIcons'),
      targetValue: map['targetValue'] as int,
      rewardPoints: map['rewardPoints'] as int,
      badgeImagePath: map['badgeImagePath'] as String?,
      isHidden: map['isHidden'] == 1,
      unlockHint: map['unlockHint'] as String?,
      prerequisiteIds: map['prerequisiteIds'] != null
          ? (map['prerequisiteIds'] as String).split(',')
          : null,
    );
  }
}

/// 用户成就进度
class AchievementProgress {
  final String id;
  final String achievementId;
  final String odId;                  // 用户ID
  final int currentValue;             // 当前进度值
  final int targetValue;              // 目标值
  final bool isUnlocked;              // 是否已解锁
  final DateTime? unlockedAt;         // 解锁时间
  final bool rewardClaimed;           // 是否已领取奖励
  final DateTime? rewardClaimedAt;    // 领取奖励时间
  final DateTime updatedAt;

  const AchievementProgress({
    required this.id,
    required this.achievementId,
    required this.odId,
    required this.currentValue,
    required this.targetValue,
    this.isUnlocked = false,
    this.unlockedAt,
    this.rewardClaimed = false,
    this.rewardClaimedAt,
    required this.updatedAt,
  });

  /// 进度百分比 (0-1)
  double get percentage =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0;

  /// 是否已完成但未领取奖励
  bool get canClaimReward => isUnlocked && !rewardClaimed;

  /// 剩余进度
  int get remaining => (targetValue - currentValue).clamp(0, targetValue);

  AchievementProgress copyWith({
    String? id,
    String? achievementId,
    String? odId,
    int? currentValue,
    int? targetValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
    bool? rewardClaimed,
    DateTime? rewardClaimedAt,
    DateTime? updatedAt,
  }) {
    return AchievementProgress(
      id: id ?? this.id,
      achievementId: achievementId ?? this.achievementId,
      odId: odId ?? this.odId,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue ?? this.targetValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
      rewardClaimedAt: rewardClaimedAt ?? this.rewardClaimedAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'achievementId': achievementId,
      'odId': odId,
      'currentValue': currentValue,
      'targetValue': targetValue,
      'isUnlocked': isUnlocked ? 1 : 0,
      'unlockedAt': unlockedAt?.millisecondsSinceEpoch,
      'rewardClaimed': rewardClaimed ? 1 : 0,
      'rewardClaimedAt': rewardClaimedAt?.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AchievementProgress.fromMap(Map<String, dynamic> map) {
    return AchievementProgress(
      id: map['id'] as String,
      achievementId: map['achievementId'] as String,
      odId: map['odId'] as String,
      currentValue: map['currentValue'] as int,
      targetValue: map['targetValue'] as int,
      isUnlocked: map['isUnlocked'] == 1,
      unlockedAt: map['unlockedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['unlockedAt'] as int)
          : null,
      rewardClaimed: map['rewardClaimed'] == 1,
      rewardClaimedAt: map['rewardClaimedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['rewardClaimedAt'] as int)
          : null,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  factory AchievementProgress.initial({
    required String id,
    required String odId,
    required Achievement achievement,
  }) {
    return AchievementProgress(
      id: id,
      achievementId: achievement.id,
      odId: odId,
      currentValue: 0,
      targetValue: achievement.targetValue,
      updatedAt: DateTime.now(),
    );
  }
}

/// 成就解锁通知
class AchievementUnlockNotification {
  final Achievement achievement;
  final DateTime unlockedAt;
  final bool isNew;                   // 是否是新解锁的成就

  const AchievementUnlockNotification({
    required this.achievement,
    required this.unlockedAt,
    this.isNew = true,
  });
}

/// 成就统计摘要
class AchievementSummary {
  final int totalAchievements;        // 总成就数
  final int unlockedCount;            // 已解锁数
  final int totalPoints;              // 已获得总积分
  final int unclaimedRewards;         // 未领取奖励数
  final Map<AchievementCategory, int> unlockedByCategory; // 各分类解锁数
  final Map<AchievementRarity, int> unlockedByRarity;     // 各稀有度解锁数
  final AchievementProgress? nearestToUnlock;             // 最接近解锁的成就

  const AchievementSummary({
    required this.totalAchievements,
    required this.unlockedCount,
    required this.totalPoints,
    required this.unclaimedRewards,
    required this.unlockedByCategory,
    required this.unlockedByRarity,
    this.nearestToUnlock,
  });

  /// 解锁率 (0-1)
  double get unlockRate =>
      totalAchievements > 0 ? unlockedCount / totalAchievements : 0;

  /// 解锁百分比显示
  String get unlockPercentage => '${(unlockRate * 100).toStringAsFixed(1)}%';

  factory AchievementSummary.empty() {
    return const AchievementSummary(
      totalAchievements: 0,
      unlockedCount: 0,
      totalPoints: 0,
      unclaimedRewards: 0,
      unlockedByCategory: {},
      unlockedByRarity: {},
      nearestToUnlock: null,
    );
  }
}

/// 预定义成就列表
class AchievementDefinitions {
  /// 记账相关成就
  static List<Achievement> get bookkeepingAchievements => [
    const Achievement(
      id: 'first_transaction',
      name: '初次记账',
      description: '记录第一笔交易',
      category: AchievementCategory.bookkeeping,
      rarity: AchievementRarity.common,
      icon: Icons.edit,
      targetValue: 1,
      rewardPoints: 10,
    ),
    const Achievement(
      id: 'transaction_10',
      name: '记账入门',
      description: '累计记录10笔交易',
      category: AchievementCategory.bookkeeping,
      rarity: AchievementRarity.common,
      icon: Icons.format_list_numbered,
      targetValue: 10,
      rewardPoints: 20,
    ),
    const Achievement(
      id: 'transaction_100',
      name: '记账达人',
      description: '累计记录100笔交易',
      category: AchievementCategory.bookkeeping,
      rarity: AchievementRarity.rare,
      icon: Icons.auto_awesome,
      targetValue: 100,
      rewardPoints: 50,
    ),
    const Achievement(
      id: 'transaction_1000',
      name: '记账大师',
      description: '累计记录1000笔交易',
      category: AchievementCategory.bookkeeping,
      rarity: AchievementRarity.epic,
      icon: Icons.emoji_events,
      targetValue: 1000,
      rewardPoints: 200,
    ),
  ];

  /// 连续打卡成就
  static List<Achievement> get streakAchievements => [
    const Achievement(
      id: 'streak_3',
      name: '三日坚持',
      description: '连续打卡3天',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.common,
      icon: Icons.local_fire_department,
      targetValue: 3,
      rewardPoints: 15,
    ),
    const Achievement(
      id: 'streak_7',
      name: '一周达人',
      description: '连续打卡7天',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.common,
      icon: Icons.whatshot,
      targetValue: 7,
      rewardPoints: 30,
    ),
    const Achievement(
      id: 'streak_30',
      name: '月度坚持',
      description: '连续打卡30天',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.rare,
      icon: Icons.local_fire_department,
      targetValue: 30,
      rewardPoints: 100,
    ),
    const Achievement(
      id: 'streak_100',
      name: '百日坚持',
      description: '连续打卡100天',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.epic,
      icon: Icons.local_fire_department,
      targetValue: 100,
      rewardPoints: 300,
    ),
    const Achievement(
      id: 'streak_365',
      name: '全年无休',
      description: '连续打卡365天',
      category: AchievementCategory.streak,
      rarity: AchievementRarity.legendary,
      icon: Icons.military_tech,
      targetValue: 365,
      rewardPoints: 1000,
    ),
  ];

  /// 钱龄相关成就
  static List<Achievement> get moneyAgeAchievements => [
    const Achievement(
      id: 'money_age_7',
      name: '钱龄入门',
      description: '钱龄达到7天',
      category: AchievementCategory.moneyAge,
      rarity: AchievementRarity.common,
      icon: Icons.access_time,
      targetValue: 7,
      rewardPoints: 20,
    ),
    const Achievement(
      id: 'money_age_14',
      name: '资金缓冲',
      description: '钱龄达到14天',
      category: AchievementCategory.moneyAge,
      rarity: AchievementRarity.common,
      icon: Icons.hourglass_bottom,
      targetValue: 14,
      rewardPoints: 40,
    ),
    const Achievement(
      id: 'money_age_30',
      name: '月度储备',
      description: '钱龄达到30天',
      category: AchievementCategory.moneyAge,
      rarity: AchievementRarity.rare,
      icon: Icons.schedule,
      targetValue: 30,
      rewardPoints: 80,
    ),
    const Achievement(
      id: 'money_age_60',
      name: '财务稳健',
      description: '钱龄达到60天',
      category: AchievementCategory.moneyAge,
      rarity: AchievementRarity.epic,
      icon: Icons.timer,
      targetValue: 60,
      rewardPoints: 150,
    ),
    const Achievement(
      id: 'money_age_90',
      name: '财务自由',
      description: '钱龄达到90天',
      category: AchievementCategory.moneyAge,
      rarity: AchievementRarity.legendary,
      icon: Icons.diamond,
      targetValue: 90,
      rewardPoints: 300,
    ),
  ];

  /// 储蓄相关成就
  static List<Achievement> get savingsAchievements => [
    const Achievement(
      id: 'first_savings',
      name: '储蓄起步',
      description: '完成第一笔储蓄存款',
      category: AchievementCategory.savings,
      rarity: AchievementRarity.common,
      icon: Icons.savings,
      targetValue: 1,
      rewardPoints: 15,
    ),
    const Achievement(
      id: 'savings_goal_complete',
      name: '目标达成',
      description: '完成一个储蓄目标',
      category: AchievementCategory.savings,
      rarity: AchievementRarity.rare,
      icon: Icons.flag,
      targetValue: 1,
      rewardPoints: 100,
    ),
    const Achievement(
      id: 'savings_goals_5',
      name: '储蓄达人',
      description: '累计完成5个储蓄目标',
      category: AchievementCategory.savings,
      rarity: AchievementRarity.epic,
      icon: Icons.emoji_events,
      targetValue: 5,
      rewardPoints: 300,
    ),
  ];

  /// 预算相关成就
  static List<Achievement> get budgetAchievements => [
    const Achievement(
      id: 'first_budget',
      name: '预算起步',
      description: '创建第一个预算',
      category: AchievementCategory.budget,
      rarity: AchievementRarity.common,
      icon: Icons.account_balance_wallet,
      targetValue: 1,
      rewardPoints: 15,
    ),
    const Achievement(
      id: 'budget_month_complete',
      name: '预算达标',
      description: '一个月内所有预算未超支',
      category: AchievementCategory.budget,
      rarity: AchievementRarity.rare,
      icon: Icons.check_circle,
      targetValue: 1,
      rewardPoints: 80,
    ),
    const Achievement(
      id: 'budget_3_months',
      name: '预算专家',
      description: '连续3个月预算达标',
      category: AchievementCategory.budget,
      rarity: AchievementRarity.epic,
      icon: Icons.verified,
      targetValue: 3,
      rewardPoints: 200,
    ),
  ];

  /// 获取所有成就定义
  static List<Achievement> get all => [
    ...bookkeepingAchievements,
    ...streakAchievements,
    ...moneyAgeAchievements,
    ...savingsAchievements,
    ...budgetAchievements,
  ];
}
