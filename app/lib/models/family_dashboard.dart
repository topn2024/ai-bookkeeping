import 'package:flutter/material.dart';

import 'common_types.dart';

/// 家庭财务看板数据
class FamilyDashboardData {
  /// 账本ID
  final String ledgerId;
  /// 时间周期（如 "2024-01"）
  final String period;
  /// 家庭汇总数据
  final FamilySummary summary;
  /// 成员贡献
  final List<MemberContribution> memberContributions;
  /// 分类分布
  final List<CategoryBreakdown> categoryBreakdown;
  /// 支出趋势
  final List<TrendPoint> spendingTrend;
  /// 预算状态
  final List<BudgetStatus> budgetStatuses;
  /// 待处理分摊
  final List<PendingSplit> pendingSplits;
  /// 储蓄目标进度
  final List<GoalProgress> goalProgresses;
  /// 最近活动
  final List<FamilyActivity> recentActivities;

  const FamilyDashboardData({
    required this.ledgerId,
    required this.period,
    required this.summary,
    this.memberContributions = const [],
    this.categoryBreakdown = const [],
    this.spendingTrend = const [],
    this.budgetStatuses = const [],
    this.pendingSplits = const [],
    this.goalProgresses = const [],
    this.recentActivities = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'ledgerId': ledgerId,
      'period': period,
      'summary': summary.toMap(),
      'memberContributions': memberContributions.map((m) => m.toMap()).toList(),
      'categoryBreakdown': categoryBreakdown.map((c) => c.toMap()).toList(),
      'spendingTrend': spendingTrend.map((t) => t.toMap()).toList(),
      'budgetStatuses': budgetStatuses.map((b) => b.toMap()).toList(),
      'pendingSplits': pendingSplits.map((p) => p.toMap()).toList(),
      'goalProgresses': goalProgresses.map((g) => g.toMap()).toList(),
      'recentActivities': recentActivities.map((a) => a.toMap()).toList(),
    };
  }
}

/// 家庭汇总数据
class FamilySummary {
  /// 总收入
  final double totalIncome;
  /// 总支出
  final double totalExpense;
  /// 净储蓄
  final double netSavings;
  /// 储蓄率 (0-100)
  final double savingsRate;
  /// 交易笔数
  final int transactionCount;
  /// 平均每日支出
  final double avgDailyExpense;
  /// 与上期对比（支出变化百分比）
  final double? expenseChange;
  /// 活跃成员数
  final int activeMemberCount;

  const FamilySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.transactionCount,
    required this.avgDailyExpense,
    this.expenseChange,
    this.activeMemberCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netSavings': netSavings,
      'savingsRate': savingsRate,
      'transactionCount': transactionCount,
      'avgDailyExpense': avgDailyExpense,
      'expenseChange': expenseChange,
      'activeMemberCount': activeMemberCount,
    };
  }

  factory FamilySummary.fromMap(Map<String, dynamic> map) {
    return FamilySummary(
      totalIncome: (map['totalIncome'] as num).toDouble(),
      totalExpense: (map['totalExpense'] as num).toDouble(),
      netSavings: (map['netSavings'] as num).toDouble(),
      savingsRate: (map['savingsRate'] as num).toDouble(),
      transactionCount: map['transactionCount'] as int,
      avgDailyExpense: (map['avgDailyExpense'] as num).toDouble(),
      expenseChange: (map['expenseChange'] as num?)?.toDouble(),
      activeMemberCount: map['activeMemberCount'] as int? ?? 0,
    );
  }
}

/// 成员贡献（非竞争性设计，不进行排名）
class MemberContribution {
  /// 成员ID
  final String memberId;
  /// 成员名称
  final String memberName;
  /// 头像URL
  final String? avatarUrl;
  /// 收入金额
  final double income;
  /// 支出金额
  final double expense;
  /// 交易笔数
  final int transactionCount;
  /// 支出占比 (0-100)
  final double contributionPercentage;
  /// 主要支出分类
  final List<String> topCategories;
  /// 最近活动时间
  final DateTime? lastActivityAt;

