import 'dart:math';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';
import 'category_localization_service.dart';

/// 智能预算建议引擎
///
/// 多维度分析用户财务数据，生成个性化、可操作的预算建议：
/// 1. 消费趋势分析（哪些分类在增长/下降）
/// 2. 异常支出检测（突然飙升的分类）
/// 3. 储蓄健康度评估（储蓄率是否合理）
/// 4. 消费结构分析（必要vs非必要支出比例）
/// 5. 季节性预警（下个月可能的高支出提醒）
/// 6. 消费节奏分析（月初花太多？月末紧张？）
/// 7. 周期性支出优化（是否有可以砍掉的订阅）
class SmartSuggestionEngine {
  final List<Transaction> allTransactions;
  final List<RecurringTransaction> recurringTransactions;
  final double monthlyIncome;

  SmartSuggestionEngine({
    required this.allTransactions,
    required this.recurringTransactions,
    required this.monthlyIncome,
  });

  /// 生成智能建议
  SuggestionResult generate() {
    final now = DateTime.now();
    final suggestions = <BudgetSuggestion>[];

    // 基础数据准备
    final monthlyData = _buildMonthlyData(now);
    final categoryTrends = _analyzeCategoryTrends(now);
    final savingsHealth = _analyzeSavingsHealth(now);
    final spendingStructure = _analyzeSpendingStructure(now);
    final spendingPace = _analyzeSpendingPace(now);
    final anomalies = _detectAnomalies(now, categoryTrends);

    // ===== 生成各类建议 =====

    // 1. 异常支出警告（最高优先级）
    for (final anomaly in anomalies) {
      suggestions.add(anomaly);
    }

    // 2. 储蓄健康度建议
    if (savingsHealth != null) {
      suggestions.add(savingsHealth);
    }

    // 3. 消费趋势建议（上升趋势的分类）
    for (final trend in categoryTrends) {
      if (trend.suggestion != null) {
        suggestions.add(trend.suggestion!);
      }
    }

    // 4. 消费结构建议
    if (spendingStructure != null) {
      suggestions.add(spendingStructure);
    }

    // 5. 消费节奏建议
    if (spendingPace != null) {
      suggestions.add(spendingPace);
    }

    // 6. 季节性预警
    final seasonalWarning = _generateSeasonalWarning(now);
    if (seasonalWarning != null) {
      suggestions.add(seasonalWarning);
    }

    // 7. 周期性支出优化建议
    final subscriptionTip = _analyzeSubscriptions();
    if (subscriptionTip != null) {
      suggestions.add(subscriptionTip);
    }

    // 按优先级排序
    suggestions.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // 计算真实的统计数据
    final stats = _calculateRealStats(now, monthlyData);

    return SuggestionResult(
      suggestions: suggestions,
      stats: stats,
      dataMonths: monthlyData.length,
      transactionCount: allTransactions.length,
    );
  }

  // ==========================================
  // 数据准备
  // ==========================================

  /// 构建月度数据（最近6个月）
  Map<String, _MonthData> _buildMonthlyData(DateTime now) {
    final data = <String, _MonthData>{};

    for (int i = 0; i < 6; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = '${month.year}-${month.month}';
      final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      double income = 0;
      double expense = 0;
      final categoryExpenses = <String, double>{};

      for (final tx in allTransactions) {
        if (tx.date.isBefore(month) || tx.date.isAfter(monthEnd)) continue;
        if (tx.type == TransactionType.income) {
          income += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          expense += tx.amount;
          categoryExpenses[tx.category] =
              (categoryExpenses[tx.category] ?? 0) + tx.amount;
        }
      }

      if (income > 0 || expense > 0) {
        data[key] = _MonthData(
          month: month,
          income: income,
          expense: expense,
          categoryExpenses: categoryExpenses,
        );
      }
    }
    return data;
  }

  // ==========================================
  // 分析引擎
  // ==========================================

