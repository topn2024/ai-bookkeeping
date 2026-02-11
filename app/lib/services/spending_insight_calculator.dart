import 'dart:math';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget.dart';

/// 洞察条目数据类
class InsightItem {
  final IconData icon;
  final String title;
  final String description;
  final String? badgeText;
  final Color? badgeColor;

  const InsightItem({
    required this.icon,
    required this.title,
    required this.description,
    this.badgeText,
    this.badgeColor,
  });
}

/// 纯静态工具类，接收交易列表做计算，不依赖任何 provider/service
class SpendingInsightCalculator {
  SpendingInsightCalculator._();

  /// 环比变化百分比
  /// 当前周期总支出 vs 等时长的上一周期总支出
  static double? periodOverPeriodChange(
    List<Transaction> allTx,
    DateTimeRange currentRange,
  ) {
    final duration = currentRange.end.difference(currentRange.start);
    final prevEnd = currentRange.start.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(duration);

    final currentExpense = allTx
        .where((t) =>
            t.type == TransactionType.expense &&
            !t.date.isBefore(currentRange.start) &&
            !t.date.isAfter(currentRange.end))
        .fold<double>(0, (sum, t) => sum + t.amount);

    final prevExpense = allTx
        .where((t) =>
            t.type == TransactionType.expense &&
            !t.date.isBefore(prevStart) &&
            !t.date.isAfter(prevEnd))
        .fold<double>(0, (sum, t) => sum + t.amount);

    if (prevExpense == 0) return null;
    return (currentExpense - prevExpense) / prevExpense * 100;
  }

