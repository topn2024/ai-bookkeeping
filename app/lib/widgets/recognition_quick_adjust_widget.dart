import 'package:flutter/material.dart';

/// Quick adjustment widget for recognition results (第23章识别结果快速微调)
class RecognitionQuickAdjustWidget extends StatefulWidget {
  final RecognitionResult result;
  final ValueChanged<RecognitionResult> onResultChanged;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const RecognitionQuickAdjustWidget({
    super.key,
    required this.result,
    required this.onResultChanged,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  State<RecognitionQuickAdjustWidget> createState() => _RecognitionQuickAdjustWidgetState();
}

class _RecognitionQuickAdjustWidgetState extends State<RecognitionQuickAdjustWidget> {
  late RecognitionResult _result;
  final bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with confidence
          _buildHeader(theme),
          const SizedBox(height: 16),

          // Main content - Amount
          _buildAmountSection(theme),
          const SizedBox(height: 12),

          // Category quick select
          _buildCategorySection(theme),
          const SizedBox(height: 12),

          // Description
          _buildDescriptionSection(theme),
          const SizedBox(height: 16),

          // Action buttons
          _buildActionButtons(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final confidence = _result.confidence;
    final confidenceText = confidence >= 0.9
        ? '高置信度'
        : confidence >= 0.7
            ? '中等置信度'
            : '低置信度';
    final confidenceColor = confidence >= 0.9
        ? Colors.green
        : confidence >= 0.7
            ? Colors.orange
            : Colors.red;

    return Row(
      children: [
        Expanded(
          child: Text(
            '识别结果',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: confidenceColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                confidence >= 0.9
                    ? Icons.check_circle
                    : confidence >= 0.7
                        ? Icons.info
                        : Icons.warning,
                size: 14,
                color: confidenceColor,
              ),
              const SizedBox(width: 4),
              Text(
                confidenceText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: confidenceColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection(ThemeData theme) {
    return GestureDetector(
      onTap: () => _showAmountEditor(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _result.isExpense ? '-' : '+',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: _result.isExpense ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '¥${_result.amount.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.edit,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(ThemeData theme) {
    final suggestedCategories = _result.suggestedCategories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '分类',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            if (_result.category != null)
              _buildCategoryChip(theme, _result.category!, isSelected: true),
          ],
        ),
        if (suggestedCategories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestedCategories
                .where((c) => c != _result.category)
                .take(4)
                .map((category) => _buildCategoryChip(theme, category))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String category, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _result = _result.copyWith(category: category);
        });
        widget.onResultChanged(_result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 16,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              category,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w500 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(ThemeData theme) {
    return GestureDetector(
      onTap: () => _showDescriptionEditor(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _result.description ?? '添加备注...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _result.description != null
                      ? null
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(
              Icons.edit,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      children: [
        if (widget.onCancel != null)
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onCancel,
              child: const Text('取消'),
            ),
          ),
        if (widget.onCancel != null) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: widget.onConfirm,
            icon: const Icon(Icons.check),
            label: const Text('确认记账'),
          ),
        ),
      ],
    );
  }

  void _showAmountEditor() {
    final controller = TextEditingController(
      text: _result.amount.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '金额',
                  prefixText: '¥ ',
                ),
                onSubmitted: (value) {
                  final amount = double.tryParse(value);
                  if (amount != null && amount > 0) {
                    setState(() {
                      _result = _result.copyWith(amount: amount);
                    });
                    widget.onResultChanged(_result);
                  }
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final amount = double.tryParse(controller.text);
                      if (amount != null && amount > 0) {
                        setState(() {
                          _result = _result.copyWith(amount: amount);
                        });
                        widget.onResultChanged(_result);
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDescriptionEditor() {
    final controller = TextEditingController(text: _result.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '备注',
                  hintText: '添加备注信息...',
                ),
                onSubmitted: (value) {
                  setState(() {
                    _result = _result.copyWith(description: value.isEmpty ? null : value);
                  });
                  widget.onResultChanged(_result);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _result = _result.copyWith(
                          description: controller.text.isEmpty ? null : controller.text,
                        );
                      });
                      widget.onResultChanged(_result);
                      Navigator.pop(context);
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    final iconMap = {
      '餐饮': Icons.restaurant,
      '交通': Icons.directions_car,
      '购物': Icons.shopping_bag,
      '娱乐': Icons.movie,
      '住房': Icons.home,
      '医疗': Icons.medical_services,
      '教育': Icons.school,
      '通讯': Icons.phone,
      '工资': Icons.account_balance_wallet,
      '转账': Icons.swap_horiz,
    };
    return iconMap[category] ?? Icons.category;
  }
}

/// Recognition result model
class RecognitionResult {
  final double amount;
  final bool isExpense;
  final String? category;
  final String? description;
  final double confidence;
  final List<String> suggestedCategories;
  final DateTime? date;

  RecognitionResult({
    required this.amount,
    required this.isExpense,
    this.category,
    this.description,
    required this.confidence,
    this.suggestedCategories = const [],
    this.date,
  });

  RecognitionResult copyWith({
    double? amount,
    bool? isExpense,
    String? category,
    String? description,
    double? confidence,
    List<String>? suggestedCategories,
    DateTime? date,
  }) {
    return RecognitionResult(
      amount: amount ?? this.amount,
      isExpense: isExpense ?? this.isExpense,
      category: category ?? this.category,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      suggestedCategories: suggestedCategories ?? this.suggestedCategories,
      date: date ?? this.date,
    );
  }
}

/// Inline amount adjuster for quick edits
class InlineAmountAdjuster extends StatelessWidget {
  final double amount;
  final ValueChanged<double> onChanged;
  final List<double> quickAdjustments;

  const InlineAmountAdjuster({
    super.key,
    required this.amount,
    required this.onChanged,
    this.quickAdjustments = const [-10, -1, 1, 10],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: quickAdjustments.map((adj) {
        final isPositive = adj > 0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                final newAmount = amount + adj;
                if (newAmount > 0) {
                  onChanged(newAmount);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${isPositive ? '+' : ''}${adj.toInt()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isPositive ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