  /// 分析各分类消费趋势
  List<_CategoryTrend> _analyzeCategoryTrends(DateTime now) {
    final trends = <_CategoryTrend>[];
    final categoryMonthly = <String, List<double>>{};

    // 收集每个分类最近4个月的数据
    for (int i = 0; i < 4; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final monthExpenses = <String, double>{};
      for (final tx in allTransactions) {
        if (tx.type != TransactionType.expense) continue;
        if (tx.date.isBefore(month) || tx.date.isAfter(monthEnd)) continue;
        monthExpenses[tx.category] =
            (monthExpenses[tx.category] ?? 0) + tx.amount;
      }

      for (final entry in monthExpenses.entries) {
        categoryMonthly.putIfAbsent(entry.key, () => []);
        categoryMonthly[entry.key]!.add(entry.value);
      }
    }

    for (final entry in categoryMonthly.entries) {
      if (entry.value.length < 2) continue;

      final values = entry.value;
      final avg = values.reduce((a, b) => a + b) / values.length;
      if (avg < 50) continue; // 忽略小额分类

      final latest = values.first;
      final previous = values.length >= 2 ? values[1] : avg;
      final changeRate = previous > 0 ? (latest - previous) / previous : 0.0;

      final cat = DefaultCategories.findById(entry.key);
      final catName = cat?.localizedName ?? entry.key;

      BudgetSuggestion? suggestion;

      // 连续上升趋势
      if (changeRate > 0.2 && latest > 200) {
        suggestion = BudgetSuggestion(
          type: SuggestionType.trendWarning,
          priority: SuggestionPriority.medium,
          title: '$catName支出持续上升',
          description: '近期$catName月均¥${avg.toStringAsFixed(0)}，'
              '本月¥${latest.toStringAsFixed(0)}，'
              '环比上升${(changeRate * 100).round()}%',
          actionText: '建议预算¥${((avg * 1.1) / 100).ceil() * 100}，并关注消费明细',
          icon: Icons.trending_up,
          color: Colors.orange,
          amount: avg,
          suggestedAmount: ((avg * 1.1) / 100).ceil() * 100.0,
        );
      }
      // 下降趋势（正面反馈）
      else if (changeRate < -0.15 && avg > 200) {
        suggestion = BudgetSuggestion(
          type: SuggestionType.positiveFeedback,
          priority: SuggestionPriority.low,
          title: '$catName支出控制得不错',
          description: '$catName本月¥${latest.toStringAsFixed(0)}，'
              '比上月减少${(-changeRate * 100).round()}%，继续保持',
          actionText: '可以将节省的部分转入储蓄',
          icon: Icons.thumb_up,
          color: Colors.green,
          amount: latest,
          suggestedAmount: latest,
        );
      }

      trends.add(_CategoryTrend(
        categoryId: entry.key,
        categoryName: catName,
        monthlyAverage: avg,
        latestAmount: latest,
        changeRate: changeRate,
        suggestion: suggestion,
      ));
    }

    return trends;
  }

  /// 检测异常支出
  List<BudgetSuggestion> _detectAnomalies(
    DateTime now, List<_CategoryTrend> trends,
  ) {
    final anomalies = <BudgetSuggestion>[];

    for (final trend in trends) {
      // 本月支出超过均值的2倍 → 异常
      if (trend.latestAmount > trend.monthlyAverage * 2 &&
          trend.latestAmount > 300) {
        anomalies.add(BudgetSuggestion(
          type: SuggestionType.anomalyAlert,
          priority: SuggestionPriority.high,
          title: '${trend.categoryName}支出异常偏高',
          description: '本月${trend.categoryName}已花费¥${trend.latestAmount.toStringAsFixed(0)}，'
              '是近期月均¥${trend.monthlyAverage.toStringAsFixed(0)}的'
              '${(trend.latestAmount / trend.monthlyAverage).toStringAsFixed(1)}倍',
          actionText: '建议检查是否有非必要的大额支出',
          icon: Icons.warning_amber,
          color: Colors.red,
          amount: trend.latestAmount,
          suggestedAmount: trend.monthlyAverage,
        ));
      }
    }

    return anomalies;
  }

  /// 分析储蓄健康度
  BudgetSuggestion? _analyzeSavingsHealth(DateTime now) {
    if (monthlyIncome <= 0) return null;

    // 计算最近3个月的平均储蓄率
    final savingsRates = <double>[];
    for (int i = 0; i < 3; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      double income = 0, expense = 0;
      for (final tx in allTransactions) {
        if (tx.date.isBefore(month) || tx.date.isAfter(monthEnd)) continue;
        if (tx.type == TransactionType.income) income += tx.amount;
        if (tx.type == TransactionType.expense) expense += tx.amount;
      }

      if (income > 0) {
        savingsRates.add((income - expense) / income);
      }
    }

    if (savingsRates.isEmpty) return null;

    final avgSavingsRate = savingsRates.reduce((a, b) => a + b) / savingsRates.length;
    final savingsPercent = (avgSavingsRate * 100).round();

    if (avgSavingsRate < 0) {
      return BudgetSuggestion(
        type: SuggestionType.savingsHealth,
        priority: SuggestionPriority.high,
        title: '支出超过收入，需要关注',
        description: '近期月均支出超过收入${(-savingsPercent)}%，处于入不敷出状态',
        actionText: '建议梳理非必要支出，优先保障基本生活和储蓄',
        icon: Icons.savings,
        color: Colors.red,
      );
    } else if (avgSavingsRate < 0.1) {
      return BudgetSuggestion(
        type: SuggestionType.savingsHealth,
        priority: SuggestionPriority.medium,
        title: '储蓄率偏低（$savingsPercent%）',
        description: '建议储蓄率保持在20%以上，当前仅$savingsPercent%',
        actionText: '尝试从非必要支出中每月多存¥${(monthlyIncome * 0.1).toStringAsFixed(0)}',
        icon: Icons.savings,
        color: Colors.orange,
      );
    } else if (avgSavingsRate >= 0.3) {
      return BudgetSuggestion(
        type: SuggestionType.positiveFeedback,
        priority: SuggestionPriority.low,
        title: '储蓄习惯优秀（$savingsPercent%）',
        description: '储蓄率$savingsPercent%，远超建议的20%，财务状况健康',
        actionText: '可以考虑将部分储蓄用于投资增值',
        icon: Icons.emoji_events,
        color: Colors.green,
      );
    }

    return null;
  }

