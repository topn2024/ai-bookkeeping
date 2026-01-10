import 'package:flutter/material.dart';

import '../services/voice/multi_intent_models.dart';

/// 多意图确认组件
///
/// 显示语音识别出的多个意图列表，支持：
/// - 查看完整意图（可直接记录）
/// - 查看不完整意图（需要补充信息）
/// - 查看导航意图
/// - 单个意图的确认/取消/编辑
/// - 批量确认
class MultiIntentConfirmWidget extends StatelessWidget {
  /// 多意图结果
  final MultiIntentResult result;

  /// 确认全部回调
  final VoidCallback? onConfirmAll;

  /// 取消全部回调
  final VoidCallback? onCancelAll;

  /// 取消单个意图回调
  final ValueChanged<int>? onCancelItem;

  /// 编辑意图回调
  final ValueChanged<int>? onEditItem;

  /// 补充金额回调
  final void Function(int index, double amount)? onSupplementAmount;

  /// 是否显示噪音
  final bool showNoise;

  const MultiIntentConfirmWidget({
    super.key,
    required this.result,
    this.onConfirmAll,
    this.onCancelAll,
    this.onCancelItem,
    this.onEditItem,
    this.onSupplementAmount,
    this.showNoise = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildHeader(context),

          // 完整意图列表
          if (result.completeIntents.isNotEmpty) ...[
            _buildSectionHeader(context, '可直接记录', Icons.check_circle, Colors.green),
            ...result.completeIntents.asMap().entries.map(
              (entry) => _buildCompleteIntentItem(context, entry.key, entry.value),
            ),
          ],

          // 不完整意图列表
          if (result.incompleteIntents.isNotEmpty) ...[
            _buildSectionHeader(context, '需要补充金额', Icons.warning, Colors.orange),
            ...result.incompleteIntents.asMap().entries.map(
              (entry) => _buildIncompleteIntentItem(
                context,
                result.completeIntents.length + entry.key,
                entry.value,
              ),
            ),
          ],

          // 导航意图
          if (result.navigationIntent != null) ...[
            _buildSectionHeader(context, '稍后执行', Icons.open_in_new, Colors.blue),
            _buildNavigationItem(context, result.navigationIntent!),
          ],

          // 噪音折叠
          if (showNoise && result.filteredNoise.isNotEmpty)
            _buildNoiseSection(context),

          const SizedBox(height: 12),

          // 操作按钮
          _buildActionButtons(context),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '识别到 ${result.totalIntentCount} 条记录',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (onCancelAll != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onCancelAll,
              color: theme.colorScheme.onPrimaryContainer,
              tooltip: '取消全部',
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteIntentItem(
    BuildContext context,
    int index,
    CompleteIntent intent,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.green.withOpacity(0.1),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        intent.displayDescription,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: intent.category != null
          ? Text(
              intent.category!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¥${intent.amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onCancelItem != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onCancelItem?.call(index),
              color: theme.colorScheme.outline,
              tooltip: '移除',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncompleteIntentItem(
    BuildContext context,
    int index,
    IncompleteIntent intent,
  ) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.orange.withOpacity(0.1),
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        intent.displayDescription,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '缺少金额',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.orange,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onSupplementAmount != null)
            TextButton(
              onPressed: () => _showAmountInput(context, index - result.completeIntents.length),
              child: const Text('补充金额'),
            ),
          if (onCancelItem != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onCancelItem?.call(index),
              color: theme.colorScheme.outline,
              tooltip: '移除',
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(BuildContext context, NavigationIntent intent) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.blue.withOpacity(0.1),
        child: const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
      ),
      title: Text(
        '打开 ${intent.targetPageName}',
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        '记账完成后跳转',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildNoiseSection(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      leading: Icon(Icons.filter_alt, size: 20, color: theme.colorScheme.outline),
      title: Text(
        '已过滤 ${result.filteredNoise.length} 条无关内容',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      children: result.filteredNoise
          .map((noise) => ListTile(
                dense: true,
                title: Text(
                  noise,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancelAll,
              child: const Text('取消全部'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: result.completeIntents.isNotEmpty ? onConfirmAll : null,
              child: Text(
                result.incompleteIntents.isEmpty
                    ? '确认记录'
                    : '确认并继续',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAmountInput(BuildContext context, int incompleteIndex) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('补充金额'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '金额',
            prefixText: '¥ ',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.of(context).pop();
                onSupplementAmount?.call(incompleteIndex, amount);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
