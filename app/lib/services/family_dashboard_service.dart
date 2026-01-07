import 'package:flutter/material.dart';
import '../models/family_dashboard.dart';
import '../models/member.dart';

/// 家庭看板服务
class FamilyDashboardService {
  static final FamilyDashboardService _instance =
      FamilyDashboardService._internal();
  factory FamilyDashboardService() => _instance;
  FamilyDashboardService._internal();

  /// 获取家庭看板数据
  Future<FamilyDashboardData> getDashboardData({
    required String ledgerId,
    required String period,
    required List<LedgerMember> members,
  }) async {
    // 获取各项数据
    final summary = await _calculateSummary(ledgerId, period, members);
    final memberContributions =
        await _calculateMemberContributions(ledgerId, period, members);
    final categoryBreakdown =
        await _calculateCategoryBreakdown(ledgerId, period);
    final spendingTrend = await _calculateSpendingTrend(ledgerId, period);
    final budgetStatuses = await _getBudgetStatuses(ledgerId, period);
    final pendingSplits = await _getPendingSplits(ledgerId);
    final goalProgresses = await _getGoalProgresses(ledgerId);
    final recentActivities = await _getRecentActivities(ledgerId);

    return FamilyDashboardData(
      ledgerId: ledgerId,
      period: period,
      summary: summary,
      memberContributions: memberContributions,
      categoryBreakdown: categoryBreakdown,
      spendingTrend: spendingTrend,
      budgetStatuses: budgetStatuses,
      pendingSplits: pendingSplits,
      goalProgresses: goalProgresses,
      recentActivities: recentActivities,
    );
  }

