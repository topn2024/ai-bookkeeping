import 'package:flutter/material.dart';

import '../../services/learning/unified_self_learning_service.dart';

/// 学习效果仪表盘
class LearningDashboard extends StatefulWidget {
  const LearningDashboard({super.key});

  @override
  State<LearningDashboard> createState() => _LearningDashboardState();
}

class _LearningDashboardState extends State<LearningDashboard> {
  LearningEffectReport? _report;
  Map<String, LearningStatus>? _moduleStatuses;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = UnifiedSelfLearningService();
      final report = await service.getOverallReport();
      final statuses = await service.getAllModuleStatus();

      setState(() {
        _report = report;
        _moduleStatuses = statuses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildModuleList(),
            const SizedBox(height: 16),
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final report = _report;
    if (report == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '学习效果总览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.trending_up,
                    label: '整体准确率',
                    value: '${(report.overallAccuracy * 100).toStringAsFixed(1)}%',
                    color: _getAccuracyColor(report.overallAccuracy),
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.rule,
                    label: '学习规则数',
                    value: '${report.totalRules}',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.data_usage,
                    label: '样本总数',
                    value: '${report.totalSamples}',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: report.overallAccuracy,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getAccuracyColor(report.overallAccuracy),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getAccuracyDescription(report.overallAccuracy),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildModuleList() {
    final statuses = _moduleStatuses;
    final report = _report;
    if (statuses == null || report == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.widgets, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '模块状态',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...statuses.entries.map((entry) => _buildModuleItem(
                  entry.key,
                  entry.value,
                  report.moduleMetrics[entry.key],
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleItem(
    String moduleId,
    LearningStatus status,
    LearningMetrics? metrics,
  ) {
    final stageName = _getStageName(status.stage);
    final stageColor = _getStageColor(status.stage);
    final accuracy = metrics?.accuracy ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _getModuleName(moduleId),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  stageName,
                  style: TextStyle(
                    fontSize: 12,
                    color: stageColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildModuleStat('准确率', '${(accuracy * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 16),
              _buildModuleStat('规则数', '${metrics?.totalRules ?? 0}'),
              const SizedBox(width: 16),
              _buildModuleStat('待处理', '${status.pendingSamples}'),
            ],
          ),
          if (status.lastTrainingTime != null) ...[
            const SizedBox(height: 4),
            Text(
              '上次训练: ${_formatTime(status.lastTrainingTime!)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleStat(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  '操作',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _triggerTraining,
                  icon: const Icon(Icons.model_training, size: 18),
                  label: const Text('立即训练'),
                ),
                OutlinedButton.icon(
                  onPressed: _exportModels,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('导出模型'),
                ),
                OutlinedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('刷新'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerTraining() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认训练'),
        content: const Text('立即触发所有模块的训练任务？这可能需要一些时间。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final service = UnifiedSelfLearningService();
      final results = await service.trainAllModules();

      if (mounted) {
        final successCount = results.values.where((r) => r.success).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('训练完成: $successCount/${results.length} 个模块成功'),
          ),
        );
        _loadData();
      }
    }
  }

  Future<void> _exportModels() async {
    try {
      final service = UnifiedSelfLearningService();
      final export = await service.exportAllModels();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出 ${export.modules.length} 个模块的模型'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  String _getModuleName(String moduleId) {
    switch (moduleId) {
      case 'smart_category':
        return '智能分类';
      case 'anomaly_detection':
        return '异常检测';
      case 'intent_recognition':
        return '意图识别';
      case 'budget_suggestion':
        return '预算建议';
      default:
        return moduleId;
    }
  }

  String _getStageName(LearningStage stage) {
    switch (stage) {
      case LearningStage.coldStart:
        return '冷启动';
      case LearningStage.collecting:
        return '收集中';
      case LearningStage.training:
        return '训练中';
      case LearningStage.active:
        return '正常运行';
      case LearningStage.degraded:
        return '降级运行';
    }
  }

  Color _getStageColor(LearningStage stage) {
    switch (stage) {
      case LearningStage.coldStart:
        return Colors.grey;
      case LearningStage.collecting:
        return Colors.blue;
      case LearningStage.training:
        return Colors.orange;
      case LearningStage.active:
        return Colors.green;
      case LearningStage.degraded:
        return Colors.red;
    }
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _getAccuracyDescription(double accuracy) {
    if (accuracy >= 0.9) return '学习效果优秀，继续保持！';
    if (accuracy >= 0.8) return '学习效果良好，还可以继续提升';
    if (accuracy >= 0.6) return '学习效果一般，需要更多数据';
    if (accuracy >= 0.4) return '学习效果较差，正在努力学习中';
    return '学习刚刚开始，需要更多使用数据';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }
}

/// 模块学习状态卡片（可单独使用）
class ModuleLearningStatusCard extends StatelessWidget {
  final String moduleId;
  final LearningStatus status;
  final LearningMetrics? metrics;
  final VoidCallback? onTrain;

  const ModuleLearningStatusCard({
    super.key,
    required this.moduleId,
    required this.status,
    this.metrics,
    this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getModuleIcon(),
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getModuleName(),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _buildStageChip(context),
              ],
            ),
            if (metrics != null) ...[
              const SizedBox(height: 12),
              _buildProgressBar(context),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '准确率: ${(metrics!.accuracy * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '规则: ${metrics!.totalRules}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            if (onTrain != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onTrain,
                child: const Text('立即训练'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStageChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStageColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStageName(),
        style: TextStyle(
          fontSize: 11,
          color: _getStageColor(),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    return LinearProgressIndicator(
      value: metrics?.accuracy ?? 0,
      backgroundColor: Colors.grey[200],
      valueColor: AlwaysStoppedAnimation<Color>(_getAccuracyColor()),
    );
  }

  IconData _getModuleIcon() {
    switch (moduleId) {
      case 'smart_category':
        return Icons.category;
      case 'anomaly_detection':
        return Icons.warning_amber;
      case 'intent_recognition':
        return Icons.chat_bubble_outline;
      case 'budget_suggestion':
        return Icons.account_balance_wallet;
      default:
        return Icons.psychology;
    }
  }

  String _getModuleName() {
    switch (moduleId) {
      case 'smart_category':
        return '智能分类';
      case 'anomaly_detection':
        return '异常检测';
      case 'intent_recognition':
        return '意图识别';
      case 'budget_suggestion':
        return '预算建议';
      default:
        return moduleId;
    }
  }

  String _getStageName() {
    switch (status.stage) {
      case LearningStage.coldStart:
        return '冷启动';
      case LearningStage.collecting:
        return '收集中';
      case LearningStage.training:
        return '训练中';
      case LearningStage.active:
        return '运行中';
      case LearningStage.degraded:
        return '降级';
    }
  }

  Color _getStageColor() {
    switch (status.stage) {
      case LearningStage.coldStart:
        return Colors.grey;
      case LearningStage.collecting:
        return Colors.blue;
      case LearningStage.training:
        return Colors.orange;
      case LearningStage.active:
        return Colors.green;
      case LearningStage.degraded:
        return Colors.red;
    }
  }

  Color _getAccuracyColor() {
    final accuracy = metrics?.accuracy ?? 0;
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
