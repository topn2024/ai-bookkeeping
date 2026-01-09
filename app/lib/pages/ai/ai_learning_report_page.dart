import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// 智能学习报告页面
///
/// 对应原型设计 14.10 智能学习报告
/// 展示AI学习成果和关键指标
class AILearningReportPage extends ConsumerWidget {
  const AILearningReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习报告'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(
                'AI学习报告\n'
                '本月识别准确率: 95%\n'
                '累计学习次数: 1,234次\n'
                '分享自AI记账',
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // 学习成就头部
          _AchievementHeader(),

          // 关键指标
          _KeyMetricsSection(),

          // 学习里程碑
          _MilestonesSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 成就头部
class _AchievementHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.deepOrange[300]!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'AI学习报告',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '2024年12月',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关键指标区域
class _KeyMetricsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: '94.6%',
                  label: '分类准确率',
                  trend: '↑12% 较首月',
                  trendColor: Colors.green,
                  valueColor: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '156',
                  label: '学习规则数',
                  trend: '+23 本月新增',
                  trendColor: Colors.green,
                  valueColor: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: '72%',
                  label: '商户命中率',
                  trend: '↑8% 较上月',
                  trendColor: Colors.green,
                  valueColor: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: '¥5.2',
                  label: '累计节省成本',
                  trend: '通过本地优先',
                  trendColor: Colors.green,
                  valueColor: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final String trend;
  final Color trendColor;
  final Color valueColor;

  const _MetricCard({
    required this.value,
    required this.label,
    required this.trend,
    required this.trendColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            trend,
            style: TextStyle(
              fontSize: 11,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 学习里程碑区域
class _MilestonesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '学习里程碑',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
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
                _MilestoneItem(
                  title: '商户库突破100个',
                  date: '12月15日达成',
                  isCompleted: true,
                  showDivider: true,
                ),
                _MilestoneItem(
                  title: '准确率突破90%',
                  date: '12月8日达成',
                  isCompleted: true,
                  showDivider: true,
                ),
                _MilestoneItem(
                  title: '连续30天零云端调用日',
                  date: '进行中...',
                  isCompleted: false,
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final String title;
  final String date;
  final bool isCompleted;
  final bool showDivider;

  const _MilestoneItem({
    required this.title,
    required this.date,
    required this.isCompleted,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green[50] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.hourglass_top,
                  size: 18,
                  color: isCompleted ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }
}
