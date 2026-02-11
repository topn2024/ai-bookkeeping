import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_provider.dart';
import '../models/category.dart';
import '../extensions/category_extensions.dart';

/// 必要支出分类ID列表
const _needsCategoryIds = {
  'food', 'transport', 'housing', 'medical', 'communication', 'education',
  'utilities', 'insurance', 'childcare',
};

/// 消费分类洞察页面（想要vs需要）
///
/// 对应原型设计 10.08 消费分类洞察
/// 分析用户消费中"想要"和"需要"的占比
class WantsNeedsInsightPage extends ConsumerWidget {
  const WantsNeedsInsightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseByCategory = ref.watch(monthlyExpenseByCategoryProvider);

    // 分类为需要和想要
    double needsAmount = 0.0;
    double wantsAmount = 0.0;
    final needsItems = <_CategoryItem>[];
    final wantsItems = <_CategoryItem>[];

    for (final entry in expenseByCategory.entries) {
      final categoryId = entry.key;
      final amount = entry.value;
      final category = DefaultCategories.allCategories
          .where((c) => c.id == categoryId)
          .firstOrNull;
      final emoji = _getCategoryEmoji(categoryId);
      final name = category?.localizedName ?? categoryId;

      if (_needsCategoryIds.contains(categoryId)) {
        needsAmount += amount;
        needsItems.add(_CategoryItem(name: name, amount: amount, emoji: emoji));
      } else {
        wantsAmount += amount;
        wantsItems.add(_CategoryItem(name: name, amount: amount, emoji: emoji));
      }
    }

    final totalAmount = needsAmount + wantsAmount;
    final needsRatio = totalAmount > 0 ? needsAmount / totalAmount : 0.5;

    return Scaffold(
      appBar: AppBar(
        title: const Text('消费分类洞察'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 总览卡片
          _OverviewCard(
            needsAmount: needsAmount,
            wantsAmount: wantsAmount,
            needsRatio: needsRatio,
          ),

          // 健康度评估
          _HealthAssessmentCard(needsRatio: needsRatio),

          // 需要消费明细
          if (needsItems.isNotEmpty)
            _CategorySection(
              title: '需要（必要支出）',
              emoji: '✅',
              amount: needsAmount,
              color: Colors.green,
              items: needsItems,
            ),

          // 想要消费明细
          if (wantsItems.isNotEmpty)
            _CategorySection(
              title: '想要（非必要支出）',
              emoji: '💭',
              amount: wantsAmount,
              color: Colors.orange,
              items: wantsItems,
            ),

          // 无数据提示
          if (needsItems.isEmpty && wantsItems.isEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('暂无本月消费数据', style: TextStyle(color: Colors.grey)),
              ),
            ),

          // 优化建议
          _OptimizationSuggestionCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('想要 vs 需要'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('需要（Needs）：'),
            Text('维持基本生活必须的支出，如房租、食物、交通等。'),
            SizedBox(height: 12),
            Text('想要（Wants）：'),
            Text('改善生活品质但非必须的支出，如娱乐、购物等。'),
            SizedBox(height: 12),
            Text('建议比例：'),
            Text('需要占比 50-70% 为健康水平。'),
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
}

/// 总览卡片
class _OverviewCard extends StatelessWidget {
  final double needsAmount;
  final double wantsAmount;
  final double needsRatio;

  const _OverviewCard({
    required this.needsAmount,
    required this.wantsAmount,
    required this.needsRatio,
  });

  @override
  Widget build(BuildContext context) {
    final wantsRatio = 1 - needsRatio;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '本月消费结构',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),

          // 环形图（简化版）
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: needsRatio,
                    strokeWidth: 16,
                    backgroundColor: Colors.orange[200],
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green[400]!),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¥${(needsAmount + wantsAmount).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '总支出',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(
                color: Colors.green[400]!,
                label: '需要',
                value: '${(needsRatio * 100).toStringAsFixed(0)}%',
                amount: needsAmount,
              ),
              const SizedBox(width: 32),
              _LegendItem(
                color: Colors.orange[400]!,
                label: '想要',
                value: '${(wantsRatio * 100).toStringAsFixed(0)}%',
                amount: wantsAmount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final double amount;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          '¥${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// 健康度评估卡片
class _HealthAssessmentCard extends StatelessWidget {
  final double needsRatio;

  const _HealthAssessmentCard({required this.needsRatio});

  @override
  Widget build(BuildContext context) {
    final isHealthy = needsRatio >= 0.5 && needsRatio <= 0.7;
    final message = isHealthy
        ? '您的消费结构健康，需要支出占比合理'
        : needsRatio > 0.7
            ? '需要支出占比偏高，可以适当增加生活品质消费'
            : '想要支出占比偏高，建议适当控制非必要消费';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHealthy ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.info,
            color: isHealthy ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: isHealthy ? Colors.green[800] : Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类明细区域
class _CategorySection extends StatelessWidget {
  final String title;
  final String emoji;
  final double amount;
  final Color color;
  final List<_CategoryItem> items;

  const _CategorySection({
    required this.title,
    required this.emoji,
    required this.amount,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '¥${amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _CategoryItemTile(item: item, color: color)),
        ],
      ),
    );
  }
}

class _CategoryItem {
  final String name;
  final double amount;
  final String emoji;

  _CategoryItem({
    required this.name,
    required this.amount,
    required this.emoji,
  });
}

class _CategoryItemTile extends StatelessWidget {
  final _CategoryItem item;
  final Color color;

  const _CategoryItemTile({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            '¥${item.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 优化建议卡片
class _OptimizationSuggestionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                '优化建议',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SuggestionItem(text: '咖啡奶茶支出较高，可考虑自己冲泡'),
          _SuggestionItem(text: '外出聚餐频繁，可适当增加家庭烹饪'),
          _SuggestionItem(text: '部分订阅服务使用率低，建议评估取消'),
        ],
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final String text;

  const _SuggestionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 根据分类ID获取emoji
String _getCategoryEmoji(String categoryId) {
  const emojiMap = {
    'food': '🍚',
    'transport': '🚇',
    'shopping': '🛍️',
    'entertainment': '🎮',
    'housing': '🏠',
    'medical': '💊',
    'communication': '📱',
    'education': '📚',
    'utilities': '💡',
    'insurance': '🛡️',
    'childcare': '👶',
    'travel': '✈️',
    'beauty': '💄',
    'social': '🍽️',
    'pets': '🐾',
    'gifts': '🎁',
    'subscription': '📺',
  };
  return emojiMap[categoryId] ?? '📦';
}
