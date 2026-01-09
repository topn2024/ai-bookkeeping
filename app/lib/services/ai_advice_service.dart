import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';

/// AI建议服务 - 调用后端AI生成的各类建议
class AIAdviceService {
  final ApiClient _apiClient;

  AIAdviceService(this._apiClient);

  /// 获取分类建议
  Future<CategorySuggestion> suggestCategory({
    required String description,
    required double amount,
    String? merchant,
    DateTime? time,
    String? location,
    List<Map<String, dynamic>>? userHistory,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/suggest-category',
      body: {
        'description': description,
        'amount': amount,
        if (merchant != null) 'merchant': merchant,
        if (time != null) 'time': time.toIso8601String(),
        if (location != null) 'location': location,
        if (userHistory != null) 'user_history': userHistory,
      },
    );

    return CategorySuggestion.fromJson(response);
  }

  /// 优化预算分配
  Future<BudgetAllocation> optimizeBudget({
    required double monthlyIncome,
    required Map<String, double> historicalExpenses,
    List<Map<String, dynamic>>? financialGoals,
    Map<String, dynamic>? userPreferences,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/optimize-budget',
      body: {
        'monthly_income': monthlyIncome,
        'historical_expenses': historicalExpenses,
        if (financialGoals != null) 'financial_goals': financialGoals,
        if (userPreferences != null) 'user_preferences': userPreferences,
      },
    );

    return BudgetAllocation.fromJson(response);
  }

  /// 生成财务建议
  Future<String> generateFinancialAdvice({
    required String adviceType,
    required Map<String, dynamic> params,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/financial-advice',
      body: {
        'advice_type': adviceType,
        'params': params,
      },
    );

    return response['advice'] as String;
  }

  /// 生成储蓄计划
  Future<SavingsPlan> generateSavingsPlan({
    required String goalName,
    required double targetAmount,
    required double currentAmount,
    required DateTime deadline,
    required double monthlyIncome,
    required double monthlyExpense,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/savings-plan',
      body: {
        'goal_name': goalName,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'deadline': deadline.toIso8601String(),
        'monthly_income': monthlyIncome,
        'monthly_expense': monthlyExpense,
      },
    );

    return SavingsPlan.fromJson(response);
  }

  /// 生成成就描述
  Future<String> generateAchievementDescription({
    required String achievementType,
    required Map<String, dynamic> achievementData,
    String? userName,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/achievement-description',
      body: {
        'achievement_type': achievementType,
        'achievement_data': achievementData,
        if (userName != null) 'user_name': userName,
      },
    );

    return response['description'] as String;
  }

  /// 生成年度报告
  Future<AnnualReport> generateAnnualReport({
    required int year,
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> categoryBreakdown,
    required List<String> highlights,
    String? userName,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/annual-report',
      body: {
        'year': year,
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'category_breakdown': categoryBreakdown,
        'highlights': highlights,
        if (userName != null) 'user_name': userName,
      },
    );

    return AnnualReport.fromJson(response);
  }

  /// 生成地点建议
  Future<String> generateLocationAdvice({
    required String locationName,
    required Map<String, dynamic> spendingData,
    List<Map<String, dynamic>>? nearbyAlternatives,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/location-advice',
      body: {
        'location_name': locationName,
        'spending_data': spendingData,
        if (nearbyAlternatives != null) 'nearby_alternatives': nearbyAlternatives,
      },
    );

    return response['advice'] as String;
  }

  /// 生成账单提醒
  Future<BillReminder> generateBillReminder({
    required String billType,
    required String billName,
    required double amount,
    required DateTime dueDate,
    double? accountBalance,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/bill-reminder',
      body: {
        'bill_type': billType,
        'bill_name': billName,
        'amount': amount,
        'due_date': dueDate.toIso8601String(),
        if (accountBalance != null) 'account_balance': accountBalance,
      },
    );

    return BillReminder.fromJson(response);
  }

  /// 生成还款策略
  Future<RepaymentStrategy> generateRepaymentStrategy({
    required List<Map<String, dynamic>> bills,
    required double availableAmount,
  }) async {
    final response = await _apiClient.post(
      '/ai-advice/repayment-strategy',
      body: {
        'bills': bills,
        'available_amount': availableAmount,
      },
    );

    return RepaymentStrategy.fromJson(response);
  }
}