  /// 分析消费结构（必要vs非必要）
  BudgetSuggestion? _analyzeSpendingStructure(DateTime now) {
    final month = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    double essential = 0, nonEssential = 0;
    final essentialKeywords = ['餐饮', '交通', '居住', '水电', '医疗', '通讯', '教育'];

    for (final tx in allTransactions) {
      if (tx.type != TransactionType.expense) continue;
      if (tx.date.isBefore(month) || tx.date.isAfter(monthEnd)) continue;

      final cat = DefaultCategories.findById(tx.category);
      final catName = cat?.localizedName ?? tx.category;

      if (essentialKeywords.any((k) => catName.contains(k))) {
        essential += tx.amount;
      } else {
        nonEssential += tx.amount;
      }
    }

    final total = essential + nonEssential;
    if (total < 100) return null;

    final nonEssentialRate = nonEssential / total;

    if (nonEssentialRate > 0.5) {
      return BudgetSuggestion(
        type: SuggestionType.structureAdvice,
        priority: SuggestionPriority.medium,
        title: '非必要支出占比偏高',
        description: '本月非必要支出占${(nonEssentialRate * 100).round()}%'
            '（¥${nonEssential.toStringAsFixed(0)}），'
            '必要支出占${((1 - nonEssentialRate) * 100).round()}%'
            '（¥${essential.toStringAsFixed(0)}）',
        actionText: '建议将非必要支出控制在40%以内',
        icon: Icons.pie_chart,
        color: Colors.purple,
      );
    }

    return null;
  }

  /// 分析消费节奏（月初vs月末）
  BudgetSuggestion? _analyzeSpendingPace(DateTime now) {
    final month = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final midMonth = DateTime(now.year, now.month, 15);

    double firstHalf = 0, secondHalf = 0;

    for (final tx in allTransactions) {
      if (tx.type != TransactionType.expense) continue;
      if (tx.date.isBefore(month) || tx.date.isAfter(monthEnd)) continue;

      if (tx.date.isBefore(midMonth)) {
        firstHalf += tx.amount;
      } else {
        secondHalf += tx.amount;
      }
    }

    // 只在月末分析才有意义（至少过了20号）
    if (now.day < 20) return null;

    final total = firstHalf + secondHalf;
    if (total < 100) return null;

    final firstHalfRate = firstHalf / total;

    if (firstHalfRate > 0.7) {
      return BudgetSuggestion(
        type: SuggestionType.paceAdvice,
        priority: SuggestionPriority.low,
        title: '月初消费集中',
        description: '本月前半月花了${(firstHalfRate * 100).round()}%的预算'
            '（¥${firstHalf.toStringAsFixed(0)}），后半月可能会比较紧张',
        actionText: '建议将大额支出分散到月中，保持消费节奏均匀',
        icon: Icons.calendar_month,
        color: Colors.blue,
      );
    }

    return null;
  }

  /// 季节性预警
  BudgetSuggestion? _generateSeasonalWarning(DateTime now) {
    final nextMonth = now.month == 12 ? 1 : now.month + 1;
    String? warning;
    if (nextMonth == 1 || nextMonth == 2) warning = '春节期间人情往来、年货采购支出会增加';
    else if (nextMonth == 6) warning = '618大促期间购物支出可能增加，建议提前设定预算上限';
    else if (nextMonth == 9) warning = '开学季教育支出可能增加，中秋节人情往来也需预留';
    else if (nextMonth == 11) warning = '双11大促期间购物支出可能增加，建议只买必需品';
    else if (nextMonth == 7 || nextMonth == 8) warning = '夏季空调用电量大，电费可能上升';
    else if (nextMonth == 12) warning = '年末聚餐、礼物支出增多，建议提前规划';
    if (warning == null) return null;
    return BudgetSuggestion(
      type: SuggestionType.seasonalWarning, priority: SuggestionPriority.low,
      title: '下月消费预警', description: warning,
      actionText: '建议提前在预算中预留相应空间',
      icon: Icons.event_note, color: Colors.teal,
    );
  }

