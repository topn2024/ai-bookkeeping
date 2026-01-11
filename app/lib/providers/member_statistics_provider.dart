import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import 'member_provider.dart';

/// 成员消费统计数据
class MemberSpendingStats {
  final String memberId;
  final String memberName;
  final MemberRole role;
  final double totalExpense;
  final double totalIncome;
  final double netAmount;
  final int transactionCount;
  final Map<String, double> categoryBreakdown;
  final double budgetLimit;
  final double budgetUsage;

  const MemberSpendingStats({
    required this.memberId,
    required this.memberName,
    required this.role,
    required this.totalExpense,
    required this.totalIncome,
    required this.netAmount,
    required this.transactionCount,
    required this.categoryBreakdown,
    this.budgetLimit = 0,
    this.budgetUsage = 0,
  });

  double get averageExpense =>
      transactionCount > 0 ? totalExpense / transactionCount : 0;

  bool get isOverBudget => budgetLimit > 0 && totalExpense > budgetLimit;

  double get budgetPercent =>
      budgetLimit > 0 ? (totalExpense / budgetLimit * 100).clamp(0, 200) : 0;
}

/// 成员对比数据
class MemberComparisonData {
  final List<MemberSpendingStats> memberStats;
  final double totalGroupExpense;
  final double totalGroupIncome;
  final double averageExpensePerMember;
  final String topSpender;
  final String topSaver;
  final Map<String, double> groupCategoryBreakdown;
  final DateTime startDate;
  final DateTime endDate;

  const MemberComparisonData({
    required this.memberStats,
    required this.totalGroupExpense,
    required this.totalGroupIncome,
    required this.averageExpensePerMember,
    required this.topSpender,
    required this.topSaver,
    required this.groupCategoryBreakdown,
    required this.startDate,
    required this.endDate,
  });
}

/// 时间范围
enum ComparisonPeriod {
  thisWeek,
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  custom,
}

extension ComparisonPeriodExtension on ComparisonPeriod {
  String get displayName {
    switch (this) {
      case ComparisonPeriod.thisWeek:
        return '本周';
      case ComparisonPeriod.thisMonth:
        return '本月';
      case ComparisonPeriod.lastMonth:
        return '上月';
      case ComparisonPeriod.last3Months:
        return '近3个月';
      case ComparisonPeriod.thisYear:
        return '今年';
      case ComparisonPeriod.custom:
        return '自定义';
    }
  }

  DateTimeRange getDateRange() {
    final now = DateTime.now();
    switch (this) {
      case ComparisonPeriod.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
          start: DateTime(weekStart.year, weekStart.month, weekStart.day),
          end: now,
        );
      case ComparisonPeriod.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case ComparisonPeriod.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0);
        return DateTimeRange(start: lastMonth, end: lastDay);
      case ComparisonPeriod.last3Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        );
      case ComparisonPeriod.thisYear:
        return DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        );
      case ComparisonPeriod.custom:
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    }
  }
}

/// 成员统计状态
class MemberStatisticsState {
  final String ledgerId;
  final ComparisonPeriod period;
  final DateTimeRange? customRange;
  final MemberComparisonData? comparisonData;
  final bool isLoading;

  const MemberStatisticsState({
    this.ledgerId = '',
    this.period = ComparisonPeriod.thisMonth,
    this.customRange,
    this.comparisonData,
    this.isLoading = false,
  });