/// 分类建议
class CategorySuggestion {
  final String category;
  final double confidence;
  final String reason;

  CategorySuggestion({
    required this.category,
    required this.confidence,
    required this.reason,
  });

  factory CategorySuggestion.fromJson(Map<String, dynamic> json) {
    return CategorySuggestion(
      category: json['category'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      reason: json['reason'] as String,
    );
  }
}

/// 预算分配
class BudgetAllocation {
  final Map<String, dynamic> allocations;
  final Map<String, double> categoryBudgets;
  final String reasoning;
  final List<String> tips;

  BudgetAllocation({
    required this.allocations,
    required this.categoryBudgets,
    required this.reasoning,
    required this.tips,
  });

  factory BudgetAllocation.fromJson(Map<String, dynamic> json) {
    return BudgetAllocation(
      allocations: json['allocations'] as Map<String, dynamic>,
      categoryBudgets: (json['category_budgets'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      reasoning: json['reasoning'] as String,
      tips: (json['tips'] as List).cast<String>(),
    );
  }
}

/// 储蓄计划
class SavingsPlan {
  final String feasibility;
  final double monthlySavings;
  final double savingsRate;
  final List<String> strategies;
  final String timelineAdjustment;
  final String motivation;

  SavingsPlan({
    required this.feasibility,
    required this.monthlySavings,
    required this.savingsRate,
    required this.strategies,
    required this.timelineAdjustment,
    required this.motivation,
  });

  factory SavingsPlan.fromJson(Map<String, dynamic> json) {
    return SavingsPlan(
      feasibility: json['feasibility'] as String,
      monthlySavings: (json['monthly_savings'] as num).toDouble(),
      savingsRate: (json['savings_rate'] as num).toDouble(),
      strategies: (json['strategies'] as List).cast<String>(),
      timelineAdjustment: json['timeline_adjustment'] as String,
      motivation: json['motivation'] as String,
    );
  }
}

/// 年度报告
class AnnualReport {
  final String title;
  final String summary;
  final String highlightsText;
  final List<String> improvements;
  final List<String> nextYearGoals;
  final String closing;

  AnnualReport({
    required this.title,
    required this.summary,
    required this.highlightsText,
    required this.improvements,
    required this.nextYearGoals,
    required this.closing,
  });

  factory AnnualReport.fromJson(Map<String, dynamic> json) {
    return AnnualReport(
      title: json['title'] as String,
      summary: json['summary'] as String,
      highlightsText: json['highlights_text'] as String,
      improvements: (json['improvements'] as List).cast<String>(),
      nextYearGoals: (json['next_year_goals'] as List).cast<String>(),
      closing: json['closing'] as String,
    );
  }
}

/// 账单提醒
class BillReminder {
  final String title;
  final String message;
  final String urgencyLevel;
  final String actionText;
  final String tips;

  BillReminder({
    required this.title,
    required this.message,
    required this.urgencyLevel,
    required this.actionText,
    required this.tips,
  });

  factory BillReminder.fromJson(Map<String, dynamic> json) {
    return BillReminder(
      title: json['title'] as String,
      message: json['message'] as String,
      urgencyLevel: json['urgency_level'] as String,
      actionText: json['action_text'] as String,
      tips: json['tips'] as String,
    );
  }
}

/// 还款策略
class RepaymentStrategy {
  final String strategy;
  final List<RepaymentOrder> repaymentOrder;
  final String shortageSolution;
  final List<String> tips;

  RepaymentStrategy({
    required this.strategy,
    required this.repaymentOrder,
    required this.shortageSolution,
    required this.tips,
  });

  factory RepaymentStrategy.fromJson(Map<String, dynamic> json) {
    return RepaymentStrategy(
      strategy: json['strategy'] as String,
      repaymentOrder: (json['repayment_order'] as List)
          .map((e) => RepaymentOrder.fromJson(e as Map<String, dynamic>))
          .toList(),
      shortageSolution: json['shortage_solution'] as String,
      tips: (json['tips'] as List).cast<String>(),
    );
  }
}

class RepaymentOrder {
  final String bill;
  final double amount;
  final String reason;

  RepaymentOrder({
    required this.bill,
    required this.amount,
    required this.reason,
  });

  factory RepaymentOrder.fromJson(Map<String, dynamic> json) {
    return RepaymentOrder(
      bill: json['bill'] as String,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String,
    );
  }
}
