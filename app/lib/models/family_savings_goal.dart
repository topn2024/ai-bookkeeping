import 'package:flutter/material.dart';

/// 家庭目标状态
enum FamilyGoalStatus {
  /// 进行中
  active,
  /// 已达成
  achieved,
  /// 已取消
  cancelled,
  /// 已过期
  expired,
  /// 暂停中
  paused,
}

/// 家庭目标状态扩展
extension FamilyGoalStatusExtension on FamilyGoalStatus {
  String get displayName {
    switch (this) {
      case FamilyGoalStatus.active:
        return '进行中';
      case FamilyGoalStatus.achieved:
        return '已达成';
      case FamilyGoalStatus.cancelled:
        return '已取消';
      case FamilyGoalStatus.expired:
        return '已过期';
      case FamilyGoalStatus.paused:
        return '暂停中';
    }
  }

  Color get color {
    switch (this) {
      case FamilyGoalStatus.active:
        return const Color(0xFF2196F3);
      case FamilyGoalStatus.achieved:
        return const Color(0xFF4CAF50);
      case FamilyGoalStatus.cancelled:
        return const Color(0xFF9E9E9E);
      case FamilyGoalStatus.expired:
        return const Color(0xFFFF9800);
      case FamilyGoalStatus.paused:
        return const Color(0xFF607D8B);
    }
  }

  IconData get icon {
    switch (this) {
      case FamilyGoalStatus.active:
        return Icons.flag;
      case FamilyGoalStatus.achieved:
        return Icons.emoji_events;
      case FamilyGoalStatus.cancelled:
        return Icons.cancel;
      case FamilyGoalStatus.expired:
        return Icons.timer_off;
      case FamilyGoalStatus.paused:
        return Icons.pause_circle;
    }
  }
}

/// 家庭目标贡献者
class FamilyGoalContributor {
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final double contribution;
  final double percentage;
  final int contributionCount;
  final DateTime? lastContributionAt;

  const FamilyGoalContributor({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.contribution,
    required this.percentage,
    this.contributionCount = 0,
    this.lastContributionAt,
  });

  FamilyGoalContributor copyWith({
    String? memberId,
    String? memberName,
    String? avatarUrl,
    double? contribution,
    double? percentage,
    int? contributionCount,
    DateTime? lastContributionAt,
  }) {
    return FamilyGoalContributor(
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      contribution: contribution ?? this.contribution,
      percentage: percentage ?? this.percentage,
      contributionCount: contributionCount ?? this.contributionCount,
      lastContributionAt: lastContributionAt ?? this.lastContributionAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'avatarUrl': avatarUrl,
      'contribution': contribution,
      'percentage': percentage,
      'contributionCount': contributionCount,
      'lastContributionAt': lastContributionAt?.toIso8601String(),
    };
  }

  factory FamilyGoalContributor.fromMap(Map<String, dynamic> map) {
    return FamilyGoalContributor(
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      contribution: (map['contribution'] as num).toDouble(),
      percentage: (map['percentage'] as num).toDouble(),
      contributionCount: map['contributionCount'] as int? ?? 0,
      lastContributionAt: map['lastContributionAt'] != null
          ? DateTime.parse(map['lastContributionAt'] as String)
          : null,
    );
  }
}

/// 家庭目标贡献记录
class FamilyGoalContribution {
  final String id;
  final String goalId;
  final String contributorId;
  final String contributorName;
  final double amount;
  final String? note;
  final DateTime createdAt;

