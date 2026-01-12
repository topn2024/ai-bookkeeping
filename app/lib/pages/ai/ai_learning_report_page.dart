import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../main_navigation.dart';
import '../../services/voice/self_learning_service.dart';

/// 智能学习报告页面
///
/// 对应原型设计 14.10 智能学习报告
/// 展示AI学习成果和关键指标
class AILearningReportPage extends ConsumerStatefulWidget {
  const AILearningReportPage({super.key});

  @override
  ConsumerState<AILearningReportPage> createState() =>
      _AILearningReportPageState();
}

class _AILearningReportPageState extends ConsumerState<AILearningReportPage> {
  final SelfLearningService _learningService = SelfLearningService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _learningService.initialize();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _learningService.metrics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习报告'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 返回首页而不是简单的pop
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainNavigation()),
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final accuracy = (metrics.accuracy * 100).toStringAsFixed(1);
              final ruleCount = metrics.ruleCount;
              final sampleCount = metrics.totalSamples;
              SharePlus.instance.share(
                ShareParams(
                  text: 'AI学习报告\n'
                      '识别准确率: $accuracy%\n'
                      '学习规则数: $ruleCount\n'
                      '累计学习样本: $sampleCount\n'
                      '分享自AI记账',
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 学习成就头部
                _AchievementHeader(),

                // 关键指标
                _KeyMetricsSection(metrics: metrics),

                // 学习里程碑
                _MilestonesSection(metrics: metrics),

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
    // 使用当前日期
    final now = DateTime.now();
    final dateStr = '${now.year}年${now.month}月';

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
            dateStr,
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
  final LearningMetrics metrics;

  const _KeyMetricsSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    // 使用真实数据
    final accuracyStr = metrics.totalSamples > 0
        ? '${(metrics.accuracy * 100).toStringAsFixed(1)}%'
        : '-';
    final ruleCountStr = '${metrics.ruleCount}';
    final ruleMatchRateStr = metrics.totalSamples > 0
        ? '${(metrics.ruleMatchRate * 100).toStringAsFixed(0)}%'
        : '-';
    final sampleCountStr = '${metrics.totalSamples}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  value: accuracyStr,
                  label: '识别准确率',
                  trend: metrics.totalSamples > 0
                      ? '基于${metrics.confirmedCount}次确认'
                      : '暂无数据',
                  trendColor: metrics.totalSamples > 0 ? Colors.green : Colors.grey,
                  valueColor: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: ruleCountStr,
                  label: '学习规则数',
                  trend: metrics.ruleCount > 0 ? '自动学习生成' : '等待学习',
                  trendColor: metrics.ruleCount > 0 ? Colors.green : Colors.grey,
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
                  value: ruleMatchRateStr,
                  label: '规则命中率',
                  trend: metrics.totalSamples > 0 ? '本地规则匹配' : '暂无数据',
                  trendColor: metrics.totalSamples > 0 ? Colors.green : Colors.grey,
                  valueColor: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  value: sampleCountStr,
                  label: '累计学习样本',
                  trend: metrics.totalSamples > 0 ? '持续增长中' : '开始使用积累',
                  trendColor: metrics.totalSamples > 0 ? Colors.green : Colors.grey,
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
  final LearningMetrics metrics;

  const _MilestonesSection({required this.metrics});

  @override
  Widget build(BuildContext context) {
    // 根据真实数据生成里程碑
    final milestones = _generateMilestones(metrics);

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
            child: milestones.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        '开始使用语音记账，解锁学习里程碑',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: milestones,
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _generateMilestones(LearningMetrics metrics) {
    final milestones = <Widget>[];

    // 根据真实数据判断里程碑完成情况

    // 里程碑1: 首次确认
    if (metrics.confirmedCount >= 1) {
      milestones.add(_MilestoneItem(
        title: '完成首次语音确认',
        date: '已达成',
        isCompleted: true,
        showDivider: true,
      ));
    }

    // 里程碑2: 10次学习样本
    final sample10Completed = metrics.totalSamples >= 10;
    milestones.add(_MilestoneItem(
      title: '累计10次学习样本',
      date: sample10Completed
          ? '已达成'
          : '进度: ${metrics.totalSamples}/10',
      isCompleted: sample10Completed,
      showDivider: true,
    ));

    // 里程碑3: 生成首条规则
    final firstRuleCompleted = metrics.ruleCount >= 1;
    milestones.add(_MilestoneItem(
      title: '生成首条学习规则',
      date: firstRuleCompleted ? '已达成' : '等待触发',
      isCompleted: firstRuleCompleted,
      showDivider: true,
    ));

    // 里程碑4: 准确率达到80%
    final accuracy80Completed =
        metrics.totalSamples >= 10 && metrics.accuracy >= 0.8;
    milestones.add(_MilestoneItem(
      title: '识别准确率达到80%',
      date: accuracy80Completed
          ? '已达成'
          : metrics.totalSamples >= 10
              ? '当前: ${(metrics.accuracy * 100).toStringAsFixed(0)}%'
              : '需要更多样本',
      isCompleted: accuracy80Completed,
      showDivider: true,
    ));

    // 里程碑5: 累计50个规则
    final rule50Completed = metrics.ruleCount >= 50;
    milestones.add(_MilestoneItem(
      title: '累计50条学习规则',
      date: rule50Completed
          ? '已达成'
          : '进度: ${metrics.ruleCount}/50',
      isCompleted: rule50Completed,
      showDivider: false,
    ));

    return milestones;
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