  const MemberContribution({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.income,
    required this.expense,
    required this.transactionCount,
    required this.contributionPercentage,
    this.topCategories = const [],
    this.lastActivityAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'avatarUrl': avatarUrl,
      'income': income,
      'expense': expense,
      'transactionCount': transactionCount,
      'contributionPercentage': contributionPercentage,
      'topCategories': topCategories,
      'lastActivityAt': lastActivityAt?.toIso8601String(),
    };
  }

  factory MemberContribution.fromMap(Map<String, dynamic> map) {
    return MemberContribution(
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      income: (map['income'] as num).toDouble(),
      expense: (map['expense'] as num).toDouble(),
      transactionCount: map['transactionCount'] as int,
      contributionPercentage: (map['contributionPercentage'] as num).toDouble(),
      topCategories: List<String>.from(map['topCategories'] ?? []),
      lastActivityAt: map['lastActivityAt'] != null
          ? DateTime.parse(map['lastActivityAt'] as String)
          : null,
    );
  }
}

/// 分类分布
class CategoryBreakdown {
  /// 分类ID
  final String categoryId;
  /// 分类名称
  final String categoryName;
  /// 分类图标
  final IconData icon;
  /// 分类颜色
  final Color color;
  /// 支出金额
  final double amount;
  /// 占比 (0-100)
  final double percentage;
  /// 交易笔数
  final int transactionCount;
  /// 与上期对比
  final double? change;

  const CategoryBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    this.change,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'icon': icon.codePoint,
      'color': color.toARGB32(),
      'amount': amount,
      'percentage': percentage,
      'transactionCount': transactionCount,
      'change': change,
    };
  }

  factory CategoryBreakdown.fromMap(Map<String, dynamic> map) {
    return CategoryBreakdown(
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      color: Color(map['color'] as int),
      amount: (map['amount'] as num).toDouble(),
      percentage: (map['percentage'] as num).toDouble(),
      transactionCount: map['transactionCount'] as int,
      change: (map['change'] as num?)?.toDouble(),
    );
  }
}

/// 趋势点
class TrendPoint {
  /// 日期
  final DateTime date;
  /// 标签（如 "1月1日"）
  final String label;
  /// 支出金额
  final double expense;
  /// 收入金额
  final double income;

  const TrendPoint({
    required this.date,
    required this.label,
    required this.expense,
    required this.income,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'label': label,
      'expense': expense,
      'income': income,
    };
  }

  factory TrendPoint.fromMap(Map<String, dynamic> map) {
    return TrendPoint(
      date: DateTime.parse(map['date'] as String),
      label: map['label'] as String,
      expense: (map['expense'] as num).toDouble(),
      income: (map['income'] as num).toDouble(),
    );
  }
}

/// 预算状态
class BudgetStatus {
  /// 预算类型（如分类名称或成员名称）
  final String name;
  /// 类型（category/member）
  final String type;
  /// 预算金额
  final double budgetAmount;
  /// 已使用金额
  final double usedAmount;
  /// 剩余金额
  final double remainingAmount;
  /// 使用百分比 (0-100)
  final double usagePercentage;
  /// 状态颜色
  final Color statusColor;

  const BudgetStatus({
    required this.name,
    required this.type,
    required this.budgetAmount,
    required this.usedAmount,
    required this.remainingAmount,
    required this.usagePercentage,
    required this.statusColor,
  });

  /// 是否超预算
  bool get isOverBudget => usedAmount > budgetAmount;