  const FamilyGoalContribution({
    required this.id,
    required this.goalId,
    required this.contributorId,
    required this.contributorName,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'contributorId': contributorId,
      'contributorName': contributorName,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FamilyGoalContribution.fromMap(Map<String, dynamic> map) {
    return FamilyGoalContribution(
      id: map['id'] as String,
      goalId: map['goalId'] as String,
      contributorId: map['contributorId'] as String,
      contributorName: map['contributorName'] as String,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// 家庭储蓄目标
class FamilySavingsGoal {
  final String id;
  final String ledgerId;
  final String name;
  final String? description;
  final String emoji;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final List<FamilyGoalContributor> contributors;
  final FamilyGoalStatus status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? achievedAt;
  final String? coverImage;
  final bool isPinned;
  final bool enableNotifications;

  const FamilySavingsGoal({
    required this.id,
    required this.ledgerId,
    required this.name,
    this.description,
    this.emoji = '🎯',
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.contributors = const [],
    this.status = FamilyGoalStatus.active,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.achievedAt,
    this.coverImage,
    this.isPinned = false,
    this.enableNotifications = true,
  });

  /// 进度百分比 (0-100)
  double get progressPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount * 100).clamp(0, 100) : 0;

  /// 剩余金额
  double get remainingAmount =>
      targetAmount > currentAmount ? targetAmount - currentAmount : 0;

  /// 剩余天数
  int? get daysRemaining =>
      deadline?.difference(DateTime.now()).inDays;

  /// 是否已过期
  bool get isExpired =>
      deadline != null && DateTime.now().isAfter(deadline!);

  /// 是否即将过期（7天内）
  bool get isExpiringSoon =>
      daysRemaining != null && daysRemaining! <= 7 && daysRemaining! > 0;

  /// 是否已达成
  bool get isAchieved =>
      status == FamilyGoalStatus.achieved || currentAmount >= targetAmount;

  /// 是否可以贡献
  bool get canContribute =>
      status == FamilyGoalStatus.active && !isExpired && currentAmount < targetAmount;

  /// 贡献者数量
  int get contributorCount => contributors.length;

  /// 平均每人贡献
  double get averageContribution =>
      contributorCount > 0 ? currentAmount / contributorCount : 0;

  FamilySavingsGoal copyWith({
    String? id,
    String? ledgerId,
    String? name,
    String? description,
    String? emoji,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    List<FamilyGoalContributor>? contributors,
    FamilyGoalStatus? status,
    String? createdBy,
    DateTime? updatedAt,
    DateTime? achievedAt,
    String? coverImage,
    bool? isPinned,
    bool? enableNotifications,
  }) {
    return FamilySavingsGoal(
      id: id ?? this.id,
      ledgerId: ledgerId ?? this.ledgerId,
      name: name ?? this.name,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      contributors: contributors ?? this.contributors,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      achievedAt: achievedAt ?? this.achievedAt,
      coverImage: coverImage ?? this.coverImage,
      isPinned: isPinned ?? this.isPinned,
      enableNotifications: enableNotifications ?? this.enableNotifications,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ledgerId': ledgerId,
      'name': name,
      'description': description,
      'emoji': emoji,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline?.toIso8601String(),
      'contributors': contributors.map((c) => c.toMap()).toList(),
      'status': status.index,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'achievedAt': achievedAt?.toIso8601String(),
      'coverImage': coverImage,
      'isPinned': isPinned,
      'enableNotifications': enableNotifications,
    };
  }

  factory FamilySavingsGoal.fromMap(Map<String, dynamic> map) {
    return FamilySavingsGoal(
      id: map['id'] as String,
      ledgerId: map['ledgerId'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      emoji: map['emoji'] as String? ?? '🎯',
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0,
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      contributors: (map['contributors'] as List?)
              ?.map((c) => FamilyGoalContributor.fromMap(c as Map<String, dynamic>))
              .toList() ??
          [],
      status: FamilyGoalStatus.values[map['status'] as int? ?? 0],
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      achievedAt: map['achievedAt'] != null
          ? DateTime.parse(map['achievedAt'] as String)
          : null,
      coverImage: map['coverImage'] as String?,
      isPinned: map['isPinned'] as bool? ?? false,
      enableNotifications: map['enableNotifications'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilySavingsGoal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FamilySavingsGoal(id: $id, name: $name, progress: ${progressPercentage.toStringAsFixed(1)}%)';
  }
}

/// 家庭目标里程碑
class FamilyGoalMilestone {
  final int percentage;
  final double amount;
  final bool isReached;
  final DateTime? reachedAt;
  final String celebrationMessage;

  const FamilyGoalMilestone({
    required this.percentage,
    required this.amount,
    this.isReached = false,
    this.reachedAt,
    required this.celebrationMessage,
  });

  static List<FamilyGoalMilestone> defaultMilestones(double targetAmount) {
    return [
      FamilyGoalMilestone(
        percentage: 25,
        amount: targetAmount * 0.25,
        celebrationMessage: '太棒了！大家一起完成了四分之一！',
      ),
      FamilyGoalMilestone(
        percentage: 50,
        amount: targetAmount * 0.50,
        celebrationMessage: '半程达成！继续加油！',
      ),
      FamilyGoalMilestone(
        percentage: 75,
        amount: targetAmount * 0.75,
        celebrationMessage: '只差一点点了！冲刺吧！',
      ),
      FamilyGoalMilestone(
        percentage: 100,
        amount: targetAmount,
        celebrationMessage: '目标达成！大家的努力终于有了回报！',
      ),
    ];
  }
}

/// 家庭目标模板
class FamilyGoalTemplate {
  final String name;
  final String emoji;
  final String description;
  final double? suggestedAmount;
  final Duration? suggestedDuration;

  const FamilyGoalTemplate({
    required this.name,
    required this.emoji,
    required this.description,
    this.suggestedAmount,
    this.suggestedDuration,
  });

  static const List<FamilyGoalTemplate> templates = [
    FamilyGoalTemplate(
      name: '家庭旅行',
      emoji: '✈️',
      description: '全家一起攒钱去旅行',
      suggestedAmount: 20000,
      suggestedDuration: Duration(days: 180),
    ),
    FamilyGoalTemplate(
      name: '新家电',
      emoji: '📺',
      description: '一起攒钱购买新家电',
      suggestedAmount: 5000,
      suggestedDuration: Duration(days: 90),
    ),
    FamilyGoalTemplate(
      name: '家庭应急金',
      emoji: '🏥',
      description: '建立家庭应急储备基金',
      suggestedAmount: 30000,
      suggestedDuration: Duration(days: 365),
    ),
    FamilyGoalTemplate(
      name: '子女教育',
      emoji: '📚',
      description: '为孩子的教育储蓄',
      suggestedAmount: 50000,
    ),
    FamilyGoalTemplate(
      name: '房屋装修',
      emoji: '🏠',
      description: '共同为装修存钱',
      suggestedAmount: 100000,
    ),
    FamilyGoalTemplate(
      name: '换新车',
      emoji: '🚗',
      description: '全家一起攒钱换车',
      suggestedAmount: 150000,
    ),
    FamilyGoalTemplate(
      name: '节日基金',
      emoji: '🎁',
      description: '春节/生日等节日开支',
      suggestedAmount: 5000,
      suggestedDuration: Duration(days: 60),
    ),
    FamilyGoalTemplate(
      name: '宠物基金',
      emoji: '🐾',
      description: '家庭宠物相关开支',
      suggestedAmount: 3000,
      suggestedDuration: Duration(days: 90),
    ),
    FamilyGoalTemplate(
      name: '婚礼基金',
      emoji: '💒',
      description: '为婚礼筹备储蓄',
      suggestedAmount: 100000,
    ),
    FamilyGoalTemplate(
      name: '蜜月基金',
      emoji: '💕',
      description: '蜜月旅行专项存款',
      suggestedAmount: 30000,
      suggestedDuration: Duration(days: 180),
    ),
  ];
}