  /// 按 weekday(1-7) 分组求和支出
  static Map<int, double> weekdayDistribution(List<Transaction> transactions) {
    final result = <int, double>{};
    for (int i = 1; i <= 7; i++) {
      result[i] = 0;
    }
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        result[t.date.weekday] = (result[t.date.weekday] ?? 0) + t.amount;
      }
    }
    return result;
  }

  /// 周末(6,7)支出占总支出比
  static double weekendRatio(List<Transaction> transactions) {
    double total = 0;
    double weekend = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        total += t.amount;
        if (t.date.weekday >= 6) {
          weekend += t.amount;
        }
      }
    }
    if (total == 0) return 0;
    return weekend / total;
  }

  /// 赫芬达尔指数(HHI): Σ(share_i²)
  /// >0.25 集中, <0.15 均衡
  static double concentrationIndex(Map<String, double> categoryExpenses) {
    final total = categoryExpenses.values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return 0;
    double hhi = 0;
    for (final amount in categoryExpenses.values) {
      final share = amount / total;
      hhi += share * share;
    }
    return hhi;
  }

  /// 综合生成洞察列表
  static List<InsightItem> generatePeriodInsights(
    List<Transaction> transactions,
    List<Transaction> allTx,
    DateTimeRange range,
    List<Budget> budgets,
  ) {
    final insights = <InsightItem>[];

    final expenseTx =
        transactions.where((t) => t.type == TransactionType.expense).toList();
    if (expenseTx.isEmpty) return insights;

    // 1. 环比趋势
    final pop = periodOverPeriodChange(allTx, range);
    if (pop != null) {
      final isUp = pop > 0;
      insights.add(InsightItem(
        icon: isUp ? Icons.trending_up : Icons.trending_down,
        title: '消费趋势',
        description: isUp
            ? '本期支出较上期增长 ${pop.toStringAsFixed(1)}%，注意控制开支'
            : '本期支出较上期下降 ${pop.abs().toStringAsFixed(1)}%，继续保持',
        badgeText: '${isUp ? "+" : ""}${pop.toStringAsFixed(1)}%',
        badgeColor: isUp ? Colors.red : Colors.green,
      ));
    }

    // 2. 集中度分析
    final categoryExpenses = <String, double>{};
    for (final t in expenseTx) {
      categoryExpenses[t.category] =
          (categoryExpenses[t.category] ?? 0) + t.amount;
    }
    final hhi = concentrationIndex(categoryExpenses);
    if (categoryExpenses.length > 1) {
      String hhiDesc;
      String hhiBadge;
      Color hhiColor;
      if (hhi >= 0.25) {
        hhiDesc = '消费集中在少数分类，建议适当分散支出';
        hhiBadge = '过于集中';
        hhiColor = Colors.red;
      } else if (hhi >= 0.15) {
        hhiDesc = '消费分布较为集中，可关注主要支出方向';
        hhiBadge = '较集中';
        hhiColor = Colors.orange;
      } else {
        hhiDesc = '消费分布均衡，各分类支出比较合理';
        hhiBadge = '均衡';
        hhiColor = Colors.green;
      }
      insights.add(InsightItem(
        icon: Icons.donut_large,
        title: '集中度分析',
        description: hhiDesc,
        badgeText: hhiBadge,
        badgeColor: hhiColor,
      ));
    }

    // 3. 周末模式
    final wRatio = weekendRatio(transactions);
    if (wRatio > 0) {
      final weekendPercent = (wRatio * 100).toStringAsFixed(0);
      insights.add(InsightItem(
        icon: Icons.weekend,
        title: '周末消费模式',
        description: wRatio > 0.4
            ? '周末消费占比 $weekendPercent%，明显偏高'
            : '周末消费占比 $weekendPercent%，比例正常',
        badgeText: '$weekendPercent%',
        badgeColor: wRatio > 0.4 ? Colors.orange : Colors.green,
      ));
    }

    // 4. 大额消费提醒 (>500)
    final bigExpenses =
        expenseTx.where((t) => t.amount > 500).toList();
    if (bigExpenses.isNotEmpty) {
      final bigTotal =
          bigExpenses.fold<double>(0, (sum, t) => sum + t.amount);
      insights.add(InsightItem(
        icon: Icons.warning_amber,
        title: '大额消费提醒',
        description:
            '本期有 ${bigExpenses.length} 笔大额消费（>¥500），合计 ¥${bigTotal.toStringAsFixed(0)}',
        badgeText: '${bigExpenses.length}笔',
        badgeColor: Colors.orange,
      ));
    }

    // 5. 小额累积提醒 (<50元占比>20%)
    final totalExpense = expenseTx.fold<double>(0, (sum, t) => sum + t.amount);
    final smallExpenses = expenseTx.where((t) => t.amount < 50).toList();
    final smallTotal =
        smallExpenses.fold<double>(0, (sum, t) => sum + t.amount);
    final smallRatio = totalExpense > 0 ? smallTotal / totalExpense : 0.0;
    if (smallRatio > 0.2 && smallExpenses.length >= 3) {
      insights.add(InsightItem(
        icon: Icons.scatter_plot,
        title: '小额累积提醒',
        description:
            '${smallExpenses.length} 笔小额消费（<¥50）累计 ¥${smallTotal.toStringAsFixed(0)}，占总支出 ${(smallRatio * 100).toStringAsFixed(0)}%',
        badgeText: '${(smallRatio * 100).toStringAsFixed(0)}%',
        badgeColor: Colors.orange,
      ));
    }

    // 6. 预算警告（使用率>80%的预算项）
    final enabledBudgets = budgets.where((b) => b.isEnabled).toList();
    if (enabledBudgets.isNotEmpty) {
      final warningBudgets = <String>[];
      for (final budget in enabledBudgets) {
        double spent = 0;
        for (final t in expenseTx) {
          if (budget.categoryId == null || t.category == budget.categoryId) {
            if (!t.date.isBefore(budget.periodStartDate) &&
                !t.date.isAfter(budget.periodEndDate)) {
              spent += t.amount;
            }
          }
        }
        final usage = budget.amount > 0 ? spent / budget.amount : 0.0;
        if (usage > 0.8) {
          warningBudgets.add(budget.name);
        }
      }
      if (warningBudgets.isNotEmpty) {
        insights.add(InsightItem(
          icon: Icons.account_balance_wallet,
          title: '预算警告',
          description:
              '${warningBudgets.join("、")} 预算使用率已超过80%，注意控制',
          badgeText: '${warningBudgets.length}项',
          badgeColor: Colors.red,
        ));
      }
    }

    return insights;
  }

  // ====== 趋势预测方法 ======

  /// 季节性因子（基于中国消费习惯）
  static double seasonalFactor(int month) {
    const factors = {
      1: 1.15, // 春节
      2: 1.10, // 春节
      3: 0.95,
      4: 0.95,
      5: 1.00,
      6: 1.10, // 618
      7: 1.05,
      8: 1.00,
      9: 0.95,
      10: 1.05, // 国庆
      11: 1.20, // 双11
      12: 1.10, // 年末
    };
    return factors[month] ?? 1.0;
  }

  /// 获取季节性事件名称
  static String? seasonalEventName(int month) {
    switch (month) {
      case 1:
      case 2:
        return '春节';
      case 6:
        return '618';
      case 10:
        return '国庆';
      case 11:
        return '双11';
      case 12:
        return '年末';
      default:
        return null;
    }
  }

  /// 获取过去 N 个月的月度支出列表 [最老→最新]
  static List<MonthlyExpenseData> getMonthlyHistory(
      List<Transaction> allTx, int months) {
    final now = DateTime.now();
    final result = <MonthlyExpenseData>[];
    for (int i = months - 1; i >= 0; i--) {
      final target = DateTime(now.year, now.month - i, 1);
      final y = target.year;
      final m = target.month;
      final total = allTx
          .where((t) =>
              t.type == TransactionType.expense &&
              t.date.year == y &&
              t.date.month == m)
          .fold<double>(0, (sum, t) => sum + t.amount);
      result.add(MonthlyExpenseData(year: y, month: m, total: total));
    }
    return result;
  }

  /// 加权移动平均预测月度支出
  static double weightedMonthlyPrediction(
      List<Transaction> allTx, int year, int month) {
    // 取过去6个月历史
    final history = getMonthlyHistory(allTx, 6);
    final values = history.map((h) => h.total).toList();

    // 数据不足时回退到日均推算
    if (values.length < 3 || values.every((v) => v == 0)) {
      final now = DateTime.now();
      if (year == now.year && month == now.month) {
        final spent = allTx
            .where((t) =>
                t.type == TransactionType.expense &&
                t.date.year == year &&
                t.date.month == month)
            .fold<double>(0, (sum, t) => sum + t.amount);
        final daysElapsed = now.day;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        return daysElapsed > 0 ? (spent / daysElapsed) * daysInMonth : 0;
      }
      return 0;
    }

    // SMA3 + WMA3 combined, same as TrendPredictionService
    final sma3 = _calculateSMA(values, 3);
    final wma3 = _calculateWMA(values, [0.5, 0.33, 0.17]);
    final factor = seasonalFactor(month);

    return (sma3 * 0.4 + wma3 * 0.6) * factor;
  }

  /// 计算置信区间上下界 (95%)
  static ({double lower, double upper}) confidenceBounds(
      List<Transaction> allTx, double predicted) {
    final history = getMonthlyHistory(allTx, 6);
    final values = history.map((h) => h.total).toList();
    final stdDev = _calculateStdDev(values);
    final lower = max(0.0, predicted - 1.96 * stdDev);
    final upper = predicted + 1.96 * stdDev;
    return (lower: lower, upper: upper);
  }

  /// 计算预测置信度 (0~1)
  static double predictionConfidence(List<Transaction> allTx) {
    final history = getMonthlyHistory(allTx, 12);
    final values = history.where((h) => h.total > 0).toList();
    if (values.length < 3) return 0.3;
    if (values.length < 6) return 0.5;

    final amounts = values.map((h) => h.total).toList();
    final mean = amounts.reduce((a, b) => a + b) / amounts.length;
    final stdDev = _calculateStdDev(amounts);
    final cv = mean > 0 ? stdDev / mean : 0;
    return (1 - cv).clamp(0.5, 0.95);
  }

  /// 分类级别月度预测（TOP N）
  static List<CategoryMonthlyPrediction> predictCategories(
      List<Transaction> allTx, int year, int month,
      {int topN = 5}) {
    final now = DateTime.now();

    // 获取本月已有支出的分类
    final currentMonthTx = allTx
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.year == year &&
            t.date.month == month)
        .toList();

    // 也考虑历史数据中的分类
    final allExpenseTx =
        allTx.where((t) => t.type == TransactionType.expense).toList();
    final allCategoryIds = <String>{};
    for (final t in currentMonthTx) {
      allCategoryIds.add(t.category);
    }
    // 补充过去3个月中出现的分类
    for (int i = 1; i <= 3; i++) {
      final target = DateTime(year, month - i, 1);
      for (final t in allExpenseTx) {
        if (t.date.year == target.year && t.date.month == target.month) {
          allCategoryIds.add(t.category);
        }
      }
    }

    final results = <CategoryMonthlyPrediction>[];
    for (final catId in allCategoryIds) {
      // 过去6个月该分类的月度支出
      final catHistory = <double>[];
      for (int i = 6; i >= 1; i--) {
        final target = DateTime(year, month - i, 1);
        final total = allExpenseTx
            .where((t) =>
                t.category == catId &&
                t.date.year == target.year &&
                t.date.month == target.month)
            .fold<double>(0, (sum, t) => sum + t.amount);
        catHistory.add(total);
      }

      // 上月支出
      final lastMonthTarget = DateTime(year, month - 1, 1);
      final lastMonth = allExpenseTx
          .where((t) =>
              t.category == catId &&
              t.date.year == lastMonthTarget.year &&
              t.date.month == lastMonthTarget.month)
          .fold<double>(0, (sum, t) => sum + t.amount);

      // 本月已支出
      final currentSpent = currentMonthTx
          .where((t) => t.category == catId)
          .fold<double>(0, (sum, t) => sum + t.amount);

      // WMA预测
      double predicted;
      final nonZero = catHistory.where((v) => v > 0).length;
      if (nonZero >= 2) {
        final wma = _calculateWMA(catHistory, [0.5, 0.33, 0.17]);
        predicted = wma * seasonalFactor(month);
      } else if (currentSpent > 0) {
        // 数据不足时日均推算
        final daysElapsed = (year == now.year && month == now.month)
            ? now.day
            : DateTime(year, month + 1, 0).day;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        predicted =
            daysElapsed > 0 ? (currentSpent / daysElapsed) * daysInMonth : 0;
      } else {
        predicted = lastMonth; // fallback to last month
      }

      if (predicted <= 0 && currentSpent <= 0) continue;

      // 趋势百分比
      double trendPercent = 0;
      if (lastMonth > 0) {
        trendPercent = ((predicted - lastMonth) / lastMonth * 100);
      }

      results.add(CategoryMonthlyPrediction(
        categoryId: catId,
        predicted: predicted,
        currentSpent: currentSpent,
        lastMonth: lastMonth,
        trendPercent: trendPercent,
      ));
    }

    // 按预测值降序，取 TOP N
    results.sort((a, b) => b.predicted.compareTo(a.predicted));
    return results.take(topN).toList();
  }

  // ====== 内部辅助 ======

  static double _calculateSMA(List<double> data, int period) {
    if (data.length < period) {
      return data.isEmpty ? 0 : data.last;
    }
    final recent = data.sublist(data.length - period);
    return recent.reduce((a, b) => a + b) / period;
  }

  static double _calculateWMA(List<double> data, List<double> weights) {
    final period = weights.length;
    if (data.length < period) {
      return data.isEmpty ? 0 : data.last;
    }
    final recent = data.sublist(data.length - period);
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += recent[i] * weights[period - 1 - i];
    }
    return sum;
  }

  static double _calculateStdDev(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }
}

/// 月度支出数据
class MonthlyExpenseData {
  final int year;
  final int month;
  final double total;

  const MonthlyExpenseData({
    required this.year,
    required this.month,
    required this.total,
  });
}

/// 分类月度预测
class CategoryMonthlyPrediction {
  final String categoryId;
  final double predicted;
  final double currentSpent;
  final double lastMonth;
  final double trendPercent;

  const CategoryMonthlyPrediction({
    required this.categoryId,
    required this.predicted,
    required this.currentSpent,
    required this.lastMonth,
    required this.trendPercent,
  });
}
