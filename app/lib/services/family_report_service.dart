import 'package:flutter/material.dart';
import '../models/family_report.dart';
import '../models/member.dart';

/// 家庭报表服务
class FamilyReportService {
  static final FamilyReportService _instance = FamilyReportService._internal();
  factory FamilyReportService() => _instance;
  FamilyReportService._internal();

  /// 生成家庭财务报表
  Future<FamilyFinancialReport> generateReport({
    required String ledgerId,
    required ReportPeriodType periodType,
    required DateTime startDate,
    required DateTime endDate,
    required List<LedgerMember> members,
  }) async {
    final title = _getReportTitle(periodType, startDate, endDate);

    // 计算各项数据
    final summary = await _calculateSummary(ledgerId, startDate, endDate);
    final categoryAnalysis =
        await _calculateCategoryAnalysis(ledgerId, startDate, endDate);
    final memberAnalysis =
        await _calculateMemberAnalysis(ledgerId, startDate, endDate, members);
    final trendAnalysis =
        await _calculateTrendAnalysis(ledgerId, startDate, endDate);
    final budgetExecution =
        await _calculateBudgetExecution(ledgerId, startDate, endDate);
    final goalProgress =
        await _calculateGoalProgress(ledgerId, startDate, endDate);
    final insights = await _generateInsights(
      summary: summary,
      categoryAnalysis: categoryAnalysis,
      trendAnalysis: trendAnalysis,
    );

    return FamilyFinancialReport(
      ledgerId: ledgerId,
      periodType: periodType,
      startDate: startDate,
      endDate: endDate,
      title: title,
      summary: summary,
      categoryAnalysis: categoryAnalysis,
      memberAnalysis: memberAnalysis,
      trendAnalysis: trendAnalysis,
      budgetExecution: budgetExecution,
      goalProgress: goalProgress,
      insights: insights,
      generatedAt: DateTime.now(),
    );
  }

  /// 获取报表标题
  String _getReportTitle(
    ReportPeriodType periodType,
    DateTime startDate,
    DateTime endDate,
  ) {
    switch (periodType) {
      case ReportPeriodType.weekly:
        return '${startDate.month}月第${_getWeekOfMonth(startDate)}周财务报告';
      case ReportPeriodType.monthly:
        return '${startDate.year}年${startDate.month}月财务报告';
      case ReportPeriodType.quarterly:
        return '${startDate.year}年Q${_getQuarter(startDate)}财务报告';
      case ReportPeriodType.yearly:
        return '${startDate.year}年度财务报告';
      case ReportPeriodType.custom:
        return '自定义周期财务报告';
    }
  }

  int _getWeekOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  int _getQuarter(DateTime date) {
    return ((date.month - 1) ~/ 3) + 1;
  }

