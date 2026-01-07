import 'package:flutter/material.dart';

/// 习惯活动类型
enum HabitActivityType {
  /// 记录交易
  transaction,

  /// 查看报表
  viewReport,

  /// 检查预算
  checkBudget,

  /// 查看钱龄
  viewMoneyAge,

  /// 完成任务
  completeTask,

  /// 记账打卡
  dailyCheckin,

  /// 储蓄存款
  savingsDeposit,

  /// 预算分配
  budgetAllocation,
}

extension HabitActivityTypeExtension on HabitActivityType {
  String get displayName {
    switch (this) {
      case HabitActivityType.transaction:
        return '记录交易';
      case HabitActivityType.viewReport:
        return '查看报表';
      case HabitActivityType.checkBudget:
        return '检查预算';
      case HabitActivityType.viewMoneyAge:
        return '查看钱龄';
      case HabitActivityType.completeTask:
        return '完成任务';
      case HabitActivityType.dailyCheckin:
        return '每日打卡';
      case HabitActivityType.savingsDeposit:
        return '储蓄存款';
      case HabitActivityType.budgetAllocation:
        return '预算分配';
    }
  }

  IconData get icon {
    switch (this) {
      case HabitActivityType.transaction:
        return Icons.edit_note;
      case HabitActivityType.viewReport:
        return Icons.bar_chart;
      case HabitActivityType.checkBudget:
        return Icons.account_balance_wallet;
      case HabitActivityType.viewMoneyAge:
        return Icons.access_time;
      case HabitActivityType.completeTask:
        return Icons.check_circle;
      case HabitActivityType.dailyCheckin:
        return Icons.calendar_today;
      case HabitActivityType.savingsDeposit:
        return Icons.savings;
      case HabitActivityType.budgetAllocation:
        return Icons.pie_chart;
    }
  }

  /// 活动基础积分
  int get basePoints {
    switch (this) {
      case HabitActivityType.transaction:
        return 5;
      case HabitActivityType.viewReport:
        return 3;
      case HabitActivityType.checkBudget:
        return 3;
      case HabitActivityType.viewMoneyAge:
        return 2;
      case HabitActivityType.completeTask:
        return 10;
      case HabitActivityType.dailyCheckin:
        return 5;
      case HabitActivityType.savingsDeposit:
        return 15;
      case HabitActivityType.budgetAllocation:
        return 8;
    }
  }
}

/// 习惯分类
enum HabitCategory {
  /// 记账习惯
  bookkeeping,

  /// 储蓄习惯
  savings,

  /// 消费习惯
  spending,

  /// 预算习惯
  budgeting,

  /// 财务审视习惯
  review,
}

extension HabitCategoryExtension on HabitCategory {
  String get displayName {
    switch (this) {
      case HabitCategory.bookkeeping:
        return '记账习惯';
      case HabitCategory.savings:
        return '储蓄习惯';
      case HabitCategory.spending:
        return '消费习惯';
      case HabitCategory.budgeting:
        return '预算习惯';
      case HabitCategory.review:
        return '财务审视';
    }
  }

  IconData get icon {
    switch (this) {
      case HabitCategory.bookkeeping:
        return Icons.edit;
      case HabitCategory.savings:
        return Icons.savings;
      case HabitCategory.spending:
        return Icons.shopping_cart;
      case HabitCategory.budgeting:
        return Icons.account_balance_wallet;
      case HabitCategory.review:
        return Icons.analytics;
    }
  }

  Color get color {
    switch (this) {
      case HabitCategory.bookkeeping:
        return Colors.blue;
      case HabitCategory.savings:
        return Colors.green;
      case HabitCategory.spending:
        return Colors.orange;
      case HabitCategory.budgeting:
        return Colors.purple;
      case HabitCategory.review:
        return Colors.teal;
    }
  }
}

/// 习惯任务状态
enum HabitTaskStatus {
  /// 待开始
  pending,

