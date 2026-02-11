import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/category_localization_service.dart';
import '../services/voice/multi_intent_models.dart';

/// 金额补充输入组件
///
/// 列表形式显示缺失金额的意图，支持：
/// - 语音输入金额
/// - 键盘快速输入
/// - 跳过单个意图
class AmountSupplementWidget extends StatefulWidget {
  /// 不完整意图列表
  final List<IncompleteIntent> incompleteIntents;

  /// 补充金额回调
  final void Function(int index, double amount) onSupplementAmount;

  /// 跳过回调
  final ValueChanged<int>? onSkip;

  /// 全部跳过回调
  final VoidCallback? onSkipAll;

  /// 完成回调
  final VoidCallback? onComplete;

  /// 是否显示语音输入按钮
  final bool showVoiceInput;

  /// 语音输入回调
  final VoidCallback? onVoiceInput;

  const AmountSupplementWidget({
    super.key,
    required this.incompleteIntents,
    required this.onSupplementAmount,
    this.onSkip,
    this.onSkipAll,
    this.onComplete,
    this.showVoiceInput = true,
    this.onVoiceInput,
  });

  @override
  State<AmountSupplementWidget> createState() => _AmountSupplementWidgetState();
}

class _AmountSupplementWidgetState extends State<AmountSupplementWidget> {
  /// 当前选中的意图索引
  int _currentIndex = 0;

  /// 金额输入控制器
  final TextEditingController _amountController = TextEditingController();

  /// 焦点节点
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _amountController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.incompleteIntents.isEmpty) {
      return _buildEmptyState(context);
    }

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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

          // 进度指示器
          _buildProgressIndicator(context),

          // 当前意图卡片
          _buildCurrentIntentCard(context),

          // 金额输入区域
          _buildAmountInput(context),

          // 操作按钮
          _buildActionButtons(context),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          Text(
            '所有金额已补充完成',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (widget.onComplete != null)
            FilledButton(
              onPressed: widget.onComplete,
              child: const Text('继续'),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '补充金额',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${_currentIndex + 1} / ${widget.incompleteIntents.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: LinearProgressIndicator(
        value: widget.incompleteIntents.isEmpty
            ? 1.0
            : (_currentIndex + 1) / widget.incompleteIntents.length,
        backgroundColor: Colors.grey.withValues(alpha: 0.2),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
      ),
    );
  }

  Widget _buildCurrentIntentCard(BuildContext context) {
    if (_currentIndex >= widget.incompleteIntents.length) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final intent = widget.incompleteIntents[_currentIndex];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(intent.category).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  intent.category?.localizedCategoryName ?? '其他',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _getCategoryColor(intent.category),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (intent.dateTime != null)
                Text(
                  _formatTime(intent.dateTime!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            intent.originalText,
            style: theme.textTheme.bodyLarge,
          ),
          if (intent.merchant != null) ...[
            const SizedBox(height: 4),
            Text(
              intent.merchant!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountInput(BuildContext context) {
    final _ = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _amountController,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                border: const OutlineInputBorder(),
                suffixIcon: widget.showVoiceInput
                    ? IconButton(
                        icon: const Icon(Icons.mic),
                        onPressed: widget.onVoiceInput,
                        tooltip: '语音输入',
                      )
                    : null,
              ),
              autofocus: true,
              onSubmitted: (_) => _submitAmount(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 跳过按钮
          if (widget.onSkip != null)
            TextButton(
              onPressed: () => _skip(),
              child: const Text('跳过'),
            ),
          const Spacer(),
          // 确认按钮
          FilledButton(
            onPressed: _submitAmount,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('确认'),
                if (_currentIndex < widget.incompleteIntents.length - 1) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submitAmount() {
    final amount = double.tryParse(_amountController.text);
    if (amount != null && amount > 0) {
      widget.onSupplementAmount(_currentIndex, amount);
      _amountController.clear();

      if (_currentIndex < widget.incompleteIntents.length - 1) {
        setState(() {
          _currentIndex++;
        });
        _focusNode.requestFocus();
      } else {
        // 完成所有补充
        widget.onComplete?.call();
      }
    }
  }

  void _skip() {
    widget.onSkip?.call(_currentIndex);

    if (_currentIndex < widget.incompleteIntents.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _focusNode.requestFocus();
    } else {
      widget.onComplete?.call();
    }
  }

  Color _getCategoryColor(String? category) {
    final colors = {
      '餐饮': Colors.orange,
      '交通': Colors.blue,
      '购物': Colors.pink,
      '娱乐': Colors.purple,
      '医疗': Colors.red,
      '居住': Colors.teal,
      '通讯': Colors.indigo,
      '教育': Colors.green,
    };

    return colors[category] ?? Colors.grey;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return '今天 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
