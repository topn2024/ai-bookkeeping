import 'package:flutter/material.dart';

/// 报表周期类型
enum ReportPeriodType {
  weekly,
  monthly,
  quarterly,
  yearly,
  custom,
}

/// 报表周期扩展
extension ReportPeriodTypeExtension on ReportPeriodType {
  String get displayName {
    switch (this) {
      case ReportPeriodType.weekly:
        return '周报';
      case ReportPeriodType.monthly:
        return '月报';
      case ReportPeriodType.quarterly:
        return '季报';
      case ReportPeriodType.yearly:
        return '年报';
      case ReportPeriodType.custom:
        return '自定义';
    }
  }
}

/// 家庭财务报表
class FamilyFinancialReport {
  /// 账本ID
  final String ledgerId;
  /// 报表周期类型
  final ReportPeriodType periodType;
  /// 开始日期
  final DateTime startDate;
  /// 结束日期
  final DateTime endDate;
  /// 报表标题
  final String title;
  /// 收支汇总
  final IncomeExpenseSummary summary;
  /// 分类分析
  final List<CategoryAnalysis> categoryAnalysis;
  /// 成员分析
  final List<MemberAnalysis> memberAnalysis;
  /// 趋势分析
  final TrendAnalysis trendAnalysis;
  /// 预算执行情况
  final BudgetExecutionSummary? budgetExecution;
  /// 储蓄目标进度
  final List<GoalProgressReport> goalProgress;
  /// 洞察建议
  final List<FinancialInsight> insights;
  /// 生成时间
  final DateTime generatedAt;

  const FamilyFinancialReport({
    required this.ledgerId,
    required this.periodType,
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.summary,
    this.categoryAnalysis = const [],
    this.memberAnalysis = const [],
    required this.trendAnalysis,
    this.budgetExecution,
    this.goalProgress = const [],
    this.insights = const [],
    required this.generatedAt,
  });

  /// 报表周期天数
  int get periodDays => endDate.difference(startDate).inDays + 1;