  /// 进行中
  active,

  /// 已完成
  completed,

  /// 已失败/过期
  failed,

  /// 已跳过
  skipped,
}

extension HabitTaskStatusExtension on HabitTaskStatus {
  String get displayName {
    switch (this) {
      case HabitTaskStatus.pending:
        return '待开始';
      case HabitTaskStatus.active:
        return '进行中';
      case HabitTaskStatus.completed:
        return '已完成';
      case HabitTaskStatus.failed:
        return '已失败';
      case HabitTaskStatus.skipped:
        return '已跳过';
    }
  }

  Color get color {
    switch (this) {
      case HabitTaskStatus.pending:
        return Colors.grey;
      case HabitTaskStatus.active:
        return Colors.blue;
      case HabitTaskStatus.completed:
        return Colors.green;
      case HabitTaskStatus.failed:
        return Colors.red;
      case HabitTaskStatus.skipped:
        return Colors.orange;
    }
  }
}

/// 习惯任务模型
///
/// 习惯任务是金融习惯培养系统的核心，每个任务定义了用户需要完成的行为
class HabitTask {
  final String id;
  final String title;
  final String description;
  final HabitCategory category;
  final HabitTaskStatus status;
  final int reward;                   // 完成奖励积分
  final Duration duration;            // 任务持续时间
  final DateTime? startDate;          // 开始日期
  final DateTime? endDate;            // 结束日期
  final DateTime? completedAt;        // 完成时间
  final int targetCount;              // 目标次数（如：记账5次）
  final int currentCount;             // 当前完成次数
  final String? relatedFeature;       // 关联功能（如：moneyAge, budget）
  final Map<String, dynamic>? metadata; // 额外数据
  final DateTime createdAt;

  const HabitTask({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.status = HabitTaskStatus.pending,
    required this.reward,
    required this.duration,
    this.startDate,
    this.endDate,
    this.completedAt,
    this.targetCount = 1,
    this.currentCount = 0,
    this.relatedFeature,
    this.metadata,
    required this.createdAt,
  });

  /// 进度 (0-1)
  double get progress =>
      targetCount > 0 ? (currentCount / targetCount).clamp(0.0, 1.0) : 0;

  /// 是否已完成
  bool get isCompleted => status == HabitTaskStatus.completed;

  /// 是否进行中
  bool get isActive => status == HabitTaskStatus.active;

