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
}
