import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'category_detail_page.dart';

/// 拿铁因子分析页面
///
/// 对应原型设计 10.03 拿铁因子分析
/// 分析用户高频小额消费（<¥50）的累计影响
class LatteFactorPage extends ConsumerWidget {
  const LatteFactorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionProvider);

    // 筛选本月小额消费（<50元）
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final smallExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.amount < 50 &&
        t.date.isAfter(monthStart.subtract(const Duration(days: 1)))).toList();

    // 按分类统计
    final categoryTotals = <String, _CategoryStats>{};
    for (final t in smallExpenses) {
      final stats = categoryTotals.putIfAbsent(
        t.category,
        () => _CategoryStats(category: t.category),
      );
      stats.count++;
      stats.total += t.amount;
    }

    // 计算周数
    final daysInMonth = now.day;
    final weeks = (daysInMonth / 7).ceil();

    // 转换为显示数据
    final topCategories = categoryTotals.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final maxTotal = topCategories.isNotEmpty ? topCategories.first.total : 1.0;

    final displayCategories = topCategories.take(3).map((stats) {
      final category = DefaultCategories.expenseCategories
          .where((c) => c.id == stats.category)
          .firstOrNull;
      final weeklyCount = weeks > 0 ? (stats.count / weeks).round() : stats.count;
      final avgAmount = stats.count > 0 ? stats.total / stats.count : 0.0;
      return LatteFactorCategory(
        categoryId: stats.category,
        emoji: _getCategoryEmoji(stats.category),
        name: category?.name ?? stats.category,
        weeklyCount: weeklyCount,
        averageAmount: avgAmount,
        monthlyTotal: stats.total,
        yearlyTotal: stats.total * 12,
        progress: stats.total / maxTotal,
        color: category?.color ?? Colors.grey,
      );
    }).toList();

    final monthlyTotal = smallExpenses.fold(0.0, (sum, t) => sum + t.amount);
    final weeklyTotal = weeks > 0 ? monthlyTotal / weeks : monthlyTotal;
    final yearlyTotal = monthlyTotal * 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('小额消费洞察'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // 总结卡片
                _SummaryCard(
                  weeklyTotal: weeklyTotal,
                  monthlyTotal: monthlyTotal,
                  yearlyTotal: yearlyTotal,
                ),

                // 洞察建议
                if (displayCategories.isNotEmpty)
                  _InsightCard(
                    category: displayCategories.first.name,
                    suggestion: '减少高频小额消费可节省更多',
                    yearlySaving: (displayCategories.first.yearlyTotal * 0.4).round().toDouble(),
                  ),

                // 高频消费TOP3
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: Text(
                    '高频消费TOP3',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                if (displayCategories.isEmpty)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('暂无小额消费数据', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...displayCategories.map((c) => GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryDetailPage(
                          categoryId: c.categoryId,
                          isExpense: true,
                        ),
                      ),
                    ),
                    child: _CategoryCard(category: c),
                  )),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // 底部按钮
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: displayCategories.isNotEmpty
                    ? () => _showSavingGoalDialog(context, displayCategories)
                    : null,
                icon: const Icon(Icons.savings),
                label: const Text('设置节约目标'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('什么是拿铁因子？'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"拿铁因子"是指日常生活中频繁出现的小额消费，如咖啡、奶茶、零食等。'),
            SizedBox(height: 12),
            Text('单笔看起来不起眼，但长期累积却是一笔不小的支出。'),
            SizedBox(height: 12),
            Text('减少这些小额消费，可以帮助您积累更多的储蓄。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showSavingGoalDialog(BuildContext context, List<LatteFactorCategory> categories) {
    if (categories.isEmpty) return;

    final topCategory = categories.first;
    final suggestedReduction = (topCategory.weeklyCount * 0.3).ceil().clamp(1, topCategory.weeklyCount);
    final monthlySaving = (topCategory.averageAmount * suggestedReduction * 4).round();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置节约目标'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('基于您的消费习惯，建议：'),
            const SizedBox(height: 16),
            ...categories.take(3).map((cat) {
              final reduction = (cat.weeklyCount * 0.3).ceil().clamp(1, cat.weeklyCount);
              final saving = (cat.averageAmount * reduction * 4).round();
              return ListTile(
                leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                title: Text('${cat.name}：每周减少$reduction次'),
                subtitle: Text('预计每月节省 ¥$saving'),
                trailing: cat == topCategory
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[400]),
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已设置目标：每周减少${topCategory.name}$suggestedReduction次，预计每月节省¥$monthlySaving')),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 总结卡片
class _SummaryCard extends StatelessWidget {
  final double weeklyTotal;
  final double monthlyTotal;
  final double yearlyTotal;

  const _SummaryCard({
    required this.weeklyTotal,
    required this.monthlyTotal,
    required this.yearlyTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.orange[300]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_cafe, color: Colors.white),
              SizedBox(width: 8),
              Text(
                '拿铁因子分析',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '每周高频小额消费（<¥50）累计',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '¥${weeklyTotal.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '相当于每月 ¥${monthlyTotal.toStringAsFixed(0)} · 每年 ¥${yearlyTotal.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// 洞察建议卡片
class _InsightCard extends StatelessWidget {
  final String category;
  final String suggestion;
  final double yearlySaving;

  const _InsightCard({
    required this.category,
    required this.suggestion,
    required this.yearlySaving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: '如果将'),
                  TextSpan(
                    text: category,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: suggestion),
                  const TextSpan(text: '，每年可以多存 '),
                  TextSpan(
                    text: '¥${yearlySaving.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 消费类别卡片
class _CategoryCard extends StatelessWidget {
  final LatteFactorCategory category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '每周约${category.weeklyCount}次 · 平均¥${category.averageAmount}/次',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${category.monthlyTotal.toStringAsFixed(0)}/月',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: category.progress >= 0.8 ? Colors.orange : null,
                    ),
                  ),
                  Text(
                    '年¥${category.yearlyTotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: category.progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(category.color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 拿铁因子类别数据模型
class LatteFactorCategory {
  final String categoryId;
  final String emoji;
  final String name;
  final int weeklyCount;
  final double averageAmount;
  final double monthlyTotal;
  final double yearlyTotal;
  final double progress;
  final Color color;

  LatteFactorCategory({
    required this.categoryId,
    required this.emoji,
    required this.name,
    required this.weeklyCount,
    required this.averageAmount,
    required this.monthlyTotal,
    required this.yearlyTotal,
    required this.progress,
    required this.color,
  });
}

/// 分类统计辅助类
class _CategoryStats {
  final String category;
  int count = 0;
  double total = 0.0;

  _CategoryStats({required this.category});
}

/// 根据分类ID获取emoji
String _getCategoryEmoji(String categoryId) {
  const emojiMap = {
    'food': '🍚',
    'transport': '🚇',
    'shopping': '🛍️',
    'entertainment': '🎮',
    'coffee': '☕',
    'drinks': '🥤',
    'snacks': '🍿',
  };
  return emojiMap[categoryId] ?? '📦';
}