  Map<String, dynamic> toMap() {
    return {
      'ledgerId': ledgerId,
      'periodType': periodType.index,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'title': title,
      'summary': summary.toMap(),
      'categoryAnalysis': categoryAnalysis.map((c) => c.toMap()).toList(),
      'memberAnalysis': memberAnalysis.map((m) => m.toMap()).toList(),
      'trendAnalysis': trendAnalysis.toMap(),
      'budgetExecution': budgetExecution?.toMap(),
      'goalProgress': goalProgress.map((g) => g.toMap()).toList(),
      'insights': insights.map((i) => i.toMap()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

/// 收支汇总
class IncomeExpenseSummary {
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
  /// 支出中位数
  final double medianExpense;
  /// 最大��笔支出
  final double maxExpense;
  /// 与上期对比
  final PeriodComparison? comparison;

  const IncomeExpenseSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.savingsRate,
    required this.transactionCount,
    required this.avgDailyExpense,
    this.medianExpense = 0,
    this.maxExpense = 0,
    this.comparison,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'netSavings': netSavings,
      'savingsRate': savingsRate,
      'transactionCount': transactionCount,
      'avgDailyExpense': avgDailyExpense,
      'medianExpense': medianExpense,
      'maxExpense': maxExpense,
      'comparison': comparison?.toMap(),
    };
  }
}

/// 周期对比
class PeriodComparison {
  /// 上期总支出
  final double previousExpense;
  /// 上期总收入
  final double previousIncome;
  /// 支出变化百分比
  final double expenseChange;
  /// 收入变化百分比
  final double incomeChange;
  /// 储蓄率变化
  final double savingsRateChange;

  const PeriodComparison({
    required this.previousExpense,
    required this.previousIncome,
    required this.expenseChange,
    required this.incomeChange,
    required this.savingsRateChange,
  });

  /// 支出是否增加
  bool get isExpenseIncreased => expenseChange > 0;

  /// 收入是否增加
  bool get isIncomeIncreased => incomeChange > 0;

  Map<String, dynamic> toMap() {
    return {
      'previousExpense': previousExpense,
      'previousIncome': previousIncome,
      'expenseChange': expenseChange,
      'incomeChange': incomeChange,
      'savingsRateChange': savingsRateChange,
    };
  }
}

/// 分类分析
class CategoryAnalysis {
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
  /// 占比
  final double percentage;
  /// 交易笔数
  final int transactionCount;
  /// 平均单笔
  final double avgTransaction;
  /// 与上期对比
  final double? change;
  /// 是否为异常增长
  final bool isAbnormal;
  /// 子分类分布
  final List<SubCategoryBreakdown> subCategories;

  const CategoryAnalysis({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    required this.avgTransaction,
    this.change,
    this.isAbnormal = false,
    this.subCategories = const [],
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
      'avgTransaction': avgTransaction,
      'change': change,
      'isAbnormal': isAbnormal,
      'subCategories': subCategories.map((s) => s.toMap()).toList(),
    };
  }
}

/// 子分类分布
class SubCategoryBreakdown {
  final String id;
  final String name;
  final double amount;
  final double percentage;

  const SubCategoryBreakdown({
    required this.id,
    required this.name,
    required this.amount,
    required this.percentage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'percentage': percentage,
    };
  }
}

/// 成员分析
class MemberAnalysis {
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
  /// 净贡献
  final double netContribution;
  /// 交易笔数
  final int transactionCount;
  /// 支出占比
  final double expensePercentage;
  /// 主要支出分类
  final List<String> topCategories;
  /// 与上期对比
  final double? expenseChange;
  /// 参与度（活跃天数比例）
  final double participationRate;

  const MemberAnalysis({
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.income,
    required this.expense,
    required this.netContribution,
    required this.transactionCount,
    required this.expensePercentage,
    this.topCategories = const [],
    this.expenseChange,
    this.participationRate = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'memberName': memberName,
      'avatarUrl': avatarUrl,
      'income': income,
      'expense': expense,
      'netContribution': netContribution,
      'transactionCount': transactionCount,
      'expensePercentage': expensePercentage,
      'topCategories': topCategories,
      'expenseChange': expenseChange,
      'participationRate': participationRate,
    };
  }
}

/// 趋势分析
class TrendAnalysis {
  /// 支出趋势点
  final List<TrendDataPoint> expenseTrend;
  /// 收入趋势点
  final List<TrendDataPoint> incomeTrend;
  /// 储蓄率趋势
  final List<TrendDataPoint> savingsRateTrend;
  /// 趋势方向（上升/下降/平稳）
  final TrendDirection expenseTrendDirection;
  /// 周期性模式
  final List<SeasonalPattern> seasonalPatterns;
  /// 预测
  final TrendForecast? forecast;

  const TrendAnalysis({
    this.expenseTrend = const [],
    this.incomeTrend = const [],
    this.savingsRateTrend = const [],
    this.expenseTrendDirection = TrendDirection.stable,
    this.seasonalPatterns = const [],
    this.forecast,
  });

  Map<String, dynamic> toMap() {
    return {
      'expenseTrend': expenseTrend.map((t) => t.toMap()).toList(),
      'incomeTrend': incomeTrend.map((t) => t.toMap()).toList(),
      'savingsRateTrend': savingsRateTrend.map((t) => t.toMap()).toList(),
      'expenseTrendDirection': expenseTrendDirection.index,
      'seasonalPatterns': seasonalPatterns.map((s) => s.toMap()).toList(),
      'forecast': forecast?.toMap(),
    };
  }
}

/// 趋势数据点
class TrendDataPoint {
  final DateTime date;
  final String label;
  final double value;

  const TrendDataPoint({
    required this.date,
    required this.label,
    required this.value,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'label': label,
      'value': value,
    };
  }
}

/// 趋势方向
enum TrendDirection {
  increasing,
  decreasing,
  stable,
}

/// 季节性模式
class SeasonalPattern {
  final String description;
  final String period;
  final double impact;

  const SeasonalPattern({
    required this.description,
    required this.period,
    required this.impact,
  });

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'period': period,
      'impact': impact,
    };
  }
}

