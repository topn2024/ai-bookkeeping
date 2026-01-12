import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/voice/self_learning_service.dart';

/// 语音学习报告页面
///
/// 展示自学习系统的学习效果，包括：
/// - 学习统计概览
/// - 准确率曲线
/// - 已学习的规则列表
/// - 手动触发学习
class VoiceLearningReportPage extends StatefulWidget {
  const VoiceLearningReportPage({super.key});

  @override
  State<VoiceLearningReportPage> createState() => _VoiceLearningReportPageState();
}

class _VoiceLearningReportPageState extends State<VoiceLearningReportPage> {
  final SelfLearningService _learningService = SelfLearningService();
  bool _isLearning = false;
  String? _learningMessage;

  @override
  void initState() {
    super.initState();
    _learningService.addListener(_onMetricsChanged);
  }

  @override
  void dispose() {
    _learningService.removeListener(_onMetricsChanged);
    super.dispose();
  }

  void _onMetricsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _triggerLearning() async {
    setState(() {
      _isLearning = true;
      _learningMessage = null;
    });

    try {
      final result = await _learningService.triggerLearning();
      setState(() {
        _learningMessage = result.message;
        if (result.success && result.newRulesCount > 0) {
          _learningMessage = '学习完成！新增 ${result.newRulesCount} 条规则';
        }
      });
    } catch (e) {
      setState(() {
        _learningMessage = '学习失败: $e';
      });
    } finally {
      setState(() {
        _isLearning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _learningService.metrics;
    final rules = _learningService.learnedRules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习报告'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 学习统计概览
            _buildStatsOverview(metrics),

            // 准确率指标
            _buildAccuracyCard(metrics),

            // 学习操作
            _buildLearningActions(),

            // 已学习的规则
            _buildLearnedRulesSection(rules),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(LearningMetrics metrics) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Text(
                '学习进度',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${metrics.totalSamples} 样本',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.check_circle,
                  label: '确认',
                  value: metrics.confirmedCount.toString(),
                  color: Colors.green.shade300,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.edit,
                  label: '修改',
                  value: metrics.modifiedCount.toString(),
                  color: Colors.orange.shade300,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.cancel,
                  label: '取消',
                  value: metrics.cancelledCount.toString(),
                  color: Colors.red.shade300,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.auto_awesome,
                  label: '规则',
                  value: metrics.ruleCount.toString(),
                  color: Colors.purple.shade300,
                ),
              ),
            ],
          ),
        ],
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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyCard(LearningMetrics metrics) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                '识别效果',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 准确率
          _buildProgressIndicator(
            label: '识别准确率',
            value: metrics.accuracy,
            color: _getAccuracyColor(metrics.accuracy),
            description: '用户确认的比例',
          ),
          const SizedBox(height: 16),

          // 规则命中率
          _buildProgressIndicator(
            label: '规则命中率',
            value: metrics.ruleMatchRate,
            color: const Color(0xFF9C27B0),
            description: '学习规则匹配的比例',
          ),
          const SizedBox(height: 16),

          // 修改率（越低越好）
          _buildProgressIndicator(
            label: '修改率',
            value: metrics.modificationRate,
            color: const Color(0xFFFF9800),
            description: '需要用户修改的比例',
            isLowerBetter: true,
          ),

          if (metrics.lastLearningTime != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(
                  '上次学习: ${_formatDateTime(metrics.lastLearningTime!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressIndicator({
    required String label,
    required double value,
    required Color color,
    required String description,
    bool isLowerBetter = false,
  }) {
    final displayValue = (value * 100).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                Text(
                  '$displayValue%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (isLowerBetter) ...[
                  const SizedBox(width: 4),
                  Icon(
                    value < 0.2 ? Icons.trending_down : Icons.trending_up,
                    size: 16,
                    color: value < 0.2 ? Colors.green : Colors.orange,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildLearningActions() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                '学习操作',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLearning ? null : _triggerLearning,
              icon: _isLearning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isLearning ? '学习中...' : '立即优化'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (_learningMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _learningMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          Text(
            '提示：系统会在每天凌晨2点自动学习（样本数>100时）',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnedRulesSection(List<LearnedRule> rules) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.rule, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '已学习规则',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${rules.length} 条',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: AppColors.textHint.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '暂无学习规则',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '多使用语音助手，系统会逐渐学习你的习惯',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rules.length.clamp(0, 10),
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) => _buildRuleItem(rules[index]),
            ),

          if (rules.length > 10)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '还有 ${rules.length - 10} 条规则...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(LearnedRule rule) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getConfidenceColor(rule.confidence).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '${(rule.confidence * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getConfidenceColor(rule.confidence),
            ),
          ),
        ),
      ),
      title: Text(
        rule.pattern,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '→ ${rule.intent} · 命中${rule.frequency}次',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.info_outline, size: 20),
        onPressed: () => _showRuleDetails(rule),
      ),
    );
  }

  void _showRuleDetails(LearnedRule rule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '规则详情',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '创建于 ${_formatDateTime(rule.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildDetailRow('模式', rule.pattern),
            _buildDetailRow('意图', rule.intent),
            _buildDetailRow('置信度', '${(rule.confidence * 100).toStringAsFixed(1)}%'),
            _buildDetailRow('命中次数', '${rule.frequency}次'),

            const SizedBox(height: 16),
            const Text(
              '示例',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...rule.examples.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Text('• ', style: TextStyle(color: AppColors.textHint)),
                  Expanded(
                    child: Text(
                      e,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('关闭'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('什么是自学习？'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '语音助手会学习你的使用习惯，不断提升识别准确率：',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            _HelpItem(
              icon: Icons.check_circle,
              color: Colors.green,
              title: '确认',
              description: '你确认了语音助手的理解是正确的',
            ),
            _HelpItem(
              icon: Icons.edit,
              color: Colors.orange,
              title: '修改',
              description: '你纠正了语音助手的理解',
            ),
            _HelpItem(
              icon: Icons.cancel,
              color: Colors.red,
              title: '取消',
              description: '你取消了当前操作',
            ),
            SizedBox(height: 16),
            Text(
              '系统会根据这些反馈生成个性化规则，让语音助手越来越懂你。',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
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

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return AppTheme.primaryColor;
    return Colors.orange;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _HelpItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
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
