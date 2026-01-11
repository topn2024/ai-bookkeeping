import 'package:flutter/material.dart';
import '../models/family_dashboard.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../core/di/service_locator.dart';
import '../core/contracts/i_database_service.dart';

/// 家庭看板服务
class FamilyDashboardService {
  static final FamilyDashboardService _instance =
      FamilyDashboardService._internal();
  factory FamilyDashboardService() => _instance;
  FamilyDashboardService._internal();

  /// 通过服务定位器获取数据库服务
  IDatabaseService get _db => sl<IDatabaseService>();

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
    try {
      final db = await _db.database;

      // 解析期间（格式：YYYY-MM）
      final periodDate = DateTime.parse('$period-01');
      final startOfMonth = DateTime(periodDate.year, periodDate.month, 1);
      final endOfMonth = DateTime(periodDate.year, periodDate.month + 1, 0, 23, 59, 59);

      // 查询本期所有交易
      final results = await db.query(
        'transactions',
        where: 'ledgerId = ? AND datetime >= ? AND datetime <= ?',
        whereArgs: [
          ledgerId,
          startOfMonth.millisecondsSinceEpoch,
          endOfMonth.millisecondsSinceEpoch,
        ],
      );

      double totalIncome = 0;
      double totalExpense = 0;
      int transactionCount = results.length;

      for (var row in results) {
        final transaction = Transaction.fromMap(row);
        if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        } else if (transaction.type == TransactionType.expense) {
          totalExpense += transaction.amount;
        }
      }

      final netSavings = totalIncome - totalExpense;
      final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0.0;

      // 计算本期天数
      final daysInPeriod = endOfMonth.day;
      final avgDailyExpense = totalExpense / daysInPeriod;

      // 计算与上月对比（简化实现，返回0）
      final expenseChange = 0.0;