  /// 计算收支汇总
  Future<IncomeExpenseSummary> _calculateSummary(
    String ledgerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // 模拟数据
    const totalIncome = 25000.0;
    const totalExpense = 18500.0;
    final netSavings = totalIncome - totalExpense;
    final savingsRate = (netSavings / totalIncome * 100);
    final days = endDate.difference(startDate).inDays + 1;
    final avgDailyExpense = totalExpense / days;

    // 计算上期对比
    final comparison = PeriodComparison(
      previousExpense: 19500,
      previousIncome: 24000,
      expenseChange: -5.1,
      incomeChange: 4.2,
      savingsRateChange: 2.5,
    );

    return IncomeExpenseSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: netSavings,
      savingsRate: savingsRate,
      transactionCount: 156,
      avgDailyExpense: avgDailyExpense,
      medianExpense: 85,
      maxExpense: 2500,
      comparison: comparison,
    );
  }

  /// 计算分类分析
  Future<List<CategoryAnalysis>> _calculateCategoryAnalysis(
    String ledgerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // 模拟数据
    return [
      CategoryAnalysis(
        categoryId: 'food',
        categoryName: '餐饮',
        icon: Icons.restaurant,
        color: const Color(0xFFFF9800),
        amount: 4500,
        percentage: 24.3,
        transactionCount: 45,
        avgTransaction: 100,
        change: 3.2,
        isAbnormal: false,
        subCategories: [
          const SubCategoryBreakdown(
            id: 'food_dining',
            name: '外出就餐',
            amount: 2800,
            percentage: 62.2,
          ),
          const SubCategoryBreakdown(
            id: 'food_groceries',
            name: '食材采购',
            amount: 1700,
            percentage: 37.8,
          ),
        ],
      ),
      CategoryAnalysis(
        categoryId: 'shopping',
        categoryName: '购物',
        icon: Icons.shopping_bag,
        color: const Color(0xFFE91E63),
        amount: 3800,
        percentage: 20.5,
        transactionCount: 28,
        avgTransaction: 135.7,
        change: -8.5,
        isAbnormal: false,
      ),
      CategoryAnalysis(
        categoryId: 'housing',
        categoryName: '住房',
        icon: Icons.home,
        color: const Color(0xFF4CAF50),
        amount: 5000,
        percentage: 27.0,
        transactionCount: 5,
        avgTransaction: 1000,
        change: 0,
        isAbnormal: false,
      ),
      CategoryAnalysis(
        categoryId: 'transport',
        categoryName: '交通',
        icon: Icons.directions_car,
        color: const Color(0xFF2196F3),
        amount: 2200,
        percentage: 11.9,
        transactionCount: 35,
        avgTransaction: 62.9,
        change: 1.5,
        isAbnormal: false,
      ),
      CategoryAnalysis(
        categoryId: 'entertainment',
        categoryName: '娱乐',
        icon: Icons.sports_esports,
        color: const Color(0xFF9C27B0),
        amount: 1500,
        percentage: 8.1,
        transactionCount: 20,
        avgTransaction: 75,
        change: 25.3,
        isAbnormal: true,
      ),
    ];
  }

  /// 计算成员分析
  Future<List<MemberAnalysis>> _calculateMemberAnalysis(
    String ledgerId,
    DateTime startDate,
    DateTime endDate,
    List<LedgerMember> members,
  ) async {
    // 模拟数据
    final analysis = <MemberAnalysis>[];

    for (int i = 0; i < members.length; i++) {
      final member = members[i];
      final expense = 9250 - i * 2000;
      final income = 12500 + i * 1500;

      analysis.add(MemberAnalysis(
        memberId: member.userId,
        memberName: member.displayName,
        avatarUrl: member.avatarUrl,
        income: income.toDouble(),
        expense: expense.toDouble(),
        netContribution: (income - expense).toDouble(),
        transactionCount: 78 - i * 20,
        expensePercentage: expense / 18500 * 100,
        topCategories: ['餐饮', '购物', '交通'],
        expenseChange: -3.2 + i * 2,
        participationRate: 0.85 - i * 0.1,
      ));
    }

    return analysis;
  }

  /// 计算趋势分析
  Future<TrendAnalysis> _calculateTrendAnalysis(
    String ledgerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // 生成趋势数据点
    final expenseTrend = <TrendDataPoint>[];
    final incomeTrend = <TrendDataPoint>[];
    final savingsRateTrend = <TrendDataPoint>[];

    final days = endDate.difference(startDate).inDays + 1;
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final baseExpense = 500 + (i % 7) * 80;
      final income = i == 0 || i == 15 ? 12500 : 0;

      expenseTrend.add(TrendDataPoint(
        date: date,
        label: '${date.month}/${date.day}',
        value: baseExpense.toDouble(),
      ));

      incomeTrend.add(TrendDataPoint(
        date: date,
        label: '${date.month}/${date.day}',
        value: income.toDouble(),
      ));

      if (i % 7 == 6) {
        // 周储蓄率
        savingsRateTrend.add(TrendDataPoint(
          date: date,
          label: '第${(i ~/ 7) + 1}周',
          value: 20 + (i % 10).toDouble(),
        ));
      }
    }

    return TrendAnalysis(
      expenseTrend: expenseTrend,
      incomeTrend: incomeTrend,
      savingsRateTrend: savingsRateTrend,
      expenseTrendDirection: TrendDirection.decreasing,
      seasonalPatterns: [
        const SeasonalPattern(
          description: '周末支出较高',
          period: '每周',
          impact: 15.5,
        ),
        const SeasonalPattern(
          description: '月初支出集中',
          period: '每月',
          impact: 8.2,
        ),
      ],
      forecast: const TrendForecast(
        nextPeriodExpense: 17800,
        nextPeriodIncome: 26000,
        confidence: 0.78,
        description: '预计下月支出将略有下降，储蓄率有望提高',
      ),
    );
  }

  /// 计算预算执行情况
  Future<BudgetExecutionSummary?> _calculateBudgetExecution(
    String ledgerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // 模拟数据
    return BudgetExecutionSummary(
      totalBudget: 20000,
      totalUsed: 18500,
      remaining: 1500,
      usageRate: 92.5,
      budgets: [
        const BudgetExecution(
          name: '餐饮',
          budget: 5000,
          used: 4500,
          usageRate: 90,
          isOverBudget: false,
        ),
        const BudgetExecution(
          name: '购物',
          budget: 4000,
          used: 3800,
          usageRate: 95,
          isOverBudget: false,
        ),
        const BudgetExecution(
          name: '娱乐',
          budget: 1200,
          used: 1500,
          usageRate: 125,
          isOverBudget: true,
        ),
      ],
      overBudgetCount: 1,
    );
  }

  /// 计算目标进度
  Future<List<GoalProgressReport>> _calculateGoalProgress(
    String ledgerId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // 模拟数据
    return [
      GoalProgressReport(
        goalId: 'goal_1',
        goalName: '家庭旅行',
        emoji: '✈️',
        targetAmount: 20000,
        currentAmount: 12500,
        progressPercentage: 62.5,
        periodContribution: 2500,
        deadline: DateTime.now().add(const Duration(days: 90)),
        isOnTrack: true,
      ),
      GoalProgressReport(
        goalId: 'goal_2',
        goalName: '新家电',
        emoji: '📺',
        targetAmount: 5000,
        currentAmount: 3800,
        progressPercentage: 76,
        periodContribution: 800,
        deadline: DateTime.now().add(const Duration(days: 30)),
        isOnTrack: false,
      ),
    ];
  }

  /// 生成财务洞察
  Future<List<FinancialInsight>> _generateInsights({
    required IncomeExpenseSummary summary,
    required List<CategoryAnalysis> categoryAnalysis,
    required TrendAnalysis trendAnalysis,
  }) async {
    final insights = <FinancialInsight>[];

    // 储蓄率分析
    if (summary.savingsRate >= 30) {
      insights.add(const FinancialInsight(
        type: InsightType.achievement,
        title: '储蓄率优秀',
        description: '本月储蓄率达到26%，高于平均水平',
        suggestion: '继续保持良好的储蓄习惯',
        importance: InsightImportance.medium,
      ));
    } else if (summary.savingsRate < 10) {
      insights.add(const FinancialInsight(
        type: InsightType.warning,
        title: '储蓄率偏低',
        description: '本月储蓄率较低，建议关注支出',
        suggestion: '建议检查可削减的非必要支出',
        importance: InsightImportance.high,
      ));
    }

    // 异常支出分析
    for (final category in categoryAnalysis) {
      if (category.isAbnormal) {
        insights.add(FinancialInsight(
          type: InsightType.anomaly,
          title: '${category.categoryName}支出异常增长',
          description: '${category.categoryName}支出比上月增长${category.change?.toStringAsFixed(1)}%',
          suggestion: '建议检查是否有不必要的支出',
          importance: InsightImportance.high,
          data: {
            'categoryId': category.categoryId,
            'change': category.change,
          },
        ));
      }
    }

    // 支出趋势分析
    if (trendAnalysis.expenseTrendDirection == TrendDirection.decreasing) {
      insights.add(const FinancialInsight(
        type: InsightType.trend,
        title: '支出呈下降趋势',
        description: '近期支出整体呈下降趋势，财务状况改善',
        importance: InsightImportance.medium,
      ));
    }

    // 周期性模式
    for (final pattern in trendAnalysis.seasonalPatterns) {
      insights.add(FinancialInsight(
        type: InsightType.spending,
        title: pattern.description,
        description: '${pattern.period}支出波动约${pattern.impact.toStringAsFixed(1)}%',
        importance: InsightImportance.low,
      ));
    }

    return insights;
  }

  /// 快速生成月度报表
  Future<FamilyFinancialReport> generateMonthlyReport({
    required String ledgerId,
    required int year,
    required int month,
    required List<LedgerMember> members,
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    return generateReport(
      ledgerId: ledgerId,
      periodType: ReportPeriodType.monthly,
      startDate: startDate,
      endDate: endDate,
      members: members,
    );
  }

  /// 快速生成周报
  Future<FamilyFinancialReport> generateWeeklyReport({
    required String ledgerId,
    required DateTime weekStart,
    required List<LedgerMember> members,
  }) async {
    final endDate = weekStart.add(const Duration(days: 6));

    return generateReport(
      ledgerId: ledgerId,
      periodType: ReportPeriodType.weekly,
      startDate: weekStart,
      endDate: endDate,
      members: members,
    );
  }

  /// 快速生成年度报表
  Future<FamilyFinancialReport> generateYearlyReport({
    required String ledgerId,
    required int year,
    required List<LedgerMember> members,
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    return generateReport(
      ledgerId: ledgerId,
      periodType: ReportPeriodType.yearly,
      startDate: startDate,
      endDate: endDate,
      members: members,
    );
  }
}
