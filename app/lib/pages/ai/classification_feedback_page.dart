import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 分类反馈学习页面
///
/// 对应原型设计 14.02 分类反馈学习
/// 展示用户修正记录和学习闭环流程
class ClassificationFeedbackPage extends ConsumerWidget {
  const ClassificationFeedbackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类学习'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 学习闭环说明
          _LearningLoopCard(),

          // 最近修正记录
          _RecentCorrectionsSection(),

          // 学习统计
          _LearningStatsSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('反馈学习机制'),
        content: const Text(
          '当您修正AI的分类结果时，系统会自动学习您的偏好，'
          '并将规则沉淀到本地，下次遇到相似交易时就能准确分类。\n\n'
          '您的每一次修正都在帮助AI变得更聪明！',
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

/// 学习闭环卡片
class _LearningLoopCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text(
                '反馈学习闭环',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LoopStep(
                icon: Icons.edit,
                label: '用户修正',
                color: Theme.of(context).primaryColor,
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
              _LoopStep(
                icon: Icons.rule,
                label: '规则沉淀',
                color: Colors.green,
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
              _LoopStep(
                icon: Icons.trending_up,
                label: '准确提升',
                color: Colors.orange,
              ),
              Icon(Icons.arrow_forward, color: Colors.grey[400], size: 16),
              _LoopStep(
                icon: Icons.savings,
                label: '成本降低',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopStep extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LoopStep({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// 最近修正记录
class _RecentCorrectionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final corrections = [
      _CorrectionData(
        emoji: '🍜',
        merchant: '沙县小吃',
        time: '今天 12:30',
        amount: 18,
        fromCategory: '购物',
        toCategory: '餐饮',
        status: CorrectionStatus.learned,
      ),
      _CorrectionData(
        emoji: '🚗',
        merchant: '滴滴出行',
        time: '昨天 18:45',
        amount: 32,
        fromCategory: '生活服务',
        toCategory: '交通',
        status: CorrectionStatus.learned,
      ),
      _CorrectionData(
        emoji: '📦',
        merchant: '京东自营',
        time: '3天前',
        amount: 299,
        fromCategory: '日用品',
        toCategory: '数码',
        status: CorrectionStatus.learning,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近修正记录',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...corrections.map((c) => _CorrectionItem(data: c)),
        ],
      ),
    );
  }
}

enum CorrectionStatus { learned, learning }

class _CorrectionData {
  final String emoji;
  final String merchant;
  final String time;
  final double amount;
  final String fromCategory;
  final String toCategory;
  final CorrectionStatus status;

  _CorrectionData({
    required this.emoji,
    required this.merchant,
    required this.time,
    required this.amount,
    required this.fromCategory,
    required this.toCategory,
    required this.status,
  });
}

class _CorrectionItem extends StatelessWidget {
  final _CorrectionData data;

  const _CorrectionItem({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              Text(data.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.merchant,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      data.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '¥${data.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  data.fromCategory,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[400],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  data.toCategory,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  data.status == CorrectionStatus.learned ? '已学习' : '学习中',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  data.status == CorrectionStatus.learned
                      ? Icons.check_circle
                      : Icons.hourglass_top,
                  size: 16,
                  color: data.status == CorrectionStatus.learned
                      ? Colors.green
                      : Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 学习统计
class _LearningStatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '156',
              label: '累计学习',
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '89%',
              label: '规则沉淀率',
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '+12%',
              label: '准确率提升',
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
