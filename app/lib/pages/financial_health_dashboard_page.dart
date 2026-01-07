import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 财务健康仪表盘页面
///
/// 对应原型设计 10.01 财务健康仪表盘
/// 展示用户的财务健康综合评分和5个维度分析
class FinancialHealthDashboardPage extends ConsumerWidget {
  const FinancialHealthDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('财务健康'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 总分展示
          _HealthScoreCard(
            score: 78,
            status: '财务良好',
            change: 5,
          ),

          // 5维度得分
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              '健康维度分析',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 钱龄得分
          _DimensionCard(
            icon: Icons.schedule,
            iconColor: const Color(0xFF6495ED),
            iconBgColor: const Color(0xFFEBF3FF),
            title: '钱龄',
            score: 16,
            maxScore: 20,
            status: '当前42天，良好状态',
            statusColor: Colors.green,
          ),

          // 预算控制
          _DimensionCard(
            icon: Icons.account_balance_wallet,
            iconColor: const Color(0xFFFFB74D),
            iconBgColor: const Color(0xFFFFF3E0),
            title: '预算控制',
            score: 14,
            maxScore: 20,
            status: '餐饮预算略有超支',
            statusColor: Colors.orange,
          ),

          // 应急金
          _DimensionCard(
            icon: Icons.shield,
            iconColor: const Color(0xFF66BB6A),
            iconBgColor: const Color(0xFFE8F5E9),
            title: '应急金',
            score: 18,
            maxScore: 20,
            status: '已覆盖3.6个月支出',
            statusColor: Colors.green,
          ),

          // 消费结构
          _DimensionCard(
            icon: Icons.pie_chart,
            iconColor: const Color(0xFF7B1FA2),
            iconBgColor: const Color(0xFFF3E5F5),
            title: '消费结构',
            score: 15,
            maxScore: 20,
            status: '必要支出占比68%',
            statusColor: Colors.green,
          ),

          // 记账习惯
          _DimensionCard(
            icon: Icons.local_fire_department,
            iconColor: const Color(0xFFEF5350),
            iconBgColor: const Color(0xFFFFEBEE),
            title: '记账习惯',
            score: 15,
            maxScore: 20,
            status: '连续记账23天',
            statusColor: Colors.green,
          ),

          // 改进建议
          _ImprovementSuggestionCard(
            title: '本月改进重点',
            suggestion: '餐饮预算控制是提升空间最大的维度，建议设置每周预算上限',
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('财务健康指数说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('财务健康指数由5个维度综合计算：'),
            SizedBox(height: 12),
            Text('• 钱龄：资金持有时间'),
            Text('• 预算控制：预算执行情况'),
            Text('• 应急金：紧急备用金储备'),
            Text('• 消费结构：必要vs非必要支出'),
            Text('• 记账习惯：记账频率和完整度'),
            SizedBox(height: 12),
            Text('每个维度满分20分，总分100分。'),
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

/// 健康分数卡片
class _HealthScoreCard extends StatelessWidget {
  final int score;
  final String status;
  final int change;

  const _HealthScoreCard({
    required this.score,
    required this.status,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (score >= 80) {
      bgColor = Colors.green;
    } else if (score >= 60) {
      bgColor = Colors.orange;
    } else {
      bgColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, bgColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            '财务健康指数',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                change >= 0 ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '较上月 ${change >= 0 ? '+' : ''}$change分',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 维度得分卡片
class _DimensionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final int score;
  final int maxScore;
  final String status;
  final Color statusColor;

  const _DimensionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = score / maxScore;

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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
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
                '$score/$maxScore',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                color: statusColor == Colors.green
                    ? Colors.grey[600]
                    : statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 改进建议卡片
class _ImprovementSuggestionCard extends StatelessWidget {
  final String title;
  final String suggestion;

  const _ImprovementSuggestionCard({
    required this.title,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
