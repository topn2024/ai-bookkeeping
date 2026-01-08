import 'package:flutter/material.dart';
import '../../services/import/batch_import_service.dart';

/// Import progress widget with visual feedback (第11章导入进度可视化)
class ImportProgressWidget extends StatelessWidget {
  final ImportStage stage;
  final int current;
  final int total;
  final String? message;
  final bool canCancel;
  final VoidCallback? onCancel;

  const ImportProgressWidget({
    super.key,
    required this.stage,
    required this.current,
    required this.total,
    this.message,
    this.canCancel = true,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = total > 0 ? current / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage indicator
          _buildStageIndicator(context),
          const SizedBox(height: 24),

          // Progress ring
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(_getStageColor(context)),
                  ),
                ),
                // Center content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getStageIcon(),
                      size: 32,
                      color: _getStageColor(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getStageColor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stage name
          Text(
            _getStageName(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Progress text
          Text(
            message ?? '$current / $total',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          // Estimated time
          if (total > 0 && current > 0 && stage != ImportStage.completed) ...[
            const SizedBox(height: 8),
            _buildEstimatedTime(context),
          ],
          const SizedBox(height: 24),

          // Cancel button
          if (canCancel && stage != ImportStage.completed)
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('取消导入'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStageIndicator(BuildContext context) {
    final stages = [
      ImportStage.detecting,
      ImportStage.parsing,
      ImportStage.deduplicating,
      ImportStage.importing,
      ImportStage.completed,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: stages.asMap().entries.map((entry) {
        final index = entry.key;
        final s = entry.value;
        final isActive = stage.index >= s.index;
        final isCurrent = stage == s;

        return Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? _getStageColor(context)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                border: isCurrent
                    ? Border.all(
                        color: _getStageColor(context),
                        width: 2,
                      )
                    : null,
              ),
              child: Center(
                child: isActive && !isCurrent
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimary,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            if (index < stages.length - 1)
              Container(
                width: 24,
                height: 2,
                color: isActive
                    ? _getStageColor(context)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEstimatedTime(BuildContext context) {
    // Simple estimation based on progress
    final remaining = total - current;
    final estimatedSeconds = remaining * 0.1; // Assume 0.1s per item

    String timeText;
    if (estimatedSeconds < 60) {
      timeText = '预计剩余 ${estimatedSeconds.toInt()} 秒';
    } else {
      final minutes = (estimatedSeconds / 60).ceil();
      timeText = '预计剩余 $minutes 分钟';
    }

    return Text(
      timeText,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }

  String _getStageName() {
    switch (stage) {
      case ImportStage.detecting:
        return '识别文件格式';
      case ImportStage.parsing:
        return '解析账单数据';
      case ImportStage.categorizing:
        return '智能分类中';
      case ImportStage.deduplicating:
        return '检查重复交易';
      case ImportStage.importing:
        return '导入交易记录';
      case ImportStage.completed:
        return '导入完成';
    }
  }

  IconData _getStageIcon() {
    switch (stage) {
      case ImportStage.detecting:
        return Icons.search;
      case ImportStage.parsing:
        return Icons.description;
      case ImportStage.categorizing:
        return Icons.category;
      case ImportStage.deduplicating:
        return Icons.compare_arrows;
      case ImportStage.importing:
        return Icons.cloud_upload;
      case ImportStage.completed:
        return Icons.check_circle;
    }
  }

  Color _getStageColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (stage) {
      case ImportStage.detecting:
        return theme.colorScheme.tertiary;
      case ImportStage.parsing:
        return theme.colorScheme.secondary;
      case ImportStage.categorizing:
        return theme.colorScheme.primary;
      case ImportStage.deduplicating:
        return Colors.orange;
      case ImportStage.importing:
        return theme.colorScheme.primary;
      case ImportStage.completed:
        return Colors.green;
    }
  }
}

/// Import result widget
class ImportResultWidget extends StatelessWidget {
  final int successCount;
  final int skippedCount;
  final int failedCount;
  final double totalExpense;
  final double totalIncome;
  final VoidCallback? onDone;
  final VoidCallback? onViewDetails;

  const ImportResultWidget({
    super.key,
    required this.successCount,
    required this.skippedCount,
    required this.failedCount,
    this.totalExpense = 0,
    this.totalIncome = 0,
    this.onDone,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuccess = failedCount == 0 && successCount > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success/Failure icon
          Icon(
            isSuccess ? Icons.check_circle : Icons.warning_amber,
            size: 64,
            color: isSuccess ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),

          Text(
            isSuccess ? '导入成功' : '导入完成（部分失败）',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                context,
                '成功',
                successCount.toString(),
                Colors.green,
              ),
              _buildStatItem(
                context,
                '跳过',
                skippedCount.toString(),
                Colors.orange,
              ),
              _buildStatItem(
                context,
                '失败',
                failedCount.toString(),
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount summary
          if (totalExpense > 0 || totalIncome > 0) ...[
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (totalExpense > 0)
                  Column(
                    children: [
                      Text(
                        '支出',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '-¥${totalExpense.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                if (totalIncome > 0)
                  Column(
                    children: [
                      Text(
                        '收入',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '+¥${totalIncome.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (onViewDetails != null)
                OutlinedButton(
                  onPressed: onViewDetails,
                  child: const Text('查看详情'),
                ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: onDone,
                child: const Text('完成'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
