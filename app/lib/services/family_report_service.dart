import 'package:flutter/material.dart';
import '../models/family_report.dart';
import '../models/member.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import 'category_localization_service.dart';

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
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
  }) async {
    final title = _getReportTitle(periodType, startDate, endDate);

    // 过滤时间范围内的交易
    final periodTransactions = transactions.where((t) =>
        t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        t.date.isBefore(endDate.add(const Duration(days: 1)))).toList();

    // 计算各项数据
    final summary = _calculateSummary(periodTransactions, startDate, endDate);
    final categoryAnalysis = _calculateCategoryAnalysis(periodTransactions);
    final memberAnalysis = _calculateMemberAnalysis(periodTransactions, members);
    final trendAnalysis = _calculateTrendAnalysis(periodTransactions, startDate, endDate);
    final budgetExecution = _calculateBudgetExecution(periodTransactions, budgets);
    final goalProgress = _calculateGoalProgress();
    final insights = _generateInsights(
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
  IncomeExpenseSummary _calculateSummary(
    List<Transaction> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense);
    final incomes = transactions.where((t) => t.type == TransactionType.income);

    final totalExpense = expenses.fold<double>(0, (sum, t) => sum + t.amount);
    final totalIncome = incomes.fold<double>(0, (sum, t) => sum + t.amount);
    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0.0;
    final days = endDate.difference(startDate).inDays + 1;
    final avgDailyExpense = days > 0 ? totalExpense / days : 0.0;

    // 计算中位数和最大支出
    final expenseAmounts = expenses.map((t) => t.amount).toList()..sort();
    final medianExpense = expenseAmounts.isNotEmpty
        ? expenseAmounts[expenseAmounts.length ~/ 2]
        : 0.0;
    final maxExpense = expenseAmounts.isNotEmpty ? expenseAmounts.last : 0.0;

    // 上期对比暂时使用空值（需要历史数据支持）
    final comparison = PeriodComparison(
      previousExpense: 0,
      previousIncome: 0,
      expenseChange: 0,
      incomeChange: 0,
      savingsRateChange: 0,
    );

    return IncomeExpenseSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netSavings: netSavings,
      savingsRate: savingsRate,
      transactionCount: transactions.length,
      avgDailyExpense: avgDailyExpense,
      medianExpense: medianExpense,
      maxExpense: maxExpense,
      comparison: comparison,
    );
  }

  /// 计算分类分析
  List<CategoryAnalysis> _calculateCategoryAnalysis(
    List<Transaction> transactions,
  ) {
    final expenses = transactions.where((t) => t.type == TransactionType.expense);
    final totalExpense = expenses.fold<double>(0, (sum, t) => sum + t.amount);

    // 按分类汇总
    final categoryData = <String, List<Transaction>>{};
    for (final t in expenses) {
      categoryData.putIfAbsent(t.category, () => []).add(t);
    }

    // 生成分类分析
    final analysis = <CategoryAnalysis>[];
    for (final entry in categoryData.entries) {
      final categoryId = entry.key;
      final categoryTransactions = entry.value;
      final amount = categoryTransactions.fold<double>(0, (sum, t) => sum + t.amount);
      final percentage = totalExpense > 0 ? (amount / totalExpense * 100) : 0.0;
      final avgTransaction = categoryTransactions.isNotEmpty
          ? amount / categoryTransactions.length
          : 0.0;

      final category = DefaultCategories.findById(categoryId);

      analysis.add(CategoryAnalysis(
        categoryId: categoryId,
        categoryName: category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(categoryId),
        icon: category?.icon ?? Icons.category,
        color: category?.color ?? Colors.grey,
        amount: amount,
        percentage: percentage,
        transactionCount: categoryTransactions.length,
        avgTransaction: avgTransaction,
        change: null, // 需要历史数据支持
        isAbnormal: false,
      ));
    }

    // 按金额排序
    analysis.sort((a, b) => b.amount.compareTo(a.amount));
    return analysis.take(10).toList();
  }

  /// 计算成员分析
  /// 注意：当前交易模型不包含成员ID，返回基于成员列表的空数据
  List<MemberAnalysis> _calculateMemberAnalysis(
    List<Transaction> transactions,
    List<LedgerMember> members,
  ) {
    // 由于交易模型没有 memberId 字段，暂时返回成员基本信息
    // TODO: 需要在交易模型中添加 memberId 字段以支持成员分析
    final analysis = <MemberAnalysis>[];

    for (final member in members) {
      analysis.add(MemberAnalysis(
        memberId: member.userId,
        memberName: member.displayName,
        avatarUrl: member.avatarUrl,
        income: 0,
        expense: 0,
        netContribution: 0,
        transactionCount: 0,
        expensePercentage: 0,
        topCategories: [],
        expenseChange: null,
        participationRate: 0,
      ));
    }

    return analysis;
  }

  /// 计算趋势分析
  TrendAnalysis _calculateTrendAnalysis(
    List<Transaction> transactions,
    DateTime startDate,
    DateTime endDate,
  ) {
    // 按日期分组交易
    final dailyExpenses = <DateTime, double>{};
    final dailyIncomes = <DateTime, double>{};

    for (final t in transactions) {
      final date = DateTime(t.date.year, t.date.month, t.date.day);
      if (t.type == TransactionType.expense) {
        dailyExpenses[date] = (dailyExpenses[date] ?? 0) + t.amount;
      } else if (t.type == TransactionType.income) {
        dailyIncomes[date] = (dailyIncomes[date] ?? 0) + t.amount;
      }
    }

    // 生成趋势数据点
    final expenseTrend = <TrendDataPoint>[];
    final incomeTrend = <TrendDataPoint>[];

    final days = endDate.difference(startDate).inDays + 1;
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateKey = DateTime(date.year, date.month, date.day);

      expenseTrend.add(TrendDataPoint(
        date: date,
        label: '${date.month}/${date.day}',
        value: dailyExpenses[dateKey] ?? 0,
      ));

      incomeTrend.add(TrendDataPoint(
        date: date,
        label: '${date.month}/${date.day}',
        value: dailyIncomes[dateKey] ?? 0,
      ));
    }

    // 计算趋势方向
    TrendDirection direction = TrendDirection.stable;
    if (expenseTrend.length >= 7) {
      final firstWeek = expenseTrend.take(7).fold<double>(0, (sum, p) => sum + p.value);
      final lastWeek = expenseTrend.skip(expenseTrend.length - 7).fold<double>(0, (sum, p) => sum + p.value);
      if (lastWeek > firstWeek * 1.1) {
        direction = TrendDirection.increasing;
      } else if (lastWeek < firstWeek * 0.9) {
        direction = TrendDirection.decreasing;
      }
    }

    return TrendAnalysis(
      expenseTrend: expenseTrend,
      incomeTrend: incomeTrend,
      savingsRateTrend: [], // 需要更复杂的计算
      expenseTrendDirection: direction,
      seasonalPatterns: [], // 需要更多历史数据
      forecast: null, // 需要预测模型
    );
  }

  /// 计算预算执行情况
  BudgetExecutionSummary? _calculateBudgetExecution(
    List<Transaction> transactions,
    List<Budget> budgets,
  ) {
    final enabledBudgets = budgets.where((b) => b.isEnabled).toList();
    if (enabledBudgets.isEmpty) return null;

    // 按分类计算支出
    final categorySpent = <String, double>{};
    for (final t in transactions.where((t) => t.type == TransactionType.expense)) {
      categorySpent[t.category] = (categorySpent[t.category] ?? 0) + t.amount;
    }

    // 计算各预算执行情况
    final budgetExecutions = <BudgetExecution>[];
    double totalBudget = 0;
    double totalUsed = 0;
    int overBudgetCount = 0;

    for (final budget in enabledBudgets) {
      final categoryId = budget.categoryId;
      if (categoryId == null) continue;

      final spent = categorySpent[categoryId] ?? 0;
      final usageRate = budget.amount > 0 ? (spent / budget.amount * 100) : 0.0;
      final isOverBudget = spent > budget.amount;

      final category = DefaultCategories.findById(categoryId);

      budgetExecutions.add(BudgetExecution(
        name: category?.localizedName ?? CategoryLocalizationService.instance.getCategoryName(categoryId),
        budget: budget.amount,
        used: spent,
        usageRate: usageRate,
        isOverBudget: isOverBudget,
      ));

      totalBudget += budget.amount;
      totalUsed += spent;
      if (isOverBudget) overBudgetCount++;
    }

    return BudgetExecutionSummary(
      totalBudget: totalBudget,
      totalUsed: totalUsed,
      remaining: totalBudget - totalUsed,
      usageRate: totalBudget > 0 ? (totalUsed / totalBudget * 100) : 0,
      budgets: budgetExecutions,
      overBudgetCount: overBudgetCount,
    );
  }

  /// 计算目标进度
  /// 注意：目标数据需要从外部传入，目前返回空列表
  List<GoalProgressReport> _calculateGoalProgress() {
    // TODO: 需要传入储蓄目标数据
    return [];
  }

  /// 生成财务洞察
  List<FinancialInsight> _generateInsights({
    required IncomeExpenseSummary summary,
    required List<CategoryAnalysis> categoryAnalysis,
    required TrendAnalysis trendAnalysis,
  }) {
    final insights = <FinancialInsight>[];

    // 数据充足性检查
    if (summary.transactionCount < 5) {
      insights.add(FinancialInsight(
        type: InsightType.warning,
        title: '数据较少',
        description: '当前仅有${summary.transactionCount}笔交易记录，建议继续记账以获得更准确的财务分析',
        suggestion: '建议至少记录一周的完整交易数据（约20-30笔）后再查看报告',
        importance: InsightImportance.medium,
      ));
      return insights; // 数据不足时只返回提示
    }

    // 储蓄率分析
    if (summary.savingsRate >= 30) {
      insights.add(FinancialInsight(
        type: InsightType.achievement,
        title: '储蓄率优秀',
        description: '本期储蓄率达到${summary.savingsRate.toStringAsFixed(1)}%，高于平均水平',
        suggestion: '继续保持良好的储蓄习惯',
        importance: InsightImportance.medium,
      ));
    } else if (summary.savingsRate < 10) {
      insights.add(FinancialInsight(
        type: InsightType.warning,
        title: '储蓄率偏低',
        description: '本期储蓄率为${summary.savingsRate.toStringAsFixed(1)}%，建议关注支出',
        suggestion: '建议检查可削减的非必要支出',
        importance: InsightImportance.high,
      ));
    }

    // 异常支出分析
    for (final category in categoryAnalysis) {
      if (category.isAbnormal && category.change != null) {
        insights.add(FinancialInsight(
          type: InsightType.anomaly,
          title: '${category.categoryName}支出异常增长',
          description: '${category.categoryName}支出比上期增长${category.change!.toStringAsFixed(1)}%',
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
    } else if (trendAnalysis.expenseTrendDirection == TrendDirection.increasing) {
      insights.add(const FinancialInsight(
        type: InsightType.warning,
        title: '支出呈上升趋势',
        description: '近期支出整体呈上升趋势，建议关注',
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
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
  }) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    return generateReport(
      ledgerId: ledgerId,
      periodType: ReportPeriodType.monthly,
      startDate: startDate,
      endDate: endDate,
      members: members,
      transactions: transactions,
      budgets: budgets,
    );
  }

  /// 快速生成周报
  Future<FamilyFinancialReport> generateWeeklyReport({
    required String ledgerId,
    required DateTime weekStart,
    required List<LedgerMember> members,
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
  }) async {
    final endDate = weekStart.add(const Duration(days: 6));

    return generateReport(
      ledgerId: ledgerId,
      periodType: ReportPeriodType.weekly,
      startDate: weekStart,
      endDate: endDate,
      members: members,
      transactions: transactions,
      budgets: budgets,
    );
  }

  /// 快速生成年度报表
  Future<FamilyFinancialReport> generateYearlyReport({
    required String ledgerId,
    required int year,
    required List<LedgerMember> members,
    List<Transaction> transactions = const [],
    List<Budget> budgets = const [],
  }) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    return generateReport(
      ledgerId: ledgerId,
      periodType: ReportPeriodType.yearly,
      startDate: startDate,
      endDate: endDate,
      members: members,
      transactions: transactions,
      budgets: budgets,
    );
  }
}
