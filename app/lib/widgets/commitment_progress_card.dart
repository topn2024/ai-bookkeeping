import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 承诺状态
enum CommitmentStatus {
  /// 进行中
  active,

  /// 已完成
  completed,

  /// 已失败
  failed,

  /// 已暂停
  paused,
}

extension CommitmentStatusExtension on CommitmentStatus {
  String get displayName {
    switch (this) {
      case CommitmentStatus.active:
        return '进行中';
      case CommitmentStatus.completed:
        return '已完成';
      case CommitmentStatus.failed:
        return '未达成';
      case CommitmentStatus.paused:
        return '已暂停';
    }
  }

  Color get color {
    switch (this) {
      case CommitmentStatus.active:
        return Colors.blue;
      case CommitmentStatus.completed:
        return Colors.green;
      case CommitmentStatus.failed:
        return Colors.red;
      case CommitmentStatus.paused:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case CommitmentStatus.active:
        return Icons.flag;
      case CommitmentStatus.completed:
        return Icons.emoji_events;
      case CommitmentStatus.failed:
        return Icons.close;
      case CommitmentStatus.paused:
        return Icons.pause;
    }
  }
}

/// 承诺类型
enum CommitmentType {
  /// 储蓄目标
  savings,

  /// 预算控制
  budgetControl,

  /// 钱龄提升
  moneyAge,

  /// 消费限制
  spendingLimit,

  /// 记账习惯
  recordingHabit,
}

extension CommitmentTypeExtension on CommitmentType {
  String get displayName {
    switch (this) {
      case CommitmentType.savings:
        return '储蓄目标';
      case CommitmentType.budgetControl:
        return '预算控制';
      case CommitmentType.moneyAge:
        return '钱龄提升';
      case CommitmentType.spendingLimit:
        return '消费限制';
      case CommitmentType.recordingHabit:
        return '记账习惯';
    }
  }

  IconData get icon {
    switch (this) {
      case CommitmentType.savings:
        return Icons.savings;
      case CommitmentType.budgetControl:
        return Icons.account_balance_wallet;
      case CommitmentType.moneyAge:
        return Icons.hourglass_full;
      case CommitmentType.spendingLimit:
        return Icons.money_off;
      case CommitmentType.recordingHabit:
        return Icons.edit_note;
    }
  }
}

/// 财务承诺数据
class FinancialCommitment {
  final String id;
  final String title;
  final String description;
  final CommitmentType type;
  final CommitmentStatus status;
  final double targetValue;
  final double currentValue;
  final DateTime startDate;
  final DateTime endDate;
  final String? rewardDescription;
  final List<String>? milestones;
  final int? currentMilestone;

  const FinancialCommitment({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.endDate,
    this.rewardDescription,
    this.milestones,
    this.currentMilestone,
  });

  /// 进度百分比 (0-1)
  double get progress => targetValue > 0
      ? (currentValue / targetValue).clamp(0.0, 1.0)
      : 0;

  /// 剩余天数
  int get remainingDays => endDate.difference(DateTime.now()).inDays;

  /// 是否即将到期（7天内）
  bool get isNearDeadline => remainingDays <= 7 && remainingDays > 0;

  /// 是否已过期
  bool get isExpired => DateTime.now().isAfter(endDate);

  /// 预计能否完成
  bool get isOnTrack {
    if (status != CommitmentStatus.active) return false;
    final totalDays = endDate.difference(startDate).inDays;
    final elapsedDays = DateTime.now().difference(startDate).inDays;
    if (totalDays <= 0 || elapsedDays <= 0) return true;
    final expectedProgress = elapsedDays / totalDays;
    return progress >= expectedProgress * 0.8; // 允许20%的容差
  }
}

/// 承诺进度卡片
///
/// 展示用户财务承诺的进度和状态
class CommitmentProgressCard extends StatelessWidget {
  /// 承诺数据
  final FinancialCommitment commitment;

  /// 是否展开显示详情
  final bool expanded;

  /// 点击回调
  final VoidCallback? onTap;

  /// 编辑回调
  final VoidCallback? onEdit;

  /// 放弃回调
  final VoidCallback? onAbandon;

