import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 同类用户对比页面
///
/// 对应原型设计 10.12 同类用户对比
/// 与相似背景用户进行匿名消费对比
class PeerComparisonPage extends ConsumerWidget {
  const PeerComparisonPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('同类用户对比'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 用户画像卡片
          _UserProfileCard(),

          // 总体对比
          _OverallComparisonCard(
            mySpending: 12700,
            peerAverage: 11500,
          ),

          // 分类对比
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '分类消费对比',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          _CategoryComparisonCard(
            category: '餐饮',
            emoji: '🍽️',
            myAmount: 2800,
            peerAmount: 2200,
          ),
          _CategoryComparisonCard(
            category: '购物',
            emoji: '🛍️',
            myAmount: 1500,
            peerAmount: 1800,
          ),
          _CategoryComparisonCard(
            category: '交通',
            emoji: '🚗',
            myAmount: 800,
            peerAmount: 750,
          ),
          _CategoryComparisonCard(
            category: '娱乐',
            emoji: '🎮',
            myAmount: 600,
            peerAmount: 900,
          ),

          // 财务习惯对比
          _HabitComparisonSection(),

          // 提升建议
          _SuggestionCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于同类对比'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('我们根据以下条件匹配相似用户：'),
            SizedBox(height: 12),
            Text('• 年龄段相近'),
            Text('• 所在城市级别相同'),
            Text('• 收入水平相近'),
            SizedBox(height: 12),
            Text('所有数据均为匿名统计，保护用户隐私。'),
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

/// 用户画像卡片
class _UserProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people, color: Colors.blue),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '您的对比群体',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _ProfileChip(label: '25-30岁'),
                    _ProfileChip(label: '一线城市'),
                    _ProfileChip(label: '中等收入'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;

  const _ProfileChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue[700],
        ),
      ),
    );
  }
}

/// 总体对比卡片
class _OverallComparisonCard extends StatelessWidget {
  final double mySpending;
  final double peerAverage;

  const _OverallComparisonCard({
    required this.mySpending,
    required this.peerAverage,
  });

  @override
  Widget build(BuildContext context) {
    final diff = mySpending - peerAverage;
    final diffPercent = (diff / peerAverage * 100).abs();
    final isHigher = diff > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            '本月消费对比',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      '我的消费',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${mySpending.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHigher ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHigher ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: isHigher ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${diffPercent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isHigher ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      '同类平均',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${peerAverage.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isHigher
                ? '您的消费比同类用户高 ${diffPercent.toStringAsFixed(0)}%'
                : '您的消费比同类用户低 ${diffPercent.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 13,
              color: isHigher ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类对比卡片
class _CategoryComparisonCard extends StatelessWidget {
  final String category;
  final String emoji;
  final double myAmount;
  final double peerAmount;

  const _CategoryComparisonCard({
    required this.category,
    required this.emoji,
    required this.myAmount,
    required this.peerAmount,
  });

  @override
  Widget build(BuildContext context) {
    final maxAmount = (myAmount > peerAmount ? myAmount : peerAmount) * 1.2;
    final myProgress = myAmount / maxAmount;
    final peerProgress = peerAmount / maxAmount;
    final isHigher = myAmount > peerAmount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isHigher)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '偏高',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 我的消费
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  '我',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: myProgress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '¥${myAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 同类平均
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  '同类',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: peerProgress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  '¥${peerAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 财务习惯对比
class _HabitComparisonSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '财务习惯对比',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _HabitCard(
                icon: Icons.schedule,
                label: '钱龄',
                myValue: '42天',
                peerValue: '35天',
                isBetter: true,
              ),
              const SizedBox(width: 8),
              _HabitCard(
                icon: Icons.savings,
                label: '储蓄率',
                myValue: '15%',
                peerValue: '18%',
                isBetter: false,
              ),
              const SizedBox(width: 8),
              _HabitCard(
                icon: Icons.local_fire_department,
                label: '连续记账',
                myValue: '23天',
                peerValue: '15天',
                isBetter: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String myValue;
  final String peerValue;
  final bool isBetter;

  const _HabitCard({
    required this.icon,
    required this.label,
    required this.myValue,
    required this.peerValue,
    required this.isBetter,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isBetter ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isBetter ? Colors.green : Colors.grey, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              myValue,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isBetter ? Colors.green : Colors.black,
              ),
            ),
            Text(
              '同类 $peerValue',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 建议卡片
class _SuggestionCard extends StatelessWidget {
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
          Text(
            '• 餐饮支出偏高，建议增加自己做饭的频率\n'
            '• 储蓄率低于同类平均，可以考虑设置自动存款',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
