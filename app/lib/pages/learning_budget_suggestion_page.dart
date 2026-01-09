import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 自学习预算建议页面
///
/// 对应原型设计 3.10 自学习预算建议
/// 展示AI根据历史消费习惯学习后的智能预算建议
class LearningBudgetSuggestionPage extends ConsumerWidget {
  const LearningBudgetSuggestionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智能预算建议'),
        actions: [
          Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI学习状态卡片
          _AILearningStatusCard(
            transactionCount: 1247,
            monthsAnalyzed: 6,
            accuracy: 0.92,
            totalSaved: 1820,
          ),

          const SizedBox(height: 16),

          // 本月预算建议标题
          const Text(
            '1月预算建议',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          // 餐饮建议
          _SuggestionCard(
            emoji: '🍽️',
            category: '餐饮',
            averageAmount: 2180,
            suggestedAmount: 2000,
            changePercent: -8,
            changeType: SuggestionChangeType.decrease,
            reason: '年后外卖支出通常减少，建议预算下调至¥2,000',
          ),

          // 交通建议
          _SuggestionCard(
            emoji: '🚗',
            category: '交通',
            averageAmount: 650,
            suggestedAmount: 800,
            changePercent: 23,
            changeType: SuggestionChangeType.increase,
            reason: '检测到1月有春节出行，建议预留更多交通预算',
          ),

          // 购物建议
          _SuggestionCard(
            emoji: '🛒',
            category: '购物',
            averageAmount: 1520,
            suggestedAmount: 1500,
            changePercent: 0,
            changeType: SuggestionChangeType.maintain,
            reason: '购物支出稳定，建议维持当前预算水平',
          ),

          const SizedBox(height: 16),

          // 采纳按钮
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已采纳全部建议')),
              );
            },
            icon: const Icon(Icons.thumb_up),
            label: const Text('采纳全部建议'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              '您也可以单独调整每项预算',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 学习反馈
          _FeedbackCard(),
        ],
      ),
    );
  }
}

/// AI学习状态卡片
class _AILearningStatusCard extends StatelessWidget {
  final int transactionCount;
  final int monthsAnalyzed;
  final double accuracy;
  final double totalSaved;

  const _AILearningStatusCard({
    required this.transactionCount,
    required this.monthsAnalyzed,
    required this.accuracy,
    required this.totalSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[50]!, Colors.indigo[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[400]!, Colors.indigo[600]!],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI已学习您的消费习惯',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '基于过去$monthsAnalyzed个月 · $transactionCount笔交易',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatItem(
                value: '${(accuracy * 100).toInt()}%',
                label: '预测准确率',
                color: Colors.indigo,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.indigo[200],
              ),
              _StatItem(
                value: '¥${totalSaved.toStringAsFixed(0)}',
                label: '累计节省',
                color: Colors.indigo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final MaterialColor color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: color[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// 建议卡片
class _SuggestionCard extends StatelessWidget {
  final String emoji;
  final String category;
  final double averageAmount;
  final double suggestedAmount;
  final int changePercent;
  final SuggestionChangeType changeType;
  final String reason;

  const _SuggestionCard({
    required this.emoji,
    required this.category,
    required this.averageAmount,
    required this.suggestedAmount,
    required this.changePercent,
    required this.changeType,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '近3月平均 ¥${averageAmount.toStringAsFixed(0)}',
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
                    '¥${suggestedAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: _getChangeColor(changeType),
                    ),
                  ),
                  _ChangeBadge(
                    percent: changePercent,
                    type: changeType,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getReasonIcon(changeType),
                  size: 16,
                  color: _getChangeColor(changeType),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getChangeColor(SuggestionChangeType type) {
    switch (type) {
      case SuggestionChangeType.decrease:
        return Colors.green[600]!;
      case SuggestionChangeType.increase:
        return Colors.orange[600]!;
      case SuggestionChangeType.maintain:
        return Colors.blue[600]!;
    }
  }

  IconData _getReasonIcon(SuggestionChangeType type) {
    switch (type) {
      case SuggestionChangeType.decrease:
      case SuggestionChangeType.increase:
        return Icons.lightbulb;
      case SuggestionChangeType.maintain:
        return Icons.check_circle;
    }
  }
}

class _ChangeBadge extends StatelessWidget {
  final int percent;
  final SuggestionChangeType type;

  const _ChangeBadge({
    required this.percent,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    switch (type) {
      case SuggestionChangeType.decrease:
        bgColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        text = '建议↓${percent.abs()}%';
        break;
      case SuggestionChangeType.increase:
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        text = '建议↑$percent%';
        break;
      case SuggestionChangeType.maintain:
        bgColor = Colors.blue[100]!;
        textColor = Colors.blue[700]!;
        text = '维持不变';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// 反馈卡片
class _FeedbackCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '建议是否准确？帮助AI更了解你',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Row(
            children: [
              _FeedbackButton(
                icon: Icons.thumb_up,
                color: Colors.green,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('感谢您的反馈！')),
                  );
                },
              ),
              const SizedBox(width: 8),
              _FeedbackButton(
                icon: Icons.thumb_down,
                color: Colors.red,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('我们会改进建议质量')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

enum SuggestionChangeType {
  decrease,
  increase,
  maintain,
}