  /// 分析周期性支出
  BudgetSuggestion? _analyzeSubscriptions() {
    final active = recurringTransactions.where((r) => r.isEnabled && r.type == TransactionType.expense).toList();
    if (active.isEmpty) return null;
    double totalMonthly = 0;
    final items = <String>[];
    for (final sub in active) {
      double monthly;
      switch (sub.frequency) {
        case RecurringFrequency.daily: monthly = sub.amount * 30;
        case RecurringFrequency.weekly: monthly = sub.amount * 4.33;
        case RecurringFrequency.monthly: monthly = sub.amount;
        case RecurringFrequency.yearly: monthly = sub.amount / 12;
      }
      totalMonthly += monthly;
      final cat = DefaultCategories.findById(sub.category);
      items.add('${cat?.localizedName ?? sub.category.localizedCategoryName} ¥${monthly.toStringAsFixed(0)}/月');
    }
    if (totalMonthly > monthlyIncome * 0.15 && monthlyIncome > 0) {
      return BudgetSuggestion(
        type: SuggestionType.subscriptionOptimize, priority: SuggestionPriority.medium,
        title: '周期性支出占比较高',
        description: '每月固定支出¥${totalMonthly.toStringAsFixed(0)}，占收入${(totalMonthly / monthlyIncome * 100).round()}%（${items.take(3).join("、")}）',
        actionText: '建议检查是否有不再使用的订阅服务可以取消',
        icon: Icons.autorenew, color: Colors.deepOrange,
      );
    }
    return null;
  }

  /// 计算真实统计数据
  SuggestionStats _calculateRealStats(DateTime now, Map<String, _MonthData> monthlyData) {
    final dataScore = min(1.0, (monthlyData.length / 4.0) * 0.5 + (min(allTransactions.length, 100) / 100.0) * 0.5);
    final months = monthlyData.values.toList()..sort((a, b) => a.month.compareTo(b.month));
    double avgExpenseChange = 0;
    if (months.length >= 2) {
      final recent = months.last.expense;
      final previous = months[months.length - 2].expense;
      avgExpenseChange = previous > 0 ? (recent - previous) / previous : 0;
    }
    return SuggestionStats(dataConfidence: dataScore, monthlyExpenseTrend: avgExpenseChange, totalTransactions: allTransactions.length, monthsAnalyzed: monthlyData.length);
  }
}

class SuggestionResult {
  final List<BudgetSuggestion> suggestions;
  final SuggestionStats stats;
  final int dataMonths;
  final int transactionCount;
  SuggestionResult({required this.suggestions, required this.stats, required this.dataMonths, required this.transactionCount});
}

class SuggestionStats {
  final double dataConfidence;
  final double monthlyExpenseTrend;
  final int totalTransactions;
  final int monthsAnalyzed;
  SuggestionStats({required this.dataConfidence, required this.monthlyExpenseTrend, required this.totalTransactions, required this.monthsAnalyzed});
}

class BudgetSuggestion {
  final SuggestionType type;
  final SuggestionPriority priority;
  final String title;
  final String description;
  final String actionText;
  final IconData icon;
  final Color color;
  final double? amount;
  final double? suggestedAmount;
  BudgetSuggestion({required this.type, required this.priority, required this.title, required this.description, required this.actionText, required this.icon, required this.color, this.amount, this.suggestedAmount});
}

enum SuggestionType { anomalyAlert, savingsHealth, trendWarning, positiveFeedback, structureAdvice, paceAdvice, seasonalWarning, subscriptionOptimize }
enum SuggestionPriority { high, medium, low }

class _MonthData {
  final DateTime month;
  final double income;
  final double expense;
  final Map<String, double> categoryExpenses;
  _MonthData({required this.month, required this.income, required this.expense, required this.categoryExpenses});
}

class _CategoryTrend {
  final String categoryId;
  final String categoryName;
  final double monthlyAverage;
  final double latestAmount;
  final double changeRate;
  final BudgetSuggestion? suggestion;
  _CategoryTrend({required this.categoryId, required this.categoryName, required this.monthlyAverage, required this.latestAmount, required this.changeRate, this.suggestion});
}