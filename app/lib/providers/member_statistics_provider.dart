import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import 'member_provider.dart';
import 'transaction_provider.dart';

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
    final transactions = ref.read(transactionProvider);

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
    // 注意：实际应用中，交易应该关联到成员ID
    // 这里使用模拟数据演示功能
    final memberStats = <MemberSpendingStats>[];
    final groupCategoryBreakdown = <String, double>{};
    double totalGroupExpense = 0;
    double totalGroupIncome = 0;

    for (final member in members) {
      // 获取成员预算
      final budget = budgets.where((b) => b.memberId == member.id).firstOrNull;

      // 模拟数据：根据成员角色分配不同的消费金额
      // 实际实现时应该根据交易记录中的memberId来统计
      final mockExpense = _getMockExpenseForMember(member, dateRange);
      final mockIncome = _getMockIncomeForMember(member, dateRange);
      final mockCategories = _getMockCategoriesForMember(member);

      final stats = MemberSpendingStats(
        memberId: member.id,
        memberName: member.userName,
        role: member.role,
        totalExpense: budget?.currentSpent ?? mockExpense,
        totalIncome: mockIncome,
        netAmount: mockIncome - (budget?.currentSpent ?? mockExpense),
        transactionCount: (mockExpense / 50).round(),
        categoryBreakdown: mockCategories,
        budgetLimit: budget?.monthlyLimit ?? 0,
        budgetUsage: budget?.usagePercent ?? 0,
      );

      memberStats.add(stats);
      totalGroupExpense += stats.totalExpense;
      totalGroupIncome += stats.totalIncome;

      // 合并分类统计
      for (final entry in stats.categoryBreakdown.entries) {
        groupCategoryBreakdown[entry.key] =
            (groupCategoryBreakdown[entry.key] ?? 0) + entry.value;
      }
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

  // 模拟数据生成方法
  double _getMockExpenseForMember(LedgerMember member, DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    final baseDaily = switch (member.role) {
      MemberRole.owner => 150.0,
      MemberRole.admin => 120.0,
      MemberRole.editor => 100.0,
      MemberRole.viewer => 80.0,
    };
    return baseDaily * days * (0.8 + (member.id.hashCode % 40) / 100);
  }

  double _getMockIncomeForMember(LedgerMember member, DateTimeRange range) {
    final days = range.end.difference(range.start).inDays + 1;
    if (days < 28) return 0; // 只有月度才有收入
    return switch (member.role) {
      MemberRole.owner => 15000.0,
      MemberRole.admin => 12000.0,
      MemberRole.editor => 10000.0,
      MemberRole.viewer => 8000.0,
    };
  }

  Map<String, double> _getMockCategoriesForMember(LedgerMember member) {
    final base = member.id.hashCode % 1000;
    return {
      '餐饮': 800.0 + base * 0.3,
      '交通': 300.0 + base * 0.1,
      '购物': 500.0 + base * 0.2,
      '娱乐': 200.0 + base * 0.1,
      '其他': 100.0 + base * 0.05,
    };
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