      return FamilySummary(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netSavings: netSavings,
        savingsRate: savingsRate,
        transactionCount: transactionCount,
        avgDailyExpense: avgDailyExpense,
        expenseChange: expenseChange,
        activeMemberCount: members.where((m) => m.isActive).length,
      );
    } catch (e) {
      // 出错时返回空数据
      return FamilySummary(
        totalIncome: 0,
        totalExpense: 0,
        netSavings: 0,
        savingsRate: 0,
        transactionCount: 0,
        avgDailyExpense: 0,
        expenseChange: 0,
        activeMemberCount: members.where((m) => m.isActive).length,
      );
    }
  }

  /// 计算成员贡献
  Future<List<MemberContribution>> _calculateMemberContributions(
    String ledgerId,
    String period,
    List<LedgerMember> members,
  ) async {
    try {
      final db = await _db.database;

      // 解析期间
      final periodDate = DateTime.parse('$period-01');
      final startOfMonth = DateTime(periodDate.year, periodDate.month, 1);
      final endOfMonth = DateTime(periodDate.year, periodDate.month + 1, 0, 23, 59, 59);

      final contributions = <MemberContribution>[];
      double totalExpense = 0;

      // 先计算总支出用于百分比计算
      final allResults = await db.query(
        'transactions',
        where: 'ledgerId = ? AND datetime >= ? AND datetime <= ? AND type = ?',
        whereArgs: [
          ledgerId,
          startOfMonth.millisecondsSinceEpoch,
          endOfMonth.millisecondsSinceEpoch,
          TransactionType.expense.index,
        ],
      );

      for (var row in allResults) {
        totalExpense += (row['amount'] as num).toDouble();
      }

      // 为每个成员计算贡献
      for (final member in members) {
        final results = await db.query(
          'transactions',
          where: 'ledgerId = ? AND createdBy = ? AND datetime >= ? AND datetime <= ?',
          whereArgs: [
            ledgerId,
            member.userId,
            startOfMonth.millisecondsSinceEpoch,
            endOfMonth.millisecondsSinceEpoch,
          ],
        );

        double income = 0;
        double expense = 0;
        final categoryMap = <String, double>{};

        for (var row in results) {
          final transaction = Transaction.fromMap(row);
          if (transaction.type == TransactionType.income) {
            income += transaction.amount;
          } else if (transaction.type == TransactionType.expense) {
            expense += transaction.amount;
            categoryMap[transaction.category] =
                (categoryMap[transaction.category] ?? 0) + transaction.amount;
          }
        }

        // 获取前3个最高消费类别
        final topCategories = categoryMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCategoryNames = topCategories.take(3).map((e) => e.key).toList();

        contributions.add(MemberContribution(
          memberId: member.userId,
          memberName: member.displayName,
          avatarUrl: member.avatarUrl,
          income: income,
          expense: expense,
          transactionCount: results.length,
          contributionPercentage: totalExpense > 0 ? expense / totalExpense * 100 : 0,
          topCategories: topCategoryNames,
          lastActivityAt: results.isNotEmpty
              ? DateTime.fromMillisecondsSinceEpoch(results.first['datetime'] as int)
              : member.joinedAt,
        ));
      }

      return contributions;
    } catch (e) {
      return [];
    }
  }

  /// 计算分类分布
  Future<List<CategoryBreakdown>> _calculateCategoryBreakdown(
    String ledgerId,
    String period,
  ) async {
    try {
      final db = await _db.database;

      // 解析期间
      final periodDate = DateTime.parse('$period-01');
      final startOfMonth = DateTime(periodDate.year, periodDate.month, 1);
      final endOfMonth = DateTime(periodDate.year, periodDate.month + 1, 0, 23, 59, 59);

      // 查询本期支出交易
      final results = await db.query(
        'transactions',
        where: 'ledgerId = ? AND datetime >= ? AND datetime <= ? AND type = ?',
        whereArgs: [
          ledgerId,
          startOfMonth.millisecondsSinceEpoch,
          endOfMonth.millisecondsSinceEpoch,
          TransactionType.expense.index,
        ],
      );

      // 按类别聚合
      final categoryMap = <String, Map<String, dynamic>>{};
      double totalExpense = 0;

      for (var row in results) {
        final transaction = Transaction.fromMap(row);
        final category = transaction.category;

        if (!categoryMap.containsKey(category)) {
          categoryMap[category] = {
            'amount': 0.0,
            'count': 0,
          };
        }

        categoryMap[category]!['amount'] += transaction.amount;
        categoryMap[category]!['count']++;
        totalExpense += transaction.amount;
      }

      // 转换为CategoryBreakdown列表
      final breakdowns = <CategoryBreakdown>[];
      for (var entry in categoryMap.entries) {
        final amount = entry.value['amount'] as double;
        final count = entry.value['count'] as int;
        final percentage = totalExpense > 0 ? (amount / totalExpense * 100) : 0.0;

        breakdowns.add(CategoryBreakdown(
          categoryId: entry.key,
          categoryName: entry.key,
          icon: Icons.category,
          color: _getCategoryColor(entry.key),
          amount: amount,
          percentage: percentage,
          transactionCount: count,
          change: 0, // 简化实现
        ));
      }

      // 按金额排序
      breakdowns.sort((a, b) => b.amount.compareTo(a.amount));

      return breakdowns;
    } catch (e) {
      return [];
    }
  }

  /// 获取类别颜色（简化实现）
  Color _getCategoryColor(String category) {
    final colors = [
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFF9C27B0),
      const Color(0xFF607D8B),
    ];
    return colors[category.hashCode % colors.length];
  }

  /// 计算支出趋势
  Future<List<TrendPoint>> _calculateSpendingTrend(
    String ledgerId,
    String period,
  ) async {
    try {
      final db = await _db.database;

      // 解析期间
      final periodDate = DateTime.parse('$period-01');
      final startOfMonth = DateTime(periodDate.year, periodDate.month, 1);
      final endOfMonth = DateTime(periodDate.year, periodDate.month + 1, 0, 23, 59, 59);

      // 查询本期所有交易
      final results = await db.query(
        'transactions',
        where: 'ledgerId = ? AND datetime >= ? AND datetime <= ?',
        whereArgs: [
          ledgerId,
          startOfMonth.millisecondsSinceEpoch,
          endOfMonth.millisecondsSinceEpoch,
        ],
        orderBy: 'datetime ASC',
      );

      // 按日期聚合
      final dailyMap = <String, Map<String, double>>{};

      for (var row in results) {
        final transaction = Transaction.fromMap(row);
        final date = DateTime.fromMillisecondsSinceEpoch(transaction.date.millisecondsSinceEpoch);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        if (!dailyMap.containsKey(dateKey)) {
          dailyMap[dateKey] = {'expense': 0.0, 'income': 0.0};
        }

        if (transaction.type == TransactionType.expense) {
          dailyMap[dateKey]!['expense'] = dailyMap[dateKey]!['expense']! + transaction.amount;
        } else if (transaction.type == TransactionType.income) {
          dailyMap[dateKey]!['income'] = dailyMap[dateKey]!['income']! + transaction.amount;
        }
      }

      // 转换为TrendPoint列表
      final trends = <TrendPoint>[];
      for (var entry in dailyMap.entries) {
        final date = DateTime.parse(entry.key);
        trends.add(TrendPoint(
          date: date,
          label: '${date.month}/${date.day}',
          expense: entry.value['expense']!,
          income: entry.value['income']!,
        ));
      }

      // 按日期排序
      trends.sort((a, b) => a.date.compareTo(b.date));

      return trends;
    } catch (e) {
      return [];
    }
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