  /// 是否接近超预算（>80%）
  bool get isNearLimit => usagePercentage >= 80 && usagePercentage < 100;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'budgetAmount': budgetAmount,
      'usedAmount': usedAmount,
      'remainingAmount': remainingAmount,
      'usagePercentage': usagePercentage,
      'statusColor': statusColor.toARGB32(),
    };
  }

  factory BudgetStatus.fromMap(Map<String, dynamic> map) {
    return BudgetStatus(
      name: map['name'] as String,
      type: map['type'] as String,
      budgetAmount: (map['budgetAmount'] as num).toDouble(),
      usedAmount: (map['usedAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num).toDouble(),
      usagePercentage: (map['usagePercentage'] as num).toDouble(),
      statusColor: Color(map['statusColor'] as int),
    );
  }
}

/// 待处理分摊
class PendingSplit {
  /// 分摊ID
  final String splitId;
  /// 描述
  final String description;
  /// 总金额
  final double totalAmount;
  /// 待结算金额
  final double pendingAmount;
  /// 付款人名称
  final String payerName;
  /// 参与者数量
  final int participantCount;
  /// 创建时间
  final DateTime createdAt;

  const PendingSplit({
    required this.splitId,
    required this.description,
    required this.totalAmount,
    required this.pendingAmount,
    required this.payerName,
    required this.participantCount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'splitId': splitId,
      'description': description,
      'totalAmount': totalAmount,
      'pendingAmount': pendingAmount,
      'payerName': payerName,
      'participantCount': participantCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingSplit.fromMap(Map<String, dynamic> map) {
    return PendingSplit(
      splitId: map['splitId'] as String,
      description: map['description'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      pendingAmount: (map['pendingAmount'] as num).toDouble(),
      payerName: map['payerName'] as String,
      participantCount: map['participantCount'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// 储蓄目标进度
class GoalProgress {
  /// 目标ID
  final String goalId;
  /// 目标名称
  final String name;
  /// 表情图标
  final String emoji;
  /// 目标金额
  final double targetAmount;
  /// 当前金额
  final double currentAmount;
  /// 进度百分比 (0-100)
  final double progressPercentage;
  /// 截止日期
  final DateTime? deadline;
  /// 剩余天数
  final int? daysRemaining;

  const GoalProgress({
    required this.goalId,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    required this.progressPercentage,
    this.deadline,
    this.daysRemaining,
  });

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'name': name,
      'emoji': emoji,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'progressPercentage': progressPercentage,
      'deadline': deadline?.toIso8601String(),
      'daysRemaining': daysRemaining,
    };
  }

  factory GoalProgress.fromMap(Map<String, dynamic> map) {
    return GoalProgress(
      goalId: map['goalId'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      progressPercentage: (map['progressPercentage'] as num).toDouble(),
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      daysRemaining: map['daysRemaining'] as int?,
    );
  }
}

/// 家庭活动类型
enum FamilyActivityType {
  transaction,     // 记账
  split,          // 分摊
  goalContribution, // 目标贡献
  memberJoined,   // 成员加入
  budgetAlert,    // 预算提醒
  goalAchieved,   // 目标达成
}

/// 家庭活动
class FamilyActivity {
  /// 活动ID
  final String id;
  /// 活动类型
  final FamilyActivityType type;
  /// 活动描述
  final String description;
  /// 成员ID
  final String memberId;
  /// 成员名称
  final String memberName;
  /// 成员头像
  final String? avatarUrl;
  /// 金额（如适用）
  final double? amount;
  /// 创建时间
  final DateTime createdAt;

  const FamilyActivity({
    required this.id,
    required this.type,
    required this.description,
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'description': description,
      'memberId': memberId,
      'memberName': memberName,
      'avatarUrl': avatarUrl,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FamilyActivity.fromMap(Map<String, dynamic> map) {
    return FamilyActivity(
      id: map['id'] as String,
      type: parseEnum(map['type'], FamilyActivityType.values, FamilyActivityType.transaction),
      description: map['description'] as String,
      memberId: map['memberId'] as String,
      memberName: map['memberName'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      createdAt: parseDateTime(map['createdAt']),
    );
  }
}