/// 趋势预测
class TrendForecast {
  final double nextPeriodExpense;
  final double nextPeriodIncome;
  final double confidence;
  final String description;

  const TrendForecast({
    required this.nextPeriodExpense,
    required this.nextPeriodIncome,
    required this.confidence,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'nextPeriodExpense': nextPeriodExpense,
      'nextPeriodIncome': nextPeriodIncome,
      'confidence': confidence,
      'description': description,
    };
  }
}

/// 预算执行汇总
class BudgetExecutionSummary {
  /// 总预算
  final double totalBudget;
  /// 已使用
  final double totalUsed;
  /// 剩余
  final double remaining;
  /// 使用率
  final double usageRate;
  /// 各预算执行情况
  final List<BudgetExecution> budgets;
  /// 超支预算数量
  final int overBudgetCount;

  const BudgetExecutionSummary({
    required this.totalBudget,
    required this.totalUsed,
    required this.remaining,
    required this.usageRate,
    this.budgets = const [],
    this.overBudgetCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalBudget': totalBudget,
      'totalUsed': totalUsed,
      'remaining': remaining,
      'usageRate': usageRate,
      'budgets': budgets.map((b) => b.toMap()).toList(),
      'overBudgetCount': overBudgetCount,
    };
  }
}

/// 预算执行情况
class BudgetExecution {
  final String name;
  final double budget;
  final double used;
  final double usageRate;
  final bool isOverBudget;

  const BudgetExecution({
    required this.name,
    required this.budget,
    required this.used,
    required this.usageRate,
    required this.isOverBudget,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'budget': budget,
      'used': used,
      'usageRate': usageRate,
      'isOverBudget': isOverBudget,
    };
  }
}

/// 目标进度报告
class GoalProgressReport {
  final String goalId;
  final String goalName;
  final String emoji;
  final double targetAmount;
  final double currentAmount;
  final double progressPercentage;
  final double periodContribution;
  final DateTime? deadline;
  final bool isOnTrack;

  const GoalProgressReport({
    required this.goalId,
    required this.goalName,
    required this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    required this.progressPercentage,
    required this.periodContribution,
    this.deadline,
    this.isOnTrack = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'goalName': goalName,
      'emoji': emoji,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'progressPercentage': progressPercentage,
      'periodContribution': periodContribution,
      'deadline': deadline?.toIso8601String(),
      'isOnTrack': isOnTrack,
    };
  }
}

/// 财务洞察
class FinancialInsight {
  /// 洞察类型
  final InsightType type;
  /// 标题
  final String title;
  /// 描述
  final String description;
  /// 建议
  final String? suggestion;
  /// 重要性
  final InsightImportance importance;
  /// 相关数据
  final Map<String, dynamic>? data;

  const FinancialInsight({
    required this.type,
    required this.title,
    required this.description,
    this.suggestion,
    this.importance = InsightImportance.medium,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'title': title,
      'description': description,
      'suggestion': suggestion,
      'importance': importance.index,
      'data': data,
    };
  }
}

/// 洞察类型
enum InsightType {
  spending,
  saving,
  budget,
  trend,
  anomaly,
  achievement,
  warning,
}

/// 洞察重要性
enum InsightImportance {
  low,
  medium,
  high,
  critical,
}

extension InsightImportanceExtension on InsightImportance {
  Color get color {
    switch (this) {
      case InsightImportance.low:
        return const Color(0xFF9E9E9E);
      case InsightImportance.medium:
        return const Color(0xFF2196F3);
      case InsightImportance.high:
        return const Color(0xFFFF9800);
      case InsightImportance.critical:
        return const Color(0xFFF44336);
    }
  }
}