  /// 是否已过期
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!) && !isCompleted;
  }

  /// 剩余天数
  int? get daysRemaining {
    if (endDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return end.difference(today).inDays;
  }

  HabitTask copyWith({
    String? id,
    String? title,
    String? description,
    HabitCategory? category,
    HabitTaskStatus? status,
    int? reward,
    Duration? duration,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? completedAt,
    int? targetCount,
    int? currentCount,
    String? relatedFeature,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return HabitTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      reward: reward ?? this.reward,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completedAt: completedAt ?? this.completedAt,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      relatedFeature: relatedFeature ?? this.relatedFeature,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.index,
      'status': status.index,
      'reward': reward,
      'durationInDays': duration.inDays,
      'startDate': startDate?.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'relatedFeature': relatedFeature,
      'metadata': metadata?.toString(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory HabitTask.fromMap(Map<String, dynamic> map) {
    return HabitTask(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: HabitCategory.values[map['category'] as int],
      status: HabitTaskStatus.values[map['status'] as int],
      reward: map['reward'] as int,
      duration: Duration(days: map['durationInDays'] as int),
      startDate: map['startDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['startDate'] as int)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endDate'] as int)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      targetCount: map['targetCount'] as int? ?? 1,
      currentCount: map['currentCount'] as int? ?? 0,
      relatedFeature: map['relatedFeature'] as String?,
      metadata: null, // TODO: Parse from string if needed
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }
}

/// 习惯活动记录
///
/// 记录用户每次习惯相关的活动
class HabitActivity {
  final String id;
  final HabitActivityType type;
  final DateTime timestamp;
  final int pointsEarned;             // 获得的积分
  final String? relatedTaskId;        // 关联的任务ID
  final Map<String, dynamic>? data;   // 活动数据

  const HabitActivity({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.pointsEarned,
    this.relatedTaskId,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'pointsEarned': pointsEarned,
      'relatedTaskId': relatedTaskId,
      'data': data?.toString(),
    };
  }

  factory HabitActivity.fromMap(Map<String, dynamic> map) {
    return HabitActivity(
      id: map['id'] as String,
      type: HabitActivityType.values[map['type'] as int],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      pointsEarned: map['pointsEarned'] as int,
      relatedTaskId: map['relatedTaskId'] as String?,
      data: null,
    );
  }
}

/// 连续打卡记录
class CheckinStreak {
  final String id;
  final int currentStreak;            // 当前连续天数
  final int longestStreak;            // 最长连续天数
  final DateTime? lastCheckinDate;    // 最后打卡日期
  final int totalCheckins;            // 总打卡次数
  final List<DateTime> recentCheckins; // 最近打卡日期列表

  const CheckinStreak({
    required this.id,
    required this.currentStreak,
    required this.longestStreak,
    this.lastCheckinDate,
    required this.totalCheckins,
    required this.recentCheckins,
  });

  /// 今天是否已打卡
  bool get hasCheckedInToday {
    if (lastCheckinDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(
      lastCheckinDate!.year,
      lastCheckinDate!.month,
      lastCheckinDate!.day,
    );
    return today == last;
  }

  /// 是否会断签（昨天未打卡）
  bool get isAboutToBreak {
    if (lastCheckinDate == null) return currentStreak > 0;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final last = DateTime(
      lastCheckinDate!.year,
      lastCheckinDate!.month,
      lastCheckinDate!.day,
    );
    return last.isBefore(yesterday) && currentStreak > 0;
  }

  /// 连续打卡奖励倍数
  double get streakMultiplier {
    if (currentStreak < 3) return 1.0;
    if (currentStreak < 7) return 1.2;
    if (currentStreak < 14) return 1.5;
    if (currentStreak < 30) return 2.0;
    return 2.5;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastCheckinDate': lastCheckinDate?.millisecondsSinceEpoch,
      'totalCheckins': totalCheckins,
      'recentCheckins': recentCheckins
          .map((d) => d.millisecondsSinceEpoch)
          .toList()
          .join(','),
    };
  }

  factory CheckinStreak.fromMap(Map<String, dynamic> map) {
    return CheckinStreak(
      id: map['id'] as String,
      currentStreak: map['currentStreak'] as int,
      longestStreak: map['longestStreak'] as int,
      lastCheckinDate: map['lastCheckinDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastCheckinDate'] as int)
          : null,
      totalCheckins: map['totalCheckins'] as int,
      recentCheckins: map['recentCheckins'] != null
          ? (map['recentCheckins'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .map((s) => DateTime.fromMillisecondsSinceEpoch(int.parse(s)))
              .toList()
          : [],
    );
  }

  factory CheckinStreak.empty(String id) {
    return CheckinStreak(
      id: id,
      currentStreak: 0,
      longestStreak: 0,
      lastCheckinDate: null,
      totalCheckins: 0,
      recentCheckins: [],
    );
  }
}

/// 用户习惯统计摘要
class HabitSummary {
  final int totalPoints;              // 总积分
  final int currentLevel;             // 当前等级
  final int pointsToNextLevel;        // 距下一等级还需积分
  final int completedTasksCount;      // 完成任务数
  final int activeTasksCount;         // 进行中任务数
  final CheckinStreak checkinStreak;  // 打卡连续情况
  final Map<HabitCategory, int> pointsByCategory; // 各分类积分
  final List<HabitTask> activeTasks;  // 当前活跃任务

  const HabitSummary({
    required this.totalPoints,
    required this.currentLevel,
    required this.pointsToNextLevel,
    required this.completedTasksCount,
    required this.activeTasksCount,
    required this.checkinStreak,
    required this.pointsByCategory,
    required this.activeTasks,
  });

  /// 当前等级进度 (0-1)
  double get levelProgress {
    final levelThreshold = _getLevelThreshold(currentLevel);
    final nextThreshold = _getLevelThreshold(currentLevel + 1);
    final range = nextThreshold - levelThreshold;
    if (range <= 0) return 1.0;
    return ((totalPoints - levelThreshold) / range).clamp(0.0, 1.0);
  }

  /// 等级名称
  String get levelName {
    switch (currentLevel) {
      case 1:
        return '记账新手';
      case 2:
        return '理财入门';
      case 3:
        return '预算达人';
      case 4:
        return '储蓄能手';
      case 5:
        return '财务专家';
      default:
        if (currentLevel > 5) return '财务大师';
        return '记账新手';
    }
  }

  static int _getLevelThreshold(int level) {
    switch (level) {
      case 1:
        return 0;
      case 2:
        return 100;
      case 3:
        return 300;
      case 4:
        return 600;
      case 5:
        return 1000;
      default:
        return 1000 + (level - 5) * 500;
    }
  }

  factory HabitSummary.empty() {
    return HabitSummary(
      totalPoints: 0,
      currentLevel: 1,
      pointsToNextLevel: 100,
      completedTasksCount: 0,
      activeTasksCount: 0,
      checkinStreak: CheckinStreak.empty('default'),
      pointsByCategory: {},
      activeTasks: [],
    );
  }
}

/// 预设习惯任务模板
class HabitTaskTemplates {
  static List<HabitTask> get dailyTasks => [
    HabitTask(
      id: 'daily_record',
      title: '每日记账',
      description: '记录今天的每一笔收支',
      category: HabitCategory.bookkeeping,
      reward: 5,
      duration: const Duration(days: 1),
      targetCount: 1,
      createdAt: DateTime.now(),
    ),
    HabitTask(
      id: 'check_budget',
      title: '检查预算',
      description: '查看今天的预算使用情况',
      category: HabitCategory.budgeting,
      reward: 3,
      duration: const Duration(days: 1),
      targetCount: 1,
      createdAt: DateTime.now(),
    ),
  ];

  static List<HabitTask> get weeklyTasks => [
    HabitTask(
      id: 'weekly_review',
      title: '周度财务回顾',
      description: '回顾本周的消费情况，检查有无异常支出',
      category: HabitCategory.review,
      reward: 20,
      duration: const Duration(days: 7),
      targetCount: 1,
      createdAt: DateTime.now(),
    ),
    HabitTask(
      id: 'improve_money_age',
      title: '提高钱龄挑战',
      description: '本周减少非必要支出，目标：钱龄提升5天',
      category: HabitCategory.savings,
      reward: 50,
      duration: const Duration(days: 7),
      targetCount: 1,
      relatedFeature: 'moneyAge',
      createdAt: DateTime.now(),
    ),
  ];

  static List<HabitTask> get monthlyTasks => [
    HabitTask(
      id: 'monthly_savings',
      title: '月度储蓄目标',
      description: '本月存入储蓄目标金额的至少一笔',
      category: HabitCategory.savings,
      reward: 100,
      duration: const Duration(days: 30),
      targetCount: 1,
      createdAt: DateTime.now(),
    ),
    HabitTask(
      id: 'budget_adherence',
      title: '预算执行达标',
      description: '本月所有类别预算使用率不超过100%',
      category: HabitCategory.budgeting,
      reward: 150,
      duration: const Duration(days: 30),
      targetCount: 1,
      createdAt: DateTime.now(),
    ),
  ];
}