  /// 计算家庭汇总
  Future<FamilySummary> _calculateSummary(
    String ledgerId,
    String period,
    List<LedgerMember> members,
  ) async {
    // 模拟数据 - 实际应从数据库查询
    const totalIncome = 25000.0;
    const totalExpense = 18500.0;
    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0;

    // 计算本期天数
    final periodDate = DateTime.parse('$period-01');
    final daysInPeriod =
        DateTime(periodDate.year, periodDate.month + 1, 0).day;
    final avgDailyExpense = totalExpense / daysInPeriod;

    return FamilySummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: netSavings,
      savingsRate: savingsRate.toDouble(),
      transactionCount: 156,
      avgDailyExpense: avgDailyExpense,
      expenseChange: -5.2, // 比上月减少5.2%
      activeMemberCount: members.where((m) => m.isActive).length,
    );
  }

  /// 计算成员贡献
  Future<List<MemberContribution>> _calculateMemberContributions(
    String ledgerId,
    String period,
    List<LedgerMember> members,
  ) async {
    // 模拟数据 - 实际应从数据库查询
    final contributions = <MemberContribution>[];
    final totalExpense = 18500.0;

    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      // 模拟不同成员的贡献
      final expense = totalExpense * (0.3 + i * 0.1);
      final income = 25000.0 * (0.4 + i * 0.15);

      contributions.add(MemberContribution(
        memberId: member.userId,
        memberName: member.displayName,
        avatarUrl: member.avatarUrl,
        income: income,
        expense: expense,
        transactionCount: 30 + i * 10,
        contributionPercentage: totalExpense > 0 ? expense / totalExpense * 100 : 0,
        topCategories: ['餐饮', '购物', '交通'],
        lastActivityAt: DateTime.now().subtract(Duration(hours: i * 2)),
      ));
    }

    return contributions;
  }

  /// 计算分类分布
  Future<List<CategoryBreakdown>> _calculateCategoryBreakdown(
    String ledgerId,
    String period,
  ) async {
    // 模拟数据
    return [
      CategoryBreakdown(
        categoryId: 'food',
        categoryName: '餐饮',
        icon: Icons.restaurant,
        color: const Color(0xFFFF9800),
        amount: 4500,
        percentage: 24.3,
        transactionCount: 45,
        change: 3.2,
      ),
      CategoryBreakdown(
        categoryId: 'shopping',
        categoryName: '购物',
        icon: Icons.shopping_bag,
        color: const Color(0xFFE91E63),
        amount: 3800,
        percentage: 20.5,
        transactionCount: 28,
        change: -8.5,
      ),
      CategoryBreakdown(
        categoryId: 'transport',
        categoryName: '交通',
        icon: Icons.directions_car,
        color: const Color(0xFF2196F3),
        amount: 2200,
        percentage: 11.9,
        transactionCount: 35,
        change: 1.5,
      ),
      CategoryBreakdown(
        categoryId: 'housing',
        categoryName: '住房',
        icon: Icons.home,
        color: const Color(0xFF4CAF50),
        amount: 5000,
        percentage: 27.0,
        transactionCount: 5,
        change: 0,
      ),
      CategoryBreakdown(
        categoryId: 'entertainment',
        categoryName: '娱乐',
        icon: Icons.sports_esports,
        color: const Color(0xFF9C27B0),
        amount: 1500,
        percentage: 8.1,
        transactionCount: 20,
        change: 12.3,
      ),
      CategoryBreakdown(
        categoryId: 'others',
        categoryName: '其他',
        icon: Icons.more_horiz,
        color: const Color(0xFF607D8B),
        amount: 1500,
        percentage: 8.2,
        transactionCount: 23,
        change: -2.1,
      ),
    ];
  }

  /// 计算支出趋势
  Future<List<TrendPoint>> _calculateSpendingTrend(
    String ledgerId,
    String period,
  ) async {
    // 模拟数据 - 生成过去30天的趋势
    final trends = <TrendPoint>[];
    final now = DateTime.now();

    for (int i = 29; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final baseExpense = 500 + (i % 7) * 100; // 周期性波动
      final baseIncome = i == 0 || i == 15 ? 12500 : 0; // 发薪日

      trends.add(TrendPoint(
        date: date,
        label: '${date.month}/${date.day}',
        expense: baseExpense.toDouble() + (i % 3) * 50,
        income: baseIncome.toDouble(),
      ));
    }

    return trends;
  }

  /// 获取预算状态
  Future<List<BudgetStatus>> _getBudgetStatuses(
    String ledgerId,
    String period,
  ) async {
    // 模拟数据
    return [
      BudgetStatus(
        name: '餐饮',
        type: 'category',
        budgetAmount: 5000,
        usedAmount: 4500,
        remainingAmount: 500,
        usagePercentage: 90,
        statusColor: const Color(0xFFFF9800),
      ),
      BudgetStatus(
        name: '购物',
        type: 'category',
        budgetAmount: 4000,
        usedAmount: 3800,
        remainingAmount: 200,
        usagePercentage: 95,
        statusColor: const Color(0xFFF44336),
      ),
      BudgetStatus(
        name: '娱乐',
        type: 'category',
        budgetAmount: 2000,
        usedAmount: 1500,
        remainingAmount: 500,
        usagePercentage: 75,
        statusColor: const Color(0xFF4CAF50),
      ),
    ];
  }

  /// 获取待处理分摊
  Future<List<PendingSplit>> _getPendingSplits(String ledgerId) async {
    // 模拟数据
    return [
      PendingSplit(
        splitId: 'split_1',
        description: '周末聚餐',
        totalAmount: 580,
        pendingAmount: 290,
        payerName: '小明',
        participantCount: 4,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      PendingSplit(
        splitId: 'split_2',
        description: '水电费',
        totalAmount: 320,
        pendingAmount: 160,
        payerName: '小红',
        participantCount: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  /// 获取储蓄目标进度
  Future<List<GoalProgress>> _getGoalProgresses(String ledgerId) async {
    // 模拟数据
    return [
      GoalProgress(
        goalId: 'goal_1',
        name: '家庭旅行',
        emoji: '✈️',
        targetAmount: 20000,
        currentAmount: 12500,
        progressPercentage: 62.5,
        deadline: DateTime.now().add(const Duration(days: 90)),
        daysRemaining: 90,
      ),
      GoalProgress(
        goalId: 'goal_2',
        name: '新家电',
        emoji: '📺',
        targetAmount: 5000,
        currentAmount: 3800,
        progressPercentage: 76,
        deadline: DateTime.now().add(const Duration(days: 30)),
        daysRemaining: 30,
      ),
    ];
  }

  /// 获取最近活动
  Future<List<FamilyActivity>> _getRecentActivities(String ledgerId) async {
    // 模拟数据
    return [
      FamilyActivity(
        id: 'activity_1',
        type: FamilyActivityType.goalContribution,
        description: '向「家庭旅行」贡献了一笔',
        memberId: 'user_1',
        memberName: '小明',
        amount: 500,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      FamilyActivity(
        id: 'activity_2',
        type: FamilyActivityType.transaction,
        description: '记录了一笔餐饮支出',
        memberId: 'user_2',
        memberName: '小红',
        amount: 128,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      FamilyActivity(
        id: 'activity_3',
        type: FamilyActivityType.split,
        description: '创建了「周末聚餐」分摊',
        memberId: 'user_1',
        memberName: '小明',
        amount: 580,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      FamilyActivity(
        id: 'activity_4',
        type: FamilyActivityType.budgetAlert,
        description: '购物预算已使用95%',
        memberId: 'system',
        memberName: '系统',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// 获取快速统计
  Future<QuickStats> getQuickStats({
    required String ledgerId,
    required String period,
  }) async {
    // 模拟数据
    return QuickStats(
      todayExpense: 156.5,
      weekExpense: 1280,
      monthExpense: 18500,
      pendingSplitCount: 2,
      pendingSplitAmount: 450,
      activeGoalCount: 2,
      budgetWarningCount: 1,
    );
  }
}

/// 快速统计
class QuickStats {
  /// 今日支出
  final double todayExpense;
  /// 本周支出
  final double weekExpense;
  /// 本月支出
  final double monthExpense;
  /// 待处理分摊数量
  final int pendingSplitCount;
  /// 待处理分摊金额
  final double pendingSplitAmount;
  /// 活跃目标数量
  final int activeGoalCount;
  /// 预算预警数量
  final int budgetWarningCount;

  const QuickStats({
    required this.todayExpense,
    required this.weekExpense,
    required this.monthExpense,
    required this.pendingSplitCount,
    required this.pendingSplitAmount,
    required this.activeGoalCount,
    required this.budgetWarningCount,
  });
}