  const CommitmentProgressCard({
    super.key,
    required this.commitment,
    this.expanded = false,
    this.onTap,
    this.onEdit,
    this.onAbandon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = commitment.status.color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: commitment.isNearDeadline
                ? Colors.orange.withOpacity(0.5)
                : theme.colorScheme.outline.withOpacity(0.1),
            width: commitment.isNearDeadline ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 主体内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 头部
                  _buildHeader(theme, statusColor),
                  const SizedBox(height: 16),

                  // 进度区域
                  _buildProgress(theme, statusColor),

                  // 里程碑
                  if (commitment.milestones != null && expanded) ...[
                    const SizedBox(height: 16),
                    _buildMilestones(theme),
                  ],

                  // 时间信息
                  const SizedBox(height: 12),
                  _buildTimeInfo(theme),

                  // 奖励信息
                  if (commitment.rewardDescription != null && expanded) ...[
                    const SizedBox(height: 12),
                    _buildReward(theme),
                  ],
                ],
              ),
            ),

            // 操作按钮（展开时显示）
            if (expanded && commitment.status == CommitmentStatus.active)
              _buildActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color statusColor) {
    return Row(
      children: [
        // 类型图标
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            commitment.type.icon,
            color: statusColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),

        // 标题和描述
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                commitment.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                commitment.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // 状态标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                commitment.status.icon,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                commitment.status.displayName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgress(ThemeData theme, Color statusColor) {
    final progress = commitment.progress;

    return Column(
      children: [
        // 进度数值
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatValue(commitment.currentValue),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            Text(
              '目标: ${_formatValue(commitment.targetValue)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 进度条
        Stack(
          children: [
            // 背景
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            // 进度
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.6),
                      statusColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            // 进度标签
            Positioned.fill(
              child: Center(
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progress > 0.5
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),

        // 预测状态
        if (commitment.status == CommitmentStatus.active) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                commitment.isOnTrack
                    ? Icons.check_circle_outline
                    : Icons.warning_amber,
                size: 14,
                color: commitment.isOnTrack ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                commitment.isOnTrack ? '进度正常，继续保持！' : '进度落后，需要加油！',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: commitment.isOnTrack ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMilestones(ThemeData theme) {
    final milestones = commitment.milestones!;
    final currentMilestone = commitment.currentMilestone ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '里程碑',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...milestones.asMap().entries.map((entry) {
          final index = entry.key;
          final milestone = entry.value;
          final isCompleted = index < currentMilestone;
          final isCurrent = index == currentMilestone;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green
                        : isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isCurrent
                                  ? Colors.white
                                  : theme.colorScheme.outline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    milestone,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCompleted
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTimeInfo(ThemeData theme) {
    final remaining = commitment.remainingDays;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: commitment.isNearDeadline
            ? Colors.orange.withOpacity(0.1)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 18,
            color: commitment.isNearDeadline
                ? Colors.orange
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commitment.isExpired
                      ? '已到期'
                      : remaining <= 0
                          ? '今天到期'
                          : '还剩 $remaining 天',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: commitment.isNearDeadline
                        ? Colors.orange
                        : null,
                  ),
                ),
                Text(
                  '${_formatDate(commitment.startDate)} - ${_formatDate(commitment.endDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReward(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.card_giftcard,
            size: 20,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '完成奖励',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  commitment.rewardDescription!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // 编辑按钮
          if (onEdit != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('编辑'),
              ),
            ),
          if (onEdit != null && onAbandon != null)
            const SizedBox(width: 12),
          // 放弃按钮
          if (onAbandon != null)
            Expanded(
              child: TextButton.icon(
                onPressed: onAbandon,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  '放弃',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}

/// 承诺列表
class CommitmentList extends StatelessWidget {
  /// 承诺列表
  final List<FinancialCommitment> commitments;

  /// 点击单个承诺的回调
  final Function(FinancialCommitment)? onCommitmentTap;

  /// 创建新承诺的回调
  final VoidCallback? onCreateNew;

  const CommitmentList({
    super.key,
    required this.commitments,
    this.onCommitmentTap,
    this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (commitments.isEmpty) {
      return _buildEmptyState(theme);
    }

    return Column(
      children: [
        ...commitments.map((commitment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CommitmentProgressCard(
                commitment: commitment,
                onTap: () => onCommitmentTap?.call(commitment),
              ),
            )),
        if (onCreateNew != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add),
            label: const Text('创建新承诺'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有财务承诺',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '设定一个财务目标，\n让我们一起完成！',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          if (onCreateNew != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateNew,
              icon: const Icon(Icons.add),
              label: const Text('创建第一个承诺'),
            ),
          ],
        ],
      ),
    );
  }
}