  MemberStatisticsState copyWith({
    String? ledgerId,
    ComparisonPeriod? period,
    DateTimeRange? customRange,
    MemberComparisonData? comparisonData,
    bool? isLoading,
  }) {
    return MemberStatisticsState(
      ledgerId: ledgerId ?? this.ledgerId,
      period: period ?? this.period,
      customRange: customRange ?? this.customRange,
      comparisonData: comparisonData ?? this.comparisonData,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MemberStatisticsNotifier extends Notifier<MemberStatisticsState> {
  @override
  MemberStatisticsState build() {
    return const MemberStatisticsState();
  }

  void setLedger(String ledgerId) {
    state = state.copyWith(ledgerId: ledgerId);
    _calculateStatistics();
  }

  void setPeriod(ComparisonPeriod period) {
    state = state.copyWith(period: period);
    _calculateStatistics();
  }

  void setCustomRange(DateTimeRange range) {
    state = state.copyWith(
      period: ComparisonPeriod.custom,
      customRange: range,
    );
    _calculateStatistics();
  }

  void _calculateStatistics() {
    if (state.ledgerId.isEmpty) return;

    state = state.copyWith(isLoading: true);

    final memberState = ref.read(memberProvider);

    // 获取账本成员
    final members = memberState.members
        .where((m) => m.ledgerId == state.ledgerId && m.isActive)
        .toList();

    if (members.isEmpty) {
      state = state.copyWith(isLoading: false);
      return;
    }

    // 获取时间范围
    final dateRange = state.period == ComparisonPeriod.custom
        ? state.customRange!
        : state.period.getDateRange();

    // 获取预算信息
    final budgets = memberState.budgets
        .where((b) => b.ledgerId == state.ledgerId)
        .toList();

    // 计算每个成员的统计数据
    // 注意：当前Transaction模型不包含memberId字段，无法按成员统计
    // TODO: 需要在Transaction模型中添加memberId字段以支持成员统计
    final memberStats = <MemberSpendingStats>[];
    final groupCategoryBreakdown = <String, double>{};
    double totalGroupExpense = 0;
    double totalGroupIncome = 0;

    for (final member in members) {
      // 获取成员预算
      final budget = budgets.where((b) => b.memberId == member.id).firstOrNull;

      // 由于Transaction模型没有memberId字段，暂时返回基于预算的数据或零值
      final stats = MemberSpendingStats(
        memberId: member.id,
        memberName: member.userName,
        role: member.role,
        totalExpense: budget?.currentSpent ?? 0,
        totalIncome: 0,
        netAmount: -(budget?.currentSpent ?? 0),
        transactionCount: 0,
        categoryBreakdown: const {},
        budgetLimit: budget?.monthlyLimit ?? 0,
        budgetUsage: budget?.usagePercent ?? 0,
      );

      memberStats.add(stats);
      totalGroupExpense += stats.totalExpense;
      totalGroupIncome += stats.totalIncome;
    }

    // 找出最高消费者和最节省者
    memberStats.sort((a, b) => b.totalExpense.compareTo(a.totalExpense));
    final topSpender = memberStats.isNotEmpty ? memberStats.first.memberName : '';

    memberStats.sort((a, b) => a.totalExpense.compareTo(b.totalExpense));
    final topSaver = memberStats.isNotEmpty ? memberStats.first.memberName : '';

    // 恢复原始顺序
    memberStats.sort((a, b) => a.memberName.compareTo(b.memberName));

    final comparisonData = MemberComparisonData(
      memberStats: memberStats,
      totalGroupExpense: totalGroupExpense,
      totalGroupIncome: totalGroupIncome,
      averageExpensePerMember:
          members.isNotEmpty ? totalGroupExpense / members.length : 0,
      topSpender: topSpender,
      topSaver: topSaver,
      groupCategoryBreakdown: groupCategoryBreakdown,
      startDate: dateRange.start,
      endDate: dateRange.end,
    );

    state = state.copyWith(
      comparisonData: comparisonData,
      isLoading: false,
    );
  }

  void refresh() {
    _calculateStatistics();
  }
}

final memberStatisticsProvider =
    NotifierProvider<MemberStatisticsNotifier, MemberStatisticsState>(
        MemberStatisticsNotifier.new);

/// 成员消费排名 Provider
final memberSpendingRankProvider = Provider.family<List<MemberSpendingStats>, String>((ref, ledgerId) {
  final state = ref.watch(memberStatisticsProvider);
  if (state.comparisonData == null) return [];

  final stats = List<MemberSpendingStats>.from(state.comparisonData!.memberStats);
  stats.sort((a, b) => b.totalExpense.compareTo(a.totalExpense));
  return stats;
});

/// 成员预算执行率排名
final memberBudgetComplianceProvider = Provider.family<List<MemberSpendingStats>, String>((ref, ledgerId) {
  final state = ref.watch(memberStatisticsProvider);
  if (state.comparisonData == null) return [];

  final stats = state.comparisonData!.memberStats
      .where((s) => s.budgetLimit > 0)
      .toList();
  stats.sort((a, b) => a.budgetPercent.compareTo(b.budgetPercent));
  return stats;
});
