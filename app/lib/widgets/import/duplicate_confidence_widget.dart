import 'package:flutter/material.dart';
import '../../models/import_candidate.dart';
import '../../models/transaction.dart' show TransactionType;

/// Duplicate confidence visualization widget (第11.3节 去重置信度可视化)
class DuplicateConfidenceWidget extends StatelessWidget {
  final DuplicateCheckResult result;
  final bool showDetails;
  final VoidCallback? onTap;

  const DuplicateConfidenceWidget({
    super.key,
    required this.result,
    this.showDetails = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getLevelColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Confidence indicator
                _buildConfidenceIndicator(context),
                const SizedBox(width: 8),
                // Level text
                Text(
                  result.levelText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${result.score}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            // Reason text
            if (result.reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Score breakdown (expanded)
            if (showDetails && result.scoreBreakdown != null) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildScoreBreakdown(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(BuildContext context) {
    final color = _getLevelColor(context);

    // Confidence ring
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 3,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.2)),
          ),
          // Progress ring
          CircularProgressIndicator(
            value: result.score / 100,
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          // Icon
          Icon(
            _getLevelIcon(),
            size: 12,
            color: color,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown(BuildContext context) {
    final theme = Theme.of(context);
    final breakdown = result.scoreBreakdown!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '匹配详情',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        ...breakdown.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (entry.value / 30).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getLevelColor(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${entry.value}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getLevelColor(context),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getLevelColor(BuildContext context) {
    switch (result.level) {
      case DuplicateLevel.exact:
        return Colors.red;
      case DuplicateLevel.high:
        return Colors.red.shade700;
      case DuplicateLevel.medium:
        return Colors.orange;
      case DuplicateLevel.low:
        return Colors.amber;
      case DuplicateLevel.none:
        return Colors.green;
    }
  }

  IconData _getLevelIcon() {
    switch (result.level) {
      case DuplicateLevel.exact:
        return Icons.block;
      case DuplicateLevel.high:
        return Icons.warning;
      case DuplicateLevel.medium:
        return Icons.help;
      case DuplicateLevel.low:
        return Icons.info;
      case DuplicateLevel.none:
        return Icons.check;
    }
  }
}

/// Duplicate comparison dialog widget
class DuplicateComparisonDialog extends StatelessWidget {
  final ImportCandidate candidate;
  final VoidCallback? onImport;
  final VoidCallback? onSkip;

  const DuplicateComparisonDialog({
    super.key,
    required this.candidate,
    this.onImport,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matched = candidate.duplicateResult?.matchedTransaction;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '重复检测',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Confidence indicator
            if (candidate.duplicateResult != null)
              DuplicateConfidenceWidget(
                result: candidate.duplicateResult!,
                showDetails: true,
              ),
            const SizedBox(height: 16),

            // Comparison table
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '待导入',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: theme.dividerColor,
                        ),
                        const Expanded(
                          child: Text(
                            '已存在',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Comparison rows
                  _buildComparisonRow(
                    context,
                    '时间',
                    _formatDate(candidate.date),
                    matched != null ? _formatDate(matched.date) : '-',
                  ),
                  _buildComparisonRow(
                    context,
                    '金额',
                    candidate.amountText,
                    matched != null
                        ? '${matched.type == TransactionType.expense ? "-" : "+"}¥${matched.amount.toStringAsFixed(2)}'
                        : '-',
                  ),
                  _buildComparisonRow(
                    context,
                    '商户',
                    candidate.rawMerchant ?? '-',
                    matched?.rawMerchant ?? '-',
                  ),
                  _buildComparisonRow(
                    context,
                    '备注',
                    candidate.note ?? '-',
                    matched?.note ?? '-',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onImport?.call();
                  },
                  child: const Text('仍然导入'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onSkip?.call();
                  },
                  child: const Text('跳过'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context,
    String label,
    String left,
    String right, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final isDifferent = left != right;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  left,
                  style: TextStyle(
                    color: isDifferent ? Colors.orange : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: theme.dividerColor,
              ),
              Expanded(
                child: Text(
                  right,
                  style: TextStyle(
                    color: isDifferent ? Colors.orange : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Quick action chip for duplicate handling
class DuplicateActionChip extends StatelessWidget {
  final DuplicateLevel level;
  final ImportAction action;
  final ValueChanged<ImportAction>? onActionChanged;

  const DuplicateActionChip({
    super.key,
    required this.level,
    required this.action,
    this.onActionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ImportAction>(
      segments: const [
        ButtonSegment(
          value: ImportAction.import_,
          icon: Icon(Icons.add, size: 16),
          label: Text('导入'),
        ),
        ButtonSegment(
          value: ImportAction.skip,
          icon: Icon(Icons.skip_next, size: 16),
          label: Text('跳过'),
        ),
      ],
      selected: {action},
      onSelectionChanged: (selection) {
        onActionChanged?.call(selection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
