import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../pages/smart_feature_recommendation_page.dart';

/// 功能推荐服务
class FeatureRecommendationService {
  /// 生成功能推荐列表
  List<FeatureRecommendation> generateRecommendations({
    required List<Transaction> transactions,
    required bool hasBudget,
    required bool hasMoneyAge,
    required bool hasSavingsGoal,
  }) {
    final recommendations = <FeatureRecommendation>[];
    final now = DateTime.now();

    // 计算连续记账天数
    final consecutiveDays = _calculateConsecutiveDays(transactions);

    // 场景1: 连续记账7天且未启用预算 → 推荐预算功能
    if (consecutiveDays >= 7 && !hasBudget) {
      recommendations.add(FeatureRecommendation(
        id: 'budget',
        title: '预算功能',
        description: '你已经连续记账${consecutiveDays}天啦！试试设置预算，让我帮你更好地控制开支？每月花多少、哪里花得多，一目了然。',
        trigger: '连续记账${consecutiveDays}天',
        icon: Icons.pie_chart,
        color: const Color(0xFF4CAF50),
        previews: [
          FeaturePreview(label: '月度预算', value: '自定义'),
          FeaturePreview(label: '分类预算', value: '多个'),
          FeaturePreview(label: '超支提醒', value: '智能'),
        ],
      ));
    }

    // 场景2: 餐饮支出占比高 → 推荐分类预算
    final foodRatio = _calculateCategoryRatio(transactions, '餐饮');
    if (foodRatio > 0.4 && !hasBudget) {
      recommendations.add(FeatureRecommendation(
        id: 'category_budget',
        title: '分类预算',
        description: '本月餐饮支出占比${(foodRatio * 100).toStringAsFixed(0)}%，高于平均水平。开启分类预算，更精细地管理开支？',
        trigger: '餐饮支出占比高',
        icon: Icons.restaurant,
        color: const Color(0xFFFF9800),
        previews: [
          FeaturePreview(label: '餐饮预算', value: '单独设置'),
          FeaturePreview(label: '超支提醒', value: '及时'),
          FeaturePreview(label: '趋势分析', value: '可视化'),
        ],
      ));
    }

    // 场景3: 有规律消费且未启用钱龄 → 推荐钱龄追踪
    final monthTransactions = transactions.where((t) =>
      t.date.year == now.year && t.date.month == now.month
    ).length;

    if (monthTransactions >= 10 && !hasMoneyAge) {
      recommendations.add(FeatureRecommendation(
        id: 'money_age',
        title: '钱龄追踪',
        description: '看起来你的消费习惯很规律！试试钱龄功能，看看你的钱平均能存多久？',
        trigger: '消费规律',
        icon: Icons.schedule,
        color: const Color(0xFF2196F3),
        previews: [
          FeaturePreview(label: '钱龄分析', value: '实时'),
          FeaturePreview(label: '健康等级', value: '评估'),
          FeaturePreview(label: '趋势图表', value: '可视化'),
        ],
      ));
    }

    // 场景4: 有收入记录且未设置储蓄目标 → 推荐储蓄目标
    final incomeCount = transactions.where((t) =>
      t.type == TransactionType.income &&
      t.date.isAfter(now.subtract(const Duration(days: 60)))
    ).length;

    if (incomeCount >= 2 && !hasSavingsGoal) {
      recommendations.add(FeatureRecommendation(
        id: 'savings_goal',
        title: '储蓄目标',
        description: '你的收入稳定，可以尝试设置储蓄目标，让我帮你规划存钱计划！',
        trigger: '收入稳定',
        icon: Icons.savings,
        color: const Color(0xFF9C27B0),
        previews: [
          FeaturePreview(label: '月存金额', value: '自定义'),
          FeaturePreview(label: '年度目标', value: '规划'),
          FeaturePreview(label: '进度追踪', value: '可视化'),
        ],
      ));
    }

    return recommendations;
  }

  /// 计算连续记账天数
  int _calculateConsecutiveDays(List<Transaction> transactions) {
    if (transactions.isEmpty) return 0;

    final sortedDates = transactions
        .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int consecutive = 0;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (int i = 0; i < sortedDates.length; i++) {
      final expectedDate = todayDate.subtract(Duration(days: i));
      if (sortedDates[i].isAtSameMomentAs(expectedDate)) {
        consecutive++;
      } else {
        break;
      }
    }

    return consecutive;
  }

  /// 计算某分类支出占比
  double _calculateCategoryRatio(List<Transaction> transactions, String category) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final monthExpenses = transactions.where((t) =>
      t.type == TransactionType.expense &&
      t.date.isAfter(monthStart.subtract(const Duration(days: 1)))
    ).toList();

    if (monthExpenses.isEmpty) return 0;

    final totalExpense = monthExpenses.fold(0.0, (sum, t) => sum + t.amount);
    final categoryExpense = monthExpenses
        .where((t) => t.category == category)
        .fold(0.0, (sum, t) => sum + t.amount);

    return totalExpense > 0 ? categoryExpense / totalExpense : 0;
  }
}
